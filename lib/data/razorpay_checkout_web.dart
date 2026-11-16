import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'razorpay_checkout.dart';

@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
}

@JS('Razorpay')
external JSAny? get _razorpayGlobal;

/// Razorpay `checkout.js` bound with `dart:js_interop`.
class RazorpayCheckout {
  RazorpayCheckout._();

  /// True once `checkout.js` has loaded on the page.
  static bool get supported {
    try {
      return _razorpayGlobal != null;
    } catch (_) {
      return false;
    }
  }

  /// Opens Checkout for the server's `paymentSession` values. The app must
  /// still wait for the server (SSE / `GET /orders/{id}`) to learn the order
  /// is paid; the success callback is never proof of payment.
  static Future<RazorpayOutcome> open({
    required String keyId,
    required String razorpayOrderId,
    required int amountPaise,
    String currency = 'INR',
    String name = '',
    String? prefillName,
    String? prefillContact,
    String? prefillEmail,
  }) {
    final done = Completer<RazorpayOutcome>();
    void finish(RazorpayOutcome o) {
      if (!done.isCompleted) done.complete(o);
    }

    try {
      if (!supported) return Future.value(RazorpayOutcome.unsupported);
      final options = <String, Object?>{
        'key': keyId,
        'order_id': razorpayOrderId,
        'amount': amountPaise,
        'currency': currency,
        'name': name,
        'prefill': {
          if ((prefillName ?? '').isNotEmpty) 'name': prefillName,
          if ((prefillContact ?? '').isNotEmpty) 'contact': prefillContact,
          if ((prefillEmail ?? '').isNotEmpty) 'email': prefillEmail,
        },
      }.jsify() as JSObject;
      options['handler'] = ((JSAny? _) => finish(RazorpayOutcome.success)).toJS;
      options['modal'] = <String, Object?>{}.jsify();
      (options['modal'] as JSObject)['ondismiss'] =
          (() => finish(RazorpayOutcome.dismissed)).toJS;
      final rzp = _Razorpay(options);
      // A failed attempt keeps the modal open so the shopper can retry; the
      // server records it. The modal closing is what ends this call.
      rzp.open();
    } catch (_) {
      finish(RazorpayOutcome.failed);
    }
    return done.future;
  }
}
