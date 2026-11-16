import 'package:flutter/material.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/api/bank_dto.dart';
import '../../data/bank_store.dart';
import '../../data/ist.dart';
import '../../data/validators.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_bank_common.dart';

// ---------------------------------------------------------------------------
// Accounts list
// ---------------------------------------------------------------------------

class BankAccountsTab extends StatefulWidget {
  const BankAccountsTab({super.key});

  @override
  State<BankAccountsTab> createState() => _BankAccountsTabState();
}

class _BankAccountsTabState extends State<BankAccountsTab> {
  final _store = BankStore.instance;
  String _kind = '';
  bool _showOff = false;
  String _q = '';
  BankPage<MoneyAccount>? _page;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _pageNo = page;
    });
    try {
      final r = await _store.api.accounts(
          kind: _kind.isEmpty ? null : _kind,
          active: _showOff ? null : true,
          q: _q.trim().isEmpty ? null : _q.trim(),
          page: _pageNo,
          size: 20);
      if (!mounted || gen != _gen) return;
      setState(() {
        _page = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e);
        _loading = false;
      });
    }
  }

  void _reset() {
    _pageNo = 0;
    _load();
  }

  Future<void> _edit([MoneyAccount? a]) async {
    final saved = await showAppSheet<MoneyAccount>(
      context: context,
      title: a == null ? 'New account' : 'Edit account',
      sub: 'Places where money sits: bank, gateway, QR, card machine, cash',
      builder: (_) => AccountForm(existing: a),
    );
    if (saved != null) {
      showToast(a == null ? 'Account created' : 'Account saved', 'success');
      unawaited2(_store.loadAccounts(force: true));
      _load();
    }
  }

  Future<void> _toggle(MoneyAccount a) async {
    if (_busy.contains(a.id)) return;
    if (a.active) {
      final ok = await bankConfirm(context,
          title: 'Switch off this account?',
          body:
              'It stops being offered for new receipts. Old receipts keep pointing at it. You can switch it on again.',
          confirmLabel: 'Switch off');
      if (!ok) return;
    }
    setState(() => _busy.add(a.id));
    try {
      await _store.api.setAccountActive(a.id, !a.active);
      showToast(a.active ? 'Account switched off' : 'Account switched on');
      unawaited2(_store.loadAccounts(force: true));
      await _load();
    } catch (e) {
      if (e is ApiException && e.code == 'ACCOUNT_IN_USE' && a.active) {
        showToast(
            gt('Active accounts still settle into this one. Switch those off or move them to another bank first.'),
            'error');
      } else {
        showToast(bankError(e), 'error');
      }
    }
    if (mounted) setState(() => _busy.remove(a.id));
  }

  Future<void> _delete(MoneyAccount a) async {
    final ok = await bankConfirm(context,
        title: 'Delete this account?',
        body:
            'Only an account nothing refers to can be deleted. If it has any history, switch it off instead.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    setState(() => _busy.add(a.id));
    try {
      await _store.api.deleteAccount(a.id);
      showToast('Account deleted');
      unawaited2(_store.loadAccounts(force: true));
      await _load();
    } catch (e) {
      showToast(bankError(e), 'error');
    }
    if (mounted) setState(() => _busy.remove(a.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton('New account', icon: 'plus', block: true, onTap: () => _edit()),
        const SizedBox(height: 12),
        AppField(
          placeholder: gt('Search name, provider or id'),
          value: _q,
          maxLength: 80,
          onChanged: (v) => _q = v,
          textInputAction: TextInputAction.search,
          onEditingComplete: _reset,
          suffix: GestureDetector(
              onTap: _reset,
              child: const Icon(Icons.search, size: 20, color: AppColors.ink3)),
        ),
        const SizedBox(height: 10),
        ChipRail(children: [
          for (final k in ['', ...accountKinds])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(k.isEmpty ? gt('All') : kindLabel(k),
                  selected: _kind == k,
                  onTap: () {
                    _kind = k;
                    _reset();
                  }),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          AppSwitch(
              value: _showOff,
              onChanged: (v) {
                _showOff = v;
                _reset();
              }),
          const SizedBox(width: 10),
          Text(gt('Show switched-off accounts'),
              style: bankStyle(12.5, FontWeight.w700, AppColors.ink2)),
        ]),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 4)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
            icon: 'card',
            title: gt('No accounts here'),
            copy: _kind == 'BANK'
                ? gt('Add your bank account to see payouts.')
                : gt('Change the filter or add an account.'),
          )
        else if (p != null) ...[
          ResultSummary('${p.totalText} ${gt(p.total == 1 ? 'account' : 'accounts')}'),
          for (final a in p.items) _card(a),
          BankPager(page: p, onPage: (n) => _load(page: n)),
        ],
        const SizedBox(height: 4),
        const BankInfoLine(
            'Money held in each account is shown in its book. "Unassigned" is the honest bucket for old receipts: it is not an error.'),
      ],
    );
  }

  Widget _card(MoneyAccount a) {
    final bank = a.settlesToAccountId == null
        ? null
        : _store.byId(a.settlesToAccountId)?.name;
    final busy = _busy.contains(a.id);
    return BankCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(a.name,
                  style: bankStyle(14.5, FontWeight.w800, AppColors.ink)),
            ),
            bankPill(a.active ? gt('Active') : gt('Off'),
                tone: a.active ? 'good' : 'neutral'),
          ]),
          const SizedBox(height: 4),
          Text(
              [
                kindLabel(a.kind),
                if (a.provider.isNotEmpty) a.provider,
                if (a.identifier.isNotEmpty) a.identifier,
              ].join(' · '),
              style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
          if (a.settlesToAccountId != null)
            Text('${gt('Settles into')}: ${bank ?? a.settlesToAccountId}',
                style: bankStyle(12, FontWeight.w600, AppColors.ink3)),
          if (a.note.isNotEmpty)
            Text(a.note, style: bankStyle(12, FontWeight.w600, AppColors.ink3)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            AppButton('Book',
                size: BtnSize.xs,
                variant: BtnVariant.soft,
                onTap: () => go('/admin/bank?tab=accounts&book=${a.id}')),
            AppButton('Edit',
                size: BtnSize.xs,
                variant: BtnVariant.secondary,
                onTap: busy ? null : () => _edit(a)),
            AppButton(a.active ? 'Switch off' : 'Switch on',
                size: BtnSize.xs,
                variant: BtnVariant.secondary,
                loading: busy,
                onTap: busy ? null : () => _toggle(a)),
            AppButton('Delete',
                size: BtnSize.xs,
                variant: BtnVariant.dangerSoft,
                onTap: busy ? null : () => _delete(a)),
          ]),
        ],
      ),
    );
  }
}

/// Fire and forget without an analyzer warning.
void unawaited2(Future<void> f) {
  f.catchError((Object _) {});
}

// ---------------------------------------------------------------------------
// Create / edit form (shown in a sheet; pops the saved account)
// ---------------------------------------------------------------------------

class AccountForm extends StatefulWidget {
  final MoneyAccount? existing;
  const AccountForm({super.key, this.existing});

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  late String _name = widget.existing?.name ?? '';
  late String _kind = widget.existing?.kind ?? 'BANK';
  late String _provider = widget.existing?.provider ?? '';
  late String _identifier = widget.existing?.identifier ?? '';
  late String _note = widget.existing?.note ?? '';
  late String? _settles = widget.existing?.settlesToAccountId;
  // One key per opening of the form: a retry after a timeout is the same action.
  String _key = newIdempotencyKey();
  bool _failed = false; // edited after a failed try -> new key
  final Map<String, String> _err = {};
  bool _saving = false;
  bool _touched = false;

  bool get _canSettle => _kind == 'GATEWAY' || _kind == 'UPI' || _kind == 'CARD_TERMINAL';

  @override
  void initState() {
    super.initState();
    BankStore.instance.loadAccounts().then((_) {
      if (mounted) setState(() {});
    });
  }

  String? _identifierCheck() {
    final s = _identifier.trim();
    if (s.isEmpty) return null;
    if (s.length > 60) return gt('At most 60 characters');
    switch (_kind) {
      case 'BANK':
        if (RegExp(r'^\d{4}$').hasMatch(s)) return null;
        final m = Validators.bankAccount(s);
        return m == null ? null : gt('Enter the last 4 digits or the full account number (9 to 18 digits)');
      case 'UPI':
        final m = Validators.upiId(s);
        return m == null ? null : gt(m);
      case 'CARD_TERMINAL':
        return RegExp(r'^[A-Za-z0-9\-_]{1,60}$').hasMatch(s)
            ? null
            : gt('Terminal id: letters, digits, - and _ only');
    }
    return null;
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    final n = Validators.text(_name, label: 'Name', required: true, max: 80);
    if (n != null) e['name'] = gt(n);
    final p = _provider.trim();
    if (p.length > 40) {
      e['provider'] = gt('At most 40 characters');
    } else if (p.isNotEmpty && !RegExp(r'^[A-Za-z0-9._\-]+$').hasMatch(p)) {
      e['provider'] = gt('Use a short code like razorpay, paytm or manual');
    }
    final i = _identifierCheck();
    if (i != null) e['identifier'] = i;
    final t = Validators.text(_note, label: 'Note', max: 300);
    if (t != null) e['note'] = gt(t);
    if (_settles != null && !_canSettle) {
      e['settlesToAccountId'] = gt('Only a gateway, UPI or card machine settles into a bank');
    }
    return e;
  }

  Future<void> _save() async {
    setState(() => _touched = true);
    final v = _validate();
    if (v.isNotEmpty) {
      setState(() => _err
        ..clear()
        ..addAll(v));
      return;
    }
    setState(() {
      _saving = true;
      _err.clear();
    });
    final body = <String, dynamic>{
      'name': _name.trim(),
      'kind': _kind,
      'provider': _provider.trim().toLowerCase(),
      'identifier': _identifier.trim(),
      'note': _note.trim(),
      if (_canSettle && _settles != null) 'settlesToAccountId': _settles,
    };
    try {
      ApiException.clearFields();
      final api = BankStore.instance.api;
      final saved = widget.existing == null
          ? await api.createAccount(body, idempotencyKey: _key)
          : await api.updateAccount(widget.existing!.id, body);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      // A failed try may be re-sent edited: the same key with another body is refused (IDEMPOTENCY_KEY_REUSED).
      _failed = true;
      final f = e is ApiException ? e.fields : const <String, String>{};
      setState(() {
        _saving = false;
        for (final k in ['name', 'kind', 'provider', 'identifier', 'note', 'settlesToAccountId']) {
          final m = ApiException.fieldError(f, [k]);
          if (m != null) _err[k] = m;
        }
        if (e is ApiException && e.code == 'DUPLICATE_ACCOUNT_NAME') {
          _err['name'] = gt('An account with this name already exists');
        }
        if (e is ApiException && e.code == 'ACCOUNT_IN_USE' && f.containsKey('kind')) {
          _err['kind'] = gt('The kind cannot change once the account is used');
        }
      });
      showToast(bankError(e), 'error');
    }
  }

  void _onChange(VoidCallback f) {
    f();
    if (_failed) {
      _key = newIdempotencyKey();
      _failed = false;
    }
    if (_touched) {
      setState(() => _err
        ..clear()
        ..addAll(_validate()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = BankStore.instance.active(const ['BANK']);
    final settlesName = banks
            .where((b) => b.id == _settles)
            .map((b) => b.name)
            .firstOrNull ??
        (_settles == null ? '' : BankStore.instance.byId(_settles)?.name ?? _settles!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
            label: 'Name',
            value: _name,
            maxLength: 80,
            placeholder: gt('For example HDFC current account'),
            error: _err['name'],
            onChanged: (v) => _onChange(() => _name = v)),
        bankGap(10),
        FieldRow(
          children: [
            SelectField(
              label: 'Kind',
              value: kindLabel(_kind),
              onTap: () async {
                final k = await pickBankOption(context,
                    title: 'Kind of account',
                    selected: _kind,
                    options: [for (final k in accountKinds) (k, kindLabel(k))]);
                if (k != null) {
                  _onChange(() {
                    _kind = k;
                    if (!_canSettle) _settles = null;
                  });
                }
              },
            ),
            AppField(
                label: 'Provider',
                value: _provider,
                maxLength: 40,
                placeholder: 'razorpay, paytm, manual',
                error: _err['provider'],
                onChanged: (v) => _onChange(() => _provider = v)),
          ],
        ),
        if (_err['kind'] != null) BankNote(_err['kind']!, error: true),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final p in const ['razorpay', 'paytm', 'manual'])
            AppChip(p,
                small: true,
                selected: _provider.trim().toLowerCase() == p,
                onTap: () => setState(() => _provider = p)),
        ]),
        bankGap(10),
        FieldRow(
          children: [
            AppField(
                label: _kind == 'UPI'
                    ? 'UPI id'
                    : _kind == 'CARD_TERMINAL'
                        ? 'Terminal id'
                        : _kind == 'BANK'
                            ? 'Account number (or last 4 digits)'
                            : 'Identifier',
                value: _identifier,
                maxLength: 60,
                placeholder: _kind == 'UPI' ? 'shop@okhdfc' : '',
                error: _err['identifier'],
                onChanged: (v) => _onChange(() => _identifier = v)),
            if (_canSettle)
              SelectField(
                label: 'Settles into (bank)',
                value: settlesName,
                placeholder: gt('None'),
                onTap: () async {
                  final k = await pickBankOption(context,
                      title: 'Settles into',
                      selected: _settles ?? '',
                      options: [
                        ('', gt('None')),
                        for (final b in banks) (b.id, b.name),
                      ]);
                  if (k != null) _onChange(() => _settles = k.isEmpty ? null : k);
                },
              ),
          ],
        ),
        if (_kind == 'CARD_TERMINAL')
          const BankInfoLine('The till sends this as the terminal id.'),
        if (_canSettle && _err['settlesToAccountId'] != null)
          BankNote(_err['settlesToAccountId']!, error: true),
        bankGap(10),
        AppField(
            label: 'Note',
            value: _note,
            maxLength: 300,
            error: _err['note'],
            onChanged: (v) => _onChange(() => _note = v)),
        bankGap(16),
        AppButton(widget.existing == null ? 'Create account' : 'Save account',
            block: true, loading: _saving, onTap: _saving ? null : _save),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Account book
// ---------------------------------------------------------------------------

class AccountBookView extends StatefulWidget {
  final String accountId;
  const AccountBookView({super.key, required this.accountId});

  @override
  State<AccountBookView> createState() => _AccountBookViewState();
}

class _AccountBookViewState extends State<AccountBookView> {
  BankRange _range = BankRange.lastDays(30);
  AccountBook? _book;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    BankStore.instance.loadAccounts().then((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load({int? page}) async {
    if (_range.error != null) return;
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _pageNo = page;
    });
    try {
      final b = await BankStore.instance.api.book(widget.accountId,
          from: _range.fromText, to: _range.toText, page: _pageNo, size: 20);
      if (!mounted || gen != _gen) return;
      setState(() {
        _book = b;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e, _range);
        _loading = false;
      });
    }
  }

  Future<void> _addEntry() async {
    final ok = await showAppSheet<bool>(
      context: context,
      title: 'Add a manual entry',
      sub: 'Opening balance, bank charge, interest. An entry cannot be edited: correct it with an opposite entry.',
      builder: (_) => _EntryForm(accountId: widget.accountId),
    );
    if (ok == true) {
      showToast('Entry added', 'success');
      _pageNo = 0;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _book;
    final acc = BankStore.instance.byId(widget.accountId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardPanel(
          title: b?.accountName ?? acc?.name ?? gt('Account book'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (acc != null)
                Text(
                    [kindLabel(acc.kind), acc.provider, acc.identifier]
                        .where((e) => e.isNotEmpty)
                        .join(' · '),
                    style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
              if (b != null) ...[
                const SizedBox(height: 8),
                BankKv('Opening balance', bankMoney(b.openingBalancePaise),
                    strong: true),
              ],
              const SizedBox(height: 10),
              AppButton('Add manual entry',
                  icon: 'plus', block: true, onTap: _addEntry),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BankRangeBar(
            range: _range,
            onChanged: (r) {
              setState(() => _range = r);
              _pageNo = 0;
              _load();
            }),
        const SizedBox(height: 12),
        if (_loading && b == null)
          const SkeletonRows(rows: 4)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (b != null && b.lines.items.isEmpty)
          EmptyState(
              icon: 'wallet',
              title: gt('No movements in this period'),
              copy: gt('The opening balance above is the balance at the start of the period.'))
        else if (b != null) ...[
          for (final r in b.lines.items) _row(r),
          BankPager(page: b.lines, onPage: (n) => _load(page: n)),
          const BankInfoLine(
              'Balances are worked out by the server. Supplier payments on purchases are not in any book yet.'),
        ],
      ],
    );
  }

  Widget _row(BookRow r) {
    final inn = r.direction == 'IN';
    return BankCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.description.isEmpty ? _typeLabel(r.type) : r.description,
                    style: bankStyle(13.5, FontWeight.w800, AppColors.ink)),
                const SizedBox(height: 3),
                Text('${bankWhen(r.at)} · ${_typeLabel(r.type)}${r.sourceType.isEmpty ? '' : ' · ${r.sourceType}'}',
                    style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${inn ? '+' : '-'}${bankMoney(r.amountPaise)}',
                  style: bankStyle(14, FontWeight.w800,
                      inn ? AppColors.green : AppColors.red)),
              const SizedBox(height: 3),
              Text('${gt('Balance')} ${bankMoney(r.balancePaise)}',
                  style: bankStyle(11.5, FontWeight.w700, AppColors.ink2)),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'RECEIPT':
        return gt('Receipt');
      case 'REFUND':
        return gt('Refund');
      case 'PAYOUT':
        return gt('Payout');
      case 'FEE':
        return gt('Fee');
      case 'ENTRY':
        return gt('Manual entry');
    }
    return t;
  }
}

class _EntryForm extends StatefulWidget {
  final String accountId;
  const _EntryForm({required this.accountId});

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  String _dir = 'IN';
  String _amount = '';
  String _note = '';
  DateTime? _day; // IST calendar day, null = now
  // Same key for a retry of the same entry; a new key once the input changed
  // after a failed try.
  String _key = newIdempotencyKey();
  bool _failed = false;
  final Map<String, String> _err = {};
  bool _saving = false;

  void _edited() {
    if (_failed) {
      _key = newIdempotencyKey();
      _failed = false;
    }
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    final a = Validators.rupees(_amount,
        label: 'Amount', required: true, min: 0.01, max: 100000000);
    if (a != null) e['amountPaise'] = gt(a);
    final n = Validators.text(_note, label: 'Note', max: 200);
    if (n != null) e['note'] = gt(n);
    return e;
  }

  Future<void> _save() async {
    final v = _validate();
    if (v.isNotEmpty) {
      setState(() => _err
        ..clear()
        ..addAll(v));
      return;
    }
    final paise = bankRupeesToPaise(_amount);
    if (paise == null || paise < 1 || paise > 10000000000) {
      setState(() => _err['amountPaise'] = gt('Enter an amount up to Rs 10,00,00,000'));
      return;
    }
    String? at;
    final d = _day;
    if (d != null) {
      final now = istNow();
      final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
      final wall = isToday
          ? now
          : DateTime.utc(d.year, d.month, d.day, 12);
      at = wall.subtract(istOffset).toIso8601String();
    }
    setState(() {
      _saving = true;
      _err.clear();
    });
    try {
      await BankStore.instance.api.addEntry(
          widget.accountId,
          {
            'direction': _dir,
            'amountPaise': paise,
            if (at != null) 'at': at,
            if (_note.trim().isNotEmpty) 'note': _note.trim(),
          },
          idempotencyKey: _key);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _failed = true;
      final f = e is ApiException ? e.fields : const <String, String>{};
      setState(() {
        _saving = false;
        for (final k in ['direction', 'amountPaise', 'note', 'at']) {
          final m = ApiException.fieldError(f, [k]);
          if (m != null) _err[k] = m;
        }
      });
      showToast(bankError(e), 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented(
          options: [
            SegmentOption('IN', gt('Money in')),
            SegmentOption('OUT', gt('Money out')),
          ],
          value: _dir,
          onChanged: (v) => setState(() {
            _edited();
            _dir = v;
          }),
        ),
        if (_err['direction'] != null) BankNote(_err['direction']!, error: true),
        bankGap(10),
        FieldRow(
          children: [
            AppField(
                label: 'Amount (Rs)',
                value: _amount,
                numeric: true,
                maxLength: 14,
                placeholder: '0.00',
                error: _err['amountPaise'],
                onChanged: (v) {
                  _edited();
                  _amount = v;
                }),
            SelectField(
              label: 'Date',
              value: _day == null ? '' : BankRange.fmt(_day!),
              placeholder: gt('Now'),
              onTap: () async {
                final d = await pickBankDay(context, _day ?? BankRange.lastDays(1).to);
                if (d != null) {
                  _edited();
                  setState(() => _day = d);
                }
              },
            ),
          ],
        ),
        if (_day != null)
          Align(
            alignment: Alignment.centerLeft,
            child: AppLink('Use current time', onTap: () => setState(() => _day = null)),
          ),
        bankGap(10),
        AppField(
            label: 'Note',
            value: _note,
            maxLength: 200,
            placeholder: gt('For example bank charge'),
            error: _err['note'],
            onChanged: (v) {
              _edited();
              _note = v;
            }),
        bankGap(16),
        AppButton('Add entry',
            block: true, loading: _saving, onTap: _saving ? null : _save),
        const SizedBox(height: 8),
      ],
    );
  }
}
