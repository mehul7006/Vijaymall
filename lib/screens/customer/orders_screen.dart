import 'package:flutter/material.dart';

import '../../data/seed_data.dart' as seed;
import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/customer_wide_parts.dart';
import '../../widgets/store_actions.dart';
import '../../widgets/panels.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_status_chip.dart';
import '../../widgets/toast.dart';
import 'sheets/cancel_order_sheet.dart';

/// `#/orders` — the customer's order history with status filters.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Held in State (not in build) so a live-order refresh cannot reset the chip.
  String _tab = 'all';

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final all = state.userOrders();
    final tab = _tab;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            void setTab(String next) => setState(() => _tab = next);

            final counts = {
              'all': all.length,
              'active': all.where(state.isActiveOrder).length,
              'completed': all
                  .where((o) =>
                      o.status == 'Delivered' || o.status == 'Picked Up')
                  .length,
              'cancelled': all.where((o) => o.isCancelled).length,
            };

            final list = all.where((o) {
              switch (tab) {
                case 'active':
                  return state.isActiveOrder(o);
                case 'completed':
                  return o.status == 'Delivered' || o.status == 'Picked Up';
                case 'cancelled':
                  return o.isCancelled;
                default:
                  return true;
              }
            }).toList();

            return Column(
              children: [
                const StatusBar(),
                ScreenBar(
                  title: gu ? 'મારા ઓર્ડર' : 'My orders',
                  sub: gu
                      ? '${all.length} ઓર્ડર ${seed.store.name} માંથી'
                      : '${all.length} order${all.length == 1 ? '' : 's'} from ${seed.store.name}',
                  onBack: () => go('/profile'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: ChipRail(
                    children: [
                      _chip(gu, 'all', 'બધા', 'All', counts['all']!, tab, setTab),
                      _chip(gu, 'active', 'ચાલુ', 'Active', counts['active']!,
                          tab, setTab),
                      _chip(gu, 'completed', 'પૂર્ણ', 'Completed',
                          counts['completed']!, tab, setTab),
                      _chip(gu, 'cancelled', 'રદ', 'Cancelled',
                          counts['cancelled']!, tab, setTab),
                    ],
                  ),
                ),
                if (list.isEmpty)
                  Expanded(
                    child: EmptyState(
                      icon: 'box',
                      title: gu ? 'અહીં કોઈ ઓર્ડર નથી' : 'No orders here',
                      copy: gu
                          ? 'ઓર્ડર કર્યા પછી અહીં દેખાશે.'
                          : 'Your orders will appear here once you place one.',
                      actionLabel: tab != 'all'
                          ? (gu ? 'બધા ઓર્ડર બતાવો' : 'Show all orders')
                          : (gu ? 'ખરીદી શરૂ કરો' : 'Start shopping'),
                      onAction: tab != 'all'
                          ? () => setTab('all')
                          : () => go('/shop'),
                    ),
                  )
                else
                  ScreenScroll(
                    bottom: 28,
                    onRefresh: () async {
                      try {
                        if (state.backendMode && !state.isBackendAdmin) {
                          await state.refreshCustomerOrders();
                        }
                      } catch (_) {}
                    },
                    child: CustomerWide.on(context)
                        ? CustomerSplit(
                            sideWidth: 380,
                            main: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                WideColumns(
                                  cols: CustomerWide.listCols(context),
                                  items: [
                                    for (var i = 0; i < list.length; i++)
                                      _orderCardAt(state, gu, list, i),
                                  ],
                                ),
                                ..._loadMore(state, gu),
                              ],
                            ),
                            side: _ordersAside(
                                context, state, gu, all, counts),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < list.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _orderCardAt(state, gu, list, i),
                              ],
                              ..._loadMore(state, gu),
                            ],
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

List<Widget> _loadMore(AppState state, bool gu) => [
      if (state.canLoadMoreOrders || state.ordersLoadingMore) ...[
        const SizedBox(height: 14),
        AppButton(
          gu ? 'વધુ ઓર્ડર લોડ કરો' : 'Load more',
          variant: BtnVariant.secondary,
          block: true,
          loading: state.ordersLoadingMore,
          onTap: state.loadMoreCustomerOrders,
        ),
      ],
    ];

/// Desktop side column: order summary, quick reorder and store help.
Widget _ordersAside(BuildContext context, AppState state, bool gu,
    List<Order> all, Map<String, int> counts) {
  Order? lastDone;
  for (final o in all) {
    if (o.isTerminal && !o.isCancelled) {
      lastDone = o;
      break;
    }
  }
  Widget stat(String guL, String enL, int n, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text('$n',
                  style: _ts(gu, size: 22, w: FontWeight.w800, color: c)),
              const SizedBox(height: 2),
              Text(gu ? guL : enL,
                  style: _ts(gu,
                      size: 11.5,
                      w: FontWeight.w700,
                      color: AppColors.white)),
            ],
          ),
        ),
      );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: StoreKit.heroNavyRed,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: .25),
                offset: const Offset(0, 12),
                blurRadius: 26),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gu ? 'તમારા ઓર્ડર' : 'YOUR ORDERS',
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w800, color: AppColors.gold2)),
            const SizedBox(height: 6),
            Text('${counts['all']}',
                style: _ts(gu,
                    size: 44,
                    w: FontWeight.w800,
                    color: AppColors.white,
                    height: 1.0)),
            const SizedBox(height: 14),
            Row(
              children: [
                stat('ચાલુ', 'Active', counts['active']!, AppColors.gold2),
                const SizedBox(width: 8),
                stat('પૂર્ણ', 'Done', counts['completed']!, AppColors.white),
                const SizedBox(width: 8),
                stat('રદ', 'Cancelled', counts['cancelled']!, AppColors.white),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (lastDone != null) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration:
              StoreKit.card(accent: AppColors.gold, radius: 22, tinted: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(gu ? 'ફરી ઓર્ડર કરો' : 'Order again',
                  style: _ts(gu, size: 15, w: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${lastDone.number} · ${money(lastDone.bill.total)}',
                style: _ts(gu,
                    size: 12, w: FontWeight.w600, color: AppColors.ink3),
              ),
              const SizedBox(height: 12),
              AppButton(
                gu ? 'ફરી ઓર્ડર' : 'Reorder',
                variant: BtnVariant.gold,
                block: true,
                icon: 'refresh',
                onTap: () async {
                  final msg = await state.reorderFromServer(lastDone!.number);
                  final failed =
                      msg == 'Those items are not available right now';
                  showToast(msg, failed ? 'error' : 'success');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      Container(
        padding: const EdgeInsets.all(16),
        decoration: StoreKit.card(accent: AppColors.navy, radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(gu ? 'મદદ જોઈએ?' : 'Need help?',
                style: _ts(gu, size: 15, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              gu
                  ? 'ઓર્ડર વિશે દુકાનને કૉલ કરો.'
                  : 'Call the store about any order.',
              style: _ts(gu,
                  size: 12, w: FontWeight.w600, color: AppColors.ink3),
            ),
            const SizedBox(height: 12),
            AppButton(
              seed.store.phone,
              variant: BtnVariant.secondary,
              block: true,
              icon: 'phone',
              onTap: () => StoreActions.call(),
            ),
            const SizedBox(height: 8),
            AppButton(
              gu ? 'ખરીદી શરૂ કરો' : 'Start shopping',
              variant: BtnVariant.secondary,
              block: true,
              icon: 'cart',
              onTap: () => go('/shop'),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _orderCardAt(AppState state, bool gu, List<Order> list, int i) {
  return FadeSlideIn(
    key: ValueKey('o-${list[i].number}'),
    delayMs: i < 6 ? i * 50 : 0,
    child: _OrderCard(state: state, gu: gu, order: list[i]),
  );
}

Widget _chip(bool gu, String key, String guLabel, String enLabel, int count,
    String current, void Function(String) setTab) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: AppChip(
      gu ? '$guLabel · $count' : '$enLabel · $count',
      small: true,
      selected: current == key,
      onTap: () => setTab(key),
    ),
  );
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  final AppState state;
  final bool gu;
  final Order order;

  const _OrderCard({
    required this.state,
    required this.gu,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final o = order;
    final active = state.isActiveOrder(o);
    final terminal = o.isTerminal;
    final pickup = o.mode == 'pickup';
    final totalQty = o.items.fold<int>(0, (sum, it) => sum + it.qty);
    final thumbs = o.items.take(3).toList();
    final extra = o.items.length - thumbs.length;

    final statusLabel = gu
        ? (AppState.statusLabelGu[o.status] ?? o.status)
        : state.statusLabel(o.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: StoreKit.card(
          accent: o.isCancelled
              ? AppColors.red
              : (terminal ? AppColors.green : AppColors.gold),
          radius: 20,
          tinted: active),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.number,
                  style: _ts(gu,
                      size: 14.5, w: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              StoreStatusChip(o.status, label: statusLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDate(o.placedAt)} · ${_time12(o.placedAt)} · ${pickup ? (gu ? 'સ્ટોર પિકઅપ' : 'Store pickup') : (gu ? 'હોમ ડિલિવરી' : 'Home delivery')}',
            style:
                _ts(gu, size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
          ),
          if (o.isCancelled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                AppState.cancelText(o, gu),
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w600, color: AppColors.red),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              for (final it in thumbs) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _toneBg(it.tone),
                          StoreKit.tone(thumbs.indexOf(it)).$2
                              .withValues(alpha: .6)
                        ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: Center(
                    child: ProductArtView(it.art, size: 30),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              if (extra > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: StoreKit.goldWarm,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    gu ? '+$extra વધુ' : '+$extra more',
                    style: _ts(gu,
                        size: 10.5,
                        w: FontWeight.w800,
                        color: AppColors.white),
                  ),
                ),
              const Spacer(),
              Text(
                gu
                    ? '$totalQty ${totalQty == 1 ? 'વસ્તુ' : 'વસ્તુઓ'}'
                    : '$totalQty item${totalQty == 1 ? '' : 's'}',
                style:
                    _ts(gu, size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (o.coinsEarned > 0 && !o.isCancelled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const AppIcon('coin',
                                size: 12, color: AppColors.gold, sw: 2),
                            const SizedBox(width: 5),
                            Text(
                              gu
                                  ? '+${o.coinsEarned} કોઈન્સ'
                                  : '+${o.coinsEarned} coins',
                              style: _ts(gu,
                                  size: 11.5,
                                  w: FontWeight.w800,
                                  color: AppColors.goldInk),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      _paymentLabel(gu, o.payment),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(gu,
                          size: 12,
                          w: FontWeight.w700,
                          color: AppColors.ink2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      money(o.bill.total),
                      style: _ts(gu,
                          size: 18,
                          w: FontWeight.w800,
                          color: AppColors.goldInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (AppState.customerCanCancel(o)) ...[
                        AppButton(
                          gu ? 'રદ કરો' : 'Cancel',
                          variant: BtnVariant.dangerSoft,
                          size: BtnSize.xs,
                          onTap: () => showCancelOrderSheet(context, o),
                        ),
                        const SizedBox(width: 6),
                      ] else if (terminal) ...[
                        AppButton(
                          gu ? 'ફરી ઓર્ડર' : 'Reorder',
                          variant: BtnVariant.secondary,
                          size: BtnSize.xs,
                          onTap: () async {
                            final msg = await state.reorderFromServer(o.number);
                            final failed = msg ==
                                'Those items are not available right now';
                            showToast(msg, failed ? 'error' : 'success');
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                      AppButton(
                        active
                            ? (gu ? 'ટ્રેક' : 'Track')
                            : (gu ? 'વિગત' : 'Details'),
                        size: BtnSize.xs,
                        onTap: () => go('/track/${o.number}'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _paymentLabel(bool gu, String payment) {
  if (!gu) return payment;
  switch (payment) {
    case 'UPI / Card':
      return 'UPI / કાર્ડ';
    case 'Cash on delivery':
      return 'ડિલિવરી પર રોકડ';
    case 'Pay at store':
      return 'દુકાન પર ચૂકવો';
    default:
      return payment;
  }
}

String _time12(DateTime t) {
  var h = t.hour % 12;
  if (h == 0) h = 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

Color _toneBg(String tone) => switch (tone) {
      'mint' => const Color(0xFFDFF4EA),
      'peach' => const Color(0xFFFFE9DC),
      'gold' => const Color(0xFFFFF1C8),
      'rose' => const Color(0xFFFBE3EA),
      'sky' => const Color(0xFFE3F1FA),
      'lilac' => const Color(0xFFECE7F8),
      'sand' => const Color(0xFFF6EDDD),
      _ => AppColors.bg,
    };

TextStyle _ts(
  bool gu, {
  double size = 13,
  FontWeight w = FontWeight.w600,
  Color color = AppColors.ink,
  double? height,
}) {
  if (gu) return AppTheme.guj(size: size, w: w, color: color);
  return TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
  );
}
