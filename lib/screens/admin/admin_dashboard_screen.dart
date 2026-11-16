import 'package:flutter/material.dart';

import '../../data/api/api_service.dart' show paiseToRupees;
import '../../data/api/dto.dart' show DashboardDto;
import '../../data/seed_data.dart' as seed;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_alerts.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/panels.dart';
import '../../state/gu_strings.dart';

/// `#/admin` — dashboard: today's KPIs, recent orders and stock alerts.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final recent = List<Order>.of(state.orders)
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final top = recent.take(5).toList();
    final alerts = state.lowStockProducts()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Dashboard'),
                  sub: '${seed.store.name} · ${seed.storeLocality()}',
                  bell: true,
                  onBell: () => showAdminAlerts(context),
                ),
                ScreenScroll(child: _DashBody(state: state, top: top, alerts: alerts)),
              ],
            ),
            const AdminNav(active: 'dashboard'),
          ],
        ),
      ),
    );
  }
}

/// `recentOrderRow(o)` — number, customer · items, total + status pill.
Widget _orderRow(AppState state, Order o, {bool divider = true}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => go('/admin/order/${o.number}'),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: divider ? AppColors.line : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.number,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${o.customer} · ${o.items.length} items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(o.bill.total),
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              StatusPill(o.status, label: state.statusLabel(o.status)),
            ],
          ),
        ],
      ),
    ),
  );
}

/// `stockAlertRow(p)` — name, category, `{n} left` / Out of stock.
Widget _stockRow(AppState state, Product p, {bool divider = true}) {
  final out = p.stock <= 0;
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: divider ? AppColors.line : Colors.transparent,
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _catName(state, p.category),
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (out)
          Pill.out('Out of stock')
        else
          Text(
            '${p.stock} left',
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.stock <= 5 ? AppColors.red : AppColors.goldInk,
            ),
          ),
      ],
    ),
  );
}

String _catName(AppState state, String id) {
  for (final c in state.categories) {
    if (c.id == id) return c.name;
  }
  return id;
}

/// `.quick-grid` — 4 colored quick-action tiles.
class _QuickGrid extends StatelessWidget {
  final AppState state;

  const _QuickGrid(this.state);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _QuickTile(
                icon: 'box',
                tint: AppColors.red,
                bg: AppColors.redTint,
                label: gt('New orders'),
                onTap: () => go('/admin/orders?view=new'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickTile(
                icon: 'flame',
                tint: AppColors.orange,
                bg: AppColors.orangeTint,
                label: gt('Hot sale'),
                onTap: () => go('/admin/hot-sale'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickTile(
                icon: 'ticket',
                tint: AppColors.goldInk,
                bg: AppColors.goldTint,
                label: gt('Coupons'),
                onTap: () => go('/admin/coupons'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickTile(
                icon: 'chart',
                tint: AppColors.navy,
                bg: AppColors.navyTint,
                label: gt('Reports'),
                onTap: () => go('/admin/reports'),
              ),
            ),
          ],
        ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final String icon;
  final Color tint;
  final Color bg;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.tint,
    required this.bg,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg.withValues(alpha: .7), AppColors.white],
          ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: tint.withValues(alpha: .25)),
          boxShadow: [
            BoxShadow(
                color: tint.withValues(alpha: .14),
                offset: const Offset(0, 6),
                blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bg, tint.withValues(alpha: .28)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(icon, size: 16, color: tint, sw: 1.8),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard body: alerts, KPI cards, revenue chart, top products, quick
/// actions, recent orders and stock alerts. Two columns on wide layouts.
class _DashBody extends StatelessWidget {
  final AppState state;
  final List<Order> top;
  final List<Product> alerts;

  const _DashBody({
    required this.state,
    required this.top,
    required this.alerts,
  });

  static Widget _grid(List<Widget> items, int cols, double gap) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += cols) {
      final cells = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) cells.add(SizedBox(width: gap));
        cells.add(Expanded(
            child: i + j < items.length ? items[i + j] : const SizedBox()));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(IntrinsicHeight(
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
      ));
    }
    return Column(children: rows);
  }

  /// Counter (till) totals since the start of today from `GET /admin/dashboard`
  /// plus refunds on returned online orders. Refunds are listed apart and are
  /// not taken off the sales figures; the net line does that.
  Widget _counterToday(DashboardDto d) {
    final refunds = d.posRefundsTodayPaise + d.onlineRefundsTodayPaise;
    return CardPanel(
      title: gt('Counter today'),
      child: Column(
        children: [
          BillRow('Counter sales',
              money(paiseToRupees(d.posSalesTodayPaise))),
          BillRow('Counter bills', '${d.posBillsToday}'),
          BillRow('Counter refunds',
              money(paiseToRupees(d.posRefundsTodayPaise))),
          BillRow('Online refunds',
              money(paiseToRupees(d.onlineRefundsTodayPaise))),
          if (refunds > 0)
            BillRow(
                'Online + counter sales, net of refunds',
                money(paiseToRupees(d.salesTodayPaise +
                    d.posSalesTodayPaise -
                    refunds))),
        ],
      ),
    );
  }

  /// Best sellers by revenue across the loaded (non-cancelled) orders.
  List<MapEntry<String, ({int qty, double rev})>> _topProducts() {
    final m = <String, ({int qty, double rev})>{};
    for (final o in state.orders) {
      if (o.status == 'Cancelled') continue;
      for (final it in o.items) {
        final cur = m[it.name] ?? (qty: 0, rev: 0.0);
        m[it.name] = (
          qty: cur.qty + it.qty,
          rev: cur.rev + it.price.toDouble() * it.qty
        );
      }
    }
    final l = m.entries.toList()..sort((a, b) => b.value.rev.compareTo(a.value.rev));
    return l.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 760;
      final week = state.weekSales;
      final amounts = [for (final w in week) w.amount.toDouble()];
      // The order list holds only the newest 50: once more exist on the
      // server, today's figures come from GET /admin/dashboard instead.
      final srv = state.canLoadMoreOrders ? state.adminDashboard : null;
      final todaySales =
          srv != null ? paiseToRupees(srv.salesTodayPaise) : state.dashboardSales();
      double? delta;
      if (amounts.length >= 2) {
        delta = pctDelta(amounts.last, amounts[amounts.length - 2]);
      }
      // Same definition as the orders list "Needs action" view; the server's
      // `needsAction` (PLACED..READY_FOR_PICKUP, cached ~30 s) covers orders
      // beyond the loaded page, so the larger of the two is shown.
      final dash = state.adminDashboard;
      final localPending = state.needActionCount();
      final pending = (dash?.needsAction ?? 0) > localPending
          ? dash!.needsAction!
          : localPending;
      final todayCount = srv?.ordersToday ?? state.todayOrders().length;
      final lowCount = alerts.length;

      final kpis = <Widget>[
        KpiCard(
          icon: 'chart',
          tint: AppColors.green,
          bg: AppColors.greenTint,
          label: gt('Sales today'),
          value: money(todaySales),
          deltaPct: delta,
          deltaHint: gt('vs yesterday'),
          spark: amounts.length >= 2 ? amounts : null,
          onTap: () => go('/admin/reports'),
        ),
        KpiCard(
          icon: 'box',
          tint: AppColors.navy,
          bg: AppColors.navyTint,
          label: gt('Orders today'),
          value: '$todayCount',
          onTap: () => go('/admin/orders?day=today'),
        ),
        KpiCard(
          icon: 'bolt',
          tint: AppColors.goldInk,
          bg: AppColors.goldTint,
          label: gt('Need action'),
          value: '$pending',
          deltaHint: pending > 0 ? gt('New') : null,
          onTap: () => go('/admin/orders?view=action'),
        ),
        KpiCard(
          icon: 'flame',
          tint: lowCount > 0 ? AppColors.red : AppColors.green,
          bg: lowCount > 0 ? AppColors.redTint : AppColors.greenTint,
          label: gt('Stock alerts'),
          value: '$lowCount',
          onTap: () => go('/admin/inventory?filter=low'),
        ),
      ];

      final banners = <Widget>[
        if (state.failedRefunds > 0)
          AlertBanner(
            icon: 'bolt',
            tint: AppColors.red3,
            bg: AppColors.redTint,
            title: '${state.failedRefunds} ${gt('refunds failed')}',
            sub: gt('Tap to retry them'),
            onTap: () => go('/admin/system?tab=refunds'),
          ),
        if (state.configProblems > 0)
          AlertBanner(
            icon: 'bolt',
            tint: AppColors.goldInk,
            bg: AppColors.goldTint,
            title: '${state.configProblems} ${gt('server settings need attention')}',
            sub: gt('Open Configuration'),
            onTap: () => go('/admin/system?tab=config'),
          ),
        if (pending > 0)
          AlertBanner(
            icon: 'bolt',
            tint: AppColors.goldInk,
            bg: AppColors.goldTint,
            title: '$pending ${gt('orders waiting for action')}',
            sub: gt('Tap to review and confirm'),
            onTap: () => go('/admin/orders?view=action'),
          ),
        if (lowCount > 0)
          AlertBanner(
            icon: 'box',
            tint: AppColors.red3,
            bg: AppColors.redTint,
            title: '$lowCount ${gt('products low or out of stock')}',
            sub: gt('Open inventory to restock'),
            onTap: () => go('/admin/inventory?filter=low'),
          ),
      ];

      final chart = CardPanel(
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 13),
        child: week.isEmpty
            ? EmptyState(
                icon: 'chart',
                title: gt('No sales data yet'),
                copy: gt('Sales for the last 7 days will appear here.'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(gt('This week’s sales'),
                                style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink)),
                            const SizedBox(height: 2),
                            Text(gt('Revenue by day · 7 day view'),
                                style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink3)),
                          ],
                        ),
                      ),
                      Pill.active(money(week.fold<num>(0, (s, w) => s + w.amount))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RevenueBarChart(
                    data: [
                      for (final w in week) BarChartData(w.day, w.amount.toDouble())
                    ],
                    semanticsLabel: gt('This week’s sales'),
                  ),
                ],
              ),
      );

      final tp = _topProducts();
      final maxRev = tp.isEmpty ? 1.0 : tp.first.value.rev;
      final topCard = CardPanel(
        title: gt('Top products'),
        child: tp.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(gt('No sales recorded yet.'),
                    style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 12.5,
                        color: AppColors.ink3)),
              )
            : Column(
                children: [
                  for (var i = 0; i < tp.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: i == 0
                                        ? AppColors.goldTint
                                        : AppColors.bg,
                                    shape: BoxShape.circle),
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontFamily: AppTheme.uiFont,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: i == 0
                                            ? AppColors.goldInk
                                            : AppColors.ink2)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(tp[i].key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontFamily: AppTheme.uiFont,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink)),
                              ),
                              const SizedBox(width: 8),
                              Text(money(tp[i].value.rev.round()),
                                  style: const TextStyle(
                                      fontFamily: AppTheme.uiFont,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                  child: MeterBar(tp[i].value.rev / maxRev,
                                      color: i == 0
                                          ? AppColors.red
                                          : AppColors.navy2)),
                              const SizedBox(width: 8),
                              Text('${tp[i].value.qty} ${gt('sold')}',
                                  style: const TextStyle(
                                      fontFamily: AppTheme.uiFont,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink3)),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );

      final quick = _QuickGrid(state);

      final ordersCard = state.orders.isEmpty
          ? CardPanel(
              child: EmptyState(
                icon: 'box',
                title: gt('No orders yet'),
                copy: gt('New customer orders will show up here.'),
                actionLabel: gt('View inventory'),
                onAction: () => go('/admin/inventory'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHead(
                  'Recent orders',
                  actionLabel: gt('All orders'),
                  onAction: () => go('/admin/orders'),
                ),
                CardPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      for (var i = 0; i < top.length; i++)
                        _orderRow(state, top[i], divider: i < top.length - 1),
                    ],
                  ),
                ),
              ],
            );

      final stockCard = alerts.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHead('Stock alerts',
                    actionLabel: gt('Open inventory'),
                    onAction: () => go('/admin/inventory?filter=low')),
                CardPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      for (var i = 0; i < alerts.length && i < 8; i++)
                        _stockRow(state, alerts[i],
                            divider: i < alerts.length - 1 && i < 7),
                    ],
                  ),
                ),
              ],
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banners.isNotEmpty) ...[
            if (wide && banners.length > 1)
              _grid(banners, 2, 12)
            else
              for (var i = 0; i < banners.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                banners[i],
              ],
            const SizedBox(height: 12),
          ],
          _grid(kpis, wide ? 4 : 2, 10),
          const SizedBox(height: 12),
          if (dash != null) ...[
            _counterToday(dash),
            const SizedBox(height: 12),
          ],
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: topCard),
              ],
            )
          else ...[
            chart,
            const SizedBox(height: 12),
            topCard,
          ],
          const SizedBox(height: 12),
          quick,
          const SizedBox(height: 12),
          if (wide && alerts.isNotEmpty && state.orders.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: ordersCard),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: stockCard),
              ],
            )
          else ...[
            ordersCard,
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              stockCard,
            ],
          ],
        ],
      );
    });
  }
}