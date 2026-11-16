import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/api/dto.dart';
import '../../../data/models.dart';
import '../../../data/push_ref.dart';
import '../../../nav/nav.dart';
import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/popover.dart';
import '../../../widgets/sheet.dart';
import '../../../widgets/skeleton.dart';
import '../../../state/gu_strings.dart';

/// §3.14 `Notifications` — live order updates plus reward/refund alerts.
void showNotificationsSheet(BuildContext context) {
  final state = StateScope.read(context);
  final on = state.notificationsOn;
  // Refresh the backend inbox (`/me/notifications`) when it's open.
  if (state.backendMode) unawaited(state.loadInbox(force: true));

  showAppSheet<void>(
    context: context,
    title: gt('Notifications'),
    sub: on
        ? 'Order updates and reward alerts'
        : 'Notifications are quiet in your profile',
    builder: (ctx) => const _NotificationsBody(),
    onRefresh: () async {
      if (state.backendMode) await state.loadInbox(force: true);
    },
  );
}

/// Top-bar bell: a dropdown under the bell on wide windows, a bottom sheet on
/// phones. [anchor] is the bell's own context.
void showNotificationsFromBar(BuildContext anchor) {
  final state = StateScope.read(anchor);
  if (state.backendMode) unawaited(state.loadInbox(force: true));
  showTopBarPanel(
    anchor: anchor,
    tag: 'notifications',
    width: 410,
    maxHeightFactor: .7,
    builder: (_) => const NotificationsPanel(),
  );
}

/// Pinned header (title + "Mark all read" + close), scrolling list, pinned
/// "View my orders" footer.
class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    final gu = st.lang == 'gu';
    final unread = st.backendMode && st.inboxLoaded ? st.inboxUnread : 0;
    return PanelShell(
      title: 'Notifications',
      sub: st.notificationsOn
          ? 'Order updates and reward alerts'
          : 'Notifications are quiet in your profile',
      trailing: unread > 0
          ? AppLink(
              gu ? 'બધું વાંચેલું કરો' : 'Mark all read',
              onTap: () => st.markAllInboxRead(),
              size: 11.5,
              minHeight: 36,
            )
          : null,
      footer: AppButton(
        'View my orders',
        block: true,
        onTap: () {
          Navigator.of(context).maybePop();
          go('/orders');
        },
      ),
      child: const _NotificationsBody(embedded: true),
    );
  }
}

class _FeedItem {
  const _FeedItem({
    required this.icon,
    required this.gold,
    required this.title,
    required this.sub,
    required this.route,
  });

  final String icon;
  final bool gold; // gift rows use the gold tile, order rows the navy tile
  final String title;
  final String sub;
  final String route;
}

class _NotificationsBody extends StatelessWidget {
  /// Inside [NotificationsPanel] the header carries "Mark all read" and the
  /// footer carries the shortcut, so the body is just the list.
  final bool embedded;

  const _NotificationsBody({this.embedded = false});

  /// Backend rows win when the inbox has loaded; otherwise the local feed.

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    final gu = st.lang == 'gu';

    // --- backend inbox (`/me/notifications`) ------------------------------
    final useInbox =
        st.backendMode && st.inboxLoaded && st.inboxItems.isNotEmpty;
    if (useInbox) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!st.notificationsOn) ...[
            _noteRow(
              'bell',
              'Order notifications are turned off. You can switch them back on '
                  'from Profile.',
              gu,
            ),
            const SizedBox(height: 12),
          ],
          if (!embedded && st.inboxUnread > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${st.inboxUnread} unread',
                      style: _ts(gu,
                          size: 12,
                          w: FontWeight.w800,
                          color: AppColors.goldInk),
                    ),
                  ),
                  AppLink(
                    gu ? 'બધું વાંચેલું કરો' : 'Mark all read',
                    onTap: () => st.markAllInboxRead(),
                    size: 11.5,
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(19),
              boxShadow: AppColors.sh1,
            ),
            child: Column(
              children: [
                for (var i = 0; i < st.inboxItems.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  _InboxRow(row: st.inboxItems[i], gu: gu),
                ],
              ],
            ),
          ),
          if (!embedded) ...[
            const SizedBox(height: 16),
            AppButton(
              'View my orders',
              block: true,
              onTap: () {
                Navigator.of(context).maybePop();
                go('/orders');
              },
            ),
            const SizedBox(height: 8),
            AppButton(
              'Done',
              variant: BtnVariant.soft,
              block: true,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ],
      );
    }

    // --- local/demo feed --------------------------------------------------
    final feed = <_FeedItem>[];
    for (final o in st.userOrders().take(4)) {
      feed.add(_FeedItem(
        icon: o.status == 'Delivered' ? 'check' : 'box',
        gold: false,
        title: 'Order ${o.number} · ${st.statusLabel(o.status)}',
        sub: '${_orderEta(st, o, gu)} · ${whenLabel(o.updatedAt)}',
        route: '/track/${o.number}',
      ));
    }
    for (final l in st.ledger
        .where((e) => e.type == 'bonus' || e.type == 'refund')
        .take(3)) {
      feed.add(_FeedItem(
        icon: 'gift',
        gold: true,
        title: l.title,
        sub: '${l.coins > 0 ? '+' : ''}${l.coins} coins · ${whenLabel(l.date)}',
        route: '/wallet',
      ));
    }

    if (feed.isEmpty) {
      if (st.backendMode && !st.inboxLoaded && st.apiLastError == null) {
        return const ListSkeleton(count: 3, rowHeight: 72);
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!st.notificationsOn) ...[
            _noteRow(
              'bell',
              'Order notifications are turned off. You can switch them back on '
                  'from Profile.',
              gu,
            ),
            const SizedBox(height: 12),
          ],
          EmptyState(
            icon: 'bell',
            title: gt("You're all caught up"),
            copy: gt('Order updates and reward alerts will show up here.'),
            actionLabel: gt('Refresh'),
            onAction: () {
              if (st.backendMode) st.loadInbox(force: true);
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!st.notificationsOn) ...[
          _noteRow(
            'bell',
            'Order notifications are turned off. You can switch them back on '
                'from Profile.',
            gu,
          ),
          const SizedBox(height: 12),
        ],
        if (feed.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(19),
              boxShadow: AppColors.sh1,
            ),
            child: Column(
              children: [
                for (var i = 0; i < feed.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  _FeedRow(item: feed[i], gu: gu),
                ],
              ],
            ),
          ),
        if (!embedded) ...[
          const SizedBox(height: 16),
          AppButton(
            'View my orders',
            block: true,
            onTap: () {
              Navigator.of(context).maybePop();
              go('/orders');
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            'Done',
            variant: BtnVariant.soft,
            block: true,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ],
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item, required this.gu});

  final _FeedItem item;
  final bool gu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).maybePop();
        go(item.route);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.gold ? AppColors.goldTint : AppColors.navyTint,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  item.icon,
                  size: 17,
                  color: item.gold ? AppColors.goldInk : AppColors.navy,
                  sw: 1.9,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: _ts(gu, size: 13, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.sub,
                    style: _ts(gu,
                        size: 11.5,
                        w: FontWeight.w600,
                        color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const AppIcon('right', size: 14, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.row, required this.gu});

  final NotificationRowDto row;
  final bool gu;

  /// kind (SCREAMING_SNAKE on the wire) → tile icon + colour.
  bool get _gold {
    final k = (row.kind ?? '').toUpperCase();
    return k.contains('COIN') || k.contains('REWARD') || k.contains('REFUND');
  }

  String get _icon {
    final k = (row.kind ?? '').toUpperCase();
    if (k.contains('ORDER') || k.contains('PAYMENT')) return 'box';
    if (k == 'ANNOUNCEMENT') return 'spark';
    if (k == 'FLASH') return 'bolt';
    if (_gold) return 'gift';
    return 'bell';
  }

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Mark read, then open the referenced order when there is one.
        // ORDER/PAYMENT (order number), FLASH, STOCK and ANNOUNCEMENT refs
        // (`offers`, `product:<id>`, `category:<id>`, `order:<no>` ...) all
        // resolve through inboxRoute; unknown kinds/refs stay in the inbox.
        if (row.id != null) st.markInboxRead(row.id!);
        final route = inboxRoute(st, row.kind, row.ref);
        if (route != null) {
          Navigator.of(context).maybePop();
          go(route);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _gold ? AppColors.goldTint : AppColors.navyTint,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  _icon,
                  size: 17,
                  color: _gold ? AppColors.goldInk : AppColors.navy,
                  sw: 1.9,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title ?? '',
                    style: _ts(gu,
                        size: 13,
                        w: row.read ? FontWeight.w600 : FontWeight.w800),
                  ),
                  if ((row.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      row.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(gu,
                          size: 11.5,
                          w: FontWeight.w600,
                          color: AppColors.ink2),
                    ),
                  ],
                  if (row.createdDateTime != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      whenLabel(row.createdDateTime!),
                      style: _ts(gu,
                          size: 11,
                          w: FontWeight.w600,
                          color: AppColors.ink3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!row.read)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.gold2,
                  shape: BoxShape.circle,
                ),
              )
            else
              const AppIcon('right', size: 14, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

/// `.sheet__note` with a leading icon (bell when notifications are off).
Widget _noteRow(String icon, String text, bool gu) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.navyTint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 13, color: AppColors.navy, sw: 2),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: _ts(gu,
                size: 12,
                w: FontWeight.w600,
                color: AppColors.navy,
                height: 1.55),
          ),
        ),
      ],
    ),
  );
}

/// `orderEta(order, localized)` per mode/status (app.js 508–530).
String _orderEta(AppState st, Order o, bool gu) {
  if (o.status == 'Cancelled') {
    return AppState.cancelText(o, gu);
  }

  final t = _time12(o.updatedAt);
  if (o.mode == 'pickup') {
    final map = gu
        ? <String, String>{
            'Placed': 'દુકાન 15 મિનિટમાં કન્ફર્મ કરશે',
            'Confirmed': 'તમારો ઓર્ડર પેક થઈ રહ્યો છે',
            'Packed': 'પિકઅપ માટે લગભગ તૈયાર',
            'Ready for Pickup': 'આજે દુકાનમાંથી લઈ જાઓ',
            'Picked Up': 'લઈ લીધો · $t',
          }
        : <String, String>{
            'Placed': AppState.etaPickup['Placed']!,
            'Confirmed': AppState.etaPickup['Confirmed']!,
            'Packed': AppState.etaPickup['Packed']!,
            'Ready for Pickup': AppState.etaPickup['Ready for Pickup']!,
            'Picked Up': 'Picked up · $t',
          };
    return map[o.status] ?? '';
  }

  final map = gu
      ? <String, String>{
          'Placed': 'આજે 8:00 વાગ્યા સુધી ડિલિવરી',
          'Confirmed': 'દુકાન તમારો ઓર્ડર પેક કરી રહી છે',
          'Packed': 'રાઇડર થોડી વારમાં લેશે',
          'Out for Delivery': '15 – 25 મિનિટમાં પહોંચશે',
          'Delivered': 'પહોંચાડાયો · $t',
        }
      : <String, String>{
          'Placed': AppState.etaDelivery['Placed']!,
          'Confirmed': AppState.etaDelivery['Confirmed']!,
          'Packed': AppState.etaDelivery['Packed']!,
          'Out for Delivery': AppState.etaDelivery['Out for Delivery']!,
          'Delivered': 'Delivered · $t',
        };
  return map[o.status] ?? '';
}

/// `timeOnly()` — 4:32 PM style clock used inside the ETA copy.
String _time12(DateTime d) {
  var h = d.hour % 12;
  if (h == 0) h = 12;
  return '$h:${pad2(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Bilingual text style — Gujarati falls back to the Hind Vadodara family.
TextStyle _ts(
  bool gu, {
  double size = 11.5,
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
