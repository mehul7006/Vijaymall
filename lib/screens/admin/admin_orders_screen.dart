import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/ist.dart';
import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_alerts.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../state/gu_strings.dart';

/// `#/admin/orders` — searchable, status / day / view filterable order list.
///
/// Deep links: `?day=today|yesterday|YYYY-MM-DD`, `?view=action|new`.
/// Filters live only for one visit of this screen (see
/// [AppState.presetAdminOrderFilters] / [AppState.endAdminOrdersSession]).
class AdminOrdersScreen extends StatelessWidget {
  final String? day;
  final String? view;

  const AdminOrdersScreen({super.key, this.day, this.view});

  @override
  Widget build(BuildContext context) => _OrdersBody(day: day, view: view);
}

/// Display order of the filter chips (any other status shows after these).
const List<String> _statusOrder = [
  'Placed',
  'Confirmed',
  'Packed',
  'Ready for Pickup',
  'Out for Delivery',
  'Delivered',
  'Picked Up',
  'Cancelled',
];

const List<String> _dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _mon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _dayLabel(DateTime d) =>
    '${_dow[d.weekday - 1]}, ${d.day} ${_mon[d.month - 1]} ${d.year}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _OrdersBody extends StatefulWidget {
  final String? day;
  final String? view;

  const _OrdersBody({this.day, this.view});

  @override
  State<_OrdersBody> createState() => _OrdersBodyState();
}

class _OrdersBodyState extends State<_OrdersBody> {
  String _query = '';
  Timer? _debounce;
  AppState? _stateRef;

  @override
  void initState() {
    super.initState();
    final st = StateScope.read(context);
    _stateRef = st;
    // Clear whatever a previous visit left behind, then apply the deep link.
    final refetch =
        st.presetAdminOrderFilters(this, day: widget.day, view: widget.view);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(st.startAdminOrders(this, refetch));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Leave the shared list unfiltered for the dashboard badge and the SSE
    // refresh, and forget day / view / search for the next visit.
    _stateRef?.endAdminOrdersSession(this);
    super.dispose();
  }

  /// Type-to-search: 400 ms after the last keystroke the term goes to the
  /// backend as `GET /admin/orders?q=` (matches phone/email too).
  void _onQuery(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(StateScope.read(context).searchAdminOrdersAndFill(v));
    });
  }

  void _clearAll() {
    _debounce?.cancel();
    setState(() => _query = '');
    unawaited(StateScope.read(context).clearAdminOrderFilters());
  }

  DateTime get _today {
    final n = istNow();
    return DateTime.utc(n.year, n.month, n.day);
  }

  Future<void> _pickDate(AppState st) async {
    final t = _today;
    final today = DateTime(t.year, t.month, t.day);
    final first = DateTime(2020);
    final cur = st.adminOrderDay;
    var initial = cur == null ? today : DateTime(cur.year, cur.month, cur.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(today)) initial = today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
      helpText: gt('Select order date'),
    );
    if (picked == null || !mounted) return;
    st.setAdminOrderDay(DateTime.utc(picked.year, picked.month, picked.day));
  }

  Widget _dateBar(AppState st) {
    final day = st.adminOrderDay;
    final today = _today;
    final yesterday = today.subtract(const Duration(days: 1));
    final canPrev = day == null || day.isAfter(DateTime.utc(2020));
    final canNext = day != null && day.isBefore(today);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppChip(gt('All dates'),
            selected: day == null, onTap: () => st.setAdminOrderDay(null)),
        AppChip(gt('Today'),
            selected: day != null && _sameDay(day, today),
            onTap: () => st.setAdminOrderDay(today)),
        AppChip(gt('Yesterday'),
            selected: day != null && _sameDay(day, yesterday),
            onTap: () => st.setAdminOrderDay(yesterday)),
        _DayBtn(
          icon: Icons.chevron_left_rounded,
          tip: gt('Previous day'),
          onTap: canPrev
              ? () => st.setAdminOrderDay(
                  day == null ? today : day.subtract(const Duration(days: 1)))
              : null,
        ),
        _DayBtn(
          icon: Icons.chevron_right_rounded,
          tip: gt('Next day'),
          onTap: canNext
              ? () => st.setAdminOrderDay(day.add(const Duration(days: 1)))
              : null,
        ),
        _DayBtn(
          icon: Icons.calendar_month_rounded,
          tip: gt('Pick a date'),
          onTap: () => _pickDate(st),
        ),
        if (day != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              _dayLabel(day),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    _stateRef = state;
    final present = state.orders.map((o) => o.status).toSet();
    // Static chips: the server filters, so a status with no loaded row (yet)
    // is still reachable.
    final statuses = [
      ..._statusOrder,
      ...present.where((s) => !_statusOrder.contains(s)),
    ];
    final day = state.adminOrderDay;
    final view = state.adminOrderView;
    final status = state.adminOrderStatus;
    final cutoff = istNow().subtract(const Duration(hours: 24));
    // The search term is matched on the server (order number, customer name,
    // mobile, e-mail); day / view are applied here over the loaded pages.
    final filtered = state.orders.where((o) {
      if (status.isNotEmpty && o.status != status) return false;
      if (view == 'action' && !state.orderNeedsAction(o)) return false;
      if (view == 'new' && o.placedAt.isBefore(cutoff)) return false;
      if (day != null && !_sameDay(o.placedAt, day)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final active = state.adminOrderFiltersActive || _query.trim().isNotEmpty;
    final filling = state.adminOrdersFilling;

    String summary;
    if (day != null) {
      final cancelled = filtered.where((o) => o.status == 'Cancelled').length;
      // Same rule as the "Orders today" tile: cancelled orders are listed
      // (with their pill) but not counted.
      summary = '${filtered.length - cancelled} ${gt('orders on')} ${_dayLabel(day)}'
          '${cancelled > 0 ? ' · $cancelled ${gt('cancelled')}' : ''}';
    } else if (view == 'action') {
      summary = '${filtered.length} ${gt('orders need action')}';
    } else if (view == 'new') {
      summary = '${filtered.length} ${gt('orders in the last 24 hours')}';
    } else {
      summary = '${filtered.length} of ${state.orders.length} ${gt('orders')}';
    }

    String emptyTitle;
    if (day != null) {
      emptyTitle = '${gt('No orders on')} ${_dayLabel(day)}';
    } else if (view == 'action') {
      emptyTitle = gt('No orders need action');
    } else if (view == 'new') {
      emptyTitle = gt('No orders in the last 24 hours');
    } else {
      emptyTitle = gt('No orders match');
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Orders'),
                  sub: '${state.newOrderCount()} new · ${state.orders.length} total',
                  bell: true,
                  onBell: () => showAdminAlerts(context),
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppField(
                              label: gt('Search orders'),
                              placeholder: gt('Order ID, customer, phone or e-mail'),
                              value: _query,
                              onChanged: _onQuery,
                            ),
                            const SizedBox(height: 14),
                            _dateBar(state),
                            const SizedBox(height: 12),
                            ChipRail(
                              children: [
                                AppChip(
                                  gt('All'),
                                  selected: view.isEmpty && status.isEmpty,
                                  onTap: () =>
                                      state.setAdminOrderStatusChip(''),
                                ),
                                const SizedBox(width: 8),
                                AppChip(
                                  '${gt('Needs action')} (${state.needActionCount()})',
                                  selected: view == 'action',
                                  onTap: () => state.setAdminOrderView('action'),
                                ),
                                const SizedBox(width: 8),
                                AppChip(
                                  view == 'new' && !filling
                                      ? '${gt('New (24h)')} (${filtered.length})'
                                      : gt('New (24h)'),
                                  selected: view == 'new',
                                  onTap: () => state.setAdminOrderView('new'),
                                ),
                                for (final s in statuses) ...[
                                  const SizedBox(width: 8),
                                  AppChip(
                                    state.statusLabel(s),
                                    selected: status == s,
                                    onTap: () =>
                                        state.setAdminOrderStatusChip(s),
                                  ),
                                ],
                              ],
                            ),
                            if (active) ...[
                              const SizedBox(height: 12),
                              AppLink(gt('Clear filters'), onTap: _clearAll),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ResultSummary(
                        summary,
                        trailing: active
                            ? AppLink(gt('Clear filters'), onTap: _clearAll)
                            : null,
                      ),
                      if (filling)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  gt('Loading orders…'),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (state.adminOrdersCapHit)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            gt('Showing orders loaded so far'),
                            style: const TextStyle(
                              fontFamily: AppTheme.uiFont,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldInk,
                            ),
                          ),
                        ),
                      filtered.isEmpty
                          ? (filling
                              ? const SizedBox(height: 60)
                              : CardPanel(
                                  child: EmptyState(
                                    icon: 'box',
                                    title: emptyTitle,
                                    copy: gt('Try another date or status, or clear the filters.'),
                                    actionLabel:
                                        active ? gt('Clear filters') : null,
                                    onAction: active ? _clearAll : null,
                                  ),
                                ))
                          : _OrdersList(state, filtered),
                      if (state.canLoadMoreOrders || state.ordersLoadingMore) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          gt('Load more'),
                          variant: BtnVariant.secondary,
                          block: true,
                          loading: state.ordersLoadingMore,
                          onTap: state.loadMoreAdminOrders,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'orders'),
          ],
        ),
      ),
    );
  }
}

/// Small square icon button used by the date navigator.
class _DayBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;

  const _DayBtn({required this.icon, required this.tip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Tooltip(
        message: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, size: 20, color: AppColors.ink2),
          ),
        ),
      ),
    );
  }
}

/// `orderListRow(o)` — number, customer · items, total + status pill.
class _OrderRow extends StatelessWidget {
  final AppState state;
  final Order order;
  final bool divider;

  const _OrderRow(this.state, this.order, {this.divider = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => go('/admin/order/${order.number}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                    order.number,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${order.customer} · ${order.items.length} items',
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
                  money(order.bill.total),
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                StatusPill(order.status, label: state.statusLabel(order.status)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]}, $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// Orders list: sticky-style data table on wide layouts, cards on phones.
class _OrdersList extends StatelessWidget {
  final AppState state;
  final List<Order> orders;

  const _OrdersList(this.state, this.orders);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return CardPanel(
          child: Column(
            children: [
              for (var i = 0; i < orders.length; i++)
                _OrderRow(state, orders[i], divider: i < orders.length - 1),
            ],
          ),
        );
      }
      const cols = [
        TableCol('Order', 3),
        TableCol('Customer', 4),
        TableCol('Placed', 3),
        TableCol('Payment', 3),
        TableCol('Total', 2, align: TextAlign.right),
        TableCol('Status', 3),
      ];
      const cell = TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink2,
      );
      return Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.sh1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const TableHeadRow(cols, trailing: 24),
            for (var i = 0; i < orders.length; i++)
              TableRowShell(
                last: i == orders.length - 1,
                onTap: () => go('/admin/order/${orders[i].number}'),
                semanticLabel: 'Order ${orders[i].number}, ${orders[i].customer}',
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(orders[i].number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cell.copyWith(
                              fontWeight: FontWeight.w800, color: AppColors.ink)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                          '${orders[i].customer} · ${orders[i].items.length} items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cell),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(_when(orders[i].placedAt),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: cell),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PayPill(orders[i].paymentState,
                            label: orders[i].paymentState),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(money(orders[i].bill.total),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cell.copyWith(
                              fontWeight: FontWeight.w800, color: AppColors.ink)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(orders[i].status,
                            label: state.statusLabel(orders[i].status)),
                      ),
                    ),
                    const SizedBox(
                      width: 24,
                      child: Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}