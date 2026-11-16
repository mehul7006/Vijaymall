import 'dart:async';

import '../../data/validators.dart';
import '../../data/ist.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart' show Api;
import '../../data/api/dto.dart';
import '../../state/app_state.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/confirm.dart';
import '../../widgets/panels.dart';
import '../../widgets/period_picker.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

String _rs(int paise) {
  final neg = paise < 0;
  final a = paise.abs();
  final p = a % 100;
  final base = money(a ~/ 100);
  return '${neg ? '-' : ''}$base${p == 0 ? '' : '.${p.toString().padLeft(2, '0')}'}';
}

/// Parses a rupee string ("250", "250.50") to paise, or null when invalid.
int? _paise(String raw) {
  final v = double.tryParse(raw.trim());
  // "NaN" / "Infinity" parse as doubles but cannot become paise; absurd sizes
  // would overflow the backend's 64-bit amounts.
  if (v == null || !v.isFinite || v.abs() > 1e12) return null;
  return (v * 100).round();
}

String _day(String? iso) {
  final d = parseIst(iso ?? '');
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// `#/admin/credit` - customers' udhar: who owes what, limits, ledger,
/// adjustments and the credit report summary.
class AdminCreditScreen extends StatelessWidget {
  const AdminCreditScreen({super.key});

  @override
  Widget build(BuildContext context) => const _CreditBody();
}

class _CreditBody extends StatefulWidget {
  const _CreditBody();

  @override
  State<_CreditBody> createState() => _CreditBodyState();
}

class _CreditBodyState extends State<_CreditBody> {
  bool _loaded = false;

  /// 'credit' = limit above zero (`eligibleOnly`), 'dues' = owes right now
  /// (`outstandingOnly`), 'all' = every account (`outstandingOnly=false`).
  String _view = 'credit';
  final _q = TextEditingController();
  Timer? _debounce;

  final List<DebtorDto> _rows = [];
  int _page = 0;
  int _total = 0;
  bool _totalExact = true;
  bool _hasMore = false;
  bool _loading = true;
  bool _more = false;
  String? _error;
  int _gen = 0;

  PeriodSel _sel = const PeriodSel('month');
  Map<String, dynamic>? _report;
  String? _reportError;
  int _repGen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _reload();
    _loadReport();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  /// The search runs on the server (`q`: part of the name or mobile).
  void _onSearch() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _resetFilters() {
    _q.clear();
    _view = 'credit';
    _reload();
  }

  Future<PageDebtorDto> _fetch(int page) => Api.instance.admin.getCreditAccounts(
        outstandingOnly: _view == 'dues',
        eligibleOnly: _view == 'credit',
        q: _q.text,
        page: page,
        size: 50,
      );

  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _fetch(0);
      if (!mounted || gen != _gen) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(p.items);
        _page = 0;
        _total = p.total;
        _totalExact = p.totalExact;
        _hasMore = p.hasMore ?? (p.items.length < p.total);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = gt(ApiException.fieldError(e.fields, ['q']) ?? e.message);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = gt('Could not load credit accounts.');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_more) return;
    final gen = _gen;
    setState(() => _more = true);
    try {
      final p = await _fetch(_page + 1);
      if (!mounted || gen != _gen) return;
      setState(() {
        _rows.addAll(p.items);
        _page++;
        _total = p.total;
        _totalExact = p.totalExact;
        _hasMore = p.hasMore ?? false;
      });
    } on ApiException catch (e) {
      if (mounted) showToast(gt(e.message), 'error');
    } catch (_) {
      if (mounted) showToast(gt('Could not load more customers.'), 'error');
    }
    if (mounted) setState(() => _more = false);
  }

  Future<void> _loadReport() async {
    final gen = ++_repGen;
    setState(() => _reportError = null);
    try {
      final r = await Api.instance.admin.creditReportRaw(
          period: _sel.apiPeriod, from: _sel.apiFrom, to: _sel.apiTo);
      if (!mounted || gen != _repGen) return;
      setState(() => _report = r);
    } on ApiException catch (e) {
      if (!mounted || gen != _repGen) return;
      setState(() => _reportError = gt(
          ApiException.fieldError(e.fields, ['to', 'from', 'period']) ??
              e.message));
    } catch (_) {
      if (mounted) {
        setState(() => _reportError = gt('Could not load the credit report.'));
      }
    }
  }

  void _open(DebtorDto d) {
    showAppSheet<void>(
      context: context,
      title: d.name?.isNotEmpty == true ? d.name! : (d.mobile ?? gt('Customer')),
      sub: d.mobile ?? '',
      builder: (ctx) => _DetailBody(customerId: d.customerId ?? ''),
    ).then((_) {
      if (mounted) {
        _reload();
        _loadReport();
      }
    });
  }

  void _approve() {
    showAppSheet<void>(
      context: context,
      title: gt('Approve credit'),
      sub: gt('Give a customer an udhar limit by mobile number'),
      builder: (ctx) => const _ApproveBody(),
    ).then((_) {
      if (mounted) {
        _reload();
        _loadReport();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Credit'),
                  sub: r == null
                      ? gt('Customer udhar accounts')
                      : '${_n(r['customersWithDues'])} ${gt('customers owe')} ${_rs(_n(r['outstandingPaise']))}',
                  bell: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: IconBtn('plus', size: 38, iconSize: 17, onTap: _approve),
                    ),
                  ],
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summary(r),
                      const SizedBox(height: 12),
                      CardPanel(
                        title: gt('Accounts'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppField(
                              label: gt('Search customers'),
                              controller: _q,
                              placeholder: gt('Name or mobile'),
                              maxLength: 100,
                              onChanged: (_) => _onSearch(),
                            ),
                            const SizedBox(height: 10),
                            ChipRail(children: [
                              for (final v in const ['credit', 'dues', 'all'])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: AppChip(
                                      gt(v == 'credit'
                                          ? 'Credit customers'
                                          : v == 'dues'
                                              ? 'With dues'
                                              : 'All accounts'),
                                      selected: _view == v,
                                      onTap: () {
                                        if (_view == v) return;
                                        _view = v;
                                        _reload();
                                      }),
                                ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              _view == 'dues'
                                  ? gt('Customers who owe money right now.')
                                  : _view == 'all'
                                      ? gt('Every customer with a credit account, with or without a limit or balance.')
                                      : gt('Customers with a credit limit above zero. Tap one to change the limit.'),
                              style: _sub,
                            ),
                            const SizedBox(height: 10),
                            if (_loading && _rows.isEmpty)
                              const SkeletonRows(rows: 4)
                            else if (_error != null)
                              ErrorRetry(
                                title: gt("Couldn't load accounts"),
                                message: _error!,
                                onRetry: _reload,
                                retryLabel: gt('Try again'),
                              )
                            else if (_rows.isEmpty) ...[
                              Hint(_q.text.trim().isNotEmpty
                                  ? gt('No customer matches that search.')
                                  : _view == 'dues'
                                      ? gt('No customer owes anything right now.')
                                      : gt('No customer has credit yet. Tap + to approve one by mobile number.')),
                              if (_q.text.trim().isNotEmpty || _view != 'credit')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: AppButton(gt('Clear search and filters'),
                                      size: BtnSize.xs,
                                      variant: BtnVariant.secondary,
                                      onTap: _resetFilters),
                                ),
                            ] else ...[
                              Text(
                                  '${_total}${_totalExact ? '' : '+'} ${gt('customers')}'
                                  '${_totalExact || _total < 10000 ? '' : ' (10,000+)'}',
                                  style: _sub),
                              const SizedBox(height: 4),
                              for (var i = 0; i < _rows.length; i++)
                                _row(_rows[i]),
                            ],
                            if (_hasMore && !_loading) ...[
                              const SizedBox(height: 10),
                              AppButton(gt('Load more'),
                                  variant: BtnVariant.secondary,
                                  block: true,
                                  loading: _more,
                                  onTap: _more ? null : _loadMore),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }

  Widget _summary(Map<String, dynamic>? r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r != null) ...[
          KpiGrid([
            KpiCard(
              icon: 'wallet',
              tint: AppColors.red,
              bg: AppColors.redTint,
              label: gt('Outstanding'),
              value: _rs(_n(r['outstandingPaise'])),
            ),
            KpiCard(
              icon: 'users',
              tint: AppColors.goldInk,
              bg: AppColors.goldTint,
              label: gt('Customers with dues'),
              value: '${_n(r['customersWithDues'])}',
            ),
            KpiCard(
              icon: 'check',
              tint: AppColors.green,
              bg: AppColors.greenTint,
              label: gt('Recovered'),
              value: _rs(_n(r['recoveredPaise'])),
            ),
            KpiCard(
              icon: 'coin',
              tint: AppColors.navy2,
              bg: AppColors.navyTint,
              label: gt('Credit given'),
              value: _rs(_n(r['givenPaise'])),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        _summaryPanel(r),
      ],
    );
  }

  Widget _summaryPanel(Map<String, dynamic>? r) {
    final byMode = r?['recoveredByMode'] is Map
        ? Map<String, dynamic>.from(r!['recoveredByMode'] as Map)
        : const <String, dynamic>{};
    final types = (r?['salesByPaymentType'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final days = (r?['byDay'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final debtors = (r?['topDebtors'] as List? ?? [])
        .whereType<Map>()
        .map((e) => DebtorDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return CardPanel(
      title: gt('Credit report'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PeriodPicker(
            value: _sel,
            maxDays: 366,
            error: _reportError,
            onChanged: (v) {
              setState(() => _sel = v);
              _loadReport();
            },
          ),
          const SizedBox(height: 10),
          if (r == null)
            (_reportError == null
                ? const SkeletonRows(rows: 3)
                : Hint(gt('No report yet.')))
          else ...[
            Text('${r['from']} ${gt('to')} ${r['to']}', style: _sub),
            const SizedBox(height: 4),
            _kv(gt('Outstanding now'), _rs(_n(r['outstandingPaise'])),
                bold: true),
            _kv(gt('Customers with dues'), '${_n(r['customersWithDues'])}'),
            _kv(gt('Credit given'), _rs(_n(r['givenPaise']))),
            _kv(gt('Recovered'), _rs(_n(r['recoveredPaise']))),
            _kv(gt('Returned against credit'), _rs(_n(r['returnedPaise']))),
            _kv(gt('Written off'), _rs(_n(r['writtenOffPaise']))),
            _kv(gt('Added by adjustment'), _rs(_n(r['addedPaise']))),
            if (byMode.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final e in byMode.entries)
                _kv('${gt('Recovered via')} ${e.key}', _rs(_n(e.value))),
            ],
            if (types.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(gt('Bills by payment type'), style: _h),
              const SizedBox(height: 4),
              for (final t in types)
                _kv('${t['type']} (${_n(t['bills'])} ${gt('bills')})',
                    _rs(_n(t['totalPaise']))),
            ],
            if (days.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(gt('Per day: given / recovered'), style: _h),
              const SizedBox(height: 4),
              for (final d in days.reversed.take(31))
                _kv('${d['date']}',
                    '${_rs(_n(d['creditGivenPaise']))} / ${_rs(_n(d['recoveredPaise']))}'),
              if (days.length > 31)
                Text(gt('The latest 31 days are listed.'), style: _sub),
            ],
            const SizedBox(height: 10),
            Text(gt('Top debtors'), style: _h),
            const SizedBox(height: 4),
            if (debtors.isEmpty)
              Hint(gt('Nobody owes anything right now.'))
            else
              for (final d in debtors)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: d.customerId == null ? null : () => _open(d),
                  child: _kv(
                      d.name?.isNotEmpty == true
                          ? '${d.name}${d.blocked ? ' (${gt('blocked')})' : ''}'
                          : (d.mobile ?? '-'),
                      _rs(d.balancePaise)),
                ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _sub),
            Text(value,
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.ink,
                )),
          ],
        ),
      );

  Widget _row(DebtorDto d) {
    final over = d.limitPaise > 0 && d.balancePaise > d.limitPaise;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(
                child: Text(
                    d.name?.isNotEmpty == true ? d.name! : (d.mobile ?? '-'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _h),
              ),
              if (d.blocked) ...[
                const SizedBox(width: 8),
                StatusChip(gt('Blocked'),
                    fg: AppColors.red, bg: AppColors.redTint),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              '${d.mobile ?? ''}'
              '${d.lastPaymentAt == null ? '' : ' - ${gt('Last payment')} ${_day(d.lastPaymentAt)}'}',
              style: _sub,
            ),
            const SizedBox(height: 6),
            Wrap(
              runSpacing: 4,
              children: [
                _stat(gt('Limit'), _rs(d.limitPaise)),
                _stat(gt('Owes'), _rs(d.balancePaise),
                    color: d.balancePaise > 0 ? AppColors.red : null),
                _stat(gt('Available'), _rs(d.availablePaise),
                    color: d.limitPaise <= 0 || over || d.blocked
                        ? AppColors.red
                        : AppColors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

const _h = TextStyle(
  fontFamily: AppTheme.uiFont,
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  color: AppColors.ink,
);
const _sub = TextStyle(
  fontFamily: AppTheme.uiFont,
  fontSize: 11.5,
  color: AppColors.ink3,
);

Widget _kv(String k, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink2,
                )),
          ),
          Text(v,
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: bold ? 15 : 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              )),
        ],
      ),
    );

/// Account detail: balance/limit, ledger, set limit, adjust balance.
class _DetailBody extends StatefulWidget {
  const _DetailBody({required this.customerId});
  final String customerId;

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  CreditAccountDto? _acc;
  final List<CreditLedgerEntryDto> _ledger = [];
  int _ledgerPage = 0;
  bool _ledgerHasMore = false;
  bool _ledgerMore = false;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  final _limit = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _writeOff = true;

  /// One `Idempotency-Key` per adjustment: kept while the same adjustment is
  /// retried (so it is applied once), renewed when the figures change.
  String? _adjKey;
  String? _adjPrint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _limit.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final admin = Api.instance.admin;
      final acc = await admin.getCreditAccount(widget.customerId);
      final led = await admin.getCreditLedger(widget.customerId, page: 0);
      if (!mounted) return;
      setState(() {
        _acc = acc;
        _ledger
          ..clear()
          ..addAll(led.items);
        _ledgerPage = 0;
        _ledgerHasMore = led.hasMore ?? (led.items.length < led.total);
        _error = null;
        _loading = false;
        if (_limit.text.isEmpty) {
          _limit.text = (acc.limitPaise / 100).toStringAsFixed(0);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = gt(e.message);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = gt('Could not load that account.');
        _loading = false;
      });
    }
  }

  Future<void> _moreLedger() async {
    if (_ledgerMore) return;
    setState(() => _ledgerMore = true);
    try {
      final led = await Api.instance.admin
          .getCreditLedger(widget.customerId, page: _ledgerPage + 1);
      if (!mounted) return;
      setState(() {
        _ledger.addAll(led.items);
        _ledgerPage++;
        _ledgerHasMore = led.hasMore ?? false;
      });
    } on ApiException catch (e) {
      if (mounted) showToast(gt(e.message), 'error');
    } catch (_) {
      if (mounted) showToast(gt('Could not load more entries.'), 'error');
    }
    if (mounted) setState(() => _ledgerMore = false);
  }

  String? _limitErr;
  String? _amountErr;
  String? _noteErr;

  Future<void> _saveLimit() async {
    // 0 switches credit off; the server accepts 0 to 100,000,000 paise.
    final m = Validators.rupees(_limit.text,
        label: 'Credit limit', required: true, max: 1000000);
    setState(() => _limitErr = m == null ? null : gt(m));
    final p = m == null ? _paise(_limit.text) : null;
    if (p == null || p < 0) return;
    final ok = await confirmAction(
      context,
      title: 'Change the udhar limit?',
      body: p == 0
          ? gt('Credit will be switched off for this customer (limit 0).')
          : '${gt("The customer's udhar limit becomes")} ${_rs(p.round())}.',
      confirmLabel: 'Change',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.instance.admin.setCreditLimit(widget.customerId, p);
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(gt('Limit updated'));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _limitErr = gt(
            ApiException.fieldError(e.fields, ['limitPaise']) ?? e.message);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(gt('Could not change the limit.'), 'error');
    }
  }

  Future<void> _adjust() async {
    final m = Validators.rupees(_amount.text,
        label: 'Amount', required: true, min: 0.01, max: 1000000);
    final n = Validators.text(_note.text,
        label: 'Note', required: true, max: 200);
    final p = m == null ? _paise(_amount.text) : null;
    String? amountErr = m == null ? null : gt(m);
    if (amountErr == null && p != null && p <= 0) {
      amountErr = gt('Amount must be more than zero');
    }
    final owed = _acc?.balancePaise ?? 0;
    if (amountErr == null && p != null && _writeOff && p > owed) {
      amountErr =
          '${gt('A write-off cannot be more than what the customer owes')} (${_rs(owed)})';
    }
    setState(() {
      _amountErr = amountErr;
      _noteErr = n == null ? null : gt(n);
    });
    if (amountErr != null || n != null || p == null) return;
    final ok = await confirmAction(
      context,
      title: _writeOff ? 'Write off udhar?' : 'Add to udhar?',
      body: '${gt(_writeOff ? 'Reduce what the customer owes by' : 'Increase what the customer owes by')} '
          '${_rs((p).round())}. ${gt('This can only be reversed by another adjustment.')}',
      confirmLabel: _writeOff ? 'Write off' : 'Add',
    );
    if (!ok || !mounted) return;
    final signed = _writeOff ? -p : p;
    final note = _note.text.trim();
    final print = '$signed|$note';
    if (_adjKey == null || _adjPrint != print) {
      _adjKey = newIdempotencyKey();
      _adjPrint = print;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.admin.adjustCredit(widget.customerId, signed, note,
          idempotencyKey: _adjKey);
      if (!mounted) return;
      _adjKey = null;
      _adjPrint = null;
      _amount.clear();
      _note.clear();
      setState(() => _busy = false);
      showToast(gt('Balance adjusted'));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'IDEMPOTENCY_KEY_REUSED') {
        _adjKey = null;
        _adjPrint = null;
      }
      final bal = e.details?['balancePaise'];
      setState(() {
        _busy = false;
        if (e.code == 'CREDIT_ADJUST_TOO_LARGE') {
          _amountErr = bal is num
              ? '${gt('That would make the balance negative. The customer owes')} ${_rs(bal.toInt())}.'
              : gt('That would make the balance negative.');
        } else {
          final fa = ApiException.fieldError(e.fields, ['amountPaise']);
          final fn = ApiException.fieldError(e.fields, ['note']);
          _amountErr = fa == null ? null : gt(fa);
          _noteErr = fn == null ? null : gt(fn);
          if (fa == null && fn == null) {
            showToast(gt(e.message), 'error');
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(gt('Could not adjust the balance.'), 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _acc;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 6, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppColors.red)),
            )
          : _error != null
              ? Hint(_error!)
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (a != null) ...[
                        _kv(gt('Owes'), _rs(a.balancePaise), bold: true),
                        _kv(gt('Limit'), _rs(a.limitPaise)),
                        _kv(gt('Available'), _rs(a.availablePaise)),
                        if (a.blocked)
                          Hint(gt('This customer is blocked: no credit sales until they are unblocked.')),
                      ],
                      const SizedBox(height: 12),
                      AppField(
                        label: gt('Credit limit (Rs)'),
                        controller: _limit,
                        numeric: true,
                        error: _limitErr,
                      ),
                      const SizedBox(height: 4),
                      Text(gt('0 switches credit off. Lowering the limit below the balance only stops further credit.'),
                          style: _sub),
                      const SizedBox(height: 8),
                      AppButton(gt('Save limit'),
                          variant: BtnVariant.secondary,
                          block: true,
                          loading: _busy,
                          onTap: _busy ? null : _saveLimit),
                      const SizedBox(height: 16),
                      Text(gt('Adjust balance'), style: _h),
                      const SizedBox(height: 8),
                      ChipRail(children: [
                        AppChip(gt('Write off / reduce'),
                            selected: _writeOff,
                            onTap: () => setState(() => _writeOff = true)),
                        AppChip(gt('Add to dues'),
                            selected: !_writeOff,
                            onTap: () => setState(() => _writeOff = false)),
                      ]),
                      const SizedBox(height: 10),
                      FieldRow(
                        flex: const [2, 3],
                        children: [
                          AppField(
                              label: gt('Amount (Rs)'),
                              controller: _amount,
                              error: _amountErr,
                              numeric: true),
                          AppField(
                              label: gt('Note (required)'),
                              controller: _note,
                              error: _noteErr,
                              maxLength: 200),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppButton(gt('Apply adjustment'),
                          block: true,
                          loading: _busy,
                          onTap: _busy ? null : _adjust),
                      const SizedBox(height: 16),
                      Text(gt('Ledger'), style: _h),
                      const SizedBox(height: 6),
                      if (_ledger.isEmpty)
                        Hint(gt('No entries yet.'))
                      else
                        for (final e in _ledger) _ledgerRow(e),
                      if (_ledgerHasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AppButton(gt('Load more'),
                              variant: BtnVariant.secondary,
                              block: true,
                              loading: _ledgerMore,
                              onTap: _ledgerMore ? null : _moreLedger),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _ledgerRow(CreditLedgerEntryDto e) {
    final owes = e.deltaPaise > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${gt(_kindLabel(e.kind))}${(e.refNo ?? '').isEmpty ? '' : ' - ${e.refNo}'}',
                  style: _h,
                ),
                Text(
                  '${_day(e.at)}${(e.note ?? '').isEmpty ? '' : ' - ${e.note}'}',
                  style: _sub,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${owes ? '+' : ''}${_rs(e.deltaPaise)}',
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: owes ? AppColors.red : AppColors.ink,
                ),
              ),
              Text('${gt('Bal')} ${_rs(e.balanceAfterPaise)}', style: _sub),
            ],
          ),
        ],
      ),
    );
  }
}

/// Approve / set a credit limit: customer name, mobile and limit are all required.
class _ApproveBody extends StatefulWidget {
  const _ApproveBody();

  @override
  State<_ApproveBody> createState() => _ApproveBodyState();
}

class _ApproveBodyState extends State<_ApproveBody> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _limit = TextEditingController();
  bool _busy = false;
  String? _nameErr;
  String? _mobileErr;
  String? _limitErr;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final nm = Validators.text(_name.text,
        label: gt('Customer name'), max: 100, required: true);
    final mm = Validators.mobile(_mobile.text, required: true);
    final lm = Validators.rupees(_limit.text,
        label: 'Credit limit', required: true, max: 1000000);
    setState(() {
      _nameErr = nm;
      _mobileErr = mm == null ? null : gt(mm);
      _limitErr = lm == null ? null : gt(lm);
    });
    final p = lm == null ? _paise(_limit.text) : null;
    if (nm != null || mm != null || p == null || p < 0) return;
    setState(() => _busy = true);
    try {
      await Api.instance.admin.approveCreditLimit(_mobile.text.trim(), p, name: _name.text.trim());
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(gt('Credit approved'));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      final fm = ApiException.fieldError(e.fields, ['mobile']);
      final fl = ApiException.fieldError(e.fields, ['limitPaise']);
      setState(() {
        _busy = false;
        _mobileErr = fm == null ? null : gt(fm);
        _limitErr = fl == null ? null : gt(fl);
      });
      if (fm == null && fl == null) showToast(gt(e.message), 'error');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(gt('Could not approve credit.'), 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 6, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: gt('Customer name'),
              controller: _name,
              error: _nameErr,
              maxLength: 100,
              placeholder: gt('Name of the customer'),
              onChanged: (_) => setState(() => _nameErr = null),
            ),
            const SizedBox(height: 10),
            FieldRow(
              children: [
                AppField(
                  label: gt('Customer mobile'),
                  controller: _mobile,
                  error: _mobileErr,
                  numeric: true,
                  maxLength: 10,
                  onChanged: (_) => setState(() => _mobileErr = null),
                ),
                AppField(
                  label: gt('Credit limit (Rs)'),
                  controller: _limit,
                  error: _limitErr,
                  numeric: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppButton(gt('Approve'),
                block: true, loading: _busy, onTap: _busy ? null : _go),
          ],
        ),
      ),
    );
  }
}

/// Ledger `kind` codes (doc 30) as readable, translatable labels.
String _kindLabel(String? k) => switch (k) {
      'SALE' => 'Credit sale',
      'RETURN' => 'Return',
      'PAYMENT' => 'Repayment',
      'ADJUST' => 'Adjustment',
      _ => k ?? '',
    };
