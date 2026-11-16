import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart' show Api, paiseToRupees;
import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/panels.dart';
import '../../widgets/period_picker.dart';
import '../../state/gu_strings.dart';

/// `#/admin/reports` — week chart, status counts and revenue breakdowns.
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReportsBody();
  }
}

class _ReportsBody extends StatefulWidget {
  const _ReportsBody();

  @override
  State<_ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends State<_ReportsBody> {
  String _period = 'week'; // week | month | quarter
  PeriodSel _sel = const PeriodSel('week');
  String _view = 'orders'; // orders | revenue
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick off the backend period summary once (no-op outside backend mode).
    if (!_bootstrapped) {
      _bootstrapped = true;
      StateScope.of(context).loadReportSummary(_period);
      StateScope.of(context).loadReportExtras();
    }
  }

  String get _periodTitle => switch (_period) {
        'month' => 'This month',
        'quarter' => 'This quarter',
        _ => 'This week',
      };

  /// 7-bar chart from `state.weekSales` — peak day uses the red gradient.
  Widget _weekChart(List<WeekSale> sales) {
    if (sales.isEmpty) {
      return const EmptyState(
        icon: 'chart',
        title: 'No sales data yet',
        copy: 'Daily sales will appear here once orders come in.',
      );
    }
    return RevenueBarChart(
      height: 190,
      semanticsLabel: 'Sales by day',
      data: [for (final w in sales) BarChartData(w.day, w.amount.toDouble())],
    );
  }
  /// `Card(count) + Card(progress bar)` per distinct status.
  Widget _statusBlock(AppState state, String status, int count, int total) {
    final frac = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(status, label: state.statusLabel(status)),
              const Spacer(),
              Text(
                '$count',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.navy2,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _distinctStatuses(AppState state) {
    final out = <String>[];
    for (final o in state.orders) {
      if (!out.contains(o.status)) out.add(o.status);
    }
    return out;
  }

  Widget _ordersView(AppState state) {
    final statuses = _distinctStatuses(state);
    final total = state.orders.length;
    final periodOrders = state.reportOrders(_period);
    final periodRevenue =
        periodOrders.fold<num>(0, (sum, o) => sum + o.bill.total);
    final delivered =
        state.orders.where((o) => o.status == 'Delivered').length;

    // Server-backed totals (`/admin/reports/summary`) when loaded for this
    // period; the local model stays as the fallback.
    final server = state.adminReportLoaded && state.adminReportPeriod == _period
        ? state.adminReport
        : null;
    final serverOrders =
        server == null ? null : (server.orderCount ?? server.orders.length);
    final serverRevenue = server == null
        ? null
        : (server.salesPaise != null
            ? paiseToRupees(server.salesPaise!)
            : server.orders.fold<int>(0, (s, o) => s + o.totalPaise));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: KpiCard(
                icon: 'box',
                tint: AppColors.navy,
                bg: AppColors.navyTint,
                label: gt('Orders'),
                value: '${serverOrders ?? periodOrders.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                icon: 'chart',
                tint: AppColors.green,
                bg: AppColors.greenTint,
                label: gt('Revenue'),
                value: money(serverRevenue ?? periodRevenue),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                icon: 'coin',
                tint: AppColors.goldInk,
                bg: AppColors.goldTint,
                label: gt('Avg order'),
                value: money((serverOrders ?? periodOrders.length) > 0
                    ? ((serverRevenue ?? periodRevenue) /
                            (serverOrders ?? periodOrders.length))
                        .round()
                    : 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Sales this week'),
          child: _weekChart(state.weekSales),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: _periodTitle,
          child: Column(
            children: [
              BillRow(
                'Orders',
                '${serverOrders ?? periodOrders.length}'
                '${serverOrders != null ? ' · live' : ''}',
              ),
              BillRow(
                'Revenue',
                '${money(serverRevenue ?? periodRevenue)}'
                '${serverRevenue != null ? ' · live' : ''}',
              ),
              // Counter / online split and udhar figures of
              // `/admin/reports/summary` (shown only when the server sent them).
              if (server?.onlineSalesPaise != null)
                BillRow('Online sales',
                    money(paiseToRupees(server!.onlineSalesPaise!))),
              if (server?.posSalesPaise != null)
                BillRow(
                    'Counter sales (${server!.posBills ?? 0} bills)',
                    money(paiseToRupees(server.posSalesPaise!))),
              if (server?.posRefundsPaise != null &&
                  server!.posRefundsPaise! > 0)
                BillRow('Counter refunds',
                    money(paiseToRupees(server.posRefundsPaise!))),
              if (server?.onlineRefundsPaise != null &&
                  server!.onlineRefundsPaise! > 0)
                BillRow('Online refunds',
                    money(paiseToRupees(server.onlineRefundsPaise!))),
              // Revenue above is gross: the backend lists refunds apart and
              // does not subtract them, so show the net once there are any.
              if (server != null &&
                  ((server.posRefundsPaise ?? 0) +
                          (server.onlineRefundsPaise ?? 0)) >
                      0)
                BillRow(
                    'Net of refunds',
                    money(paiseToRupees((server.salesPaise ?? 0) -
                        (server.posRefundsPaise ?? 0) -
                        (server.onlineRefundsPaise ?? 0)))),
              if (server?.creditGivenPaise != null)
                BillRow('Udhar given',
                    money(paiseToRupees(server!.creditGivenPaise!))),
              if (server?.creditRecoveredPaise != null)
                BillRow('Udhar recovered',
                    money(paiseToRupees(server!.creditRecoveredPaise!))),
              if (server?.outstandingCreditPaise != null)
                BillRow('Udhar outstanding now',
                    money(paiseToRupees(server!.outstandingCreditPaise!))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Orders by status'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in statuses)
                _statusBlock(
                  state,
                  s,
                  state.orders.where((o) => o.status == s).length,
                  total,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Today'),
          child: Column(
            children: [
              BillRow(
                  'Orders placed',
                  state.adminReportToday != null
                      ? '${state.adminReportToday!.orderCount ?? state.adminReportToday!.orders.length}'
                      : state.newOrderCount().toString()),
              BillRow(
                  'Revenue',
                  state.adminReportToday?.salesPaise != null
                      ? money(paiseToRupees(state.adminReportToday!.salesPaise!))
                      : money(state.dashboardSales())),
              BillRow('Delivered', '$delivered'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revenueView(AppState state) {
    // Server figures (online + counter bills) when loaded; the loaded online
    // orders are only the fallback.
    final sm = state.adminReportMonth;
    final sy = state.adminReportYear;
    final month = state.reportOrders('month');
    final monthCount = sm?.orderCount ?? month.length;
    final monthRevenue = sm?.salesPaise != null
        ? paiseToRupees(sm!.salesPaise!)
        : month.fold<num>(0, (sum, o) => sum + o.bill.total);
    final allCount = sy?.orderCount ?? state.orders.length;
    final allRevenue = sy?.salesPaise != null
        ? paiseToRupees(sy!.salesPaise!)
        : state.orders.fold<num>(0, (sum, o) => sum + o.bill.total);
    final average = allCount > 0 ? allRevenue ~/ allCount : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardPanel(
          title: gt('This month'),
          child: Column(
            children: [
              BillRow('Orders', '$monthCount'),
              BillRow('Revenue', money(monthRevenue)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: sy != null ? gt('Last 12 months') : gt('All time'),
          child: Column(
            children: [
              BillRow('Orders', '$allCount'),
              BillRow('Revenue', money(allRevenue)),
              BillRow('Average order', money(average)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Reports'),
                  sub: gt('Revenue · stock movement · top products'),
                  bell: false,
                ),
                const SizedBox(height: 10),
                _ReportTabs(
                  active: 'sales',
                  onSales: () => setState(() {}),
                  onStock: () => go('/admin/stock-report'),
                ),
                const SizedBox(height: 12),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PeriodPicker(
                        value: _sel,
                        maxDays: 366,
                        onChanged: (v) {
                          setState(() {
                            _sel = v;
                            if (!v.custom) _period = v.period;
                          });
                          // Pull the server summary for the new period.
                          if (!v.custom) {
                            StateScope.of(context).loadReportSummary(v.period);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _ServerSummary(key: ValueKey(_sel.key), sel: _sel),
                      if (!_sel.custom) ...[
                        const SizedBox(height: 12),
                        Segmented(
                          options: const [
                            SegmentOption('orders', 'Orders'),
                            SegmentOption('revenue', 'Revenue'),
                          ],
                          value: _view,
                          onChanged: (v) => setState(() => _view = v),
                        ),
                        const SizedBox(height: 12),
                        if (_view == 'orders')
                          _ordersView(state)
                        else
                          _revenueView(state),
                      ],
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
}

/// Report tab row (Sales / Stock movement) shared between reports and stock report.
class _ReportTabs extends StatelessWidget {
  final String active;
  final VoidCallback onSales;
  final VoidCallback onStock;

  const _ReportTabs({
    required this.active,
    required this.onSales,
    required this.onStock,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(
          tabKey: 'sales',
          label: gt('Sales'),
          icon: 'chart',
          active: active == 'sales',
          onTap: onSales,
        ),
        const SizedBox(width: 10),
        _Tab(
          tabKey: 'stock',
          label: gt('Stock movement'),
          icon: 'box',
          active: active == 'stock',
          onTap: onStock,
        ),
      ],
    );
  }
}

class _Tab extends StatefulWidget {
  final String tabKey;
  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.tabKey,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active
                ? AppColors.navy
                : hovered
                    ? AppColors.bg
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.active
                  ? AppColors.navy
                  : hovered
                      ? AppColors.line
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                widget.icon,
                size: 14,
                color: widget.active
                    ? AppColors.white
                    : hovered
                        ? AppColors.ink
                        : AppColors.ink3,
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13,
                  fontWeight: widget.active
                      ? FontWeight.w800
                      : FontWeight.w700,
                  color: widget.active
                      ? AppColors.white
                      : hovered
                          ? AppColors.ink
                          : AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Server period report: GET /admin/reports/summary (doc 30, "Reports")
// ---------------------------------------------------------------------------

String _rs(num? paise) {
  final v = (paise ?? 0).round();
  final a = v.abs();
  final p = a % 100;
  return '${v < 0 ? '-' : ''}${money(a ~/ 100)}${p == 0 ? '' : '.${p.toString().padLeft(2, '0')}'}';
}

int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// Sales over a period (week / month / quarter or a custom range of at most
/// 366 days): online + counter totals, refunds listed apart (and a net line),
/// per-day series, top products and the udhar figures.
class _ServerSummary extends StatefulWidget {
  const _ServerSummary({super.key, required this.sel});
  final PeriodSel sel;

  @override
  State<_ServerSummary> createState() => _ServerSummaryState();
}

class _ServerSummaryState extends State<_ServerSummary> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;

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
      final d = await Api.instance.admin.reportSummaryRaw(
          period: widget.sel.apiPeriod,
          from: widget.sel.apiFrom,
          to: widget.sel.apiTo);
      if (mounted) setState(() => _d = d);
    } on ApiException catch (e) {
      if (!mounted) return;
      final f = ApiException.fieldError(e.fields, ['to', 'from', 'period']);
      setState(() => _error = gt(f ?? e.message));
    } catch (_) {
      if (mounted) setState(() => _error = gt('Could not load the report.'));
    }
    if (mounted) setState(() => _loading = false);
  }

  List<BarChartData> _bars(List<Map<String, dynamic>> byDay) {
    if (byDay.length <= 31) {
      return [
        for (final r in byDay)
          BarChartData(
              '${r['date'] ?? ''}'.length >= 10
                  ? '${r['date']}'.substring(8, 10)
                  : '${r['date']}',
              _n(r['salesPaise']) / 100),
      ];
    }
    // Long ranges: one bar per month so the chart stays readable.
    final m = <String, double>{};
    for (final r in byDay) {
      final k = '${r['date'] ?? ''}'.length >= 7
          ? '${r['date']}'.substring(0, 7)
          : '${r['date']}';
      m[k] = (m[k] ?? 0) + _n(r['salesPaise']) / 100;
    }
    return [
      for (final e in m.entries)
        BarChartData(e.key.length >= 7 ? e.key.substring(2) : e.key, e.value)
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _d == null) return const SkeletonRows(rows: 4);
    if (_error != null) {
      return ErrorRetry(message: _error!, onRetry: _load);
    }
    final d = _d!;
    final byDay = (d['byDay'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final top = (d['topProducts'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final sales = _n(d['salesPaise']);
    final posRef = _n(d['posRefundsPaise']);
    final onRef = _n(d['onlineRefundsPaise']);
    final orders = _n(d['orders']);
    final bars = _bars(byDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultSummary('${d['from']} ${gt('to')} ${d['to']}'),
        KpiGrid([
          KpiCard(
            icon: 'chart',
            tint: AppColors.green,
            bg: AppColors.greenTint,
            label: gt('Sales (online + counter)'),
            value: _rs(sales),
          ),
          KpiCard(
            icon: 'box',
            tint: AppColors.navy,
            bg: AppColors.navyTint,
            label: gt('Orders and bills'),
            value: '$orders',
          ),
          KpiCard(
            icon: 'coin',
            tint: AppColors.goldInk,
            bg: AppColors.goldTint,
            label: gt('Avg per order'),
            value: _rs(orders > 0 ? (sales / orders).round() : 0),
          ),
          KpiCard(
            icon: 'wallet',
            tint: AppColors.red,
            bg: AppColors.redTint,
            label: gt('Refunds'),
            value: _rs(posRef + onRef),
          ),
        ]),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Period totals'),
          child: Column(children: [
            BillRow('Online sales (${_n(d['onlineOrders'])} orders)',
                _rs(_n(d['onlineSalesPaise']))),
            BillRow('Counter sales (${_n(d['posBills'])} bills)',
                _rs(_n(d['posSalesPaise']))),
            BillRow('Counter refunds', _rs(posRef)),
            BillRow('Online refunds', _rs(onRef)),
            BillRow('Net of refunds', _rs(sales - posRef - onRef),
                strong: true),
            BillRow('Coins issued', '${_n(d['coinsIssued'])}'),
            BillRow('Udhar given', _rs(_n(d['creditGivenPaise']))),
            BillRow('Udhar recovered', _rs(_n(d['creditRecoveredPaise']))),
            BillRow('Udhar outstanding now',
                _rs(_n(d['outstandingCreditPaise']))),
          ]),
        ),
        const SizedBox(height: 4),
        Hint(gt(
            'Refunds are listed apart and are not taken off the sales figures. Udhar outstanding is what is owed now, not at the end date.')),
        const SizedBox(height: 12),
        CardPanel(
          title: byDay.length > 31 ? gt('Sales by month') : gt('Sales by day'),
          child: bars.isEmpty
              ? EmptyState(
                  icon: 'chart',
                  title: gt('No sales data yet'),
                  copy: gt('Nothing was sold in this period.'))
              : RevenueBarChart(
                  height: 190,
                  semanticsLabel: gt('Sales by day'),
                  data: bars),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Top products'),
          child: top.isEmpty
              ? Hint(gt('No sales recorded in this period.'))
              : Column(children: [
                  for (var i = 0; i < top.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        SizedBox(
                            width: 22,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink3))),
                        Expanded(
                            child: Text('${top[i]['name'] ?? '-'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink))),
                        const SizedBox(width: 8),
                        Text(
                            '${_n(top[i]['qty'])} ${gt('sold')}  ${_rs(_n(top[i]['salesPaise']))}',
                            style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  Hint(gt(
                      'Top 10 by sales. Pieces are counted; weighed items add to the amount but not to the count.')),
                ]),
        ),
      ],
    );
  }
}
