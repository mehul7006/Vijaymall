import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/api/purchase_dto.dart';
import '../../data/purchase_store.dart';
import '../../data/validators.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_purchases_common.dart';

/// Strips spaces, dashes and a `+91` / `91` prefix so a typed phone can be
/// checked as a 10 digit mobile number.
String normPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[\s\-]'), '');
  if (d.startsWith('+91')) d = d.substring(3);
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  return d;
}

String? _fe(Map<String, String> f, String name) =>
    ApiException.fieldError(f, [name]);

// ---------------------------------------------------------------------------
// Supplier list (a tab of the purchases hub)
// ---------------------------------------------------------------------------

class SupplierListView extends StatefulWidget {
  const SupplierListView({super.key});
  @override
  State<SupplierListView> createState() => _SupplierListViewState();
}

class _SupplierListViewState extends State<SupplierListView> {
  final _q = TextEditingController();
  Timer? _debounce;
  bool _inactive = false;
  final List<SupplierDto> _rows = [];
  int _page = 0;
  bool _loading = true, _more = false, _hasMore = false;
  String? _error;
  String _total = '0';
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final gen = more ? _gen : ++_gen;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _rows.clear();
        _page = 0;
        _loading = true;
        _error = null;
      }
    });
    try {
      final r = await PurchaseStore.instance.api.suppliers(
          q: _q.text,
          active: _inactive ? null : true,
          page: more ? _page + 1 : 0,
          size: 20);
      if (!mounted || gen != _gen) return;
      setState(() {
        _rows.addAll(r.items);
        _page = r.page;
        _hasMore = r.hasMore;
        _total = r.totalLabel;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = purchaseError(e);
        _loading = false;
        _more = false;
      });
    }
  }

  Future<void> _add() async {
    final s = await showSupplierForm(context);
    if (s != null) {
      showToast(gt('Supplier added'));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppButton('Add supplier', icon: 'plus', block: true, onTap: _add),
      const SizedBox(height: 12),
      AppField(
        label: 'Search suppliers',
        controller: _q,
        placeholder: 'Name, phone or GSTIN',
        onChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), _load);
        },
      ),
      const SizedBox(height: 10),
      Row(children: [
        AppSwitch(
            value: _inactive,
            onChanged: (v) {
              setState(() => _inactive = v);
              _load();
            }),
        const SizedBox(width: 10),
        Expanded(child: Text(gt('Show switched-off suppliers'), style: pBody)),
      ]),
      const SizedBox(height: 10),
      if (_loading)
        const SkeletonRows(rows: 4)
      else if (_error != null)
        ErrorRetry(message: _error!, onRetry: _load)
      else if (_rows.isEmpty)
        EmptyState(
            icon: 'users',
            title: gt('No suppliers found'),
            copy: _q.text.trim().isEmpty
                ? gt('No suppliers yet - add one.')
                : '${gt('Nothing matches')} "${_q.text.trim()}".')
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('$_total ${gt('suppliers')}', style: pSub),
        ),
        for (final s in _rows) _SupplierRow(s),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppButton('Load more',
                variant: BtnVariant.secondary,
                block: true,
                loading: _more,
                onTap: _more ? null : () => _load(more: true)),
          ),
      ],
    ]);
  }
}

class _SupplierRow extends StatelessWidget {
  final SupplierDto s;
  const _SupplierRow(this.s);

  @override
  Widget build(BuildContext context) {
    final due = s.totalDuePaise;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => go('/admin/purchases?supplier=${s.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.sh1,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(s.name, style: pHead)),
                if (!s.active) ...[
                  const SizedBox(width: 8),
                  Pill(label: gt('Inactive'), bg: AppColors.bg, fg: AppColors.ink2),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                  [
                    if (s.phone.isNotEmpty) s.phone,
                    if (s.gstin.isNotEmpty) s.gstin,
                  ].join(' · '),
                  style: pSub),
              Text(
                  '${s.purchaseCount} ${gt('purchases')}'
                  '${s.lastInvoiceNo.isEmpty ? '' : ' · ${gt('last')} ${s.lastInvoiceNo}'}'
                  '${s.lastPurchaseAt == null ? '' : ' · ${pDate(s.lastPurchaseAt)}'}',
                  style: pSub),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (due > 0)
              Text('${gt('You owe')} ${pRs(due)}',
                  style: pHead.copyWith(color: AppColors.red))
            else if (due < 0)
              Text('${gt('Credit')} ${pRs(-due)}',
                  style: pHead.copyWith(color: AppColors.green))
            else
              Text(gt('Settled'), style: pSub),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supplier form (sheet)
// ---------------------------------------------------------------------------

Future<SupplierDto?> showSupplierForm(BuildContext context,
    {SupplierDto? edit, String? presetName}) {
  return showAppSheet<SupplierDto>(
    context: context,
    title: edit == null ? gt('Add supplier') : gt('Edit supplier'),
    builder: (ctx) => _SupplierForm(edit: edit, presetName: presetName),
  );
}

class _SupplierForm extends StatefulWidget {
  final SupplierDto? edit;
  final String? presetName;
  const _SupplierForm({this.edit, this.presetName});
  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  late final _name =
      TextEditingController(text: widget.edit?.name ?? widget.presetName ?? '');
  late final _gstin = TextEditingController(text: widget.edit?.gstin ?? '');
  late final _state = TextEditingController(text: widget.edit?.stateCode ?? '');
  late final _phone = TextEditingController(text: widget.edit?.phone ?? '');
  late final _address = TextEditingController(text: widget.edit?.address ?? '');
  late final _terms = TextEditingController(
      text: '${widget.edit?.paymentTermsDays ?? 0}');
  String _key = newIdempotencyKey();
  Map<String, String> _err = {};
  String? _existingId;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _gstin, _state, _phone, _address, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _stateError() {
    final s = _state.text.trim();
    final g = _gstin.text.trim().toUpperCase();
    if (g.length >= 2 && RegExp(r'^\d\d').hasMatch(g) && s.isNotEmpty && s != g.substring(0, 2)) {
      return 'State must match the GSTIN (${g.substring(0, 2)})';
    }
    if (s.isNotEmpty && !RegExp(r'^\d{2}$').hasMatch(s)) {
      return 'State code is 2 digits';
    }
    return null;
  }

  Future<void> _save() async {
    final local = <String, String>{};
    void chk(String f, String? m) {
      if (m != null) local[f] = m;
    }

    chk('name', Validators.text(_name.text, label: 'Name', required: true, max: 120));
    chk('gstin', Validators.gstin(_gstin.text));
    chk('stateCode', _stateError());
    // A phone already stored (maybe a landline) stays editable as it is.
    if (_phone.text.trim() != (widget.edit?.phone ?? '').trim()) {
      chk('phone', Validators.mobile(normPhone(_phone.text)));
    }
    chk('address', Validators.text(_address.text, label: 'Address', max: 300));
    chk('paymentTermsDays',
        Validators.whole(_terms.text, label: 'Payment days', max: 365));
    if (local.isNotEmpty) {
      setState(() => _err = {for (final e in local.entries) e.key: pgt(e.value)});
      return;
    }
    final g = _gstin.text.trim().toUpperCase();
    final body = {
      'name': _name.text.trim(),
      'gstin': g,
      'stateCode': g.isNotEmpty ? g.substring(0, 2) : _state.text.trim(),
      'phone': _phone.text.trim() == (widget.edit?.phone ?? '').trim()
          ? _phone.text.trim()
          : normPhone(_phone.text),
      'address': _address.text.trim(),
      'paymentTermsDays': int.tryParse(_terms.text.trim()) ?? 0,
    };
    setState(() {
      _busy = true;
      _err = {};
      _existingId = null;
    });
    try {
      final api = PurchaseStore.instance.api;
      final r = widget.edit == null
          ? await api.createSupplier(body, key: _key)
          : await api.updateSupplier(widget.edit!.id, body);
      if (mounted) Navigator.of(context).pop(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      String? existing;
      if (e.code == 'SUPPLIER_EXISTS' && e.payload is Map) {
        final d = (e.payload as Map)['details'];
        if (d is Map) existing = d['supplierId']?.toString();
      }
      if (e.code == 'IDEMPOTENCY_KEY_REUSED') _key = newIdempotencyKey();
      setState(() {
        _err = e.fields.isNotEmpty ? e.fields : {'_': e.messageWithRef};
        _existingId = existing;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = {'_': purchaseError(e)};
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGstin = _gstin.text.trim().length >= 2 &&
        RegExp(r'^\d\d').hasMatch(_gstin.text.trim());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppField(
          label: 'Name',
          controller: _name,
          maxLength: 120,
          error: _fe(_err, 'name')),
      const SizedBox(height: 10),
      FieldRow(flex: const [3, 2], children: [
        AppField(
            label: 'GSTIN (optional)',
            controller: _gstin,
            uppercase: true,
            maxLength: 15,
            placeholder: '24ABCDE1234F1Z5',
            error: _fe(_err, 'gstin'),
            onChanged: (v) => setState(() {
                  final g = v.trim().toUpperCase();
                  if (g.length >= 2 && RegExp(r'^\d\d').hasMatch(g)) {
                    _state.text = g.substring(0, 2);
                  }
                })),
        AppField(
            label: 'State code (2 digits)',
            controller: _state,
            numeric: true,
            maxLength: 2,
            readOnly: hasGstin,
            error: _fe(_err, 'stateCode')),
      ]),
      if (hasGstin) const PHint('The state follows the first two digits of the GSTIN.'),
      const SizedBox(height: 10),
      FieldRow(flex: const [3, 2], children: [
        AppField(
            label: 'Mobile (optional)',
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            error: _fe(_err, 'phone')),
        AppField(
            label: 'Payment terms (days, 0 to 365)',
            controller: _terms,
            numeric: true,
            maxLength: 3,
            error: _fe(_err, 'paymentTermsDays')),
      ]),
      const PHint('Used for the due date of new purchases when none is chosen.'),
      const SizedBox(height: 10),
      AppField(
          label: 'Address (optional)',
          controller: _address,
          maxLength: 300,
          error: _fe(_err, 'address')),
      if (_err['_'] != null) PNote(_err['_']!, error: true),
      if (_existingId != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: AppLink('Already exists - open it', onTap: () {
            Navigator.of(context).pop();
            go('/admin/purchases?supplier=$_existingId');
          }),
        ),
      const SizedBox(height: 14),
      AppButton(widget.edit == null ? 'Add supplier' : 'Save changes',
          block: true, loading: _busy, onTap: _busy ? null : _save),
      const SizedBox(height: 8),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Supplier account: summary, statement, refunds
// ---------------------------------------------------------------------------

class SupplierAccountScreen extends StatefulWidget {
  final String id;
  const SupplierAccountScreen({super.key, required this.id});
  @override
  State<SupplierAccountScreen> createState() => _SupplierAccountScreenState();
}

class _SupplierAccountScreenState extends State<SupplierAccountScreen> {
  SupplierDto? _s;
  StatementDto? _st;
  List<SupplierRefundDto> _refunds = const [];
  bool _loading = true, _busy = false;
  String? _error;
  String? _from, _to;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = PurchaseStore.instance.api;
      final r = await Future.wait([
        api.supplier(widget.id),
        api.statement(widget.id, from: _from, to: _to, page: _page, size: 20),
        api.refunds(widget.id).catchError((_) => <SupplierRefundDto>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _s = r[0] as SupplierDto;
        _st = r[1] as StatementDto;
        _refunds = r[2] as List<SupplierRefundDto>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = purchaseError(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final s = _s!;
    setState(() => _busy = true);
    try {
      await PurchaseStore.instance.api.setSupplierActive(s.id, !s.active);
      showToast(s.active ? gt('Supplier switched off') : gt('Supplier switched on'));
      await _load();
    } catch (e) {
      showToast(purchaseError(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final r = await showSupplierForm(context, edit: _s);
    if (r != null) {
      showToast(gt('Supplier saved'));
      _load();
    }
  }

  Future<void> _refund() async {
    final ok = await showAppSheet<bool>(
      context: context,
      title: gt('Record supplier refund'),
      builder: (ctx) => _RefundForm(supplier: _s!),
    );
    if (ok == true) {
      showToast(gt('Refund recorded'));
      PurchaseStore.instance.loadPayables();
      _load();
    }
  }

  Future<void> _pickRange() async {
    final a = await pickYmd(context, _from, last: DateTime.now());
    if (a == null || !mounted) return;
    final b = await pickYmd(context, _to ?? a, last: DateTime.now());
    if (b == null) return;
    setState(() {
      _from = a.compareTo(b) <= 0 ? a : b;
      _to = a.compareTo(b) <= 0 ? b : a;
      _page = 0;
    });
    _load();
  }

  String _kind(String k) {
    switch (k) {
      case 'PURCHASE':
        return gt('Purchase');
      case 'PAYMENT':
        return gt('Payment');
      case 'DEBIT_NOTE':
        return gt('Debit note');
      case 'SUPPLIER_REFUND':
        return gt('Refund received');
      case 'CREDIT_USED':
        return gt('Credit used');
    }
    return k;
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return PurchasePage(
      title: s?.name ?? gt('Supplier'),
      sub: gt('Account, statement and refunds'),
      back: true,
      onRefresh: _load,
      child: _loading
          ? const SkeletonRows(rows: 5)
          : _error != null || s == null
              ? ErrorRetry(message: _error ?? '', onRetry: _load)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CardPanel(
                    title: s.name,
                    trailing: s.active
                        ? Pill.active(gt('Active'))
                        : Pill(label: gt('Inactive'), bg: AppColors.bg, fg: AppColors.ink2),
                    child: Column(children: [
                      PKv('Mobile', s.phone.isEmpty ? '-' : s.phone),
                      PKv('GSTIN', s.gstin.isEmpty ? '-' : s.gstin),
                      PKv('State', s.stateCode.isEmpty ? '-' : s.stateCode),
                      PKv('Address', s.address.isEmpty ? '-' : s.address),
                      PKv('Payment terms', '${s.paymentTermsDays} ${gt('days')}'),
                      PKv('Purchases', '${s.purchaseCount}'),
                      const Divider(height: 18, color: AppColors.line),
                      PKv(
                          s.balancePaise < 0 ? 'Supplier owes you' : 'You owe',
                          pRs(s.balancePaise.abs()),
                          bold: true,
                          color: s.balancePaise > 0 ? AppColors.red : AppColors.ink),
                      PKv('Usable credit', pRs(s.creditPaise)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: AppButton('Edit',
                                variant: BtnVariant.secondary, onTap: _edit)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: AppButton(s.active ? 'Switch off' : 'Switch on',
                                variant: BtnVariant.secondary,
                                loading: _busy,
                                onTap: _busy ? null : _toggle)),
                      ]),
                      const SizedBox(height: 8),
                      AppButton('New purchase from this supplier',
                          icon: 'plus',
                          block: true,
                          disabled: !s.active,
                          onTap: () => go('/admin/purchases?new=1&supplier=${s.id}')),
                      if (s.creditPaise > 0) ...[
                        const SizedBox(height: 8),
                        AppButton('Record refund from supplier',
                            variant: BtnVariant.secondary,
                            block: true,
                            onTap: _refund),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _statement(),
                  if (_refunds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CardPanel(
                      title: gt('Refunds received'),
                      child: Column(children: [
                        for (final r in _refunds)
                          PKv('${pDate(r.receivedAt)} · ${modeLabel(r.mode)}'
                              '${r.reference.isEmpty ? '' : ' · ${r.reference}'}',
                              pRs(r.amountPaise)),
                      ]),
                    ),
                  ],
                ]),
    );
  }

  Widget _statement() {
    final st = _st!;
    return CardPanel(
      title: gt('Statement'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: AppButton(
                  _from == null ? 'All dates' : '${pDate(_from)} - ${pDate(_to)}',
                  variant: BtnVariant.secondary,
                  onTap: _pickRange)),
          if (_from != null) ...[
            const SizedBox(width: 8),
            AppButton('Clear', variant: BtnVariant.secondary, onTap: () {
              setState(() {
                _from = null;
                _to = null;
                _page = 0;
              });
              _load();
            }),
          ],
        ]),
        const SizedBox(height: 10),
        PKv('Opening balance', pRs(st.openingBalancePaise)),
        PKv('Closing balance', pRs(st.closingBalancePaise), bold: true),
        const PHint('Positive = you owe the supplier. Negative = the supplier owes you.'),
        const SizedBox(height: 6),
        if (st.rows.items.isEmpty)
          Text(gt('No activity in this period.'), style: pSub)
        else
          for (final r in st.rows.items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: r.purchaseId == null
                  ? null
                  : () => go('/admin/purchases?id=${r.purchaseId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                          r.kind == 'PAYMENT' && r.mode.toUpperCase() == 'CREDIT_NOTE'
                              ? '${gt('Adjusted with credit note')} ${r.reference}'
                              : r.kind == 'CREDIT_USED'
                                  ? gt('Credit used (adjusted)')
                                  : _kind(r.kind),
                          style: pHead),
                      Text(
                          [
                            pDate(r.date),
                            if (r.invoiceNo.isNotEmpty) r.invoiceNo,
                            if (r.mode.isNotEmpty) modeLabel(r.mode),
                            if (r.reference.isNotEmpty && r.reference != r.invoiceNo)
                              r.reference,
                          ].join(' · '),
                          style: pSub),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${r.amountPaise > 0 ? '+' : ''}${pRs(r.amountPaise)}',
                        style: pHead.copyWith(
                            color: r.amountPaise < 0 ? AppColors.green : AppColors.ink)),
                    Text('${gt('Bal')} ${pRs(r.balancePaise)}', style: pSub),
                  ]),
                ]),
              ),
            ),
        if (st.rows.page > 0 || st.rows.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(
                  child: AppButton('Previous',
                      variant: BtnVariant.secondary,
                      disabled: st.rows.page == 0,
                      onTap: () {
                        setState(() => _page = st.rows.page - 1);
                        _load();
                      })),
              const SizedBox(width: 8),
              Expanded(
                  child: AppButton('Next',
                      variant: BtnVariant.secondary,
                      disabled: !st.rows.hasMore,
                      onTap: () {
                        setState(() => _page = st.rows.page + 1);
                        _load();
                      })),
            ]),
          ),
      ]),
    );
  }
}

class _RefundForm extends StatefulWidget {
  final SupplierDto supplier;
  const _RefundForm({required this.supplier});
  @override
  State<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends State<_RefundForm> {
  late final _amount =
      TextEditingController(text: paiseToText(widget.supplier.creditPaise));
  final _ref = TextEditingController();
  String _mode = 'CASH';
  String _key = newIdempotencyKey();
  Map<String, String> _err = {};
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = rsToPaise(_amount.text);
    final local = <String, String>{};
    if (p == null || p < 1) {
      local['amountPaise'] = gt('Enter an amount of at least Rs 0.01');
    } else if (p > widget.supplier.creditPaise) {
      local['amountPaise'] = pf('At most {0}', [pRs(widget.supplier.creditPaise)]);
    }
    final r = Validators.text(_ref.text, label: 'Reference', max: 80);
    if (r != null) local['reference'] = pgt(r);
    if (local.isNotEmpty) {
      setState(() => _err = local);
      return;
    }
    setState(() {
      _busy = true;
      _err = {};
    });
    try {
      await PurchaseStore.instance.api.refund(
          widget.supplier.id,
          {
            'amountPaise': p,
            'mode': _mode,
            if (_ref.text.trim().isNotEmpty) 'reference': _ref.text.trim(),
          },
          _key);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.code == 'IDEMPOTENCY_KEY_REUSED') _key = newIdempotencyKey();
      if (mounted) {
        setState(() {
          final okKeys = e.fields.keys.any((k) => const {'amountPaise', 'mode', 'reference'}.contains(k));
          _err = e.fields.isNotEmpty && okKeys ? e.fields : {'_': e.messageWithRef};
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = {'_': purchaseError(e)};
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Hint('${gt('Credit available')}: ${pRs(widget.supplier.creditPaise)}. '
          '${gt('Use this when the supplier paid money back.')}'),
      const SizedBox(height: 10),
      AppField(
          label: 'Amount (Rs)',
          controller: _amount,
          numeric: true,
          error: _fe(_err, 'amountPaise')),
      const SizedBox(height: 10),
      Text(gt('Received by'), style: pHead),
      const SizedBox(height: 6),
      PChoice<String>(
        options: const [
          ('CASH', 'Cash'),
          ('UPI', 'UPI'),
          ('CARD', 'Card'),
          ('BANK', 'Bank'),
          ('CHEQUE', 'Cheque'),
        ],
        value: _mode,
        onChanged: (v) => setState(() => _mode = v),
      ),
      if (_fe(_err, 'mode') != null) PNote(_fe(_err, 'mode')!, error: true),
      const SizedBox(height: 10),
      AppField(
          label: 'Reference (optional)',
          controller: _ref,
          maxLength: 80,
          error: _fe(_err, 'reference')),
      if (_err['_'] != null) PNote(_err['_']!, error: true),
      const SizedBox(height: 14),
      AppButton('Record refund',
          block: true, loading: _busy, onTap: _busy ? null : _save),
      const SizedBox(height: 8),
    ]);
  }
}
