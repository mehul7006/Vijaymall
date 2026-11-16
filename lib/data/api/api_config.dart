/// Backend connection configuration.
///
/// The Spring Boot backend serves its API under `/api/v1/...` on
/// `http://localhost:8080`. Change [baseUrl] here (or via `--dart-define`)
/// when the backend moves to another host.
class ApiConfig {
  ApiConfig._();

  /// Backend root. Override at build/run time with:
  /// `flutter run --dart-define=API_BASE=http://192.168.1.5:8080`
  static const String fromEnv =
      String.fromEnvironment('API_BASE', defaultValue: '');

  /// Runtime override (set via `Api.configure(baseUrl: ...)`). When non-empty
  /// it wins over [fromEnv] and the localhost default.
  static String? customBase;

  /// True when this app is pointed at a real backend: either the build was
  /// compiled with `--dart-define=API_BASE=...`, or a base URL was set at
  /// runtime. In that case the UI must only ever show data served by the
  /// API — the prototype's seed/demo content, dev OTP hints and other
  /// offline conveniences stay out of the build.
  static bool get isLive =>
      fromEnv.isNotEmpty || (customBase?.isNotEmpty ?? false);

  /// Effective base URL (no trailing slash).
  static String get baseUrl {
    final chosen = (customBase != null && customBase!.isNotEmpty)
        ? customBase!
        : (fromEnv.isNotEmpty ? fromEnv : 'http://localhost:8080');
    return _strip(chosen);
  }

  /// Force a new base URL at runtime.
  static void setBaseUrl(String url) => customBase = _strip(url);

  static String _strip(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// All business endpoints live under this prefix.
  static const String apiPrefix = '/api/v1';

  /// Full path helper: `${apiPrefix}/admin/products`.
  static String path(String endpoint) => endpoint.startsWith('/')
      ? '$apiPrefix$endpoint'
      : '$apiPrefix/$endpoint';

  /// Default request timeout.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// SharedPreferences keys for the persisted session.
  static const String keyAccessToken = 'vsm.accessToken';
  static const String keyRefreshToken = 'vsm.refreshToken';

  /// Profile JSON written by an older build. Never read any more — the
  /// profile comes from `GET /me` — but still removed on session load so a
  /// previous install doesn't leave user data behind on the device.
  static const String keyLegacyUserJson = 'vsm.user';
}
