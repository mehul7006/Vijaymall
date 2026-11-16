import 'package:flutter/material.dart';

import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/sheet.dart';

/// §3.14 `How coins work` — earning, redemption and expiry explainer.
void showHowCoinsSheet(BuildContext context) {
  final AppState state = StateScope.read(context);
  final gu = state.lang == 'gu';
  final best = state.bestEarnRule(1000);
  final rate = best.coins > 0 ? best.coins : 10;

  showAppSheet<void>(
    context: context,
    title: gu ? 'કોઈન્સ કેવી રીતે ચાલે' : 'How coins work',
    sub: gu ? 'સરળ રિવોર્ડ લૂપ' : 'A simple rewards loop',
    builder: (ctx) => _HowCoinsBody(rate: rate),
    footer: Builder(
      builder: (c) => AppButton(
        gu ? 'સમજાયું' : 'Got it',
        block: true,
        onTap: () => Navigator.of(c).maybePop(),
      ),
    ),
  );
}

class _HowCoinsBody extends StatelessWidget {
  const _HowCoinsBody({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    final AppState state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final expiry = state.coinSettings.expiryMonths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _card(
          gu,
          'coin',
          gu ? 'કમાણી' : 'Earning',
          gu
              ? 'ડિલિવર અને પિકઅપ થયેલા ઓર્ડર પર કોઈન્સ કમાઓ. શ્રેષ્ઠ સક્રિય નિયમ આપોઆપ લાગુ થાય — એકથી વધુ નિયમ લાગુ ન થાય. ₹1,000ના ઓર્ડર પર માનક દરે 10 કોઈન્સ મળે.'
              : 'Earn coins on delivered and picked-up orders. The best active rule is applied automatically — no stacking. A ₹1,000 order earns 10 coins at the standard rate.',
          preview: gu
              ? 'હાલનો દર: ₹1,000 ખર્ચો → $rate કોઈન્સ મેળવો, પ્રમાણસર.'
              : 'Current rate: spend ₹1,000 → earn $rate coins, pro-rata.',
        ),
        const SizedBox(height: 12),
        _card(
          gu,
          'cart',
          gu ? 'રિડેમ્પ્શન' : 'Redemption',
          gu
              ? '1 કોઈન = ₹1. ફક્ત માન્ય વસ્તુઓ પર, કૂપનની છૂટ પછી કોઈન્સ વાપરો. ચા અને તેલ જેવી કેટલીક વસ્તુઓ કોઈન્સ લેતી નથી. દરેક ઓર્ડરની મર્યાદા હોય છે.'
              : '1 coin = ₹1. Use coins only on eligible products, after any coupon discount. Some items such as tea and oil do not accept coins. Each order has a per-order cap.',
        ),
        const SizedBox(height: 12),
        _card(
          gu,
          'clock',
          gu ? 'માન્યતા અને રદ' : 'Expiry & cancellations',
          gu
              ? 'કોઈન્સ ડિલિવરી કે પિકઅપ પછી જમા થાય અને $expiry મહિના પછી રદ થાય. પહેલાના કોઈન્સ પહેલા વપરાય. ઓર્ડર રદ થાય તો વપરાયેલા કોઈન્સ પાછા મળે અને બાકીના પેન્ડિંગ કોઈન્સ દૂર થાય.'
              : 'Coins are credited after delivery or pickup and expire after $expiry months. Oldest coins are used first. If an order is cancelled, redeemed coins are returned and pending coins are removed.',
        ),
      ],
    );
  }
}

/// `.card.card--pad` explainer card with an inline icon title.
Widget _card(bool gu, String icon, String title, String body,
    {String? preview}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
      boxShadow: AppColors.sh1,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: AppIcon(icon, size: 16, color: AppColors.red, sw: 2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: _ts(gu, size: 15, w: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: _ts(gu,
              size: 13, w: FontWeight.w600, color: AppColors.ink2, height: 1.5),
        ),
        if (preview != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              preview,
              style: _ts(gu,
                  size: 12.5,
                  w: FontWeight.w700,
                  color: AppColors.goldInk,
                  height: 1.4),
            ),
          ),
        ],
      ],
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
