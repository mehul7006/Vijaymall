import 'package:flutter/material.dart';

import '../../data/api/api_config.dart';
import '../../data/seed_data.dart' as seed;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';

/// `#/admin/more` — shortcut links, session actions and store footer.
class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) => const _MoreBody();
}

class _MoreBody extends StatefulWidget {
  const _MoreBody();

  @override
  State<_MoreBody> createState() => _MoreBodyState();
}

class _MoreBodyState extends State<_MoreBody> {
  bool _resetting = false;

  void _reset() {
    if (_resetting) return;
    setState(() => _resetting = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      StateScope.read(context).resetDemo();
      setState(() => _resetting = false);
      showToast(gt('Demo data reset'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('More'),
                  sub: gt('Store settings, reports and shortcuts'),
                  bell: false,
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardPanel(
                        title: gt('Admin shortcuts'),
                        child: _navGrid(
                          [
                            _navRow('user', 'My profile', '/admin/profile'),
                            _navRow('cart', 'Orders', '/admin/orders'),
                            _navRow('box', 'Inventory', '/admin/inventory'),
                            _navRow('bolt', 'POS till', '/admin/pos'),
                            _navRow('flame', 'Hot sale', '/admin/hot-sale'),
                            _navRow('bolt', 'Flash sales', '/admin/flash-sales'),
                            _navRow('box', 'Purchases & suppliers', '/admin/purchases'),
                            _navRow('box', 'Stock lots and expiry', '/admin/stock-lots'),
                            _navRow('ticket', 'Barcode labels', '/admin/labels'),
                            _navRow('box', 'GST and HSN master', '/admin/gst-master'),
                            _navRow('card', 'Bank and settlements', '/admin/bank'),
                            _navRow('bell', 'Push notifications', '/admin/push'),
                            _navRow('ticket', 'Coupons', '/admin/coupons'),
                            _navRow('coin', 'Credit (udhar)', '/admin/credit'),
                            _navRow('coin', 'Coin rules', '/admin/coins'),
                            _navRow('store', 'Shop settings',
                                '/admin/shop-settings'),
                            _navRow('users', 'Staff', '/admin/staff'),
                            _navRow('users', 'Customers', '/admin/customers'),
                            _navRow('card', 'Payment methods',
                                '/admin/payments'),
                            _navRow('store', 'Shop profile & hours',
                                '/admin/system?tab=profile'),
                            _navRow('coin', 'Refunds',
                                '/admin/system?tab=refunds'),
                            _navRow('filter', 'Configuration',
                                '/admin/system?tab=config'),
                            _navRow('box', 'Caches & logs',
                                '/admin/system?tab=caches'),
                            _navRow('grid', 'Units', '/admin/units'),
                            _navRow('grid', 'Categories', '/admin/categories'),
                            _navRow('chart', 'Reports', '/admin/reports'),
                            _navRow(
                                'filter', 'Stock report', '/admin/stock-report'),
                            _navRow('box', 'Stock in & count',
                                '/admin/stock-ops'),
                            _navRow('clock', 'Cash drawer shifts',
                                '/admin/counter?tab=shifts'),
                            _navRow('chart', 'Counter controls',
                                '/admin/counter?tab=controls'),
                            _navRow('box', 'Low stock', '/admin/counter?tab=low'),
                            _navRow('filter', 'Audit log',
                                '/admin/counter?tab=audit'),
                            _navRow('card', 'Payment problems',
                                '/admin/counter?tab=anomalies'),
                            _navRow('box', 'Returned goods to check',
                                '/admin/counter?tab=defective'),
                            _navRow('settings', 'Till sync & manager PIN',
                                '/admin/counter?tab=sync'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CardPanel(
                        title: gt('Session'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Offline prototype only — a live build has no
                            // demo data to reset.
                            if (!ApiConfig.isLive) ...[
                              AppButton(
                                'Reset demo data',
                                variant: BtnVariant.secondary,
                                block: true,
                                loading: _resetting,
                                onTap: _resetting ? null : _reset,
                              ),
                              const SizedBox(height: 10),
                            ],
                            AppButton(
                              'Sign out',
                              variant: BtnVariant.danger,
                              block: true,
                              onTap: () {
                                StateScope.read(context).adminSignOut();
                                go('/signin');
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 18, bottom: 6),
                        child: Column(
                          children: [
                            Text(
                              seed.store.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              seed.store.address,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 11.5,
                                height: 1.4,
                                color: AppColors.ink3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              seed.store.phone,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  /// Shortcut rows: one column on phones, two on wide layouts.
  Widget _navGrid(List<Widget> rows) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 640) return Column(children: rows);
      final half = (rows.length + 1) ~/ 2;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: rows.sublist(0, half))),
          const SizedBox(width: 20),
          Expanded(child: Column(children: rows.sublist(half))),
        ],
      );
    });
  }

  Widget _navRow(String icon, String title, String route) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NavRow(
        icon: icon,
        title: title,
        onTap: () => go(route),
      ),
    );
  }
}
