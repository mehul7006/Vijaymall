import 'api_client.dart';
import 'api_service.dart';
import 'lots_dto.dart';

/// Stock lots, expiry, valuation and margin (`74-stock-lots-and-pricing.md`,
/// P5). ADMIN only. None of these calls uses an `Idempotency-Key`.
class LotsApi {
  LotsApi(this._client);

  /// Not on the shared [Api] facade (a shared file): built on its client.
  static LotsApi? _inst;
  static LotsApi get instance {
    final c = Api.instance.client;
    final cur = _inst;
    if (cur == null || !identical(cur._client, c)) _inst = LotsApi(c);
    return _inst!;
  }

  final ApiClient _client;

  Map<String, dynamic> _m(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  Future<LotPage> lots(String variantId,
          {bool onlyOpen = false, int page = 0, int size = 20}) async =>
      LotPage.fromJson(_m(
          await _client.get('/admin/variants/$variantId/lots', query: {
        'onlyOpen': '$onlyOpen',
        'page': '$page',
        'size': '$size',
      })));

  Future<LotSettings> settings(String variantId) async => LotSettings.fromJson(
      _m(await _client.get('/admin/variants/$variantId/lot-settings')));

  /// Both flags are always sent.
  Future<LotSettings> saveSettings(String variantId,
          {required bool lotPriced, required bool trackExpiry}) async =>
      LotSettings.fromJson(_m(await _client.put(
          '/admin/variants/$variantId/lot-settings',
          body: {'lotPriced': lotPriced, 'trackExpiry': trackExpiry})));

  /// [days] null = the shop's `inventory.expiryAlertDays`.
  Future<ExpiringResult> expiring({int? days}) async =>
      ExpiringResult.fromJson(_m(await _client.get('/admin/stock/expiring',
          query: {if (days != null) 'days': '$days'})));

  Future<WriteOffResult> writeOff(String lotId, {String? reason}) async {
    final r = (reason ?? '').trim();
    return WriteOffResult.fromJson(_m(await _client.post(
        '/admin/stock/lots/$lotId/write-off',
        body: r.isEmpty ? null : {'reason': r})));
  }

  Future<Valuation> valuation(
          {String groupBy = 'product', int page = 0, int size = 20}) async =>
      Valuation.fromJson(_m(await _client.get('/admin/stock/valuation',
          query: {'groupBy': groupBy, 'page': '$page', 'size': '$size'})));

  Future<MarginPage> margin(
          {String groupBy = 'product',
          String? from,
          String? to,
          int page = 0,
          int size = 20}) async =>
      MarginPage.fromJson(
          _m(await _client.get('/admin/reports/margin', query: {
        'groupBy': groupBy,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'page': '$page',
        'size': '$size',
      })));

  Future<LotCheck> lotCheck() async =>
      LotCheck.fromJson(_m(await _client.get('/admin/stock/lot-check')));
}
