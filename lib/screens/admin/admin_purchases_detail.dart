import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/api/purchase_dto.dart';
import '../../data/purchase_file_view.dart';
import '../../data/purchase_store.dart';
import '../../data/validators.dart';
import '../../data/web_file_picker.dart';
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
import 'admin_purchases_reports.dart' show showPriceHistory;

String? _fe(Map<String, String> f, String name) =>
    ApiException.fieldError(f, [name]);

/// Server `details.<key>` of an error, when present.
dynamic _detail(ApiException e, String key) {
  final p = e.payload;
  if (p is Map && p['details'] is Map) return (p['details'] as Map)[key];
  return null;
}

/// `#/admin/purchases?id=<purchase>` - one purchase with its lines, GST by
/// slab, payments, debit notes and invoice file.
class PurchaseDetailScreen extends StatefulWidget {
  final String id;
  const PurchaseDetailScreen({super.key, required this.id});
  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  final _store = PurchaseStore.instance;
  PurchaseDto? _p;
  SupplierDto? _sup;
  List<PurchaseReturnDto> _returns = const [];
  String _rounding = 'PAISE';
  bool _loading = true, _busy = false;
  String? _error;
  List<String> _warnings = const [];

  @override
  void initState() {
    super.initState();
    _warnings = _store.postWarnings.remove(widget.id) ?? const [];
    _store.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final p = await _store.api.get(widget.id, rounding: _rounding);
      final r = await _store.api
          .returnsOf(widget.id)
          .then((v) => v.items)
          .catchError((_) => <PurchaseReturnDto>[]);
      SupplierDto? s;
      try {
        s = await _store.api.supplier(p.supplierId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _p = p;
        _returns = r;
        _sup = s;
        _loading = false;
      });
      _store.ensurePacks(p.items.map((e) => e.productId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = purchaseError(e);
        _loading = false;
      });
    }
  }

  void _replace(PurchaseDto p) {
    setState(() => _p = p);
    _store.loadPayables();
    _load(quiet: true);
  }

  String _q(PurchaseLineDto l, int n, {bool plus = true}) =>
      _store.qty(l.productId, n, plus: plus);

  // ---- actions ---------------------------------------------------------------

  Future<void> _addPayment() async {
    final r = await showAppSheet<PurchaseDto>(
      context: context,
      title: gt('Add payment'),
      builder: (ctx) => _PaymentForm(p: _p!, sup: _sup, returns: _returns),
    );
    if (r != null) {
      showToast(gt('Payment recorded'));
      _replace(r);
    }
  }

  Future<void> _returnGoods() async {
    final r = await showAppSheet<PurchaseReturnDto>(
      context: context,
      title: gt('Return goods'),
      builder: (ctx) => _ReturnForm(p: _p!),
    );
    if (r != null) {
      showToast('${gt('Debit note')} ${r.noteNo} · ${pRs(r.totalPaise)}');
      _store.loadPayables();
      _load(quiet: true);
    }
  }

  Future<void> _edit() async {
    final r = await showAppSheet<PurchaseDto>(
      context: context,
      title: gt('Edit invoice details'),
      builder: (ctx) => _EditForm(p: _p!),
    );
    if (r != null) {
      showToast(gt('Saved'));
      if (r.warnings.isNotEmpty) setState(() => _warnings = r.warnings);
      setState(() => _p = r);
      _load(quiet: true);
    }
  }

  Future<void> _upload() async {
    final f = await pickImageFile(
        accept: 'application/pdf,image/jpeg,image/png,image/webp');
    if (f == null || !mounted) return;
    final n = f.name.toLowerCase();
    if (!RegExp(r'\.(pdf|jpe?g|png|webp)$').hasMatch(n)) {
      showToast(gt('Choose a PDF, JPEG, PNG or WebP file.'), 'error');
      return;
    }
    if (f.bytes.length > 5 * 1024 * 1024) {
      showToast(gt('This file is larger than 5 MB. Choose a smaller one.'), 'error');
      return;
    }
    setState(() => _busy = true);
    try {
      final p = await _store.api.uploadAttachment(widget.id, f.bytes, f.name);
      if (!mounted) return;
      showToast(gt('Invoice file saved'));
      setState(() => _p = p);
    } catch (e) {
      showToast(purchaseError(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewFile() async {
    setState(() => _busy = true);
    try {
      final r = await _store.api.attachmentBytes(widget.id);
      if (!mounted) return;
      final ct = r.contentType.split(';').first.trim();
      if (ct.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: InteractiveViewer(
                    child: Image.memory(Uint8List.fromList(r.bytes))),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: AppButton('Open in new tab',
                          variant: BtnVariant.secondary,
                          onTap: () => openBytesInTab(r.bytes, ct))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: AppButton('Close',
                          onTap: () => Navigator.of(ctx).pop())),
                ]),
              ),
            ]),
          ),
        );
      } else if (!openBytesInTab(r.bytes, ct)) {
        showToast(gt('Could not open the file here.'), 'error');
      }
    } catch (e) {
      showToast(purchaseError(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFile() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gt('Remove invoice file?')),
        content: Text(gt('The uploaded file will be deleted.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(gt('Cancel'))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(gt('Remove'),
                  style: const TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final p = await _store.api.deleteAttachment(widget.id);
      if (mounted) setState(() => _p = p);
    } catch (e) {
      showToast(purchaseError(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- UI ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return PurchasePage(
      title: p == null
          ? gt('Purchase')
          : (p.invoiceNo.isEmpty ? gt('Purchase') : '${gt('Invoice')} ${p.invoiceNo}'),
      sub: p?.supplierName ?? '',
      back: true,
      onRefresh: _load,
      child: _loading
          ? const SkeletonRows(rows: 6)
          : _error != null || p == null
              ? ErrorRetry(message: _error ?? '', onRetry: _load)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_warnings.isNotEmpty) _warningBanner(),
                  _header(p),
                  const SizedBox(height: 12),
                  _lines(p),
                  const SizedBox(height: 12),
                  CardPanel(
                    title: gt('GST by slab'),
                    child: GstSlabTable(rows: slabsOf(p)),
                  ),
                  const SizedBox(height: 12),
                  _payments(p),
                  const SizedBox(height: 12),
                  _returnsCard(p),
                  const SizedBox(height: 12),
                  _fileCard(p),
                ]),
    );
  }

  Widget _warningBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.goldTint,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.gold),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              gt('Same invoice number was entered before: check you are not counting this delivery twice.'),
              style: pHead.copyWith(color: AppColors.goldInk)),
          for (final w in _warnings) Text(w, style: pSub),
        ]),
      );

  Widget _header(PurchaseDto p) {
    final credit = p.duePaise < 0;
    return CardPanel(
      title: p.supplierName,
      trailing: payBadges(p.paymentStatus, p.overdue, p.duePaise),
      child: Column(children: [
        PKv('Invoice date', pDate(p.invoiceDate)),
        PKv('Received', pDate(p.receivedDate)),
        PKv('Due date', p.dueDate == null ? '-' : pDate(p.dueDate)),
        PKv('GST type', gstModeLabel(p.gstMode)),
        PKv('Tax', p.interState ? gt('IGST (inter-state)') : 'CGST + SGST'),
        if (p.supplierPhone.isNotEmpty) PKv('Mobile', p.supplierPhone),
        if (p.supplierGstin.isNotEmpty) PKv('Supplier GSTIN', p.supplierGstin),
        if (p.supplierStateCode.isNotEmpty) PKv('State', p.supplierStateCode),
        if (p.note.isNotEmpty) PKv('Note', p.note),
        if (p.attachmentNote.isNotEmpty) PKv('Link / note', p.attachmentNote),
        const Divider(height: 18, color: AppColors.line),
        PKv('Goods (taxable)', pRs(p.taxablePaise)),
        if (p.lineDiscountPaise + p.docDiscountPaise > 0)
          PKv('Discounts', '-${pRs(p.lineDiscountPaise + p.docDiscountPaise)}'),
        PKv('CGST', pRs(p.cgstPaise)),
        PKv('SGST', pRs(p.sgstPaise)),
        PKv('IGST', pRs(p.igstPaise)),
        if (p.cessPaise > 0) PKv('Cess', pRs(p.cessPaise)),
        if (p.freightPaise > 0) PKv('Freight', pRs(p.freightPaise)),
        if (p.freightGstPaise > 0)
          PKv(pf('Freight GST ({0}%)', [p.freightGstPercent]), pRs(p.freightGstPaise)),
        if (p.roundOffPaise != 0) PKv('Round off', pRs(p.roundOffPaise)),
        PKv('Total', pRs(p.totalCostPaise), bold: true),
        PKv('Paid', pRs(p.paidPaise)),
        if (p.returnedPaise > 0) PKv('Returned', pRs(p.returnedPaise)),
        PKv(credit ? 'Supplier owes you' : 'Due', pRs(p.duePaise.abs()),
            bold: true,
            color: p.duePaise > 0
                ? AppColors.red
                : credit
                    ? AppColors.green
                    : AppColors.ink),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: AppButton('Edit details',
                  variant: BtnVariant.secondary, onTap: _edit)),
          const SizedBox(width: 8),
          Expanded(
              child: AppButton('Supplier account',
                  variant: BtnVariant.secondary,
                  onTap: () => go('/admin/purchases?supplier=${p.supplierId}'))),
        ]),
      ]),
    );
  }

  Widget _lines(PurchaseDto p) {
    final rounded = _rounding == 'EXACT' ? 4 : 2;
    return CardPanel(
      title: gt('Items'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(gt('Unit cost'), style: pSub),
          const SizedBox(width: 8),
          PChoice<String>(
            options: const [
              ('PAISE', 'To the paisa'),
              ('RUPEE', 'To the rupee'),
              ('EXACT', 'Exact'),
            ],
            value: _rounding,
            onChanged: (v) {
              setState(() => _rounding = v);
              _load(quiet: true);
            },
          ),
        ]),
        const SizedBox(height: 8),
        for (final l in p.items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.name, style: pHead)),
                Text(pRs(l.lineTotalPaise), style: pHead),
              ]),
              const SizedBox(height: 2),
              Text(
                  '${gt('Stock')} ${_q(l, l.received)}'
                  '${l.freeQty > 0 ? ' (${l.qty} ${gt('paid')} + ${l.freeQty} ${gt('free')})' : ''}',
                  style: pHead.copyWith(color: AppColors.green)),
              if (l.returnedQty > 0)
                Text('${gt('Returned')} ${_q(l, -l.returnedQty)}',
                    style: pSub.copyWith(color: AppColors.red)),
              const SizedBox(height: 4),
              Text(
                  '${gt('Cost')} ${pRs(l.unitCostPaise)} · GST ${l.gstPercent}%'
                  '${l.discountPercent != null && l.discountPercent! > 0 ? ' · ${l.discountPercent}% ${gt('off')}' : ''}'
                  '${l.lineDiscountPaise + l.docDiscountSharePaise > 0 ? ' · ${gt('discount')} ${pRs(l.lineDiscountPaise + l.docDiscountSharePaise)}' : ''}',
                  style: pSub),
              Text(
                  '${gt('Taxable')} ${pRs(l.taxablePaise)} · '
                  '${l.igstPaise > 0 ? 'IGST ${pRs(l.igstPaise)}' : 'CGST ${pRs(l.cgstPaise)} + SGST ${pRs(l.sgstPaise)}'}'
                  '${l.cessPaise > 0 ? ' + ${gt('cess')} ${pRs(l.cessPaise)}' : ''}',
                  style: pSub),
              Text(
                  '${gt('Landed cost per unit')} ${pRsD(l.landedUnitCostRoundedPaise, decimals: rounded)}'
                  '${_rounding == 'EXACT' ? '' : ' (${gt('exact')} ${pRsD(l.landedUnitCostPaise, decimals: 4)})'}',
                  style: pSub.copyWith(color: AppColors.ink2)),
              if (l.batchNo.isNotEmpty || l.expiryDate != null || l.hsn.isNotEmpty)
                Text(
                    [
                      if (l.hsn.isNotEmpty) 'HSN ${l.hsn}',
                      if (l.batchNo.isNotEmpty) '${gt('Batch')} ${l.batchNo}',
                      if (l.expiryDate != null) '${gt('Expiry')} ${pDate(l.expiryDate)}',
                    ].join(' · '),
                    style: pSub),
              if (l.mrpPaise != null || l.sellingPricePaise != null)
                Text(
                    [
                      if (l.mrpPaise != null) 'MRP ${pRs(l.mrpPaise!)}',
                      if (l.sellingPricePaise != null) '${gt('Price')} ${pRs(l.sellingPricePaise!)}',
                      if (l.applyToVariant) gt('applied to product'),
                    ].join(' · '),
                    style: pSub),
              Align(
                alignment: Alignment.centerLeft,
                child: AppLink('Price history', size: 12,
                    onTap: () => _priceHistory(l)),
              ),
            ]),
          ),
      ]),
    );
  }

  void _priceHistory(PurchaseLineDto l) {
    showPriceHistory(context, l.productId, l.name);
  }

  Widget _payments(PurchaseDto p) {
    return CardPanel(
      title: gt('Payments'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (p.payments.isEmpty)
          Text(gt('Nothing paid yet.'), style: pSub)
        else
          for (final x in p.payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        x.mode.toUpperCase() == 'CREDIT_NOTE'
                            ? '${gt('Adjusted with credit note')} ${x.reference}'
                            : modeLabel(x.mode),
                        style: pHead),
                    Text(
                        [
                          pDate(x.paidAt),
                          if (x.reference.isNotEmpty && x.mode.toUpperCase() != 'CREDIT_NOTE') x.reference,
                          if (x.note.isNotEmpty) x.note,
                        ].join(' · '),
                        style: pSub),
                  ]),
                ),
                Text(pRs(x.amountPaise), style: pHead),
              ]),
            ),
        const SizedBox(height: 10),
        if (p.duePaise > 0)
          AppButton('Add payment', icon: 'plus', block: true, onTap: _addPayment)
        else
          Text(
              p.duePaise < 0
                  ? gt('Supplier credit: no more payments. Use it on another purchase or record a refund from the supplier account.')
                  : gt('Fully paid.'),
              style: pSub),
      ]),
    );
  }

  Widget _returnsCard(PurchaseDto p) {
    return CardPanel(
      title: gt('Returns (debit notes)'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_returns.isEmpty)
          Text(gt('No goods returned.'), style: pSub)
        else
          for (final r in _returns)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.noteNo, style: pHead)),
                  Text(pRs(r.totalPaise), style: pHead),
                ]),
                Text('${pDate(r.createdAt)} · ${r.reason}', style: pSub),
                Text(
                    '${gt('Taxable')} ${pRs(r.taxablePaise)} · '
                    '${r.igstPaise > 0 ? 'IGST ${pRs(r.igstPaise)}' : 'CGST ${pRs(r.cgstPaise)} + SGST ${pRs(r.sgstPaise)}'}'
                    '${r.cessPaise > 0 ? ' + ${gt('cess')} ${pRs(r.cessPaise)}' : ''}',
                    style: pSub),
                for (final l in r.items)
                  Text('${l.name} · ${_store.qty(l.productId, -l.qty)}', style: pSub),
              ]),
            ),
        if (p.canReturn) ...[
          const SizedBox(height: 10),
          AppButton('Return goods',
              variant: BtnVariant.secondary, block: true, onTap: _returnGoods),
        ],
      ]),
    );
  }

  Widget _fileCard(PurchaseDto p) {
    return CardPanel(
      title: gt('Invoice file'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            p.hasAttachment
                ? gt('An invoice file is attached.')
                : gt('No invoice file yet. PDF, JPEG, PNG or WebP, up to 5 MB.'),
            style: pSub),
        const SizedBox(height: 10),
        if (p.hasAttachment)
          Row(children: [
            Expanded(
                child: AppButton('View',
                    variant: BtnVariant.secondary,
                    loading: _busy,
                    onTap: _busy ? null : _viewFile)),
            const SizedBox(width: 8),
            Expanded(
                child: AppButton('Replace',
                    variant: BtnVariant.secondary,
                    onTap: _busy ? null : _upload)),
            const SizedBox(width: 8),
            Expanded(
                child: AppButton('Remove',
                    variant: BtnVariant.secondary,
                    onTap: _busy ? null : _removeFile)),
          ])
        else
          AppButton('Upload invoice file',
              block: true, loading: _busy, onTap: _busy ? null : _upload),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Add payment (money or supplier credit)
// ---------------------------------------------------------------------------

class _PaymentForm extends StatefulWidget {
  final PurchaseDto p;
  final SupplierDto? sup;
  final List<PurchaseReturnDto> returns;
  const _PaymentForm({required this.p, this.sup, required this.returns});
  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  late final _amount = TextEditingController(text: paiseToText(widget.p.duePaise));
  final _ref = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'CASH';
  bool _credit = false;
  String? _noteId;
  List<PurchaseReturnDto> _notes = const [];
  bool _loadingNotes = false;
  String _key = newIdempotencyKey();
  Map<String, String> _err = {};
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _hasCredit => (widget.sup?.creditPaise ?? 0) > 0;

  /// Debit notes of this supplier's credit purchases (not this purchase).
  Future<void> _loadNotes() async {
    setState(() => _loadingNotes = true);
    try {
      final api = PurchaseStore.instance.api;
      final pur = await api.list(
          supplierId: widget.p.supplierId, paymentStatus: 'PAID', size: 50);
      final out = <PurchaseReturnDto>[];
      for (final x in pur.items.where((e) => e.duePaise < 0 && e.id != widget.p.id)) {
        out.addAll((await api.returnsOf(x.id)).items);
      }
      if (!mounted) return;
      setState(() {
        _notes = out;
        _noteId = out.isEmpty ? null : out.first.id;
        _loadingNotes = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingNotes = false;
          _err = {'_': purchaseError(e)};
        });
      }
    }
  }

  Future<void> _save() async {
    final due = widget.p.duePaise;
    final a = rsToPaise(_amount.text);
    final local = <String, String>{};
    if (a == null || a < 1) {
      local['amountPaise'] = gt('Enter an amount of at least Rs 0.01');
    } else if (a > due) {
      local['amountPaise'] = pf('At most {0}', [pRs(due)]);
    }
    final r = Validators.text(_ref.text, label: 'Reference', max: 80);
    if (r != null) local['reference'] = pgt(r);
    final n = Validators.text(_note.text, label: 'Note', max: 200);
    if (n != null) local['note'] = pgt(n);
    if (_credit && _noteId == null) local['debitNoteId'] = gt('Choose a debit note');
    if (local.isNotEmpty) {
      setState(() => _err = local);
      return;
    }
    setState(() {
      _busy = true;
      _err = {};
    });
    try {
      final body = <String, dynamic>{
        'amountPaise': a,
        'mode': _credit ? 'CREDIT_NOTE' : _mode,
        if (_credit) 'debitNoteId': _noteId,
        if (!_credit && _ref.text.trim().isNotEmpty) 'reference': _ref.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      };
      final p = await PurchaseStore.instance.api.pay(widget.p.id, body, _key);
      if (mounted) Navigator.of(context).pop(p);
    } on ApiException catch (e) {
      if (!mounted) return;
      final f = Map<String, String>.from(e.fields);
      if (e.code == 'PAYMENT_EXCEEDS_DUE' || e.code == 'ALREADY_PAID') {
        final d = _detail(e, 'duePaise');
        if (d is num) _amount.text = paiseToText(d.toInt() < 0 ? 0 : d.toInt());
        f['_'] = e.code == 'ALREADY_PAID'
            ? gt('Nothing is due on this purchase any more. Refresh the page.')
            : e.messageWithRef;
      } else if (e.code == 'CREDIT_EXCEEDS_AVAILABLE') {
        final d = _detail(e, 'availablePaise');
        if (d is num) _amount.text = paiseToText(d.toInt());
        f['_'] = pf('Only {0} credit is left on that note.', [pRs(((d is num) ? d.toInt() : 0))]);
      } else if (e.code == 'IDEMPOTENCY_KEY_REUSED') {
        _key = newIdempotencyKey();
        f['_'] = e.messageWithRef;
      } else if (!f.keys.any(_shown)) {
        f['_'] = f.isEmpty ? e.messageWithRef : f.entries.map((x) => '${x.key}: ${x.value}').join('\n');
      }
      setState(() {
        _err = f;
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

  static bool _shown(String k) =>
      const {'amountPaise', 'reference', 'note', 'mode', 'debitNoteId', '_'}.contains(k);

  @override
  Widget build(BuildContext context) {
    final due = widget.p.duePaise;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PKv('Due now', pRs(due), bold: true),
      const SizedBox(height: 6),
      AppField(
          label: 'Amount (Rs)',
          controller: _amount,
          numeric: true,
          maxLength: 12,
          error: _fe(_err, 'amountPaise')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        AppChip('25%', small: true, selected: false, onTap: () => setState(() => _amount.text = paiseToText(due ~/ 4))),
        AppChip('50%', small: true, selected: false, onTap: () => setState(() => _amount.text = paiseToText(due ~/ 2))),
        AppChip('Mark paid', small: true, selected: false, onTap: () => setState(() => _amount.text = paiseToText(due))),
      ]),
      if (_hasCredit) ...[
        const SizedBox(height: 12),
        Row(children: [
          AppSwitch(
              value: _credit,
              onChanged: (v) {
                setState(() => _credit = v);
                if (v && _notes.isEmpty) _loadNotes();
              }),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  '${gt('Pay with supplier credit')} (${pRs(widget.sup!.creditPaise)})',
                  style: pBody)),
        ]),
      ],
      if (_credit) ...[
        const SizedBox(height: 8),
        if (_loadingNotes)
          const SkeletonRows(rows: 2)
        else if (_notes.isEmpty)
          PNote(gt('No debit notes with credit were found for this supplier.'))
        else
          for (final n in _notes)
            GestureDetector(
              onTap: () => setState(() => _noteId = n.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  AppRadio(selected: _noteId == n.id),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          '${n.noteNo} · ${pRs(n.totalPaise)} · ${n.invoiceNo.isEmpty ? pDate(n.createdAt) : n.invoiceNo}',
                          style: pBody)),
                ]),
              ),
            ),
        if (_fe(_err, 'debitNoteId') != null) PNote(_fe(_err, 'debitNoteId')!, error: true),
      ] else ...[
        const SizedBox(height: 12),
        Text(gt('Paid by'), style: pHead),
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
            label: 'Reference (UTR / cheque no., optional)',
            controller: _ref,
            maxLength: 80,
            error: _fe(_err, 'reference')),
      ],
      const SizedBox(height: 10),
      AppField(label: 'Note (optional)', controller: _note, maxLength: 200, error: _fe(_err, 'note')),
      if (_err['_'] != null) PNote(_err['_']!, error: true),
      const SizedBox(height: 14),
      AppButton('Record payment', block: true, loading: _busy, onTap: _busy ? null : _save),
      const SizedBox(height: 8),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Return goods
// ---------------------------------------------------------------------------

class _ReturnForm extends StatefulWidget {
  final PurchaseDto p;
  const _ReturnForm({required this.p});
  @override
  State<_ReturnForm> createState() => _ReturnFormState();
}

class _ReturnFormState extends State<_ReturnForm> {
  final _reason = TextEditingController();
  late final Map<String, TextEditingController> _qty = {
    for (final l in widget.p.items.where((l) => l.returnable > 0))
      l.id: TextEditingController()
  };
  String _key = newIdempotencyKey();
  Map<String, String> _err = {};
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final local = <String, String>{};
    final r = Validators.text(_reason.text, label: 'Reason', required: true, max: 200);
    if (r != null) local['reason'] = pgt(r);
    final items = <Map<String, dynamic>>[];
    for (final l in widget.p.items) {
      final c = _qty[l.id];
      if (c == null || c.text.trim().isEmpty) continue;
      final q = int.tryParse(c.text.trim());
      if (q == null || q < 0) {
        local['qty:${l.id}'] = gt('Enter a whole number');
      } else if (q > l.returnable) {
        local['qty:${l.id}'] = pf('At most {0}', [l.returnable]);
      } else if (q > 0) {
        items.add({'purchaseItemId': l.id, 'qty': q});
      }
    }
    if (items.isEmpty && local.isEmpty) local['items'] = gt('Enter a quantity to return for at least one item.');
    if (local.isNotEmpty) {
      setState(() => _err = local);
      return;
    }
    setState(() {
      _busy = true;
      _err = {};
    });
    try {
      final n = await PurchaseStore.instance.api.returnGoods(
          widget.p.id, {'reason': _reason.text.trim(), 'items': items}, _key);
      if (mounted) Navigator.of(context).pop(n);
    } on ApiException catch (e) {
      if (!mounted) return;
      final f = <String, String>{...e.fields};
      final id = _detail(e, 'purchaseItemId');
      if (e.code == 'RETURN_EXCEEDS_RECEIVED' && id != null) {
        f['qty:$id'] = e.fields.values.isEmpty ? e.messageWithRef : e.fields.values.first;
      } else if (e.code == 'INSUFFICIENT_STOCK_FOR_RETURN') {
        final store0 = PurchaseStore.instance;
        f['_'] = '${e.messageWithRef}${_detail(e, 'onHand') == null ? '' : ' (${gt('in stock')}: ${store0.qty(_detail(e, 'productId')?.toString() ?? '', (_detail(e, 'onHand') as num).toInt(), plus: false)})'}';
      } else if (e.code == 'IDEMPOTENCY_KEY_REUSED') {
        _key = newIdempotencyKey();
        f['_'] = e.messageWithRef;
      } else if (!f.keys.any((k) => k == 'reason' || k == 'items' || k == '_' || k.startsWith('qty:'))) {
        f['_'] = f.isEmpty ? e.messageWithRef : f.entries.map((x) => '${x.key}: ${x.value}').join('\n');
      }
      setState(() {
        _err = f;
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
    final store = PurchaseStore.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PHint('Enter how many units go back to the supplier. Stock is reduced and a debit note is created.'),
      const SizedBox(height: 10),
      for (final l in widget.p.items.where((l) => l.returnable > 0))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.name, style: pHead),
                Text('${gt('Can return up to')} ${store.qty(l.productId, l.returnable, plus: false)}', style: pSub),
              ]),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: AppField(
                  label: 'Return qty',
                  controller: _qty[l.id],
                  numeric: true,
                  maxLength: 7,
                  error: _err['qty:${l.id}']),
            ),
          ]),
        ),
      AppField(
          label: 'Reason',
          controller: _reason,
          maxLength: 200,
          error: _fe(_err, 'reason')),
      if (_err['items'] != null) PNote(_err['items']!, error: true),
      if (_err['_'] != null) PNote(_err['_']!, error: true),
      const SizedBox(height: 14),
      AppButton('Create debit note', block: true, loading: _busy, onTap: _busy ? null : _save),
      const SizedBox(height: 8),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Edit invoice details (PATCH: only the fields that changed)
// ---------------------------------------------------------------------------

class _EditForm extends StatefulWidget {
  final PurchaseDto p;
  const _EditForm({required this.p});
  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  late final _invoice = TextEditingController(text: widget.p.invoiceNo);
  late final _note = TextEditingController(text: widget.p.note);
  late final _attach = TextEditingController(text: widget.p.attachmentNote);
  late final _gstin = TextEditingController(text: widget.p.supplierGstin);
  late final _state = TextEditingController(text: widget.p.supplierStateCode);
  late String _inv = widget.p.invoiceDate;
  late String? _due = widget.p.dueDate;
  Map<String, String> _err = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_invoice, _note, _attach, _gstin, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final local = <String, String>{};
    void chk(String f, String? m) {
      if (m != null) local[f] = pgt(m);
    }

    chk('invoiceNo', Validators.text(_invoice.text, label: 'Invoice no.', max: 60));
    chk('note', Validators.text(_note.text, label: 'Note', max: 200));
    chk('attachmentNote', Validators.text(_attach.text, label: 'Link or note', max: 500));
    chk('supplierGstin', Validators.gstin(_gstin.text));
    final g = _gstin.text.trim().toUpperCase();
    final st = _state.text.trim();
    if (st.isNotEmpty && !RegExp(r'^\d{2}$').hasMatch(st)) local['supplierStateCode'] = gt('State code is 2 digits');
    if (g.length >= 2 && st.isNotEmpty && RegExp(r'^\d\d').hasMatch(g) && st != g.substring(0, 2)) {
      local['supplierStateCode'] = gt('State must match the GSTIN');
    }
    if (_inv.compareTo(todayYmd()) > 0) local['invoiceDate'] = gt('Invoice date cannot be in the future');
    if (_due != null && _due!.compareTo(_inv) < 0) local['dueDate'] = gt('Due date cannot be before the invoice date');
    if (local.isNotEmpty) {
      setState(() => _err = local);
      return;
    }
    final p = widget.p;
    final body = <String, dynamic>{
      if (_invoice.text.trim() != p.invoiceNo) 'invoiceNo': _invoice.text.trim(),
      if (_inv != p.invoiceDate) 'invoiceDate': _inv,
      if (_due != p.dueDate) 'dueDate': _due, // null clears it
      if (_note.text.trim() != p.note) 'note': _note.text.trim(),
      if (_attach.text.trim() != p.attachmentNote) 'attachmentNote': _attach.text.trim(),
      if (g != p.supplierGstin) 'supplierGstin': g,
      if (st != p.supplierStateCode) 'supplierStateCode': st,
    };
    if (body.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = true;
      _err = {};
    });
    try {
      final r = await PurchaseStore.instance.api.patch(p.id, body);
      if (mounted) Navigator.of(context).pop(r);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _err = e.fields.isNotEmpty ? e.fields : {'_': e.messageWithRef};
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

  Widget _date(String label, String? v, ValueChanged<String?> set, String? err,
      {bool clear = false, DateTime? last}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () async {
          final r = await pickYmd(context, v, last: last);
          if (r != null) set(r);
        },
        child: AbsorbPointer(
            child: AppField(label: label, value: v == null ? gt('Not set') : pDate(v), readOnly: true, error: err)),
      ),
      if (clear && v != null)
        Padding(padding: const EdgeInsets.only(top: 4), child: AppLink('Clear', onTap: () => set(null))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PHint('Only text and dates can be corrected. For a wrong quantity or cost, return the goods and record a new purchase.'),
      const SizedBox(height: 10),
      AppField(label: 'Supplier invoice no.', controller: _invoice, maxLength: 60, error: _fe(_err, 'invoiceNo')),
      const SizedBox(height: 10),
      FieldRow(children: [
        _date('Invoice date', _inv, (v) => setState(() => _inv = v ?? _inv), _fe(_err, 'invoiceDate'),
            last: DateTime.now()),
        _date('Due date', _due, (v) => setState(() => _due = v), _fe(_err, 'dueDate'),
            clear: true, last: DateTime.now().add(const Duration(days: 730))),
      ]),
      const SizedBox(height: 10),
      AppField(label: 'Note', controller: _note, maxLength: 200, error: _fe(_err, 'note')),
      const SizedBox(height: 10),
      AppField(label: 'Invoice link or note', controller: _attach, maxLength: 500, error: _fe(_err, 'attachmentNote')),
      const SizedBox(height: 10),
      FieldRow(flex: const [3, 2], children: [
        AppField(
            label: 'Supplier GSTIN on this bill',
            controller: _gstin,
            uppercase: true,
            maxLength: 15,
            error: _fe(_err, 'supplierGstin'),
            onChanged: (v) {
              final g = v.trim().toUpperCase();
              if (g.length >= 2 && RegExp(r'^\d\d').hasMatch(g)) _state.text = g.substring(0, 2);
            }),
        AppField(
            label: 'State code',
            controller: _state,
            numeric: true,
            maxLength: 2,
            error: _fe(_err, 'supplierStateCode')),
      ]),
      const PHint('Changing the GSTIN or state fixes the text on this bill only. Tax amounts are not recalculated.'),
      if (_err['_'] != null) PNote(_err['_']!, error: true),
      const SizedBox(height: 14),
      AppButton('Save changes', block: true, loading: _busy, onTap: _busy ? null : _save),
      const SizedBox(height: 8),
    ]);
  }
}
