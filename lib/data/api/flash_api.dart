import 'api_client.dart';
import 'flash_dto.dart';

/// Flash sales (`40-flash-sales.md`): two public lists for customers and the
/// ADMIN/CASHIER management endpoints.
class FlashApi {
  FlashApi(this._client);

  final ApiClient _client;

  Map<String, dynamic> _m(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  // ---- customer (public) ---------------------------------------------------

  Future<FlashPublicDto> active() async {
    final r = FlashPublicDto.fromJson(_m(
        await _client.get('/flash-sales/active', authRequired: false)));
    FlashClock.sync(r.now);
    return r;
  }

  Future<FlashPublicDto> upcoming() async {
    final r = FlashPublicDto.fromJson(_m(
        await _client.get('/flash-sales/upcoming', authRequired: false)));
    FlashClock.sync(r.now);
    return r;
  }

  // ---- staff ---------------------------------------------------------------

  Future<FlashSalePage> list({String? status, int page = 0, int size = 20}) async =>
      FlashSalePage.fromJson(_m(await _client.get('/admin/flash-sales', query: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': '$page',
        'size': '$size',
      })));

  Future<FlashSaleView> get(String id) async =>
      FlashSaleView.fromJson(_m(await _client.get('/admin/flash-sales/$id')));

  Future<FlashSaleView> create(Map<String, dynamic> body) async =>
      FlashSaleView.fromJson(
          _m(await _client.post('/admin/flash-sales', body: body)));

  Future<FlashSaleView> patch(String id, Map<String, dynamic> body) async =>
      FlashSaleView.fromJson(
          _m(await _client.patch('/admin/flash-sales/$id', body: body)));

  Future<FlashSaleView> addItem(String id, Map<String, dynamic> body) async =>
      FlashSaleView.fromJson(
          _m(await _client.post('/admin/flash-sales/$id/items', body: body)));

  Future<FlashSaleView> updateItem(
          String id, String itemId, Map<String, dynamic> body) async =>
      FlashSaleView.fromJson(_m(
          await _client.put('/admin/flash-sales/$id/items/$itemId', body: body)));

  Future<FlashSaleView> deleteItem(String id, String itemId) async =>
      FlashSaleView.fromJson(
          _m(await _client.deleteJson('/admin/flash-sales/$id/items/$itemId')));

  /// `DELETE /admin/flash-sales/{id}` (204): only a sale that never started.
  /// A repeated delete answers 404, which callers treat as done.
  Future<void> deleteSale(String id) =>
      _client.delete('/admin/flash-sales/$id');

  Future<FlashSaleView> startNow(String id) async => FlashSaleView.fromJson(
      _m(await _client.post('/admin/flash-sales/$id/start-now')));

  Future<FlashSaleView> endNow(String id) async => FlashSaleView.fromJson(
      _m(await _client.post('/admin/flash-sales/$id/end-now')));

  Future<FlashSaleView> cancel(String id) async => FlashSaleView.fromJson(
      _m(await _client.post('/admin/flash-sales/$id/cancel')));

  Future<FlashSaleView> duplicate(String id, {Map<String, dynamic>? body}) async =>
      FlashSaleView.fromJson(_m(
          await _client.post('/admin/flash-sales/$id/duplicate', body: body)));

  Future<FlashSaleReport> report(String id) async => FlashSaleReport.fromJson(
      _m(await _client.get('/admin/flash-sales/$id/report')));

  Future<FlashPeriodReport> periodReport({String? from, String? to}) async =>
      FlashPeriodReport.fromJson(
          _m(await _client.get('/admin/flash-sales/report', query: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      })));
}
