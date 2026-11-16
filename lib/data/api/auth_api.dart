import 'api_client.dart';
import 'dto.dart';
import 'session_store.dart';

/// `/api/v1/auth/*` plus the `/api/v1/me/*` profile endpoints.
class AuthApi {
  AuthApi(this._client, {SessionStore? session})
      : _session = session ?? SessionStore.instance;

  final ApiClient _client;
  final SessionStore _session;

  SessionStore get session => _session;

  /// `POST /auth/otp/send` → 204. Sends a one-time code to [email].
  Future<void> sendOtp(String email) async {
    await _client.post(
      '/auth/otp/send',
      body: {'email': email.trim()},
      authRequired: false,
    );
  }

  /// `POST /auth/otp/send-mobile` → 204. Sends an OTP to [mobile].
  ///
  /// Returns 503 `SMS_NOT_CONFIGURED` until the backend has an SMS provider —
  /// the server's message is surfaced to the user as-is.
  Future<void> sendMobileOtp(String mobile) async {
    await _client.post(
      '/auth/otp/send-mobile',
      body: {'mobile': mobile.trim()},
      authRequired: false,
    );
  }

  /// `POST /auth/otp/verify` → `AuthResult`. Stores the returned JWTs.
  Future<AuthResultDto> verifyOtp(String email, String otp, {String? deviceId}) async {
    final raw = await _client.post(
      '/auth/otp/verify',
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
        'deviceId': (deviceId != null && deviceId.isNotEmpty)
            ? deviceId
            : _session.deviceId,
      },
      authRequired: false,
    );
    return _adoptSession(raw);
  }

  /// `POST /auth/otp/verify-mobile` → `AuthResult`. Stores the returned JWTs.
  ///
  /// A counter customer with the same number is claimed on first OTP login,
  /// so coins earned at the counter carry over. Admin/cashier accounts keep
  /// using email.
  Future<AuthResultDto> verifyMobileOtp(String mobile, String otp,
      {String? deviceId}) async {
    final raw = await _client.post(
      '/auth/otp/verify-mobile',
      body: {
        'mobile': mobile.trim(),
        'otp': otp.trim(),
        'deviceId': (deviceId != null && deviceId.isNotEmpty)
            ? deviceId
            : _session.deviceId,
      },
      authRequired: false,
    );
    return _adoptSession(raw);
  }

  /// Parse an `AuthResult` and persist the JWTs into the session.
  ///
  /// Only the tokens are kept: the profile itself is re-read from `GET /me`
  /// on every launch, so nothing about the user is cached on the device.
  Future<AuthResultDto> _adoptSession(dynamic raw) async {
    final result = AuthResultDto.fromJson(Map<String, dynamic>.from(raw as Map));
    await _session.save(
      accessToken: result.accessToken ?? '',
      refreshToken: result.refreshToken ?? '',
    );
    return result;
  }

  /// The push token registered for this device in this app run (set by
  /// [registerDevice]); sent with logout so the server stops pushing to a
  /// signed-out device.
  String? _fcmToken;

  /// `POST /auth/logout` → 204. Carries the device's `fcmToken` when one was
  /// registered.
  Future<void> logout() async {
    final refresh = _session.refreshToken;
    final fcm = _fcmToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _client.post(
          '/auth/logout',
          body: {
            'refreshToken': refresh,
            if (fcm != null && fcm.isNotEmpty) 'fcmToken': fcm,
          },
          authRequired: false,
        );
      }
    } catch (_) {
      // Best-effort; clear the local session regardless.
    }
    await _session.clear();
  }

  /// `GET /me` → current user.
  Future<UserDto> me() async {
    final raw = await _client.get('/me');
    return UserDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `PUT /me` → update profile.
  Future<UserDto> updateProfile({String? name, String? mobile}) async {
    final raw = await _client.put(
      '/me',
      body: {
        if (name != null) 'name': name,
        if (mobile != null) 'mobile': mobile,
      },
    );
    return UserDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `DELETE /me` → 204. Erases the customer's account (409
  /// `ACCOUNT_HAS_OPEN_ORDERS` / `ACCOUNT_HAS_DUES` while orders are open or
  /// credit is owed). All tokens are revoked server-side on success.
  Future<void> deleteAccount() => _client.delete('/me');

  /// `GET /me/addresses` → address list.
  Future<List<AddressDto>> addresses() async {
    final raw = await _client.get('/me/addresses') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => AddressDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /me/addresses` → created address.
  Future<AddressDto> addAddress({
    required String label,
    required String line1,
    required String area,
    required String pincode,
    String phone = '',
    bool isDefault = false,
  }) async {
    final raw = await _client.post(
      '/me/addresses',
      body: {
        'label': label,
        'line1': line1,
        'area': area,
        'pincode': pincode,
        // PUT replaces the whole address: an omitted phone is cleared.
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        'isDefault': isDefault,
      },
    );
    return AddressDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `PUT /me/addresses/{id}` → updated address.
  Future<AddressDto> updateAddress(
    String id, {
    required String label,
    required String line1,
    required String area,
    required String pincode,
    String phone = '',
    bool isDefault = false,
  }) async {
    final raw = await _client.put(
      '/me/addresses/$id',
      body: {
        'label': label,
        'line1': line1,
        'area': area,
        'pincode': pincode,
        // PUT replaces the whole address: an omitted phone is cleared.
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        'isDefault': isDefault,
      },
    );
    return AddressDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `DELETE /me/addresses/{id}` → 204.
  Future<void> deleteAddress(String id) =>
      _client.delete('/me/addresses/$id');

  /// `POST /me/devices` → 204 (FCM registration).
  Future<void> registerDevice(String fcmToken, String platform) async {
    await _client.post('/me/devices', body: {
      'fcmToken': fcmToken,
      'platform': platform,
    });
    _fcmToken = fcmToken;
  }

  /// `DELETE /me/devices/{fcmToken}` → 204 (idempotent, own token only).
  Future<void> unregisterDevice(String fcmToken) async {
    await _client.delete('/me/devices/${Uri.encodeComponent(fcmToken)}');
    if (_fcmToken == fcmToken) _fcmToken = null;
  }

  // ---------------------------------------------------------------------------
  // Wishlist (`/me/wishlist`)
  // ---------------------------------------------------------------------------

  /// `GET /me/wishlist` → the saved products (public `Product` rows).
  Future<List<PublicProductDto>> wishlist() async {
    final raw = await _client.get('/me/wishlist') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => PublicProductDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /me/wishlist/{productId}` → 204 (save a pack).
  Future<void> addToWishlist(String productId) =>
      _client.post('/me/wishlist/$productId');

  /// `DELETE /me/wishlist/{productId}` → 204 (unsave a pack).
  Future<void> removeFromWishlist(String productId) =>
      _client.delete('/me/wishlist/$productId');

  // ---------------------------------------------------------------------------
  // Notifications inbox (`/me/notifications`)
  // ---------------------------------------------------------------------------

  /// `GET /me/notifications` → paged inbox + unread count.
  Future<InboxDto> notifications({int page = 0, int size = 50}) async {
    final raw = await _client.get('/me/notifications', query: {
      'page': '$page',
      'size': '$size',
    });
    return InboxDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /me/notifications/{id}/read` → 204 (mark one as read).
  Future<void> markNotificationRead(String id) =>
      _client.post('/me/notifications/$id/read');

  /// `POST /me/notifications/read-all` → 204 (mark the inbox read).
  Future<void> markAllNotificationsRead() =>
      _client.post('/me/notifications/read-all');
}
