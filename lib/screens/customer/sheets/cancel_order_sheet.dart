import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/sheet.dart';
import '../../../widgets/toast.dart';

/// §3.14 `Cancel order?` — localized reasons, refund note and confirmation.
const _reasonGu = {
  'Changed my mind': 'મન બદલાઈ ગયું',
  'Ordered by mistake': 'ભૂલથી ઓર્ડર કર્યું',
  'Need a different address': 'બીજું સરનામું જોઈએ',
  'Found a better price': 'વધુ સારી કિંમત મળી',
};

void showCancelOrderSheet(BuildContext context, Order order) {
  final gu = StateScope.read(context).lang == 'gu';
  final pickup = order.mode == 'pickup';

  showAppSheet<void>(
    context: context,
    title: gu ? 'ઓર્ડર રદ કરવો છે?' : 'Cancel order?',
    sub: '${order.number} · ${pickup ? (gu ? 'સ્ટોર પિકઅપ' : 'Store pickup') : (gu ? 'હોમ ડિલિવરી' : 'Home delivery')}',
    builder: (ctx) => _CancelBody(order: order),
  );
}

class _CancelBody extends StatefulWidget {
  const _CancelBody({required this.order});

  final Order order;

  @override
  State<_CancelBody> createState() => _CancelBodyState();
}

class _CancelBodyState extends State<_CancelBody> {
  String _reason = 'Changed my mind';

  /// True while `POST /orders/{id}/cancel` is in flight — the backend owns
  /// the transition, so the button waits for it instead of closing first.
  bool _busy = false;

  bool get _prepaid =>
      widget.order.payment == 'UPI / Card' &&
      widget.order.paymentState == 'Paid';

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await StateScope.read(context)
        .cancelOrder(widget.order.number, _reason, 'customer');
    if (!mounted) return;
    setState(() => _busy = false);
    if (res != null && !res.ok) {
      // Stay on the sheet: the refusal (e.g. packing has started) belongs
      // right here, and closing would make it look like the cancel worked.
      showToast(res.message, 'error');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
    if (res != null) showToast(res.message);
  }

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    final order = widget.order;
    // Mirrors the backend's `customerCanCancel`: cancellable until the shop
    // starts packing.
    final cancellable = AppState.customerCanCancel(order);

    final intro = gu
        ? 'રદ કરવાનું કારણ જણાવો.${cancellable ? ' સ્ટોર પેકિંગ શરૂ ન કરે ત્યાં સુધી ઓર્ડર રદ કરી શકાય છે.' : ''}'
        : 'Tell us why you’re cancelling.${cancellable ? ' You can cancel until the store starts packing.' : ''}';

    final note = StringBuffer();
    if (order.coinsUsed > 0) {
      note.write(gu
          ? '${order.coinsUsed} કોઈન્સ તમારા વોલેટમાં પાછા મળશે. '
          : '${order.coinsUsed} coins used on this order will be returned to your wallet. ');
    }
    if (_prepaid) {
      note.write(gu
          ? 'તમારી પ્રીપેઇડ રકમ 3–5 કાર્યકારી દિવસમાં પરત મળશે. '
          : 'Your prepaid amount will be refunded in 3–5 working days. ');
    }
    note.write(gu
        ? 'સ્ટોક તરત જ દુકાનમાં પાછો ઉમેરાય છે.'
        : 'Stock is released back to the store immediately.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          intro,
          style: _ts(gu,
              size: 13.5, w: FontWeight.w600, color: AppColors.ink2, height: 1.5),
        ),
        const SizedBox(height: 8),
        for (final reason in AppState.cancelReasons)
          SheetOption(
            title: gu ? (_reasonGu[reason] ?? reason) : reason,
            selected: _reason == reason,
            onTap: () => setState(() => _reason = reason),
          ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.navyTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIcon('info', size: 16, color: AppColors.navy, sw: 2),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  note.toString(),
                  style: _ts(gu,
                      size: 12.5,
                      w: FontWeight.w600,
                      color: AppColors.navy,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          gu ? 'ઓર્ડર રદ કરો' : 'Cancel order',
          variant: BtnVariant.dangerSoft,
          block: true,
          loading: _busy,
          onTap: _confirm,
        ),
        const SizedBox(height: 10),
        AppButton(
          gu ? 'ઓર્ડર રાખો' : 'Keep my order',
          variant: BtnVariant.secondary,
          block: true,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
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
