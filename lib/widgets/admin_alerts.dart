import 'package:flutter/material.dart';

import '../nav/nav.dart';
import '../provider/state_scope.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'admin_kit.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'controls.dart';
import 'popover.dart';
import 'sheet.dart';
import '../state/gu_strings.dart';

/// `sheets['admin-notifications']` — store alerts: new orders, stock alerts
/// and pending coin payouts, with shortcuts into Orders / Inventory.
Future<void> showAdminAlerts(BuildContext context) {
  final state = StateScope.read(context);
  return showAppSheet<void>(
    context: context,
    title: gt('Store alerts'),
    sub: _alertsSub(state),
    builder: (ctx) => adminAlertsBody(ctx, state),
  );
}

String _alertsSub(AppState state) {
  final newOrders = state.orders.where((o) => o.status == 'Placed').length;
  final low = state.lowStockProducts().length;
  final orderWord = newOrders == 1 ? 'order' : 'orders';
  final alertWord = low == 1 ? 'alert' : 'alerts';
  return '$newOrders new $orderWord · $low stock $alertWord';
}

/// Top-bar bell for admin/staff: dropdown on wide windows, bottom sheet on
/// phones. [anchor] is the bell's own context.
void showAdminAlertsFromBar(BuildContext anchor) {
  showTopBarPanel(
    anchor: anchor,
    tag: 'admin-alerts',
    width: 410,
    maxHeightFactor: .7,
    builder: (_) => Builder(builder: (c) {
      final st = StateScope.of(c);
      return PanelShell(
        title: 'Store alerts',
        sub: _alertsSub(st),
        bodyPadding: EdgeInsets.zero,
        child: adminAlertsBody(c, st),
      );
    }),
  );
}

/// The alerts list (new orders, stock alerts, payouts, shortcuts).
Widget adminAlertsBody(BuildContext ctx, AppState state) {
  final newOrders =
      state.orders.where((o) => o.status == 'Placed').toList();
  final low = state.lowStockProducts();
  final pending =
      state.ledger.where((l) => l.status == 'pending').length;
  return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionHead('New orders', 'Need confirming'),
          _card(
            child: newOrders.isEmpty
                ? _EmptyLine(
                    title: gt('No new orders'), copy: gt('Everything is confirmed.'))
                : Column(
                    children: [
                      for (final o in newOrders.take(4))
                        _row(
                          ctx,
                          icon: 'box',
                          title: '${o.number} · ${o.customer}',
                          sub: '${money(o.bill.total)} · ${whenLabel(o.placedAt)} · '
                              '${o.mode == 'pickup' ? 'Pickup' : 'Delivery'}',
                          pill: Pill(
                            label: gt('New'),
                            bg: AppColors.navyTint,
                            fg: AppColors.navy,
                          ),
                          onTap: () {
                            Navigator.of(ctx).maybePop();
                            go('/admin/order/${o.number}');
                          },
                        ),
                    ],
                  ),
          ),
          _sectionHead('Stock alerts', '${low.length} ${low.length == 1 ? 'item' : 'items'}'),
          _card(
            child: low.isEmpty
                ? _EmptyLine(
                    title: gt('All stocked up'), copy: gt('No low stock items.'))
                : Column(
                    children: [
                      for (final p in low.take(4))
                        _row(
                          ctx,
                          icon: 'info',
                          tint: p.stock <= 0 ? AppColors.red : AppColors.goldInk,
                          tintBg:
                              p.stock <= 0 ? AppColors.redTint : AppColors.goldTint,
                          title: p.name,
                          sub: '${p.stock} left · low stock threshold ${p.lowStock}',
                          pill: p.stock <= 0
                              ? Pill(
                                  label: gt('Out'),
                                  bg: AppColors.redTint,
                                  fg: AppColors.red,
                                )
                              : Pill(
                                  label: gt('Low'),
                                  bg: AppColors.goldTint,
                                  fg: AppColors.goldInk,
                                ),
                          onTap: () {
                            Navigator.of(ctx).maybePop();
                            go('/admin/product/${p.id}');
                          },
                        ),
                    ],
                  ),
          ),
          if (pending > 0) ...[
            const SizedBox(height: 12),
            AlertBanner(
              icon: 'coin',
              tint: AppColors.goldInk,
              bg: AppColors.goldTint,
              title: gt('Coin payouts pending'),
              sub: '$pending order coin payout is pending until delivery or pickup.',
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            'Open orders queue',
            block: true,
            onTap: () {
              Navigator.of(ctx).maybePop();
              go('/admin/orders');
            },
          ),
          const SizedBox(height: 9),
          AppButton(
            'Review inventory',
            variant: BtnVariant.secondary,
            block: true,
            onTap: () {
              Navigator.of(ctx).maybePop();
              go('/admin/inventory');
            },
          ),
          const SizedBox(height: 9),
          AppButton(
            'Done',
            variant: BtnVariant.soft,
            block: true,
            onTap: () => Navigator.of(ctx).maybePop(),
          ),
        ],
      ),
  );
}

Widget _sectionHead(String title, String hint) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        StatusChip(hint, fg: AppColors.ink2, bg: AppColors.bg),
      ],
    ),
  );
}

Widget _card({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
      boxShadow: AppColors.sh1,
    ),
    child: child,
  );
}

Widget _row(
  BuildContext ctx, {
  required String icon,
  required String title,
  required String sub,
  required Pill pill,
  required VoidCallback onTap,
  Color tint = AppColors.navy,
  Color tintBg = AppColors.navyTint,
}) {
  return _TapRow(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tintBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: AppIcon(icon, size: 17, color: tint),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          pill,
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.ink3),
        ],
      ),
    ),
  );
}

class _TapRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapRow({required this.child, required this.onTap});

  @override
  State<_TapRow> createState() => _TapRowState();
}

class _TapRowState extends State<_TapRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: _hover ? AppColors.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String title;
  final String copy;

  const _EmptyLine({required this.title, required this.copy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.greenTint, shape: BoxShape.circle),
            child: const Center(
                child: Icon(Icons.check_rounded,
                    size: 20, color: AppColors.green)),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            copy,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
