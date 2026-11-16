/// Typed error raised by every API call so screens can branch on
/// [statusCode] and show [message] without parsing raw HTTP.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Object? payload;

  /// `traceId` from the error envelope / `X-Trace-Id` header. Show it on
  /// generic failure screens ("Something went wrong (ref abc123)").
  final String? traceId;

  /// `details.fields` of a validation error: request field name -> message.
  /// Forms use it to highlight the offending inputs.
  final Map<String, String> fields;

  /// `Retry-After` response header (seconds) when the server sent one (every
  /// 429 does; same value as `details.retryAfterSeconds`).
  final int? retryAfterHeader;

  const ApiException(
    this.statusCode,
    this.message, {
    this.code,
    this.payload,
    this.traceId,
    this.fields = const <String, String>{},
    this.retryAfterHeader,
  });

  /// Field errors of the most recent validation failure (400/422 with
  /// `details.fields`), recorded by the API client. A form clears it before
  /// saving ([clearFields]) and reads it after a failure ([takeFields]) to
  /// highlight the offending inputs.
  static Map<String, String> _lastFields = const <String, String>{};

  static void recordFields(Map<String, String> f) => _lastFields = f;
  static void clearFields() => _lastFields = const <String, String>{};
  static Map<String, String> takeFields() {
    final f = _lastFields;
    _lastFields = const <String, String>{};
    return f;
  }

  /// Picks the first message whose backend field name is in [names]
  /// (case-insensitive, also matches `a.b.name` suffixes).
  static String? fieldError(Map<String, String> f, List<String> names) {
    for (final e in f.entries) {
      final k = e.key.toLowerCase();
      for (final n in names) {
        final l = n.toLowerCase();
        if (k == l || k.endsWith('.$l') || k.startsWith('$l[')) {
          return e.value;
        }
      }
    }
    return null;
  }

  /// 429 RATE_LIMITED: wait, never auto-retry in a loop.
  bool get isRateLimited => statusCode == 429;

  /// 503: a provider (SMS, payment) is not set up or is down.
  bool get isProviderUnavailable => statusCode == 503 && code != 'SERVICE_BUSY';

  /// 503 `SERVICE_BUSY`: the server is briefly overloaded (retry shortly),
  /// not a feature that is switched off.
  bool get isServiceBusy => code == 'SERVICE_BUSY';

  /// 5xx or transport failure: a generic "Something went wrong" case.
  bool get isGeneric => statusCode == 0 || statusCode >= 500;

  /// Message plus the support reference, for generic failure screens/toasts.
  String get messageWithRef {
    final t = traceId;
    if (t == null || t.isEmpty || !(statusCode >= 500)) return message;
    if (message.contains('(ref ')) return message;
    return '$message (ref $t)';
  }

  /// The backend's `details` object (`{}` when empty), or null.
  Map<String, dynamic>? get details {
    final p = payload;
    if (p is Map && p['details'] is Map) {
      return Map<String, dynamic>.from(p['details'] as Map);
    }
    return null;
  }

  /// `details.retryAfterSeconds` of a 429 `RATE_LIMITED`.
  int? get retryAfterSeconds {
    final v = details?['retryAfterSeconds'];
    final fromBody = v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    return fromBody ?? retryAfterHeader;
  }

  /// `details.reason` of a 422 `OTP_INVALID` / `COUPON_INVALID`
  /// (`EXPIRED`, `LOCKED`, `WRONG`, ...).
  String? get reason => details?['reason']?.toString();

  /// A customer-facing message for the auth errors the guide tells the UI to
  /// branch on (`OTP_INVALID`, `RATE_LIMITED`, `SMS_NOT_CONFIGURED`, blocked
  /// account); every other error keeps the server's [message].
  String get authMessage {
    // The backend now words OTP failures itself (wrong / expired / too many
    // attempts / "Try again in N seconds"): show that text as it is.
    if ((code == 'OTP_INVALID' || code == 'RATE_LIMITED') &&
        message.trim().isNotEmpty &&
        !message.startsWith('Something went wrong (')) {
      return message.trim();
    }
    switch (code) {
      case 'OTP_INVALID':
        switch (reason) {
          case 'WRONG':
            return 'Wrong code, please try again.';
          case 'LOCKED':
            return 'Too many wrong tries. Request a new code.';
          case 'EXPIRED':
            return 'This code has expired. Request a new code.';
        }
        return 'That code is not valid. Request a new code.';
      case 'RATE_LIMITED':
        final s = retryAfterSeconds;
        if (s == null || s <= 0) {
          return 'Too many attempts. Please wait a little and try again.';
        }
        final wait = s >= 120 ? '${(s / 60).ceil()} minutes' : '$s seconds';
        return 'Too many attempts. Try again in $wait.';
      case 'SMS_NOT_CONFIGURED':
        return 'Mobile sign-in is not available right now. Please use email.';
    }
    if (statusCode == 403) {
      return 'This account has been blocked. Please contact the shop.';
    }
    return message;
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 400 || statusCode == 422;
  bool get isNetwork => statusCode == 0;

  /// True when the token could not be refreshed and the user must sign in again.
  bool get needsAuth => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when a required JWT is missing (never sent a request).
class NotAuthenticatedException extends ApiException {
  const NotAuthenticatedException()
      : super(401, 'Please sign in to continue.', code: 'NO_TOKEN');
}
