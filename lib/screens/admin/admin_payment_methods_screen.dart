import 'package:flutter/material.dart';

import '../../provider/state_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/panels.dart';
import '../../state/gu_strings.dart';

/// `#/admin/payments` — which payment methods checkout offers.
///
/// Reads `GET /admin/payment-methods`; each toggle persists the full matrix
/// with `PUT /admin/payment-methods`.
class AdminPaymentMethodsScreen extends StatelessWidget {
  const AdminPaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PaymentsBody();
}

class _PaymentsBody extends StatelessWidget {
  const _PaymentsBody();

  String _label(String? code) {
    final c = (code ?? '').toUpperCase();
    if (c == 'ONLINE') return 'Online payment (Razorpay)';
    if (c.contains('UPI')) return 'UPI';
    if (c.contains('COD') || c.contains('CASH')) return 'Cash on delivery';
    if (c.contains('CARD')) return 'Card';
    if (c.contains('STORE') || c.contains('PICKUP')) return 'Pay at store';
    if (c.contains('NET') || c.contains('BANK')) return 'Net banking';
    if (c.contains('WALLET')) return 'Wallet';
    if (c.isEmpty) return 'Method';
    return c[0] + c.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final methods = state.paymentMethods;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Payment methods'),
                  sub: '${methods.where((m) => m.enabled).length} of ${methods.length} enabled',
                  bell: false,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (methods.isNotEmpty) ...[
                        KpiGrid([
                          KpiCard(
                            icon: 'check',
                            tint: AppColors.green,
                            bg: AppColors.greenTint,
                            label: gt('Enabled'),
                            value: '${methods.where((m) => m.enabled).length}',
                          ),
                          KpiCard(
                            icon: 'card',
                            tint: AppColors.navy2,
                            bg: AppColors.navyTint,
                            label: gt('Methods'),
                            value: '${methods.length}',
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      CardPanel(
                        title: gt('Accepted at checkout'),
                        child: methods.isEmpty
                            ? const Hint(
                                'No payment methods are configured on the '
                                'backend yet.')
                            : Column(
                                children: [
                                  for (var i = 0; i < methods.length; i++)
                                    Container(
                                      constraints: const BoxConstraints(
                                          minHeight: 56),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: i == methods.length - 1
                                          ? null
                                          : const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                    color: AppColors.line),
                                              ),
                                            ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _label(methods[i].code),
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        AppTheme.uiFont,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: AppColors.ink,
                                                  ),
                                                ),
                                                // Backend flag: the method is
                                                // on but has no credentials —
                                                // checkout would answer 422
                                                // PAYMENT_NOT_CONFIGURED.
                                                if (!methods[i].configured) ...[
                                                  const SizedBox(height: 2),
                                                  Text(gt('Add the Razorpay key id and secret in '
                                                    'Configuration first'),
                                                    style: TextStyle(
                                                      fontFamily:
                                                          AppTheme.uiFont,
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.red,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (!methods[i].configured)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8),
                                              child: StatusChip('Needs setup',
                                                  fg: AppColors.goldInk,
                                                  bg: AppColors.goldTint),
                                            ),
                                          AppSwitch(
                                            value: methods[i].enabled,
                                            onChanged: (!methods[i].configured &&
                                                    !methods[i].enabled)
                                                ? (_) {}
                                                : (_) => state
                                                    .togglePaymentMethod(
                                                        methods[i].code ?? ''),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Hint(
                          'Toggles save immediately. The customer checkout '
                          'shows only the enabled methods, and the backend '
                          'rejects a method that is on but not configured '
                          '(at least one must stay on).',
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
}
