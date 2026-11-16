import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/bank_dto.dart';
import '../../data/bank_store.dart';
import '../../data/local_store.dart';
import '../../data/validators.dart';
import '../../data/web_file_picker.dart';
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

const _syncProviders = ['razorpay', 'paytm'];

// ---------------------------------------------------------------------------
// List + actions
// ---------------------------------------------------------------------------

class BankSettlementsTab extends StatefulWidget {
  const BankSettlementsTab({super.key});

  @override
  State<BankSettlementsTab> createState() => _BankSettlementsTabState();
}

class _BankSettlementsTabState extends State<BankSettlementsTab> {
  BankRange _range = BankRange.lastDays(30);
  String _provider = '';
  String _source = '';
  String _account = '';
  BankPage<SettlementRow>? _page;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;
  ImportResult? _lastImport;

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
      final r = await BankStore.instance.api.settlements(
          from: _range.fromText,
          to: _range.toText,
          accountId: _account,
          provider: _provider,
          source: _source,
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
        _error = bankError(e, _range);
        _loading = false;
      });
    }
  }

  void _filter(VoidCallback f) {
    setState(f);
    _pageNo = 0;
    _load();
  }

  Future<void> _sync() async {
    final r = await showAppSheet<SyncResult>(
      context: context,
      title: 'Sync now',
      sub: 'Pull the latest payouts from the provider. The nightly job does the same at 04:30.',
      builder: (_) => const _SyncForm(),
    );
    if (r == null) return;
    if (r.skipped) {
      showToast('Another sync is already running. Try again in a minute.', 'error');
    } else {
      showToast(
          '${gt('Seen')} ${r.settlementsSeen}, ${gt('new')} ${r.settlementsStored} (${r.itemsStored} ${gt('items')})',
          'success');
    }
    _pageNo = 0;
    _load();
    BankStore.instance.refreshBadge();
  }

  Future<void> _import() async {
    final r = await showAppSheet<ImportResult>(
      context: context,
      title: 'Import statement',
      sub: 'A CSV from the bank, the card machine or the Paytm dashboard (Settlement Report).',
      builder: (_) => const _ImportForm(),
    );
    if (r == null) return;
    setState(() => _lastImport = r);
    showToast(r.alreadyImported ? 'This file was already imported' : 'Statement imported',
        r.alreadyImported ? 'info' : 'success');
    _pageNo = 0;
    _load();
    BankStore.instance.refreshBadge();
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    final accName = BankStore.instance.byId(_account)?.name ?? '';
    final imp = _lastImport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: AppButton('Sync now',
                  icon: 'refresh', onTap: _sync)),
          const SizedBox(width: 10),
          Expanded(
              child: AppButton('Import statement',
                  icon: 'import',
                  variant: BtnVariant.secondary,
                  onTap: _import)),
        ]),
        if (imp != null) ...[
          const SizedBox(height: 12),
          CardPanel(
            title: imp.alreadyImported ? gt('Already imported') : gt('Import result'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    imp.alreadyImported
                        ? '${imp.rows} ${gt('rows')}. ${gt('The same file for the same account is never counted twice.')}'
                        : '${imp.rows} ${gt('rows')}: ${imp.matched} ${gt('matched')}, ${imp.unmatched} ${gt('need a look')}. ${gt('Net')} ${bankMoney(imp.netPaise)}',
                    style: bankStyle(13, FontWeight.w700, AppColors.ink)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  AppButton('Open settlement',
                      size: BtnSize.sm,
                      onTap: () => go('/admin/bank?tab=settlements&settlement=${imp.settlementId}')),
                  if (imp.unmatched > 0)
                    AppButton('Show unmatched items',
                        size: BtnSize.sm,
                        variant: BtnVariant.secondary,
                        onTap: () => go(
                            '/admin/bank?tab=settlements&settlement=${imp.settlementId}&unmatched=1')),
                  AppButton('Dismiss',
                      size: BtnSize.sm,
                      variant: BtnVariant.ghost,
                      onTap: () => setState(() => _lastImport = null)),
                ]),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        BankRangeBar(range: _range, onChanged: (r) => _filter(() => _range = r)),
        const SizedBox(height: 10),
        ChipRail(children: [
          for (final v in const ['', 'razorpay', 'paytm', 'manual'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(v.isEmpty ? gt('All vendors') : v,
                  small: true,
                  selected: _provider == v,
                  onTap: () => _filter(() => _provider = v)),
            ),
          for (final v in const [('GATEWAY_API', 'Pulled from provider'), ('CSV', 'Imported CSV')])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(v.$2,
                  small: true,
                  selected: _source == v.$1,
                  onTap: () => _filter(() => _source = _source == v.$1 ? '' : v.$1)),
            ),
        ]),
        const SizedBox(height: 10),
        SelectField(
          label: 'Account',
          value: _account.isEmpty ? '' : accName,
          placeholder: gt('All accounts'),
          onTap: () async {
            final k = await pickBankOption(context,
                title: 'Account',
                selected: _account,
                options: [
                  ('', gt('All accounts')),
                  for (final a in BankStore.instance.accounts) (a.id, a.name),
                ]);
            if (k != null) _filter(() => _account = k);
          },
        ),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 4)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
              icon: 'wallet',
              title: gt('No settlements in this period'),
              copy: gt('Use Sync now or Import statement.'))
        else if (p != null) ...[
          ResultSummary('${p.totalText} ${gt(p.total == 1 ? 'settlement' : 'settlements')}'),
          for (final s in p.items) _row(s),
          BankPager(page: p, onPage: (n) => _load(page: n)),
        ],
      ],
    );
  }

  Widget _row(SettlementRow s) {
    return BankCard(
      alert: s.unmatchedItems > 0,
      onTap: () => go('/admin/bank?tab=settlements&settlement=${s.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(s.utr ?? s.providerSettlementId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bankStyle(14, FontWeight.w800, AppColors.ink)),
            ),
            Text(bankMoney(s.netPaise),
                style: bankStyle(14.5, FontWeight.w800, AppColors.ink)),
          ]),
          const SizedBox(height: 3),
          Text(
              '${bankWhen(s.settledAt)} · ${s.provider} · ${s.accountName ?? gt('Unassigned')}',
              style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            bankPill(s.source == 'CSV' ? gt('CSV') : gt('Provider'), ),
            bankPill(s.status),
            bankPill('${s.items} ${gt('items')}'),
            if (s.unmatchedItems > 0)
              bankPill('${s.unmatchedItems} ${gt('unmatched')}', tone: 'bad'),
          ]),
          const SizedBox(height: 4),
          Text(
              '${gt('Gross')} ${bankMoney(s.grossPaise)} · ${gt('Fee')} ${bankMoney(s.feePaise)} · GST ${bankMoney(s.taxPaise)}',
              style: bankStyle(11.5, FontWeight.w600, AppColors.ink2)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync form
// ---------------------------------------------------------------------------

class _SyncForm extends StatefulWidget {
  const _SyncForm();

  @override
  State<_SyncForm> createState() => _SyncFormState();
}

class _SyncFormState extends State<_SyncForm> {
  String _provider = 'razorpay';
  String _days = '7';
  String? _daysErr;
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    final d = Validators.whole(_days, label: 'Days', required: true, min: 1, max: 60);
    if (d != null) {
      setState(() => _daysErr = gt(d));
      return;
    }
    setState(() {
      _busy = true;
      _daysErr = null;
    });
    try {
      final r = await BankStore.instance.api
          .sync(_provider, days: int.parse(_days.trim()));
      if (mounted) Navigator.of(context).pop(r);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is ApiException) {
          _daysErr = ApiException.fieldError(e.fields, ['days']);
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
        FieldRow(
          flex: const [3, 2],
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gt('Provider'),
                    style: bankStyle(13, FontWeight.w800, AppColors.ink)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in _syncProviders)
                    AppChip(p, selected: _provider == p, onTap: () => setState(() => _provider = p)),
                ]),
              ],
            ),
            AppField(
                label: 'Days to read back (1 to 60)',
                value: _days,
                numeric: true,
                maxLength: 2,
                error: _daysErr,
                onChanged: (v) => _days = v),
          ],
        ),
        const BankInfoLine(
            'Needs the provider keys on the configuration screen. Paytm settlement sync is off until it is enabled there and is not verified against Paytm.'),
        bankGap(16),
        AppButton('Sync now', block: true, loading: _busy, onTap: _busy ? null : _run),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Statement CSV import
// ---------------------------------------------------------------------------

class _ImportForm extends StatefulWidget {
  const _ImportForm();

  @override
  State<_ImportForm> createState() => _ImportFormState();
}

class _ImportFormState extends State<_ImportForm> {
  List<int>? _bytes;
  String _fileName = '';
  List<String> _headers = const [];
  bool _paytm = false;
  String _accountId = '';
  String _format = ''; // '' = auto, PAYTM, GENERIC
  String _provider = '';
  String _utr = '';
  String _delimiter = ',';
  String _amountUnit = 'RUPEES';
  String _dateFormat = '';
  final Map<String, String> _map = {
    'dateColumn': '',
    'referenceColumn': '',
    'amountColumn': '',
    'feeColumn': '',
    'taxColumn': '',
    'descriptionColumn': '',
  };
  final Map<String, String> _err = {};
  List<String> _problems = const [];
  bool _busy = false;

  static const _defaults = {
    'dateColumn': 'date',
    'referenceColumn': 'reference',
    'amountColumn': 'amount',
    'feeColumn': 'fee',
    'taxColumn': 'tax',
    'descriptionColumn': 'description',
  };

  @override
  void initState() {
    super.initState();
    BankStore.instance.loadAccounts().then((_) {
      if (mounted) setState(() {});
    });
  }

  String get _delimChar => _delimiter == 'tab' ? '\t' : _delimiter;

  List<String> _splitHeader(String line, String d) {
    final out = <String>[];
    final b = StringBuffer();
    var q = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        q = !q;
      } else if (c == d && !q) {
        out.add(b.toString().trim());
        b.clear();
      } else {
        b.write(c);
      }
    }
    out.add(b.toString().trim());
    return out.where((e) => e.isNotEmpty).toList();
  }

  void _readHeader() {
    final bytes = _bytes;
    if (bytes == null) return;
    var text = utf8.decode(bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes,
        allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    final line = text.split(RegExp(r'\r?\n')).first;
    _headers = _splitHeader(line, _delimChar);
    final low = _headers.map((e) => e.toLowerCase()).toList();
    _paytm = low.contains('settled amount') ||
        (low.any((e) => e.startsWith('utr')) && low.contains('commission'));
    // Pre-fill each mapping by case-insensitive name match.
    for (final e in _defaults.entries) {
      final hit = _headers.where((h) => h.toLowerCase() == e.value);
      _map[e.key] = hit.isEmpty ? '' : hit.first;
    }
  }

  void _guessDelimiter() {
    final bytes = _bytes;
    if (bytes == null) return;
    final text = utf8.decode(bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes,
        allowMalformed: true);
    final line = text.split(RegExp(r'\r?\n')).first;
    final counts = {
      ',': ','.allMatches(line).length,
      ';': ';'.allMatches(line).length,
      'tab': '\t'.allMatches(line).length,
    };
    var best = ',';
    for (final e in counts.entries) {
      if (e.value > counts[best]!) best = e.key;
    }
    _delimiter = best;
  }

  Future<void> _pick() async {
    final f = await pickImageFile(accept: '.csv,text/csv,text/plain');
    if (f == null || !mounted) return;
    setState(() {
      _bytes = f.bytes;
      _fileName = f.name;
      _problems = const [];
      _err.remove('file');
      _guessDelimiter();
      _readHeader();
    });
    _loadSaved();
  }

  void _loadSaved() {
    if (_accountId.isEmpty || _paytm) return;
    final raw = LocalStore.get('bank.csvmap.$_accountId');
    if (raw == null) return;
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      setState(() {
        for (final k in _map.keys) {
          final v = (j[k] ?? '').toString();
          if (v.isNotEmpty && (_headers.isEmpty || _headers.contains(v))) _map[k] = v;
        }
        _dateFormat = (j['dateFormat'] ?? _dateFormat).toString();
        _amountUnit = (j['amountUnit'] ?? _amountUnit).toString();
      });
    } catch (_) {}
  }

  void _saveMapping() {
    if (_accountId.isEmpty || _paytm) return;
    LocalStore.set(
        'bank.csvmap.$_accountId',
        jsonEncode({..._map, 'dateFormat': _dateFormat, 'amountUnit': _amountUnit}));
  }

  bool get _generic => _format == 'GENERIC' || (!_paytm && _format != 'PAYTM');

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_bytes == null) e['file'] = gt('Choose the CSV file');
    if (_bytes != null && _bytes!.length > 2 * 1024 * 1024) {
      e['file'] = gt('The file is over 2 MB');
    }
    if (_accountId.isEmpty) e['moneyAccountId'] = gt('Choose the account this statement belongs to');
    final p = Validators.text(_provider, label: 'Provider', max: 40);
    if (p != null) e['provider'] = gt(p);
    final u = Validators.text(_utr, label: 'UTR', max: 60);
    if (u != null) e['utr'] = gt(u);
    if (_generic && _format != 'PAYTM') {
      if (_dateFormat.trim().isNotEmpty &&
          !RegExp(r'^[dMyHhmsaE/\-\. :T,]+$').hasMatch(_dateFormat.trim())) {
        e['dateFormat'] = gt('Use a pattern like dd/MM/yyyy');
      }
      if (_headers.isNotEmpty) {
        final low = _headers.map((h) => h.toLowerCase()).toList();
        for (final k in ['dateColumn', 'referenceColumn', 'amountColumn']) {
          final name = (_map[k]!.isEmpty ? _defaults[k]! : _map[k]!).toLowerCase();
          if (!low.contains(name)) {
            e[k] = '${gt('No column named')} "${_map[k]!.isEmpty ? _defaults[k] : _map[k]}"';
          }
        }
      }
    }
    return e;
  }

  Future<void> _run() async {
    if (_busy) return;
    final v = _validate();
    if (v.isNotEmpty) {
      setState(() {
        _err
          ..clear()
          ..addAll(v);
      });
      return;
    }
    setState(() {
      _busy = true;
      _err.clear();
      _problems = const [];
    });
    final opts = <String, String>{
      'moneyAccountId': _accountId,
      if (_format.isNotEmpty) 'format': _format,
      if (_provider.trim().isNotEmpty) 'provider': _provider.trim().toLowerCase(),
      if (_utr.trim().isNotEmpty) 'utr': _utr.trim(),
    };
    if (_generic && _format != 'PAYTM') {
      for (final e in _map.entries) {
        if (e.value.isNotEmpty) opts[e.key] = e.value;
      }
      if (_dateFormat.trim().isNotEmpty) opts['dateFormat'] = _dateFormat.trim();
      opts['amountUnit'] = _amountUnit;
      opts['delimiter'] = _delimiter;
    }
    try {
      final r = await BankStore.instance.api.importStatement(
          bytes: _bytes!, filename: _fileName, options: opts);
      _saveMapping();
      if (mounted) Navigator.of(context).pop(r);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is ApiException) {
          for (final k in [
            'moneyAccountId', 'provider', 'utr', 'format', 'dateFormat', 'amountUnit',
            'delimiter', 'dateColumn', 'referenceColumn', 'amountColumn',
            'feeColumn', 'taxColumn', 'descriptionColumn', 'file'
          ]) {
            final m = ApiException.fieldError(e.fields, [k]);
            if (m != null) _err[k] = m;
          }
          final pr = e.details?['problems'];
          if (pr is List) _problems = [for (final x in pr) '$x'];
        }
      });
      showToast(bankError(e), 'error');
    }
  }

  Widget _col(String key, String label) {
    final cur = _map[key]!;
    if (_headers.isEmpty) {
      return AppField(
          label: label,
          value: cur,
          maxLength: 60,
          placeholder: _defaults[key],
          error: _err[key],
          onChanged: (v) => _map[key] = v.trim());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectField(
        label: label,
        value: cur,
        placeholder: '${gt('Default')}: ${_defaults[key]}',
        onTap: () async {
          final k = await pickBankOption(context,
              title: label,
              selected: cur,
              options: [('', gt('Default / not in file')), for (final h in _headers) (h, h)]);
          if (k != null) setState(() => _map[key] = k);
        },
      ),
      if (_err[key] != null) BankNote(_err[key]!, error: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = BankStore.instance;
    final picks = store.active(const []);
    final accName = store.byId(_accountId)?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(_bytes == null ? 'Choose CSV file' : _fileName,
            icon: 'import', variant: BtnVariant.secondary, block: true, onTap: _pick),
        if (_err['file'] != null) BankNote(_err['file']!, error: true),
        if (_bytes != null)
          BankNote(
              _paytm
                  ? gt('Paytm Settlement Report detected: it is read with its own columns.')
                  : '${_headers.length} ${gt('columns found')}: ${_headers.join(', ')}'),
        bankGap(10),
        SelectField(
          label: 'Account of this statement',
          value: accName,
          placeholder: gt('Choose'),
          onTap: () async {
            final k = await pickBankOption(context,
                title: 'Account',
                selected: _accountId,
                options: [for (final a in picks) (a.id, '${a.name} · ${kindLabel(a.kind)}')]);
            if (k != null) {
              setState(() => _accountId = k);
              _loadSaved();
            }
          },
        ),
        if (_err['moneyAccountId'] != null) BankNote(_err['moneyAccountId']!, error: true),
        bankGap(10),
        Text(gt('Format'), style: bankStyle(13, FontWeight.w800, AppColors.ink)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          AppChip('Automatic', selected: _format.isEmpty, onTap: () => setState(() => _format = '')),
          AppChip('Paytm Settlement Report',
              selected: _format == 'PAYTM', onTap: () => setState(() => _format = 'PAYTM')),
          AppChip('Generic columns',
              selected: _format == 'GENERIC', onTap: () => setState(() => _format = 'GENERIC')),
        ]),
        if (_err['format'] != null) BankNote(_err['format']!, error: true),
        bankGap(10),
        FieldRow(
          children: [
            AppField(
                label: 'Provider (optional)',
                value: _provider,
                maxLength: 40,
                placeholder: 'manual',
                error: _err['provider'],
                onChanged: (v) => _provider = v),
            AppField(
                label: 'UTR of the whole payout (optional)',
                value: _utr,
                maxLength: 60,
                error: _err['utr'],
                onChanged: (v) => _utr = v),
          ],
        ),
        if (_generic && _format != 'PAYTM') ...[
          bankGap(16),
          bankTitle('Column mapping'),
          FieldRow(children: [
            _col('dateColumn', 'Date column'),
            _col('referenceColumn', 'Reference column'),
          ]),
          bankGap(10),
          FieldRow(children: [
            _col('amountColumn', 'Amount column'),
            _col('feeColumn', 'Fee column'),
          ]),
          bankGap(10),
          FieldRow(children: [
            _col('taxColumn', 'GST column'),
            _col('descriptionColumn', 'Description column'),
          ]),
          bankGap(10),
          FieldRow(
            children: [
              AppField(
                  label: 'Date format (blank = yyyy-MM-dd)',
                  value: _dateFormat,
                  maxLength: 30,
                  placeholder: 'dd/MM/yyyy',
                  error: _err['dateFormat'],
                  onChanged: (v) => _dateFormat = v),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gt('Amounts are in'),
                      style: bankStyle(13, FontWeight.w800, AppColors.ink)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    AppChip('Rupees',
                        selected: _amountUnit == 'RUPEES',
                        onTap: () => setState(() => _amountUnit = 'RUPEES')),
                    AppChip('Paise',
                        selected: _amountUnit == 'PAISE',
                        onTap: () => setState(() => _amountUnit = 'PAISE')),
                  ]),
                ],
              ),
            ],
          ),
          bankGap(10),
          Text(gt('Separator'), style: bankStyle(13, FontWeight.w800, AppColors.ink)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final d in const [(',', 'Comma'), (';', 'Semicolon'), ('tab', 'Tab')])
              AppChip(d.$2,
                  selected: _delimiter == d.$1,
                  onTap: () => setState(() {
                        _delimiter = d.$1;
                        _readHeader();
                      })),
          ]),
        ],
        if (_problems.isNotEmpty) ...[
          bankGap(10),
          CardPanel(
            title: gt('Nothing was saved. Fix these rows:'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in _problems)
                  Text(p, style: bankStyle(12, FontWeight.w700, AppColors.red)),
              ],
            ),
          ),
        ],
        const BankInfoLine(
            'Up to 2 MB and 5000 rows. Importing the same file twice is safe. Do not edit and re-upload a statement already imported: its rows would count again.'),
        bankGap(16),
        AppButton('Import', block: true, loading: _busy, onTap: _busy ? null : _run),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settlement detail + items
// ---------------------------------------------------------------------------

class SettlementDetailView extends StatefulWidget {
  final String id;
  final bool unmatchedOnly;
  const SettlementDetailView({super.key, required this.id, this.unmatchedOnly = false});

  @override
  State<SettlementDetailView> createState() => _SettlementDetailViewState();
}

class _SettlementDetailViewState extends State<SettlementDetailView> {
  SettlementRow? _s;
  BankPage<SettlementItem>? _items;
  late bool _unmatched = widget.unmatchedOnly;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;

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
      final api = BankStore.instance.api;
      final s = _s ?? await api.settlement(widget.id);
      final it = await api.settlementItems(widget.id,
          unmatchedOnly: _unmatched, page: _pageNo, size: 50);
      if (!mounted || gen != _gen) return;
      setState(() {
        _s = s;
        _items = it;
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

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final it = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s != null)
          CardPanel(
            title: s.utr ?? s.providerSettlementId,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BankKv('Provider', s.provider),
                BankKv('Account', s.accountName ?? gt('Unassigned')),
                BankKv('Settled', bankWhen(s.settledAt)),
                BankKv('Source', s.source == 'CSV' ? gt('Imported CSV') : gt('Pulled from provider')),
                BankKv('Status', s.status),
                const Divider(color: AppColors.line),
                BankKv('Gross', bankMoney(s.grossPaise)),
                BankKv('Fee', bankMoney(s.feePaise)),
                BankKv('GST on fee', bankMoney(s.taxPaise)),
                BankKv('Net paid out', bankMoney(s.netPaise), strong: true),
                BankKv('Items', '${s.items}'),
                if (s.unmatchedItems > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: bankPill('${s.unmatchedItems} ${gt('unmatched')}', tone: 'bad'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        ChipRail(children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip('All items',
                selected: !_unmatched,
                onTap: () {
                  _unmatched = false;
                  _pageNo = 0;
                  _load();
                }),
          ),
          AppChip('Unmatched only',
              selected: _unmatched,
              onTap: () {
                _unmatched = true;
                _pageNo = 0;
                _load();
              }),
        ]),
        const SizedBox(height: 12),
        if (_loading && it == null)
          const SkeletonRows(rows: 4)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (it != null && it.items.isEmpty)
          EmptyState(
              icon: 'check',
              title: gt(_unmatched ? 'Nothing unmatched' : 'No items yet'),
              copy: gt(_unmatched
                  ? 'Every line of this settlement is matched.'
                  : 'Details may arrive a little after the payout.'))
        else if (it != null) ...[
          ResultSummary('${it.totalText} ${gt('items')}'),
          for (final i in it.items) _item(i),
          BankPager(page: it, onPage: (n) => _load(page: n)),
        ],
      ],
    );
  }

  Widget _item(SettlementItem i) {
    return BankCard(
      alert: !i.matched,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(i.providerEntityId.isEmpty ? (i.reference ?? '-') : i.providerEntityId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bankStyle(13.5, FontWeight.w800, AppColors.ink)),
            ),
            Text(bankMoney(i.netPaise),
                style: bankStyle(14, FontWeight.w800, i.netPaise < 0 ? AppColors.red : AppColors.ink)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            bankPill(i.kind),
            if (i.method != null) bankPill(i.method!),
            bankPill(i.matched ? gt('Matched') : gt('Not matched'),
                tone: i.matched ? 'good' : 'bad'),
          ]),
          const SizedBox(height: 6),
          Text(
              '${gt('Gross')} ${bankMoney(i.grossPaise)} · ${gt('Fee')} ${bankMoney(i.feePaise)} · GST ${bankMoney(i.taxPaise)}'
              '${i.reference == null ? '' : ' · ${i.reference}'}'
              '${i.utr == null ? '' : ' · UTR ${i.utr}'}',
              style: bankStyle(11.5, FontWeight.w600, AppColors.ink2)),
          if (i.orderNo != null || i.invoiceNo != null || i.refundId != null) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 12, children: [
              if (i.orderNo != null)
                AppLink('${gt('Order')} ${i.orderNo}',
                    minHeight: 30, onTap: () => go('/admin/order/${i.orderNo}')),
              if (i.invoiceNo != null)
                Text('${gt('Bill')} ${i.invoiceNo}',
                    style: bankStyle(12, FontWeight.w800, AppColors.ink)),
              if (i.refundId != null)
                Text(gt('Refund'), style: bankStyle(12, FontWeight.w800, AppColors.ink)),
            ]),
          ],
        ],
      ),
    );
  }
}
