import 'razorpay_checkout.dart';

/// Native fallback: no Razorpay SDK is bundled.
class RazorpayCheckout {
  RazorpayCheckout._();

  /// False when this build cannot open Razorpay Checkout.
  static bool get supported => false;

  static Future<RazorpayOutcome> open({
    required String keyId,
    required String razorpayOrderId,
    required int amountPaise,
    String currency = 'INR',
    String name = '',
    String? prefillName,
    String? prefillContact,
    String? prefillEmail,
  }) async =>
      RazorpayOutcome.unsupported;
}
