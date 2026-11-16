import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/seed_data.dart' as seed;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/panels.dart';
import '../../widgets/product_card.dart' show toneBg;
import '../../widgets/skeleton.dart' show FadeSlideIn, Pressable;
import '../../widgets/orders_paused_banner.dart';
import '../../widgets/store_actions.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_layout.dart';
import '../../widgets/toast.dart';
import 'sheets/addresses_sheet.dart';

const List<String> _slots = [
  'Today · 4:00 – 6:00 PM',
  'Today · 6:00 – 8:00 PM',
  'Tomorrow · 10:00 AM – 12:00 PM',
];

/// `#/checkout` — delivery/pickup mode, address or slot, payment, bill, place.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _quoteStarted = false;

  /// True while `POST /orders` is in flight — blocks a double submit and
  /// shows the pending state until the backend answers.
  bool _placing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_quoteStarted) {
      _quoteStarted = true;
      // Pull server quote warnings (coupon skipped, coins above cap, …)
      // so checkout shows them before the order is placed.
      StateScope.of(context).refreshCartQuoteWarnings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';

    if (state.cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const StatusBar(),
              ScreenBar(
                title: gu ? 'ચેકઆઉટ' : 'Checkout',
                onBack: () => go('/cart'),
              ),
              Expanded(
                child: EmptyState(
                  icon: 'cart',
                  title: gu ? 'ચેકઆઉટ માટે કંઈ નથી' : 'Nothing to check out',
                  copy: gu
                      ? 'તમારી કાર્ટ ખાલી છે.'
                      : 'Your cart is empty. Add something from the store first.',
                  actionLabel: gu ? 'વસ્તુઓ જુઓ' : 'Browse products',
                  onAction: () => go('/shop'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final totals = state.cartTotals();
            final mode = state.flow.checkoutMode;
            final pickup = mode == 'pickup';
            // Cash on delivery and pay-at-store are one option ('cash');
            // online options only exist while the admin has them enabled.
            final offered = state.checkoutPaymentKeys();
            if (!offered.contains(state.checkoutPayKey)) {
              state.flow.checkoutPayment = 'cash';
            }
            final payment = state.checkoutPayKey;

            void switchMode(String next) {
              final flow = StateScope.read(context).flow;
              flow.checkoutMode = next;
              setLocal(() {});
            }

            final wide = MediaQuery.sizeOf(context).width >= 1000;

            // Wide screens frame every step in its own rich card.
            Widget step(int n, String label, Widget child) {
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_StepHeader(n, label, gu), child],
                );
              }
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration:
                    StoreKit.card(accent: AppColors.red, radius: 24)
                        .copyWith(gradient: StoreKit.creamSoft, color: null),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StepHeader(n, label, gu, big: true),
                    child,
                  ],
                ),
              );
            }
            final ctaRow = Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gu ? 'કુલ ચૂકવવાનું' : 'Total payable',
                              style: _ts(gu,
                                  size: 11.5,
                                  w: FontWeight.w700,
                                  color: AppColors.ink3),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              money(totals.total),
                              style: _ts(gu,
                                  size: 21,
                                  w: FontWeight.w800,
                                  color: AppColors.goldInk),
                            ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (btnCtx) {
                          final payLabel = gu ? 'ઓર્ડર કરો' : 'Place order';
                          return AppButton(
                            '$payLabel · ${money(totals.total)}',
                            loading: _placing,
                            onTap: _placing
                                ? null
                                : () async {
                                    setState(() => _placing = true);
                                    final res = await StateScope.read(btnCtx)
                                        .placeOrder();
                                    if (!mounted) return;
                                    setState(() => _placing = false);
                                    // The backend rejected the order (400
                                    // validation, stock, coupon, …): stay on
                                    // checkout and show its message.
                                    if (res.error != null) {
                                      showToast(res.error!, 'error');
                                      return;
                                    }
                                    go('/placed/${res.number}');
                                    showToast('Order ${res.number} placed');
                                  },
                          );
                        },
                      ),
                    ],
            );
            final leftW = <Widget>[
                      const OrdersPausedBanner(),
                      // Server quote warnings (coupon not applicable, coins
                      // skipped by the coupon, coins above cap, …).
                      if (state.cartQuoteWarnings.isNotEmpty) ...[
                        for (final w in state.cartQuoteWarnings) ...[
                          Hint(w),
                          const SizedBox(height: 8),
                        ],
                      ],
                      Segmented(
                        value: mode,
                        onChanged: switchMode,
                        options: [
                          SegmentOption(
                            'delivery',
                            gu ? 'હોમ ડિલિવરી' : 'Home delivery',
                            icon: 'truck',
                          ),
                          SegmentOption(
                            'pickup',
                            gu ? 'સ્ટોર પિકઅપ' : 'Store pickup',
                            icon: 'store',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (state.checkoutFieldErrors.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.red),
                          ),
                          child: Text(
                            state.checkoutFieldErrors.values.join('\n'),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.red),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      step(
                        1,
                        pickup
                            ? (gu ? 'પિકઅપ' : 'Pickup')
                            : (gu ? 'ડિલિવરી' : 'Delivery'),
                        FadeSlideIn(
                        child: !pickup
                            ? _deliveryCard(context, state, gu)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _storeCard(gu),
                                  const SizedBox(height: 12),
                                  _slotCard(context, state, gu,
                                      () => setLocal(() {})),
                                ],
                              ),
                      )),
                      const SizedBox(height: 18),
                      step(
                        2,
                        gu ? 'સમીક્ષા' : 'Review',
                        FadeSlideIn(
                            delayMs: 60,
                            child: _summaryCard(
                                gu, totals, state.cartQuoteText)),
                      ),
                      const SizedBox(height: 18),
                      step(
                        3,
                        gu ? 'ચુકવણી' : 'Payment',
                        FadeSlideIn(
                          delayMs: 120,
                          child: _paymentCard(context, gu, pickup, payment,
                              offered, () => setLocal(() {})),
                        ),
                      ),
            ];
            final rightW = <Widget>[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration:
                            StoreKit.card(accent: AppColors.gold, radius: 20)
                                .copyWith(
                                    gradient: StoreKit.creamSoft, color: null),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            StoreSectionTitle(gu ? 'બિલની વિગત' : 'Bill summary'),
                            const SizedBox(height: 12),
                            BillLines(BillData.fromTotals(totals)),
                            if (!pickup &&
                                state.cartQuoteDeliveryPaise > 0 &&
                                state.cartQuoteTotalPaise != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(gt('Delivery fee'),
                                      style: _ts(gu,
                                          size: 12.5,
                                          w: FontWeight.w700,
                                          color: AppColors.ink3)),
                                  Text(
                                      money(state.cartQuoteDeliveryPaise / 100),
                                      style: _ts(gu,
                                          size: 12.5,
                                          w: FontWeight.w800,
                                          color: AppColors.ink)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(gt('Total with delivery'),
                                      style: _ts(gu,
                                          size: 12.5,
                                          w: FontWeight.w700,
                                          color: AppColors.ink3)),
                                  Text(
                                      money(state.cartQuoteTotalPaise! / 100),
                                      style: _ts(gu,
                                          size: 12.5,
                                          w: FontWeight.w800,
                                          color: AppColors.ink)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: StoreKit.goldWarm,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                const AppIcon('ticket',
                                    size: 15, color: AppColors.white, sw: 2),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _couponText(gu, totals),
                                    style: _ts(gu,
                                        size: 12,
                                        w: FontWeight.w800,
                                        color: AppColors.white),
                                  ),
                                ),
                              ]),
                            ),
                            EarnNote(
                              coins: totals.coinsEarned,
                              ruleName: totals.earnRule?.name,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppColors.navyTint,
                            Color(0xFFFFF3DC),
                          ]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.navy.withValues(alpha: .12)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppIcon(
                              pickup ? 'store' : 'truck',
                              size: 16,
                              color: AppColors.navy,
                              sw: 2,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                pickup
                                    ? (gu
                                        ? 'તમારો ઓર્ડર પેક થઈને સ્ટોર કાઉન્ટર પર તૈયાર રહેશે.'
                                        : 'Your order will be packed and kept ready at the ${seed.storeLocality()} counter.')
                                    : (gu
                                        ? 'મફત હોમ ડિલિવરી. રાઇડર આવતાં પહેલાં કૉલ કરશે.'
                                        : 'Free home delivery. Our rider will call you before arriving.'),
                                style: _ts(gu,
                                    size: 12,
                                    w: FontWeight.w600,
                                    color: AppColors.navy,
                                    height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
            ];
            return Column(
              children: [
                const StatusBar(),
                ScreenBar(
                  title: gu ? 'ચેકઆઉટ' : 'Checkout',
                  sub: pickup
                      ? (gu ? 'સ્ટોરથી પિકઅપ' : 'Pickup from ${seed.storeLocality()}')
                      : (gu ? 'મફત હોમ ડિલિવરી' : 'Free home delivery'),
                  onBack: () => go('/cart'),
                ),
                if (wide)
                  // Desktop: steps on the left, summary + Place order pinned
                  // on the right.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                      child: StoreTwoPane(
                        breakpoint: 1000,
                        asideWidth: 420,
                        gap: 28,
                        main: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: leftW,
                          ),
                        ),
                        aside: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...rightW,
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: StoreKit.card(
                                    accent: AppColors.red, radius: 20),
                                child: ctaRow,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  ScreenScroll(
                    bottom: 128,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...leftW,
                            const SizedBox(height: 12),
                            ...rightW,
                          ],
                        ),
                      ),
                    ),
                  ),
                  ActionBar(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ctaRow,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delivery address / pickup store + slot
// ---------------------------------------------------------------------------

Widget _deliveryCard(BuildContext context, AppState state, bool gu) {
  Address? addr;
  if (state.addresses.isNotEmpty) {
    addr = state.addresses.firstWhere(
      (a) => a.id == state.flow.selectedAddressId,
      orElse: () => state.addresses.first,
    );
  }

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.gold, radius: 20, tinted: true),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: StoreKit.goldWarm,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: AppIcon('pin', size: 19, color: AppColors.white, sw: 2),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gu ? 'ડિલિવરી સરનામું' : 'Deliver to',
                      style: _ts(gu,
                          size: 11.5,
                          w: FontWeight.w700,
                          color: AppColors.ink3),
                    ),
                  ),
                  if (addr != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.redTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        addr.label,
                        style: _ts(gu,
                            size: 10.5,
                            w: FontWeight.w800,
                            color: AppColors.red),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                addr?.full ?? '',
                style: _ts(gu,
                    size: 13,
                    w: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.4),
              ),
              const SizedBox(height: 5),
              Text(
                addr == null
                    ? (gu ? 'સરનામું પસંદ કરો' : 'Choose an address')
                    : '${addr.phone} · ${gu ? '8 વાગ્યા સુધી મફત ડિલિવરી' : 'Free delivery by 8 PM'}',
                style: _ts(gu,
                    size: 11.5,
                    w: FontWeight.w600,
                    color: AppColors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AppLink(
          gu ? 'બદલો' : 'Change',
          onTap: () => showAddressSheet(context),
        ),
      ],
    ),
  );
}

Widget _storeCard(bool gu) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: StoreKit.heroNavyRed,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
            color: AppColors.navy.withValues(alpha: .25),
            offset: const Offset(0, 10),
            blurRadius: 22),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: AppIcon('store', size: 18, color: AppColors.white),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gu ? 'પિકઅપ સ્ટોર' : 'Pickup store',
                style: _ts(gu,
                    size: 11.5,
                    w: FontWeight.w700,
                    color: const Color(0xB8FFFFFF)),
              ),
              const SizedBox(height: 5),
              Text(
                seed.store.addressFor(gu),
                style: _ts(gu,
                    size: 13,
                    w: FontWeight.w700,
                    color: AppColors.white,
                    height: 1.4),
              ),
              const SizedBox(height: 5),
              Text(
                seed.store.phone,
                style: _ts(gu,
                    size: 11.5,
                    w: FontWeight.w600,
                    color: const Color(0xB8FFFFFF)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AppLink(
          gu ? 'કૉલ' : 'Call',
          color: AppColors.gold2,
          onTap: StoreActions.call,
        ),
      ],
    ),
  );
}

Widget _slotCard(
    BuildContext context, AppState state, bool gu, VoidCallback setLocal) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.red, radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreSectionTitle(gu ? 'પિકઅપ સમય પસંદ કરો' : 'Pick a pickup slot',
            icon: 'clock'),
        const SizedBox(height: 4),
        for (final slot in _slots)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              StateScope.read(context).flow.selectedSlot = slot;
              setLocal();
            },
            child: _SlotRow(
              label: slot,
              selected: state.flow.selectedSlot == slot,
              gu: gu,
            ),
          ),
      ],
    ),
  );
}

class _SlotRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool gu;

  const _SlotRow({
    required this.label,
    required this.selected,
    required this.gu,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [AppColors.redTint, Color(0xFFFFF3DC)])
            : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: selected ? AppColors.red : AppColors.line,
            width: selected ? 1.6 : 1),
      ),
      child: Row(
        children: [
          AppRadio(selected: selected),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: _ts(gu,
                  size: 13.5,
                  w: FontWeight.w700,
                  color: selected ? AppColors.ink : AppColors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order summary
// ---------------------------------------------------------------------------

Widget _summaryCard(
    bool gu, CartTotals t, Map<String, (String, String)> quoteText) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.navy, radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreSectionTitle(gu ? 'ઓર્ડર સારાંશ' : 'Order summary',
            actionLabel: gu ? 'બદલો' : 'Edit',
            onAction: () => go('/cart')),
        const SizedBox(height: 6),
        for (var i = 0; i < t.details.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: AppColors.line),
          _summaryRow(gu, t.details[i], quoteText[t.details[i].v.backendId ?? '']),
        ],
      ],
    ),
  );
}

Widget _summaryRow(bool gu, CartLine it, (String, String)? qt) {
  final qName = qt?.$1 ?? '';
  final qLabel = qt?.$2 ?? '';
  final name = gu
      ? (qName.isNotEmpty ? qName : (it.p.nameGu.isNotEmpty ? it.p.nameGu : it.p.name))
      : it.p.name;
  final tn = StoreKit.tone(it.p.id.hashCode.abs());
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [toneBg(it.p.tone), tn.$2.withValues(alpha: .6)]),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.white, width: 2),
          ),
          child: Center(
            child: ProductArtView(it.p.art, size: 32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(gu,
                    size: 13, w: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${qLabel.isNotEmpty ? qLabel : (it.v.label.trim().isNotEmpty ? it.v.label : it.v.unit)} × ${it.qty}',
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          money(it.lineTotal),
          style: _ts(gu, size: 13.5, w: FontWeight.w800, color: AppColors.ink),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

Widget _paymentCard(
  BuildContext context,
  bool gu,
  bool pickup,
  String payment,
  List<String> offered,
  VoidCallback setLocal,
) {
  final all = <_PayOption>[
    _PayOption(
      key: 'upi',
      icon: 'card',
      title: gu ? 'ઓનલાઇન ચૂકવો' : 'Pay online',
      sub: gu
          ? 'UPI, કાર્ડ, નેટ બેંકિંગ (Razorpay)'
          : 'UPI, card or net banking (Razorpay)',
    ),
    _PayOption(
      key: 'card',
      icon: 'card',
      title: gu ? 'કાર્ડ' : 'Card',
      sub: gu ? 'ડેબિટ / ક્રેડિટ કાર્ડ' : 'Debit / credit card',
    ),
    _PayOption(
      key: 'netbanking',
      icon: 'card',
      title: gu ? 'નેટ બેંકિંગ' : 'Net banking',
      sub: gu ? 'તમારી બેંક દ્વારા ચૂકવો' : 'Pay through your bank',
    ),
    // Cash on delivery and pay at store are the same option.
    pickup
        ? _PayOption(
            key: 'cash',
            icon: 'store',
            title: gu ? 'દુકાન પર ચૂકવો' : 'Pay at store',
            sub: gu ? 'લેવા આવતી વખતે ચૂકવો' : 'Pay when you collect',
          )
        : _PayOption(
            key: 'cash',
            icon: 'cash',
            title: gu ? 'ડિલિવરી પર રોકડ' : 'Cash on delivery',
            sub: gu ? 'રાઇડરને ઘરે ચૂકવો' : 'Pay our rider at your door',
          ),
  ];
  final rows = [for (final o in all) if (offered.contains(o.key)) o];

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.red, radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                gu ? 'પેમેન્ટ પદ્ધતિ' : 'Payment method',
                style: _ts(gu,
                    size: 15, w: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            Pill(
              label: gu ? 'સુરક્ષિત' : 'Secure',
              bg: AppColors.greenTint,
              fg: AppColors.green,
              icon: 'shield',
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var oi = 0; oi < rows.length; oi++)
          Builder(builder: (_) {
            final option = rows[oi];
            final tn = StoreKit.tone(oi + 3);
            return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Pressable(
              scale: .98,
              onTap: () {
                StateScope.read(context).flow.checkoutPayment = option.key;
                setLocal();
              },
              child: Semantics(
                button: true,
                selected: payment == option.key,
                label: '${option.title}. ${option.sub}',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 60),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: payment == option.key
                        ? const LinearGradient(colors: [
                            AppColors.redTint,
                            Color(0xFFFFF3DC)
                          ])
                        : null,
                    color: payment == option.key ? null : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: payment == option.key
                          ? AppColors.red
                          : AppColors.line,
                      width: payment == option.key ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [tn.$1, tn.$2]),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Center(
                          child: AppIcon(
                            option.icon,
                            size: 19,
                            color: tn.$3,
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
                              option.title,
                              style: _ts(gu,
                                  size: 13.5,
                                  w: FontWeight.w800,
                                  color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              option.sub,
                              style: _ts(gu,
                                  size: 11.5,
                                  w: FontWeight.w600,
                                  color: AppColors.ink2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppRadio(selected: payment == option.key),
                    ],
                  ),
                ),
              ),
            ),
          );
          }),
      ],
    ),
  );
}

class _PayOption {
  final String key;
  final String icon;
  final String title;
  final String sub;

  const _PayOption({
    required this.key,
    required this.icon,
    required this.title,
    required this.sub,
  });
}

/// Numbered section header ("1  Delivery") above each checkout card.
class _StepHeader extends StatelessWidget {
  final int n;
  final String label;
  final bool gu;
  final bool big;
  const _StepHeader(this.n, this.label, this.gu, {this.big = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: big ? 14 : 8, left: 2),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: StoreKit.redWarm,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.red.withValues(alpha: .3),
                    offset: const Offset(0, 3),
                    blurRadius: 8),
              ],
            ),
            alignment: Alignment.center,
            child: Text('$n',
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    height: 1)),
          ),
          const SizedBox(width: 8),
          Text(label, style: _ts(gu, size: big ? 18 : 14, w: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _couponText(bool gu, CartTotals t) {
  if (t.couponOk && t.coupon?.coupon != null) {
    final code = t.coupon!.coupon!.code;
    return gu
        ? '$code · ${money(t.discount)} બચ્યા'
        : '$code · ${money(t.discount)} saved';
  }
  if (t.coupon != null) {
    return gu ? 'કૂપન ઉપલબ્ધ નથી' : 'Coupon unavailable';
  }
  if (t.coinsUsed > 0) {
    return gu ? '${t.coinsUsed} કોઈન્સ લાગુ' : '${t.coinsUsed} coins applied';
  }
  return gu ? 'કોઈ કૂપન લાગુ નથી' : 'No coupon applied';
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
