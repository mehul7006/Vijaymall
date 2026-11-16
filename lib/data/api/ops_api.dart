import 'api_client.dart';
import 'dto_ops.dart';

/// Admin operations from `20-orders-payments-admin-config.md`: refunds, shop
/// profile (hours / pause switch / logo), the generic configuration screen,
/// start-up health, "Test" buttons, caches and log status. All ADMIN only.
class OpsApi {
  OpsApi(this._client);

  final ApiClient _client;

  // ---- refunds -------------------------------------------------------------

  /// `GET /admin/refunds?status=` (PENDING | PROCESSING | ISSUED | FAILED).
  Future<RefundPageDto> listRefunds(
      {String? status, int page = 0, int size = 20}) async {
    final raw = await _client.get('/admin/refunds', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      'page': '$page',
      'size': '$size',
    });
    return RefundPageDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /admin/refunds/{id}/retry` (204) - FAILED refunds only, else 409
  /// `REFUND_NOT_FAILED`.
  Future<void> retryRefund(String id) async {
    await _client.post('/admin/refunds/$id/retry');
  }

  // ---- shop profile --------------------------------------------------------

  Future<ShopProfileDto> getShopProfile() async {
    final raw = await _client.get('/admin/shop-profile');
    return ShopProfileDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<ShopProfileDto> saveShopProfile(ShopProfileDto p) async {
    final raw = await _client.put('/admin/shop-profile', body: p.toJson());
    return ShopProfileDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<ShopProfileDto> uploadShopLogo(List<int> bytes, String filename) async {
    final raw = await _client.postMultipart('/admin/shop-profile/logo',
        fileField: 'file', bytes: bytes, filename: filename);
    return ShopProfileDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /admin/shop-profile/logo/icon` (no body): rebuild the app icons
  /// from the stored logo. 404 when there is no logo.
  Future<ShopProfileDto> createShopIcon() async {
    final raw = await _client.post('/admin/shop-profile/logo/icon');
    return ShopProfileDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<ShopProfileDto> deleteShopLogo() async {
    final raw = await _client.deleteJson('/admin/shop-profile/logo');
    return ShopProfileDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---- configuration -------------------------------------------------------

  Future<ConfigViewDto> getConfig() async {
    final raw = await _client.get('/admin/config');
    return ConfigViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `PUT /admin/config` with only the edited keys. A blank value clears a
  /// setting (a blank secret deletes it); untouched secrets must be omitted.
  Future<ConfigViewDto> saveConfig(Map<String, String> changes) async {
    final raw = await _client.put('/admin/config', body: {
      'changes': [
        for (final e in changes.entries) {'key': e.key, 'value': e.value}
      ],
    });
    return ConfigViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<BootstrapItemDto>> getBootstrap() async {
    final raw = await _client.get('/admin/config/bootstrap') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => BootstrapItemDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /admin/config/test/{razorpay|fcm|sms|email}` - always 200; read
  /// `ok` / `message`. Uses the **saved** values.
  Future<TestResultDto> testConfig(String target,
      {Map<String, String>? args}) async {
    final raw = await _client.post('/admin/config/test/$target',
        body: args == null ? null : {'args': args});
    return TestResultDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---- logs + caches -------------------------------------------------------

  Future<LogStatusDto> getLogStatus() async {
    final raw = await _client.get('/admin/logs/status');
    return LogStatusDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<CacheStatDto>> getCaches() async =>
      _caches(await _client.get('/admin/cache'));

  /// `POST /admin/cache/refresh` (all) or `/refresh/{name}` (`settings`
  /// reloads the configuration values).
  Future<List<CacheStatDto>> refreshCache([String? name]) async => _caches(
      await _client.post(name == null || name.isEmpty
          ? '/admin/cache/refresh'
          : '/admin/cache/refresh/$name'));

  List<CacheStatDto> _caches(Object? raw) => (raw as List? ?? [])
      .whereType<Map>()
      .map((e) => CacheStatDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
