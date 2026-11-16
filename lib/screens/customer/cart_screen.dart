import 'package:flutter/material.dart' hide Stepper;

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
import '../../widgets/skeleton.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_layout.dart';
import '../../widgets/product_card.dart' show toneBg;
import '../../widgets/toast.dart';
import 'sheets/coins_sheet.dart';
import 'sheets/coupons_sheet.dart';

/// `#/cart` — cart lines, coupon, coins panel, bill and the checkout CTA.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
                title: gu ? 'મારી કાર્ટ' : 'My cart',
                sub: gu ? 'મફત હોમ ડિલિવરી' : 'Free home delivery',
                onBack: () => go('/home'),
              ),
              Expanded(
                child: EmptyState(
                  icon: 'cart',
                  title: gu ? 'તમારી કાર્ટ ખાલી છે' : 'Your cart is empty',
                  copy: gu
                      ? 'કરિયાણું, સૂકો ફળ કે આઇસ્ક્રીમ ઉમેરો.'
                      : 'Add groceries, dry fruit or a treat from the freezer.',
                  actionLabel: gu ? 'ખરીદી શરૂ કરો' : 'Start shopping',
                  onAction: () => go('/shop'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final t = state.cartTotals();
    final count = state.cartCount();
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final itemWidgets = <Widget>[
      for (var i = 0; i < t.details.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        FadeSlideIn(
          key: ValueKey('ci-${t.details[i].p.id}-${t.details[i].v.label}'),
          delayMs: i < 6 ? i * 40 : 0,
          child: _CartItemCard(
            line: t.details[i],
            index: i,
            state: state,
            gu: gu,
            wide: wide,
          ),
        ),
      ],
    ];
    final billPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: StoreKit.card(accent: AppColors.gold, radius: 20)
          .copyWith(gradient: StoreKit.creamSoft, color: null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoreSectionTitle(gu ? 'બિલની વિગત' : 'Bill summary'),
          const SizedBox(height: 12),
          BillLines(BillData.fromTotals(t)),
          EarnNote(coins: t.coinsEarned, ruleName: t.earnRule?.name),
        ],
      ),
    );
    final secureHint = Hint(
      gu
          ? 'સુરક્ષિત ચેકઆઉટ · ${seed.store.promiseFor(gu)}'
          : 'Secure checkout · ${seed.store.promiseFor(gu)}',
      icon: 'shield',
    );
    final cta = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gu ? 'ચૂકવવાનું' : 'To pay',
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w700, color: AppColors.ink3),
              ),
              const SizedBox(height: 2),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: t.total.toDouble()),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, v, _) => Text(
                  money(v.round()),
                  style: _ts(gu,
                      size: 20, w: FontWeight.w800, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
        AppButton(
          gu ? 'ચેકઆઉટ' : 'Checkout',
          icon: 'arrow',
          onTap: () => go('/checkout'),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const StatusBar(),
            ScreenBar(
              title: gu ? 'મારી કાર્ટ' : 'My cart',
              sub: gu
                  ? '$count ${count == 1 ? 'વસ્તુ' : 'વસ્તુઓ'} · મફત ડિલિવરી'
                  : '$count item${count == 1 ? '' : 's'} · free delivery',
              onBack: () => go('/shop'),
              right: IconBtn(
                'trash',
                iconSize: 20,
                onTap: () {
                  state.resetCart();
                  showToast('Cart cleared');
                },
              ),
            ),
            if (wide)
              // Desktop: items on the left, coupon / coins / bill and the
              // checkout button pinned on the right.
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
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: StoreKit.heroNavyRed,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.red
                                        .withValues(alpha: .22),
                                    offset: const Offset(0, 8),
                                    blurRadius: 20),
                              ],
                            ),
                            child: Row(
                              children: [
                                const AppIcon('cart',
                                    size: 22, color: AppColors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    gu ? 'તમારી કાર્ટની વસ્તુઓ' : 'Items in your cart',
                                    style: _ts(gu,
                                        size: 18,
                                        w: FontWeight.w800,
                                        color: AppColors.white),
                                  ),
                                ),
                                Text(
                                  gu
                                      ? '$count ${count == 1 ? 'વસ્તુ' : 'વસ્તુઓ'}'
                                      : '$count item${count == 1 ? '' : 's'}',
                                  style: _ts(gu,
                                      size: 13,
                                      w: FontWeight.w700,
                                      color: AppColors.goldTint),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...itemWidgets,
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _couponBlock(context, state, gu, t)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _coinsPanel(context, state, gu, t)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    aside: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          billPanel,
                          const SizedBox(height: 14),
                          Container(
                              padding: const EdgeInsets.all(18),
                              decoration: StoreKit.card(
                                  accent: AppColors.red, radius: 20),
                              child: cta),
                          const SizedBox(height: 12),
                          secureHint,
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              ScreenScroll(
                bottom: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...itemWidgets,
                    const SizedBox(height: 12),
                    _couponBlock(context, state, gu, t),
                    const SizedBox(height: 12),
                    _coinsPanel(context, state, gu, t),
                    const SizedBox(height: 12),
                    billPanel,
                    const SizedBox(height: 12),
                    secureHint,
                  ],
                ),
              ),
              ActionBar(child: cta),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cart line card
// ---------------------------------------------------------------------------

class _CartItemCard extends StatelessWidget {
  final CartLine line;
  final int index;
  final AppState state;
  final bool gu;
  final bool wide;

  const _CartItemCard({
    required this.line,
    required this.index,
    required this.state,
    required this.gu,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = line.p;
    final qt = state.cartQuoteText[line.v.backendId ?? ''];
    final qName = qt?.$1 ?? '';
    final qLabel = qt?.$2 ?? '';
    final name = gu
        ? (qName.isNotEmpty
            ? qName
            : (p.nameGu.isNotEmpty ? p.nameGu : p.name))
        : p.name;
    final category = _categoryLabel(state, p.category, gu);

    final tn = StoreKit.tone(index);
    return Container(
      padding: EdgeInsets.all(wide ? 18 : 12),
      decoration: StoreKit.card(accent: tn.$3, radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: wide ? 112 : 64,
            height: wide ? 112 : 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [toneBg(p.tone), tn.$2.withValues(alpha: .65)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: tn.$3.withValues(alpha: .15),
                    offset: const Offset(0, 4),
                    blurRadius: 10),
              ],
            ),
            child: Center(
              child: ProductArtView(p.art, size: wide ? 92 : 52),
            ),
          ),
          SizedBox(width: wide ? 20 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(gu,
                      size: wide ? 17 : 14,
                      w: FontWeight.w800,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  '${qLabel.isNotEmpty ? qLabel : (line.v.label.trim().isNotEmpty ? line.v.label : line.v.unit)} · $category',
                  style:
                      _ts(gu, size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
                ),
                if (_saleNote(state, line, gu) != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _saleNote(state, line, gu)!,
                    style: _ts(gu,
                        size: 11.5, w: FontWeight.w800, color: AppColors.red),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.goldTint, Color(0xFFFFE7A0)]),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        money(line.v.price),
                        style: _ts(gu,
                            size: 15,
                            w: FontWeight.w800,
                            color: AppColors.goldInk),
                      ),
                    ),
                    if (!p.allowCoins)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.redTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          gu ? 'કોઈન્સ નહીં' : 'No coins',
                          style: _ts(gu,
                              size: 10,
                              w: FontWeight.w800,
                              color: AppColors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (wide) ...[
                Text(
                  money(line.lineTotal),
                  style: _ts(gu,
                      size: 20, w: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 10),
              ],
              Stepper(
                value: line.qty,
                ariaDec: gu ? 'ઘટાડો' : 'Decrease',
                ariaInc: gu ? 'વધારો' : 'Increase',
                onDec: () {
                  final err = state.setQty(index, -1);
                  if (err != null) showToast(err, 'error');
                },
                onInc: () {
                  final err = state.setQty(index, 1);
                  if (err != null) showToast(err, 'error');
                },
              ),
              if (wide) ...[
                const SizedBox(height: 10),
                AppLink(
                  gu ? 'કાઢો' : 'Remove',
                  onTap: () => state.removeLine(index),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coupon block
// ---------------------------------------------------------------------------

Widget _couponBlock(
    BuildContext context, AppState state, bool gu, CartTotals t) {
  if (t.couponOk && t.coupon?.coupon != null) {
    final code = t.coupon!.coupon!.code;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: StoreKit.card(accent: AppColors.gold, radius: 18, tinted: true),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: StoreKit.goldWarm,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(
              child: AppIcon('ticket', size: 18, color: AppColors.white),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gu ? '$code લાગુ' : '$code applied',
                  style: _ts(gu,
                      size: 13.5, w: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  gu
                      ? 'તમે ${money(t.discount)} બચાવ્યા.'
                      : 'You saved ${money(t.discount)}.',
                  style: _ts(gu,
                      size: 11.5, w: FontWeight.w600, color: AppColors.green),
                ),
              ],
            ),
          ),
          AppLink(
            gu ? 'કાઢો' : 'Remove',
            onTap: () {
              state.clearCoupon();
              showToast('Coupon removed');
            },
          ),
        ],
      ),
    );
  }

  if (t.coupon != null && !t.couponOk) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.red),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon('info', size: 15, color: AppColors.red, sw: 2),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              t.coupon!.message,
              style: _ts(gu,
                  size: 12.5,
                  w: FontWeight.w700,
                  color: AppColors.red,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: StoreKit.card(accent: AppColors.red, radius: 18, tinted: true),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: StoreKit.redWarm,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: AppIcon('ticket', size: 18, color: AppColors.white),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            gu ? 'કૂપન લગાવો' : 'Apply a coupon',
            style: _ts(gu,
                size: 13.5, w: FontWeight.w800, color: AppColors.ink),
          ),
        ),
        AppLink(
          gu ? 'ઓફર જુઓ' : 'View offers',
          onTap: () => showCouponsSheet(context),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Coins panel
// ---------------------------------------------------------------------------

Widget _coinsPanel(
    BuildContext context, AppState state, bool gu, CartTotals t) {
  final usable = t.balance < t.cap ? t.balance : t.cap;
  final switchOff = t.balance == 0 || !t.canUseCoins;
  final ineligible = <String>[];
  for (final it in t.details) {
    if (!it.p.allowCoins) {
      final n = gu && it.p.nameGu.isNotEmpty ? it.p.nameGu : it.p.name;
      if (!ineligible.contains(n)) ineligible.add(n);
    }
  }

  final String headline;
  if (t.coinsUsed > 0) {
    headline = gu
        ? '${t.coinsUsed} કોઈન્સ લાગુ · ${money(t.coinDiscount)}'
        : '${t.coinsUsed} coins applied · ${money(t.coinDiscount)}';
  } else {
    headline = gu
        ? '${t.balance} કોઈન્સ ઉપલબ્ધ'
        : '${t.balance} coins available';
  }

  final String note;
  if (!t.canUseCoins) {
    final code = t.coupon?.coupon?.code;
    final who = gu
        ? '${code ?? 'આ કૂપન'} આ કૂપન સાથે કોઈન્સ લાગુ નહીં'
        : "${code ?? 'This coupon'} can't be combined with coins";
    note = who;
  } else if (usable <= 0) {
    note = gu
        ? 'આ ઓર્ડર પર હજી કોઈન્સ ઉપલબ્ધ નથી'
        : 'No coins available to use on this order yet';
  } else {
    note = gu
        ? '1 કોઈન = ₹1 · આ ઓર્ડર પર $usable કોઈન્સ સુધી વાપરી શકાય'
        : '1 coin = ₹1 · up to $usable coins can be used on this order';
  }

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: t.canUseCoins
        ? StoreKit.card(accent: AppColors.gold, radius: 18, tinted: true)
        : StoreKit.card(accent: AppColors.red, radius: 18, tinted: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: _ts(gu,
                        size: 13.5, w: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: _ts(gu,
                        size: 11.5,
                        w: FontWeight.w600,
                        color: t.canUseCoins ? AppColors.ink3 : AppColors.red,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AppSwitch(
              value: state.useCoins,
              disabled: switchOff,
              onChanged: (v) => state.setUseCoins(v),
            ),
          ],
        ),
        if (t.canUseCoins && ineligible.isNotEmpty) ...[
          const SizedBox(height: 8),
          Hint(
            gu
                ? 'કોઈન્સ નહીં ${ineligible.join(', ')}'
                : 'No coins on ${ineligible.join(', ')}',
            icon: 'info',
          ),
        ],
        const SizedBox(height: 12),
        AppButton(
          state.useCoins
              ? (gu ? 'કોઈન્સ બદલો' : 'Change coins')
              : (gu ? 'કોઈન્સ પસંદ કરો' : 'Choose coins'),
          variant: BtnVariant.soft,
          size: BtnSize.sm,
          block: true,
          icon: 'coin',
          onTap: () => showCoinsSheet(context),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _categoryLabel(AppState state, String id, bool gu) {
  for (final c in state.categories) {
    if (c.id == id) return gu && c.nameGu.isNotEmpty ? c.nameGu : c.name;
  }
  return id;
}

/// Bilingual text style — Gujarati falls back to the Hind Vadodara family.
/// "1 of 3 at sale price" when only part of a line gets the flash price
/// (cap or per-customer limit); from the last server quote.
String? _saleNote(AppState state, CartLine line, bool gu) {
  final id = line.v.backendId;
  if (id == null) return null;
  final split = state.cartSaleSplit[id];
  if (split == null || split.$1 == 0 || split.$1 >= split.$2) return null;
  return gu
      ? 'ફ્લેશ સેલ: ${split.$2} માંથી ${split.$1} સેલ ભાવે'
      : 'Flash sale: ${split.$1} of ${split.$2} at sale price';
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
