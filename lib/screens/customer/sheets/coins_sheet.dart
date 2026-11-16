import 'package:flutter/material.dart';

import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/fields.dart';
import '../../../widgets/sheet.dart';
import '../../../widgets/toast.dart';

/// §3.14 `Use your coins` — balance summary, mode options and custom amount.
void showCoinsSheet(BuildContext context) {
  final state = StateScope.read(context);
  final t = state.cartTotals();
  final gu = state.lang == 'gu';

  showAppSheet<void>(
    context: context,
    title: gu ? 'તમારા કોઈન્સ વાપરો' : 'Use your coins',
    sub: '${t.balance} coins = ${money(t.balance)}',
    builder: (ctx) => const _CoinsBody(),
    footer: Builder(
      builder: (c) => AppButton(
        gu ? 'પત્યું' : 'Done',
        variant: BtnVariant.secondary,
        block: true,
        onTap: () => Navigator.of(c).maybePop(),
      ),
    ),
  );
}

class _CoinsBody extends StatefulWidget {
  const _CoinsBody();

  @override
  State<_CoinsBody> createState() => _CoinsBodyState();
}

class _CoinsBodyState extends State<_CoinsBody> {
  late final TextEditingController _coinsCtrl;

  @override
  void initState() {
    super.initState();
    final s = StateScope.read(context);
    _coinsCtrl = TextEditingController(
      text: s.coinMode == 'custom' ? s.flow.coinCustom : '',
    );
  }

  @override
  void dispose() {
    _coinsCtrl.dispose();
    super.dispose();
  }

  void _selectMode(AppState state, String mode) {
    state.setCoinMode(mode);
    state.setUseCoins(true);
  }

  void _apply(AppState state, CartTotals t) {
    final requested = int.tryParse(_coinsCtrl.text.trim()) ?? 0;
    final usable = t.balance < t.cap ? t.balance : t.cap;
    if (requested <= 0) {
      showToast('Enter how many coins to use', 'error');
      return;
    }
    if (usable <= 0) {
      showToast('No coins can be used on this order', 'error');
      return;
    }
    final coins = requested < usable ? requested : usable;
    state.setCoinMode('custom');
    state.setCoinCustom('$coins');
    state.setUseCoins(true);
    _coinsCtrl.text = '$coins';
    showToast('${coins} coins applied · save ${money(coins * t.coinValue)}');
  }

  void _stopCoins(AppState state) {
    state.setUseCoins(false);
    Navigator.of(context).maybePop();
    showToast('Coins removed from this order');
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final t = state.cartTotals();
    final cap = t.balance < t.cap ? t.balance : t.cap;
    final pct = ((t.balance * state.flow.coinPercent) / 100).floor();
    final percent = pct < t.cap ? pct : t.cap;
    final coupon = t.coupon?.coupon;
    final couponLabel =
        (coupon != null && coupon.code.isNotEmpty) ? coupon.code : 'This coupon';
    final customSelected = state.coinMode == 'custom';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `.coins-panel` summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFAEC), AppColors.goldTint],
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFF8E4A5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child:
                      AppIcon('coin', size: 19, color: AppColors.gold, sw: 1.9),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gu ? '${t.coinsUsed} કોઈન્સ લાગુ' : '${t.coinsUsed} coins applied',
                      style: _ts(gu, size: 13, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      gu
                          ? 'માન્ય કિંમત ${money(t.eligibleBase)} · આ ઓર્ડર પર ${t.cap} કોઈન્સ સુધી વાપરી શકાય.'
                          : 'Eligible value ${money(t.eligibleBase)} · up to ${t.cap} coins can be used on this order.',
                      style: _ts(gu,
                          size: 12.5,
                          w: FontWeight.w600,
                          color: AppColors.goldInk,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (!t.canUseCoins) ...[
          const SizedBox(height: 12),
          _note(
            gu
                ? '$couponLabel કોઈન્સ સાથે વાપરી શકાય નહીં. કોઈન્સ વાપરવા માટે કૂપન દૂર કરો.'
                : '$couponLabel can’t be combined with coins. Remove the coupon to use coins.',
            gu,
            error: true,
          ),
        ],

        if (t.cap <= 0) ...[
          const SizedBox(height: 12),
          _note(
            gu
                ? 'આ કાર્ટની કોઈ વસ્તુ કોઈન્સ સ્વીકારતી નથી. ચા અને તેલ જેવી વસ્તુઓ કોઈન્સથી ચૂકવી શકાય નહીં.'
                : 'None of the items in this cart accept coins. Items like tea and oil can’t be paid for with coins.',
            gu,
          ),
        ] else ...[
          const SizedBox(height: 12),
          SheetOption(
            title: gu ? 'મારા બધા કોઈન્સ વાપરો' : 'Use all my coins',
            sub: '$cap coins · save ${money(cap)}',
            selected: state.coinMode == 'all',
            onTap: () => _selectMode(state, 'all'),
          ),
          SheetOption(
            title: gu
                ? '${state.flow.coinPercent}% કોઈન્સ વાપરો'
                : 'Use ${state.flow.coinPercent}% of my coins',
            sub: '$percent coins · save ${money(percent)}',
            selected: state.coinMode == 'percent',
            onTap: () => _selectMode(state, 'percent'),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectMode(state, 'custom'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: customSelected ? AppColors.redTint : AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: customSelected ? AppColors.red : AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gu ? 'રકમ પસંદ કરો' : 'Choose an amount',
                              style: _ts(gu, size: 14, w: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              gu
                                  ? 'વધુમાં વધુ $cap કોઈન્સ'
                                  : 'Up to $cap coins',
                              style: _ts(gu,
                                  size: 11.5,
                                  w: FontWeight.w600,
                                  color: AppColors.ink2),
                            ),
                          ],
                        ),
                      ),
                      AppRadio(
                        selected: customSelected,
                        onTap: () => _selectMode(state, 'custom'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppField(
                          controller: _coinsCtrl,
                          numeric: true,
                          maxLength: 6,
                          placeholder:
                              gu ? 'વાપરવાના કોઈન્સ' : 'Coins to use',
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        gu ? 'લાગુ કરો' : 'Apply',
                        size: BtnSize.sm,
                        onTap: () => _apply(state, t),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (state.useCoins && t.coinsUsed > 0) ...[
            const SizedBox(height: 12),
            AppButton(
              gu ? 'આ ઓર્ડર પર કોઈન્સ વાપરશો નહીં' : 'Don’t use coins on this order',
              variant: BtnVariant.soft,
              block: true,
              onTap: () => _stopCoins(state),
            ),
          ],
        ],

        const SizedBox(height: 12),
        _note(
          gu
              ? '1 કોઈન = ₹1. પહેલા કૂપનની છૂટ લાગુ થાય, પછી ફક્ત માન્ય વસ્તુઓ પર કોઈન્સ વપરાય. ઓર્ડર કરતાં જ કોઈન્સ કપાઈ જાય.'
              : '1 coin = ₹1. A coupon discount is applied first, then coins against eligible items only. Coins are deducted immediately when you place the order.',
          gu,
        ),
      ],
    );
  }
}

/// `.sheet__note` / `.sheet__error` — tinted info box inside a sheet.
Widget _note(String text, bool gu, {bool error = false}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? AppColors.redTint : AppColors.navyTint,
      borderRadius: BorderRadius.circular(error ? 12 : 14),
    ),
    child: Text(
      text,
      style: error
          ? _ts(gu, size: 12.5, w: FontWeight.w700, color: AppColors.red, height: 1.5)
          : _ts(gu, size: 12.5, w: FontWeight.w600, color: AppColors.navy, height: 1.5),
    ),
  );
}

/// Bilingual text style — Gujarati falls back to the Hind Vadodara family.
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
