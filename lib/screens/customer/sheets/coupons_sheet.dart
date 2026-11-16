import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/api/api_config.dart';
import '../../../data/api/dto.dart';
import '../../../data/models.dart';
import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/fields.dart';
import '../../../widgets/sheet.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/toast.dart';

/// §3.14 `Coupons & offers` — apply a code, remove the current one and pick
/// from the live offers. Opening the sheet clears the inline message.
void showCouponsSheet(BuildContext context) {
  // Refresh the public offers (`GET /coupons`) on every open: a code can
  // expire or a new one can start between two visits, and the sheet should
  // never list a row the backend would refuse. Non-blocking — the sheet
  // paints with whatever is loaded and updates when the response lands.
  final st = StateScope.read(context);
  if (ApiConfig.isLive && !st.isBackendAdmin) {
    unawaited(st.loadPublicOffers());
    unawaited(st.loadCouponOptions());
  }
  showAppSheet<void>(
    context: context,
    title: 'Coupons & offers',
    sub: 'Discounts are applied before your coins',
    builder: (ctx) => const _CouponsBody(),
    onRefresh: () async {
      if (ApiConfig.isLive && !st.isBackendAdmin) {
        await st.loadPublicOffers();
        await st.loadCouponOptions();
      }
    },
    footer: Builder(
      builder: (c) => AppButton(
        'Done',
        variant: BtnVariant.secondary,
        block: true,
        onTap: () => Navigator.of(c).maybePop(),
      ),
    ),
  );
}

class _CouponsBody extends StatefulWidget {
  const _CouponsBody();

  @override
  State<_CouponsBody> createState() => _CouponsBodyState();
}

class _CouponsBodyState extends State<_CouponsBody> {
  final _code = TextEditingController();
  String _msg = '';

  /// True while a code is being validated against the store, so the Apply
  /// button shows a spinner instead of letting the user double-submit.
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Server-first apply: listing an offer only proves the code exists, so
  /// `POST /cart/quote` is what proves it is usable *for this basket*.
  Future<void> _apply(AppState st) async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _msg = 'Enter a coupon code.');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = '';
    });
    final error = await st.applyCouponFromServer(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      setState(() => _msg = error);
      return;
    }
    final saved = st.cartTotals().discount;
    Navigator.of(context).maybePop();
    showToast(
        'Coupon ${code.toUpperCase()} applied · saved ${money(saved)}');
  }

  Future<void> _useOffer(AppState st, Coupon c) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = '';
    });
    final error = await st.applyCouponFromServer(c.code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      // Ineligible: surface the reason inside the sheet instead of applying.
      setState(() => _msg = error);
      return;
    }
    final saved = st.cartTotals().discount;
    Navigator.of(context).maybePop();
    showToast('Coupon ${c.code} applied · saved ${money(saved)}');
  }

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    final gu = st.lang == 'gu';
    final t = st.cartTotals();
    final applied = st.cartCoupon.isNotEmpty && t.couponOk;
    final offers =
        st.coupons.where((c) => st.couponDateStatus(c) == 'active').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `.coupon-row` — the coupon currently on the cart.
        if (applied)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(17),
              boxShadow: AppColors.sh1,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.redTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: AppIcon('ticket',
                        size: 16, color: AppColors.red),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${st.cartCoupon} applied',
                        style: _ts(gu, size: 13.5, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You saved ${money(t.discount)}',
                        style: _ts(gu,
                            size: 11.5,
                            w: FontWeight.w600,
                            color: AppColors.ink2,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    st.clearCoupon();
                    showToast('Coupon removed');
                  },
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 64, minHeight: 44),
                    child: Center(
                      child: Text(
                        'Remove',
                        style: _ts(gu,
                            size: 12.5,
                            w: FontWeight.w800,
                            color: AppColors.red),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Apply form: label + input + primary sm Apply.
        const SizedBox(height: 12),
        Text(
          'Coupon code',
          style: TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: AppField(
                controller: _code,
                uppercase: true,
                placeholder: 'Coupon code',
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              'Apply',
              size: BtnSize.sm,
              loading: _busy,
              onTap: () => _apply(st),
            ),
          ],
        ),
        if (_msg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.redTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _msg,
              style: _ts(gu,
                  size: 12.5, w: FontWeight.w700, color: AppColors.red),
            ),
          ),
        ],

        // `Live offers` head.
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Live offers',
                style: _ts(gu, size: 14, w: FontWeight.w800),
              ),
            ),
            Text(
              '${offers.length} available',
              style: _ts(gu, size: 12, w: FontWeight.w600,
                  color: AppColors.ink2),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (offers.isEmpty)
          (ApiConfig.isLive && st.backendMode)
              ? LoadingOrElse(
                  seconds: 4,
                  skeleton: const ListSkeleton(count: 2, rowHeight: 68),
                  fallback: _note(
                    'No live offers are running right now. You can still apply any '
                    'code above — it is checked against the store before the '
                    'discount is added.',
                    gu,
                  ),
                )
              : _note(
                  'No live offers are running right now. You can still apply any '
                  'code above — it is checked against the store before the '
                  'discount is added.',
                  gu,
                ),
        for (var i = 0; i < offers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _OfferRow(
            coupon: offers[i],
            eligible: st.couponCheck(offers[i].code, t.details),
            option: st.couponOptions[offers[i].code.toUpperCase()],
            gu: gu,
            busy: _busy,
            onTap: () => _useOffer(st, offers[i]),
          ),
        ],

        // `.sheet__note`.
        const SizedBox(height: 12),
        _note(
          'Coupons apply to the eligible item value. Coins can be combined '
          'unless the offer says otherwise. Minimum cart value is checked '
          'before the discount.',
          gu,
        ),

        if (st.cartCoupon.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppButton(
            'Remove coupon',
            variant: BtnVariant.soft,
            block: true,
            onTap: () {
              st.clearCoupon();
              showToast('Coupon removed');
            },
          ),
        ],
      ],
    );
  }
}

/// `.sheet-offer` — one live offer row (dashed card, icon, code, saving).
class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.coupon,
    required this.eligible,
    required this.gu,
    required this.onTap,
    this.busy = false,
    this.option,
  });

  final Coupon coupon;
  final CouponResult eligible;

  /// Server preview for this cart (`POST /cart/coupons`); wins over the
  /// device-side [eligible] check when present.
  final CouponOptionDto? option;
  final bool gu;
  final VoidCallback onTap;

  /// A code is being validated — dim the row so it can't be double-tapped.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final ok = o != null ? o.applicable : eligible.ok;
    final detail = o != null
        ? (ok
            ? '${coupon.desc} · ${gu ? 'તમે બચાવો' : 'You save'} ${money(o.discountPaise / 100)}'
                '${o.appliesToText.isNotEmpty ? ' · ${o.appliesToText}' : ''}'
                '${o.coveredLines.isNotEmpty ? '\n${gu ? 'આ વસ્તુઓ પર' : 'On'}: ${o.coveredLines.map((l) => l.name).take(3).join(', ')}${o.coveredLines.length > 3 ? ' +${o.coveredLines.length - 3}' : ''}' : ''}'
            : '${coupon.desc} · ${(o.message ?? '').isNotEmpty ? o.message : eligible.message}')
        : ok
            ? '${coupon.desc} · Save ${money(eligible.discount)}'
            : '${coupon.desc} · ${eligible.message}';

    return Opacity(
      opacity: busy ? .6 : (ok ? 1 : .72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A coupon the server says does not apply to this cart is disabled.
        onTap: (o != null && !ok) ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: const Color(0xFFD9DCEA)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.redTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: AppIcon(
                    coupon.type == 'percent' ? 'percent' : 'ticket',
                    size: 17,
                    color: AppColors.red,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.code,
                      style: _ts(gu, size: 14, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(gu,
                          size: 11.5,
                          w: FontWeight.w600,
                          color: AppColors.ink2,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppIcon(ok ? 'right' : 'info',
                  size: ok ? 15 : 14, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.sheet__note` — tinted info box inside the sheet.
Widget _note(String text, bool gu) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.navyTint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: _ts(gu,
          size: 12,
          w: FontWeight.w600,
          color: AppColors.navy,
          height: 1.55),
    ),
  );
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
