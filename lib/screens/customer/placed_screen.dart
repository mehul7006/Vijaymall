import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/seed_data.dart' as seed;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/panels.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_status_chip.dart';
import 'missing_screen.dart';
import 'order_bill.dart';
import 'order_extras.dart';

/// `#/placed/{number}` — celebration screen right after `placeOrder()`.
class PlacedScreen extends StatelessWidget {
  final String number;

  const PlacedScreen({super.key, required this.number});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final order = state.orderByNumber(number);

    if (order == null) {
      return MissingScreen(
        title: gu ? 'ઓર્ડર થઈ ગયો' : 'Order placed',
        copy: gu
            ? 'અમને એ ઓર્ડર મળ્યો નહીં.'
            : 'We could not find that order.',
        backRoute: '/orders',
      );
    }

    final pickup = order.mode == 'pickup';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const StatusBar(),
            ScreenScroll(
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
                    decoration: BoxDecoration(
                      gradient: StoreKit.heroNavyRed,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.red.withValues(alpha: .28),
                            offset: const Offset(0, 12),
                            blurRadius: 28),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.elasticOut,
                          builder: (context, v, c) =>
                              Transform.scale(scale: v.clamp(0.0, 1.3), child: c),
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: StoreKit.goldWarm,
                              border: Border.all(color: AppColors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: .55),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: AppIcon('check',
                                  size: 40, color: AppColors.white, sw: 2.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        gu ? 'ઓર્ડર થઈ ગયો!' : 'Order placed!',
                        textAlign: TextAlign.center,
                        style: _ts(gu,
                            size: 25, w: FontWeight.w800, color: AppColors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pickup
                            ? (gu
                                ? 'પિકઅપ માટે તૈયાર થાય ત્યારે સંદેશ મોકલીશું.'
                                : 'We’ll message you when it’s ready for pickup.')
                            : (gu
                                ? 'તમારો ઓર્ડર અમારી દુકાનમાં છે.'
                                : 'Your order is with our ${seed.store.name} store.'),
                        textAlign: TextAlign.center,
                        style: _ts(gu,
                            size: 13,
                            w: FontWeight.w600,
                            color: AppColors.white.withValues(alpha: .88),
                            height: 1.5),
                      ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (MediaQuery.sizeOf(context).width >= 1000)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (order.awaitingPayment) ...[
                                PayPendingCard(order: order),
                                const SizedBox(height: 12),
                              ],
                              _summaryCard(state, gu, order),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                gu ? 'હવે પછી શું' : 'What next',
                                style: _ts(gu,
                                    size: 18,
                                    w: FontWeight.w800,
                                    color: AppColors.ink),
                              ),
                              const SizedBox(height: 12),
                              if (order.coinsEarned > 0) ...[
                                _coinsCard(gu, order),
                                const SizedBox(height: 12),
                              ],
                              _addressCard(gu, order),
                              const SizedBox(height: 18),
                              AppButton(
                                gu ? 'ઓર્ડર ટ્રેક કરો' : 'Track my order',
                                icon: 'truck',
                                block: true,
                                onTap: () => go('/track/${order.number}'),
                              ),
                              const SizedBox(height: 10),
                              AppButton(
                                gu ? 'ખરીદી ચાલુ રાખો' : 'Continue shopping',
                                variant: BtnVariant.secondary,
                                block: true,
                                onTap: () => go('/shop'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                  if (order.awaitingPayment) ...[
                    PayPendingCard(order: order),
                    const SizedBox(height: 12),
                  ],
                  _summaryCard(state, gu, order),
                  if (order.coinsEarned > 0) ...[
                    const SizedBox(height: 12),
                    _coinsCard(gu, order),
                  ],
                  const SizedBox(height: 12),
                  _addressCard(gu, order),
                  const SizedBox(height: 18),
                  AppButton(
                    gu ? 'ઓર્ડર ટ્રેક કરો' : 'Track my order',
                    icon: 'truck',
                    block: true,
                    onTap: () => go('/track/${order.number}'),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    gu ? 'ખરીદી ચાલુ રાખો' : 'Continue shopping',
                    variant: BtnVariant.secondary,
                    block: true,
                    onTap: () => go('/shop'),
                  ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

Widget _summaryCard(AppState state, bool gu, Order order) {
  final pickup = order.mode == 'pickup';
  final statusLabel =
      gu ? (AppState.statusLabelGu[order.status] ?? order.status) : state.statusLabel(order.status);
  final strong = pickup
      ? (order.slot.isNotEmpty
          ? order.slot
          : (gu ? 'આજે 6:00 – 8:00 PM' : 'Today · 6:00 – 8:00 PM'))
      : (gu ? 'આજે 8 વાગ્યા સુધી' : 'Arriving today by 8 PM');
  final itemCount = order.items.fold<int>(0, (sum, it) => sum + it.qty);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: StoreKit.card(accent: AppColors.gold, radius: 22, tinted: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                (gu ? 'ઓર્ડર ' : 'ORDER ') + order.number,
                style: _ts(gu,
                    size: 12,
                    w: FontWeight.w800,
                    color: AppColors.red,
                    height: 1.3),
              ),
            ),
            StoreStatusChip(order.status, label: statusLabel),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          strong,
          style: _ts(gu,
              size: 16, w: FontWeight.w800, color: AppColors.ink, height: 1.35),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: AppColors.line),
        const SizedBox(height: 4),
        BillLines(orderBillData(state, order)),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: AppColors.line),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _paymentLabel(gu, order.payment),
                    style: _ts(gu,
                        size: 13,
                        w: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  PayPill(
                    order.paymentState,
                    label: gu
                        ? (AppState.payStateGu[order.paymentState] ??
                            order.paymentState)
                        : order.paymentState,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  gu
                      ? '$itemCount ${itemCount == 1 ? 'વસ્તુ' : 'વસ્તુઓ'}'
                      : '$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: _ts(gu,
                      size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
                ),
                const SizedBox(height: 2),
                Text(
                  money(order.bill.total),
                  style: _ts(gu,
                      size: 19, w: FontWeight.w800, color: AppColors.goldInk),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Coins + address cards
// ---------------------------------------------------------------------------

Widget _coinsCard(bool gu, Order order) {
  final pickup = order.mode == 'pickup';
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: AppColors.goldPanel,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      border: Border.all(color: const Color(0x66F5B301)),
      boxShadow: [
        BoxShadow(
            color: AppColors.gold.withValues(alpha: .2),
            offset: const Offset(0, 8),
            blurRadius: 20),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.coinGradient,
          ),
          child: const Center(
            child: AppIcon('coin', size: 18, color: AppColors.white, sw: 2),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gu
                    ? '${order.coinsEarned} કોઈન્સ રસ્તામાં'
                    : '${order.coinsEarned} coins on the way',
                style: _ts(gu,
                    size: 13.5, w: FontWeight.w800, color: AppColors.goldInk),
              ),
              const SizedBox(height: 3),
              Text(
                gu
                    ? '${pickup ? 'પિકઅપ' : 'ડિલિવરી'} પછી વોલેટમાં ઉમેરાશે.'
                    : 'They’ll be credited to your wallet after ${pickup ? 'pickup' : 'delivery'}.',
                style: _ts(gu,
                    size: 11.5,
                    w: FontWeight.w600,
                    color: AppColors.goldInk,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _addressCard(bool gu, Order order) {
  final pickup = order.mode == 'pickup';
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.navy, radius: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.navyTint, Color(0xFFC9D2F5)]),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: AppIcon(
              pickup ? 'store' : 'pin',
              size: 18,
              color: AppColors.navy,
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
                pickup
                    ? (gu ? 'પિકઅપ સ્થળ' : 'Pickup from')
                    : (gu ? 'ડિલિવરી સરનામું' : 'Delivering to'),
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w700, color: AppColors.ink3),
              ),
              const SizedBox(height: 5),
              Text(
                order.address,
                style: _ts(gu,
                    size: 13,
                    w: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
