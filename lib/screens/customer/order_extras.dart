import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto_ops.dart';
import '../../data/models.dart';
import '../../data/razorpay_checkout.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/toast.dart';
import 'sheets/cancel_order_sheet.dart';

TextStyle _t(bool gu, double size, FontWeight w, Color c) => gu
    ? AppTheme.guj(size: size, w: w, color: c)
    : TextStyle(
        fontFamily: AppTheme.uiFont, fontSize: size, fontWeight: w, color: c);

BoxDecoration _card(Color bg, {Color? border}) => BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg, AppColors.white]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (border ?? AppColors.line).withValues(alpha: .5)),
      boxShadow: [
        BoxShadow(
            color: (border ?? AppColors.ink3).withValues(alpha: .14),
            offset: const Offset(0, 8),
            blurRadius: 20),
      ],
    );

String _mmss(Duration d) {
  final m = d.inMinutes;
  final sec = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

/// An ONLINE order in backend `PAYMENT_PENDING`: the server is waiting for the
/// Razorpay payment. The only truth is `GET /orders/{id}` (the SDK callback is
/// never trusted), so "Pay now" reopens Checkout with the order's own
/// `paymentSession` and then waits for the server to confirm.
class PayPendingCard extends StatefulWidget {
  const PayPendingCard({super.key, required this.order});

  final Order order;

  @override
  State<PayPendingCard> createState() => _PayPendingCardState();
}

class _PayPendingCardState extends State<PayPendingCard> {
  bool _busy = false;
  String? _note;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Re-render once a second while a payment deadline is counting down.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.order.paymentExpiresAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Time left to pay (`paymentExpiresAt`), null when the server sent none.
  Duration? get _left {
    final e = widget.order.paymentExpiresAt;
    if (e == null) return null;
    final d = e.difference(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));
    return d.isNegative ? Duration.zero : d;
  }

  Future<void> _pay() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    final msg = await StateScope.read(context).payOrderOnline(widget.order.number);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = msg;
    });
    if (msg == null) showToast('Payment confirmed', 'success');
  }

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    final o = widget.order;
    final hasSession = o.paySession != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(AppColors.goldTint, border: AppColors.gold2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            gu ? 'ચુકવણી બાકી' : 'Payment pending',
            style: _t(gu, 15, FontWeight.w800, AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            _busy
                ? (gu
                    ? 'ચુકવણીની પુષ્ટિ થઈ રહી છે…'
                    : 'Confirming your payment…')
                : hasSession
                    ? (gu
                        ? 'ઓર્ડર ચુકવણી પછી જ દુકાન સુધી પહોંચે છે. સમયસર ચૂકવણી ન થાય તો ઓર્ડર આપમેળે રદ થશે.'
                        : 'The shop receives this order once it is paid. '
                            'Unpaid orders are cancelled automatically.')
                    : (gu
                        ? 'ચુકવણીનો સમય પૂરો થયો અથવા નિષ્ફળ ગઈ. ઓર્ડર ટૂંક સમયમાં રદ થશે.'
                        : 'Payment expired or failed. This order will be cancelled shortly.'),
            style: _t(gu, 12, FontWeight.w600, AppColors.ink2),
          ),
          if (_left != null) ...[
            const SizedBox(height: 8),
            Text(
              _left == Duration.zero
                  ? (gu ? 'ચુકવણીનો સમય પૂરો થયો' : 'Time to pay has run out')
                  : (gu
                      ? 'ચૂકવવા માટે બાકી સમય ${_mmss(_left!)}'
                      : 'Pay within ${_mmss(_left!)}'),
              style: _t(gu, 13, FontWeight.w800,
                  _left! < const Duration(minutes: 2)
                      ? AppColors.red
                      : AppColors.ink),
            ),
          ],
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(_note!, style: _t(gu, 12, FontWeight.w700, AppColors.red)),
          ],
          const SizedBox(height: 12),
          if (hasSession && RazorpayCheckout.supported)
            AppButton(
              gu ? 'હમણાં ચૂકવો' : 'Pay now',
              block: true,
              loading: _busy,
              onTap: _pay,
            ),
          if (AppState.customerCanCancel(o)) ...[
            const SizedBox(height: 8),
            AppButton(
              gu ? 'ઓર્ડર રદ કરો' : 'Cancel order',
              variant: BtnVariant.dangerSoft,
              block: true,
              disabled: _busy,
              onTap: () => showCancelOrderSheet(context, o),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Refund on its way" for a cancelled order whose online payment was queued
/// for refund (`status` CANCELLED + `paymentStatus` REFUNDED).
class RefundNote extends StatelessWidget {
  const RefundNote({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card(AppColors.greenTint, border: AppColors.green),
      child: Text(
        gu
            ? 'રિફંડ રસ્તામાં છે — તમારી ચુકવણી પદ્ધતિમાં પરત આવશે.'
            : 'Refund on its way — it returns to your original payment method.',
        style: _t(gu, 13, FontWeight.w700, AppColors.green),
      ),
    );
  }
}

/// Goods the shop recorded as returned on this order (`GET /orders/{id}/returns`)
/// with the refund and coin adjustments. Customers cannot start a return in
/// the app; the shop does it after delivery. Renders nothing while there are
/// none.
class OrderReturnsCard extends StatefulWidget {
  const OrderReturnsCard({super.key, required this.order});

  final Order order;

  @override
  State<OrderReturnsCard> createState() => _OrderReturnsCardState();
}

class _OrderReturnsCardState extends State<OrderReturnsCard> {
  List<OrderReturnDto> _returns = const [];
  String? _loadedFor;

  Future<void> _load(String id) async {
    try {
      final r = await Api.instance.orders.listReturns(id);
      if (mounted) setState(() => _returns = r);
    } on ApiException {
      // Optional section: stay hidden.
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final o = widget.order;
    final id = state.orderIdsByNo[o.number];
    final key = '$id|${o.status}|${o.updatedAt.millisecondsSinceEpoch}';
    if (id != null &&
        id.isNotEmpty &&
        (o.status == 'Delivered' || o.status == 'Picked Up') &&
        _loadedFor != key) {
      _loadedFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(id));
    }
    if (_returns.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _card(AppColors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gu ? 'પરત કરેલ સામાન' : 'Returned items',
                style: _t(gu, 14, FontWeight.w800, AppColors.ink)),
            for (final r in _returns) ...[
              const SizedBox(height: 10),
              Text(r.reason,
                  style: _t(gu, 13, FontWeight.w700, AppColors.ink)),
              for (final it in r.items)
                Text('${it.qty} × ${it.name}',
                    style: _t(gu, 12, FontWeight.w600, AppColors.ink3)),
              const SizedBox(height: 2),
              Text(
                _refundText(r, gu),
                style: _t(gu, 12, FontWeight.w700, AppColors.green),
              ),
              if (r.couponClawbackPaise > 0)
                Text(
                  gu
                      ? 'કૂપન લાભ પાછો લીધો: ${money(r.couponClawbackPaise / 100)}'
                      : 'Coupon benefit taken back: ${money(r.couponClawbackPaise / 100)}',
                  style: _t(gu, 11.5, FontWeight.w600, AppColors.ink3),
                ),
              if (r.coinsRestored > 0 || r.coinsClawedBack > 0)
                Text(
                  [
                    if (r.coinsRestored > 0)
                      '${r.coinsRestored} ${gu ? 'સિક્કા પરત' : 'coins returned'}',
                    if (r.coinsClawedBack > 0)
                      '${r.coinsClawedBack} ${gu ? 'સિક્કા પાછા લીધા' : 'earned coins taken back'}',
                  ].join(' · '),
                  style: _t(gu, 11.5, FontWeight.w600, AppColors.ink3),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _refundText(OrderReturnDto r, bool gu) {
    final amt = money(r.refundPaise / 100);
    switch (r.refundMode) {
      case 'ONLINE':
        return gu
            ? 'રિફંડ $amt — તમારી ચુકવણી પદ્ધતિમાં'
            : 'Refund $amt — to your payment method';
      case 'CASH':
        return gu ? 'રિફંડ $amt — દુકાન પર રોકડ' : 'Refund $amt — cash from the shop';
      default:
        return gu ? 'કોઈ રિફંડ નથી' : 'No refund';
    }
  }
}
