import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/customer_admin_dto.dart';
import '../../data/api/dto.dart' show AdminSummaryDto, LedgerViewDto;
import '../../provider/state_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';

/// `#/admin/customers` - customer support tools (admin only).
///
/// `GET /admin/customers?q=` (search), `GET /admin/customers/{id}` (coins,
/// credit owed, open orders), `PATCH /admin/customers/{id}` (block / unblock)
/// and `POST /admin/customers/{id}/coins` (goodwill coins or a take-back).
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _q = TextEditingController();
  List<CustomerRowDto> _rows = [];
  int _total = 0;
  bool _totalExact = true;
  bool _more = false;
  int _page = 0;
  bool _loading = false;
  String? _error;

  /// Search term the shown rows were fetched with (what "Load more" and a
  /// refresh must keep using, even while the box holds newer, unsent text).
  String _applied = '';
  bool _reload = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) {
      // A search / clear arrived mid-flight: run it right after.
      if (!more) _reload = true;
      return;
    }
    final page = more ? _page + 1 : 0;
    if (!more) _applied = _q.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.instance.admin
          .searchCustomers(q: _applied, page: page, size: 20);
      if (!mounted) return;
      setState(() {
        _rows = more ? [..._rows, ...r.items] : r.items;
        _total = r.total;
        _totalExact = r.totalExact;
        _more = r.hasMore ?? (_rows.length < r.total);
        _page = page;
        _loading = false;
      });
      _runPending();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = gt(e.message);
        _loading = false;
      });
      _runPending();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load customers.';
        _loading = false;
      });
      _runPending();
    }
  }

  void _runPending() {
    if (!_reload) return;
    _reload = false;
    _load();
  }

  /// Clears the box AND the applied term, then re-reads page 0.
  void _clearSearch() {
    _q.clear();
    _load();
  }

  void _open(CustomerRowDto row) {
    final id = row.id;
    if (id == null) return;
    showAppSheet<void>(
      context: context,
      title: row.title,
      sub: gt('Customer details'),
      builder: (ctx) => _CustomerDetail(id: id, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    StateScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Customers'),
                  sub: '${_totalExact ? '$_total' : '10,000+'} ${gt(_total == 1 && _totalExact ? 'customer' : 'customers')}',
                  bell: false,
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppField(
                        label: gt('Search'),
                        controller: _q,
                        placeholder: gt('Name, email or mobile'),
                        textInputAction: TextInputAction.search,
                        onEditingComplete: () => _load(),
                        onChanged: (_) => setState(() {}),
                        suffix: IconBtn(
                          'search',
                          size: 34,
                          iconSize: 16,
                          onTap: () => _load(),
                        ),
                      ),
                      if (_q.text.isNotEmpty || _applied.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        AppLink(gt('Clear search'), onTap: _clearSearch),
                      ],
                      const SizedBox(height: 12),
                      if (_rows.isNotEmpty || _total > 0) ...[
                        KpiGrid([
                          KpiCard(
                            icon: 'users',
                            tint: AppColors.navy2,
                            bg: AppColors.navyTint,
                            label: gt('Total customers'),
                            value: _totalExact ? '$_total' : '10,000+',
                          ),
                          KpiCard(
                            icon: 'check',
                            tint: AppColors.green,
                            bg: AppColors.greenTint,
                            label: gt('Active (shown)'),
                            value: '${_rows.where((r) => r.active).length}',
                          ),
                          KpiCard(
                            icon: 'close',
                            tint: AppColors.red,
                            bg: AppColors.redTint,
                            label: gt('Blocked (shown)'),
                            value: '${_rows.where((r) => !r.active).length}',
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (_error != null)
                        ErrorRetry(
                          title: gt("Couldn't load customers"),
                          message: _error!,
                          onRetry: () => _load(),
                          retryLabel: gt('Try again'),
                        )
                      else if (_rows.isEmpty && _loading)
                        const AdminLoadingOrElse(fallback: SizedBox.shrink())
                      else if (_rows.isEmpty && !_loading)
                        const Hint('No customers match that search.')
                      else if (MediaQuery.of(context).size.width >= 860)
                        TableCard(
                          header: const TableHeadRow([
                            TableCol('Customer', 4),
                            TableCol('Mobile', 3),
                            TableCol('Email', 4),
                            TableCol('Status', 2),
                          ], trailing: 22),
                          rows: [
                            for (var i = 0; i < _rows.length; i++)
                              _wideRow(_rows[i], last: i == _rows.length - 1),
                          ],
                        )
                      else
                        CardPanel(
                          title: gt('Customers'),
                          child: Column(
                            children: [
                              for (var i = 0; i < _rows.length; i++)
                                _row(_rows[i], last: i == _rows.length - 1),
                            ],
                          ),
                        ),
                      if (_loading && _rows.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        ),
                      if (!_loading && _more) ...[
                        const SizedBox(height: 10),
                        AppButton(
                          'Load more',
                          variant: BtnVariant.secondary,
                          block: true,
                          onTap: () => _load(more: true),
                        ),
                      ],
                      const SizedBox(height: 8),
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

  Widget _row(CustomerRowDto c, {required bool last}) {
    final sub = [
      if ((c.mobile ?? '').isNotEmpty) c.mobile!,
      if ((c.email ?? '').isNotEmpty) c.email!,
    ].join(' · ');
    return InkWell(
      onTap: () => _open(c),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!c.active)
              StatusChip(gt('BLOCKED'), fg: AppColors.red3, bg: AppColors.redTint)
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

extension _WideRows on _AdminCustomersScreenState {
  Widget _wideRow(CustomerRowDto c, {required bool last}) {
    const t = TextStyle(
        fontFamily: AppTheme.uiFont, fontSize: 12.5, color: AppColors.ink2);
    Widget cell(int flex, String v, {TextStyle style = t}) => Expanded(
        flex: flex,
        child: Text(v.isEmpty ? '-' : v,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: style));
    return TableRowShell(
      last: last,
      onTap: () => _open(c),
      semanticLabel: c.title,
      child: Row(children: [
        cell(4, c.title,
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink)),
        cell(3, c.mobile ?? ''),
        cell(4, c.email ?? ''),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: c.active
                ? StatusChip(gt('Active'),
                    fg: AppColors.green, bg: AppColors.greenTint)
                : StatusChip(gt('BLOCKED'),
                    fg: AppColors.red3, bg: AppColors.redTint),
          ),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 22, color: AppColors.ink3),
      ]),
    );
  }
}

class _CustomerDetail extends StatefulWidget {
  const _CustomerDetail({required this.id, required this.onChanged});

  final String id;
  final Future<void> Function({bool more}) onChanged;

  @override
  State<_CustomerDetail> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<_CustomerDetail> {
  CustomerViewDto? _c;
  String? _error;
  bool _busy = false;
  final _delta = TextEditingController();
  final _reason = TextEditingController();
  String _coinsErr = '';
  String _reasonErr = '';

  // Order history + coin ledger (paged, newest first).
  final List<AdminSummaryDto> _orders = [];
  final List<LedgerViewDto> _ledger = [];
  int _ordersPage = 0;
  int _ledgerPage = 0;
  bool _ordersMore = false;
  bool _ledgerMore = false;
  bool _ordersLoaded = false;
  bool _ledgerLoaded = false;
  bool _ordersBusy = false;
  bool _ledgerBusy = false;
  String _histErr = '';

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadOrders();
    _loadLedger();
  }

  Future<void> _loadOrders({bool more = false}) async {
    if (_ordersBusy) return;
    final page = more ? _ordersPage + 1 : 0;
    setState(() => _ordersBusy = true);
    try {
      final r = await Api.instance.admin.customerOrders(widget.id, page: page);
      if (!mounted) return;
      setState(() {
        if (!more) _orders.clear();
        _orders.addAll(r.items);
        _ordersPage = page;
        _ordersMore = r.hasMore ?? (_orders.length < r.total);
        _ordersLoaded = true;
        _ordersBusy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _histErr = gt(e.message);
        _ordersLoaded = true;
        _ordersBusy = false;
      });
    }
  }

  Future<void> _loadLedger({bool more = false}) async {
    if (_ledgerBusy) return;
    final page = more ? _ledgerPage + 1 : 0;
    setState(() => _ledgerBusy = true);
    try {
      final r =
          await Api.instance.admin.customerWalletLedger(widget.id, page: page);
      if (!mounted) return;
      setState(() {
        if (!more) _ledger.clear();
        _ledger.addAll(r.items);
        _ledgerPage = page;
        _ledgerMore = r.hasMore ?? (_ledger.length < r.total);
        _ledgerLoaded = true;
        _ledgerBusy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _histErr = gt(e.message);
        _ledgerLoaded = true;
        _ledgerBusy = false;
      });
    }
  }

  Widget _histHead(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(gt(t).toUpperCase(),
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
                color: AppColors.ink2)),
      );

  /// Rounded card around a group of rows inside the detail sheet.
  Widget _group(List<Widget> rows) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: rows),
      );

  /// One history line: [left] text, optional status chip, [right] value.
  Widget _histRow(String left, String right,
      {String? chip, Color? chipFg, Color? chipBg, Color? valueColor}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink2)),
          ),
          if (chip != null) ...[
            const SizedBox(width: 8),
            StatusChip(chip,
                fg: chipFg ?? AppColors.ink2, bg: chipBg ?? AppColors.bg),
          ],
          const SizedBox(width: 10),
          Text(right,
              style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.ink)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _delta.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final c = await Api.instance.admin.getCustomer(widget.id);
      if (!mounted) return;
      setState(() => _c = c);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = gt(e.message));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load the customer.');
    }
  }

  Future<void> _toggleBlock() async {
    final c = _c;
    if (c == null || _busy) return;
    final block = c.active;
    if (block) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(gt('Block this customer?')),
          content: Text(gt(
              'They are signed out everywhere (an open session can last up '
              'to 15 minutes) and cannot sign in until you unblock them.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(gt('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(gt('Block'),
                  style: const TextStyle(color: AppColors.red)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final u =
          await Api.instance.admin.setCustomerActive(widget.id, !c.active);
      if (!mounted) return;
      setState(() {
        _c = u;
        _busy = false;
      });
      showToast(u.active ? 'Customer unblocked' : 'Customer blocked');
      unawaited(widget.onChanged());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(gt(e.message), 'error');
    }
  }

  Future<void> _adjustCoins() async {
    if (_busy) return;
    final delta = int.tryParse(_delta.text.trim());
    final reason = _reason.text.trim();
    var coinsErr = '';
    var reasonErr = '';
    if (delta == null || delta == 0 || delta.abs() > 100000) {
      coinsErr = 'A non-zero number up to 100000 (use - to take back)';
    }
    if (reason.isEmpty || reason.length > 100) {
      reasonErr = '1 to 100 characters';
    }
    if (coinsErr.isNotEmpty || reasonErr.isNotEmpty) {
      setState(() {
        _coinsErr = coinsErr;
        _reasonErr = reasonErr;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final u = await Api.instance.admin
          .adjustCustomerCoins(widget.id, delta!, reason);
      if (!mounted) return;
      setState(() {
        _c = u;
        _busy = false;
        _coinsErr = '';
        _reasonErr = '';
      });
      _delta.clear();
      _reason.clear();
      showToast(delta > 0 ? 'Coins given' : 'Coins taken back');
      // The coin history below must show the adjustment just made.
      unawaited(_loadLedger());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // Validation errors are keyed `coins` (not `delta`) and `reason`.
      final f = e.details?['fields'];
      if (f is Map) {
        setState(() {
          _coinsErr = (f['coins'] ?? f['delta'])?.toString() ?? '';
          _reasonErr = f['reason']?.toString() ?? '';
        });
        if (_coinsErr.isNotEmpty || _reasonErr.isNotEmpty) return;
      }
      showToast(gt(e.message), 'error');
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(gt(k),
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12.5,
                      color: AppColors.ink3)),
            ),
            Text(v,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_error != null) {
      return ErrorRetry(
        title: gt("Couldn't load customer"),
        message: _error!,
        onRetry: () {
          setState(() => _error = null);
          _fetch();
        },
        retryLabel: gt('Try again'),
      );
    }
    if (c == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SkeletonRows(rows: 5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _group([
        _kv('Status', gt(c.active ? 'Active' : 'Blocked')),
        _kv('Mobile',
            (c.mobile ?? '').isEmpty
                ? '-'
                : '${c.mobile}${c.mobileVerified ? ' (${gt('verified')})' : ''}'),
        _kv('Email', (c.email ?? '').isEmpty ? '-' : c.email!),
        _kv('Signed up', gt(c.source == 'POS' ? 'At the counter' : 'In the app')),
        _kv('Coins', '${c.coinBalance}'),
        _kv('Credit owed (udhar)',
            'Rs ${(c.creditBalancePaise / 100).toStringAsFixed(2)}'),
        _kv('Open orders', '${c.openOrders}'),
        ]),
        const SizedBox(height: 14),
        Text(gt('Give or take back coins'),
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink2)),
        const SizedBox(height: 8),
        AppField(
          label: gt('Coins (+ give, - take back)'),
          controller: _delta,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          placeholder: '50',
          error: _coinsErr.isEmpty ? null : _coinsErr,
        ),
        const SizedBox(height: 8),
        AppField(
          label: gt('Reason (kept in the audit log)'),
          controller: _reason,
          maxLength: 100,
          placeholder: gt('Goodwill for late delivery'),
          error: _reasonErr.isEmpty ? null : _reasonErr,
        ),
        const SizedBox(height: 10),
        AppButton('Apply coins',
            block: true, loading: _busy, onTap: _busy ? null : _adjustCoins),
        _histHead('Orders'),
        if (!_ordersLoaded)
          const SkeletonRows(rows: 2)
        else if (_orders.isEmpty)
          _group([_histRow(gt('No orders yet'), '')])
        else
          _group([
            for (final o in _orders)
              _histRow(
                o.orderNo ?? '',
                'Rs ${(o.totalPaise / 100).toStringAsFixed(2)}',
                chip: o.status == null ? null : gt(o.status!),
                chipFg: AppColors.navy2,
                chipBg: AppColors.navyTint,
              ),
          ]),
        if (_ordersMore)
          TextButton(
              onPressed: _ordersBusy ? null : () => _loadOrders(more: true),
              child: Text(gt('Show more orders'))),
        _histHead('Coin history'),
        if (!_ledgerLoaded)
          const SkeletonRows(rows: 2)
        else if (_ledger.isEmpty)
          _group([_histRow(gt('No coin activity'), '')])
        else
          _group([
            for (final l in _ledger)
              _histRow(
                '${switch ((l.kind ?? '').toUpperCase()) {
                  'EARN' => 'Earned',
                  'REDEEM' => 'Redeemed',
                  'REVERSE' => 'Returned',
                  'ADJUST' => 'Adjusted by admin',
                  'EXPIRE' => 'Expired',
                  final k => k,
                }} · ${(l.createdAt ?? '').split('T').first}',
                '${l.coins > 0 ? '+' : ''}${l.coins}',
                valueColor: l.coins > 0 ? AppColors.green : AppColors.red3,
              ),
          ]),
        if (_ledgerMore)
          TextButton(
              onPressed: _ledgerBusy ? null : () => _loadLedger(more: true),
              child: Text(gt('Show more coin history'))),
        if (_histErr.isNotEmpty) Hint(_histErr),
        const SizedBox(height: 10),
        AppButton(
          c.active ? 'Block customer' : 'Unblock customer',
          variant: c.active ? BtnVariant.dangerSoft : BtnVariant.secondary,
          block: true,
          onTap: _busy ? null : _toggleBlock,
        ),
      ],
    );
  }
}
