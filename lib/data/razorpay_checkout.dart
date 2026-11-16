/// Razorpay Checkout launcher with **zero native plugins**.
///
/// The web build drives Razorpay's `checkout.js` through `dart:js_interop`
/// (the script tag lives in `web/index.html`). Native builds fall back to
/// `razorpay_checkout_stub.dart`, which reports "unsupported" so checkout
/// never offers an online option the device cannot complete (add
/// `razorpay_flutter` and implement [RazorpayCheckout.open] there to enable
/// it on Android / iOS).
library;

export 'razorpay_checkout_stub.dart'
    if (dart.library.js_interop) 'razorpay_checkout_web.dart';

/// How a Checkout attempt ended. A `success` only means the SDK finished:
/// the order is paid when the server says so (`GET /orders/{id}`).
enum RazorpayOutcome { success, dismissed, failed, unsupported }
