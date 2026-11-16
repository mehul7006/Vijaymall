import '../local_store.dart';
import 'api_client.dart' show newIdempotencyKey;
import 'api_config.dart';

/// Auth session (access + refresh JWTs) with write-through persistence.
///
/// **Storage policy — this class is deliberately the only thing besides the
/// guest basket that may touch `localStorage`.** Identity lives on the
/// backend: the profile is re-read from `GET /me` on every launch and
/// `role` (which gates `#/admin/*`) only ever comes from that response, so
/// nothing about the user is cached here. Keeping just the two tokens means
/// a stolen/`localStorage` dump yields credentials and never user data, and
/// there is no second, stale copy of anything the server owns.
///
/// On the web the tokens live in `localStorage`, so a browser refresh — or
/// an accidental tab close — does **not** sign the user out: `hasTokens`
/// stays true and `AppState.backendMode` keeps working across reloads.
///
/// Storage stays plugin-free (`dart:js_interop`, see `lib/data/local_store.dart`),
/// which keeps the Windows desktop build free of the "symlink support /
/// Developer Mode" requirement. Desktop therefore keeps the previous
/// in-memory behaviour: a restart there still starts a fresh session.
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  String? _accessToken;
  String? _refreshToken;
  bool _ready = false;

  bool get isReady => _ready;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasTokens => (_accessToken ?? _refreshToken) != null;

  String? _deviceId;

  /// Stable per-install id sent as `deviceId` on OTP verify. The backend
  /// groups refresh tokens by it (re-using a revoked token revokes the whole
  /// device, not every session of the account). Generated once, persisted,
  /// and deliberately NOT wiped by [clear] so it stays the same across
  /// sign-outs on this install.
  String get deviceId {
    var id = _deviceId;
    if (id != null && id.isNotEmpty) return id;
    try {
      id = LocalStore.get(_keyDeviceId);
    } catch (_) {
      id = null;
    }
    if (id == null || id.isEmpty) {
      id = newIdempotencyKey();
      try {
        LocalStore.set(_keyDeviceId, id);
      } catch (_) {}
    }
    _deviceId = id;
    return id;
  }

  static const String _keyDeviceId = 'vsm.deviceId';

  /// Hydrates the session from the persisted store. Called once from `main()`
  /// before `runApp`, so the very first frame already knows whether it is
  /// signed in. A corrupt or unreadable store simply yields a fresh session.
  Future<void> init() async {
    try {
      final access = LocalStore.get(ApiConfig.keyAccessToken);
      final refresh = LocalStore.get(ApiConfig.keyRefreshToken);
      if (access != null || refresh != null) {
        _accessToken = access;
        _refreshToken = refresh;
      }
    } catch (_) {
      // Corrupt store → drop it and start signed out.
      _accessToken = null;
      _refreshToken = null;
      LocalStore.remove(ApiConfig.keyAccessToken);
      LocalStore.remove(ApiConfig.keyRefreshToken);
    }
    // A row written by an older build may still carry the (unread) profile
    // JSON. Nothing reads it any more, so delete it rather than leave user
    // data on the device.
    LocalStore.remove(ApiConfig.keyLegacyUserJson);
    _ready = true;
  }

  /// Store fresh tokens (from `/auth/otp/verify` or `/auth/refresh`) and
  /// persist them so the next launch resumes this session.
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _persist();
  }

  /// Patch just the access token after a silent refresh (persisted too, so a
  /// refresh mid-session survives the next reload).
  void setAccessToken(String accessToken) {
    _accessToken = accessToken;
    LocalStore.set(ApiConfig.keyAccessToken, accessToken);
  }

  /// Ends the session locally and wipes the persisted copy.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    LocalStore.remove(ApiConfig.keyAccessToken);
    LocalStore.remove(ApiConfig.keyRefreshToken);
    LocalStore.remove(ApiConfig.keyLegacyUserJson);
  }

  /// Write the tokens through to storage (best-effort).
  void _persist() {
    final access = _accessToken;
    final refresh = _refreshToken;
    if (access != null) {
      LocalStore.set(ApiConfig.keyAccessToken, access);
    } else {
      LocalStore.remove(ApiConfig.keyAccessToken);
    }
    if (refresh != null) {
      LocalStore.set(ApiConfig.keyRefreshToken, refresh);
    } else {
      LocalStore.remove(ApiConfig.keyRefreshToken);
    }
    LocalStore.remove(ApiConfig.keyLegacyUserJson);
  }

  static const String keyAccessToken = ApiConfig.keyAccessToken;
  static const String keyRefreshToken = ApiConfig.keyRefreshToken;
}
