import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'purchase_dto.dart';
import 'session_store.dart';

/// Suppliers, purchases, payments, returns, supplier account and purchase
/// reports (`70-purchases.md`, playbook P2). ADMIN only on the server.
///
/// Every write that needs one takes the caller's `Idempotency-Key` (one key
/// per user action, reused on a retry).
class PurchaseApi {
  PurchaseApi(this._client);

  final ApiClient _client;

  Map<String, String> _idem(String key) => {'Idempotency-Key': key};

  // ---- suppliers -----------------------------------------------------------

  Future<PPage<SupplierDto>> suppliers(
          {String? q, bool? active, int page = 0, int size = 20}) async =>
      PPage.from(
          await _client.get('/admin/suppliers', query: {
            if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
            if (active != null) 'active': '$active',
            'page': '$page',
            'size': '$size',
          }),
          SupplierDto.fromJson);

  Future<SupplierDto> supplier(String id) async => SupplierDto.fromJson(
      Map<String, dynamic>.from(await _client.get('/admin/suppliers/$id')));

  Future<SupplierDto> createSupplier(Map<String, dynamic> body,
          {String? key}) async =>
      SupplierDto.fromJson(Map<String, dynamic>.from(await _client.post(
          '/admin/suppliers',
          body: body,
          headers: key == null ? null : _idem(key))));

  /// PUT replaces every field: always send the whole supplier.
  Future<SupplierDto> updateSupplier(
          String id, Map<String, dynamic> body) async =>
      SupplierDto.fromJson(Map<String, dynamic>.from(
          await _client.put('/admin/suppliers/$id', body: body)));

  Future<SupplierDto> setSupplierActive(String id, bool active) async =>
      SupplierDto.fromJson(Map<String, dynamic>.from(await _client
          .post('/admin/suppliers/$id/${active ? 'activate' : 'deactivate'}')));

  Future<StatementDto> statement(String id,
          {String? from, String? to, int page = 0, int size = 20}) async =>
      StatementDto.fromJson(Map<String, dynamic>.from(
          await _client.get('/admin/suppliers/$id/statement', query: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'page': '$page',
        'size': '$size',
      })));

  Future<SupplierRefundDto> refund(
          String id, Map<String, dynamic> body, String key) async =>
      SupplierRefundDto.fromJson(Map<String, dynamic>.from(await _client.post(
          '/admin/suppliers/$id/refunds',
          body: body,
          headers: _idem(key))));

  Future<List<SupplierRefundDto>> refunds(String id) async =>
      ((await _client.get('/admin/suppliers/$id/refunds')) as List? ?? [])
          .whereType<Map>()
          .map((e) => SupplierRefundDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  // ---- purchases -----------------------------------------------------------

  Future<PurchaseDto> create(Map<String, dynamic> body, String key) async =>
      PurchaseDto.fromJson(Map<String, dynamic>.from(await _client
          .post('/admin/purchases', body: body, headers: _idem(key))));

  Future<PPage<PurchaseDto>> list({
    String? paymentStatus,
    bool overdue = false,
    String? supplierId,
    String? supplier,
    String? from,
    String? to,
    String rounding = 'PAISE',
    int page = 0,
    int size = 20,
  }) async =>
      PPage.from(
          await _client.get('/admin/purchases', query: {
            if (paymentStatus != null && paymentStatus.isNotEmpty)
              'paymentStatus': paymentStatus,
            if (overdue) 'overdue': 'true',
            if (supplierId != null && supplierId.isNotEmpty)
              'supplierId': supplierId,
            if (supplier != null && supplier.trim().isNotEmpty)
              'supplier': supplier.trim(),
            if (from != null) 'from': from,
            if (to != null) 'to': to,
            'rounding': rounding,
            'page': '$page',
            'size': '$size',
          }),
          PurchaseDto.fromJson);

  Future<PurchaseDto> get(String id, {String rounding = 'PAISE'}) async =>
      PurchaseDto.fromJson(Map<String, dynamic>.from(await _client
          .get('/admin/purchases/$id', query: {'rounding': rounding})));

  /// Only the fields to change. `dueDate: null` clears the due date, so this
  /// takes a plain map and never a model with default nulls.
  Future<PurchaseDto> patch(String id, Map<String, dynamic> onlyChanged) async =>
      PurchaseDto.fromJson(Map<String, dynamic>.from(
          await _client.patch('/admin/purchases/$id', body: onlyChanged)));

  Future<PurchaseDto> pay(
          String id, Map<String, dynamic> body, String key) async =>
      PurchaseDto.fromJson(Map<String, dynamic>.from(await _client.post(
          '/admin/purchases/$id/payments',
          body: body,
          headers: _idem(key))));

  Future<PayablesDto> payables() async => PayablesDto.fromJson(
      Map<String, dynamic>.from(await _client.get('/admin/purchases/payables')));

  Future<PurchaseLookupDto> lookup(String productId) async =>
      PurchaseLookupDto.fromJson(Map<String, dynamic>.from(await _client
          .get('/admin/purchases/lookup', query: {'productId': productId})));

  Future<List<PriceRowDto>> priceHistory(String productId,
          {int limit = 20, String rounding = 'PAISE'}) async =>
      ((await _client.get('/admin/products/$productId/purchase-prices',
                  query: {'limit': '$limit', 'rounding': rounding})) as List? ??
              [])
          .whereType<Map>()
          .map((e) => PriceRowDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  // ---- returns (debit notes) -----------------------------------------------

  Future<PurchaseReturnDto> returnGoods(
          String id, Map<String, dynamic> body, String key) async =>
      PurchaseReturnDto.fromJson(Map<String, dynamic>.from(await _client.post(
          '/admin/purchases/$id/returns',
          body: body,
          headers: _idem(key))));

  Future<PPage<PurchaseReturnDto>> returnsOf(String id,
          {int page = 0, int size = 50}) async =>
      PPage.from(
          await _client.get('/admin/purchases/$id/returns',
              query: {'page': '$page', 'size': '$size'}),
          PurchaseReturnDto.fromJson);

  Future<PPage<PurchaseReturnDto>> allReturns(
          {String? supplierId,
          String? from,
          String? to,
          int page = 0,
          int size = 20}) async =>
      PPage.from(
          await _client.get('/admin/purchase-returns', query: {
            if (supplierId != null && supplierId.isNotEmpty)
              'supplierId': supplierId,
            if (from != null) 'from': from,
            if (to != null) 'to': to,
            'page': '$page',
            'size': '$size',
          }),
          PurchaseReturnDto.fromJson);

  Future<PurchaseReturnDto> returnNote(String id) async =>
      PurchaseReturnDto.fromJson(Map<String, dynamic>.from(
          await _client.get('/admin/purchase-returns/$id')));

  // ---- invoice file --------------------------------------------------------

  Future<PurchaseDto> uploadAttachment(
          String id, List<int> bytes, String filename) async =>
      PurchaseDto.fromJson(Map<String, dynamic>.from(
          await _client.postMultipart('/admin/purchases/$id/attachment',
              fileField: 'file', bytes: bytes, filename: filename)));

  Future<PurchaseDto> deleteAttachment(String id) async =>
      PurchaseDto.fromJson(Map<String, dynamic>.from(
          await _client.deleteJson('/admin/purchases/$id/attachment')));

  /// The invoice bytes. Needs the bearer token, so a plain link cannot be
  /// used. Returns the bytes and the real `Content-Type`.
  Future<({List<int> bytes, String contentType})> attachmentBytes(
      String id) async {
    Future<http.Response> fetch() => http.get(
          Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.path('/admin/purchases/$id/attachment')}'),
          headers: {
            'Authorization': 'Bearer ${SessionStore.instance.accessToken ?? ''}'
          },
        ).timeout(ApiConfig.receiveTimeout);
    http.Response r;
    try {
      r = await fetch();
      if (r.statusCode == 401) {
        // Any authenticated call refreshes an expired token first.
        await _client.get('/admin/purchases/payables');
        r = await fetch();
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
          0, 'Could not reach the server. Check your connection.');
    }
    if (r.statusCode != 200) {
      var msg = r.statusCode == 404
          ? 'No invoice file is attached.'
          : 'Could not open the invoice file (${r.statusCode}).';
      try {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map && j['message'] != null && r.statusCode != 404) {
          msg = '${j['message']}';
        }
      } catch (_) {}
      throw ApiException(r.statusCode, msg);
    }
    return (
      bytes: r.bodyBytes,
      contentType: r.headers['content-type'] ?? 'application/octet-stream'
    );
  }

  // ---- reports -------------------------------------------------------------

  Map<String, String> _range(String? from, String? to) => {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      };

  Future<PPage<RegisterRowDto>> register(
          {String? from,
          String? to,
          String? supplierId,
          String? productId,
          int? gstRate,
          int page = 0,
          int size = 20}) async =>
      PPage.from(
          await _client.get('/admin/reports/purchases/register', query: {
            ..._range(from, to),
            if (supplierId != null && supplierId.isNotEmpty)
              'supplierId': supplierId,
            if (productId != null && productId.isNotEmpty)
              'productId': productId,
            if (gstRate != null) 'gstRate': '$gstRate',
            'page': '$page',
            'size': '$size',
          }),
          RegisterRowDto.fromJson);

  Future<InputGstDto> inputGst({String? from, String? to}) async =>
      InputGstDto.fromJson(Map<String, dynamic>.from(await _client
          .get('/admin/reports/purchases/input-gst', query: _range(from, to))));

  Future<DiscountsDto> discounts({String? from, String? to}) async =>
      DiscountsDto.fromJson(Map<String, dynamic>.from(await _client
          .get('/admin/reports/purchases/discounts', query: _range(from, to))));

  Future<AgeingDto> ageing({String? asOf}) async =>
      AgeingDto.fromJson(Map<String, dynamic>.from(await _client.get(
          '/admin/reports/purchases/ageing',
          query: {if (asOf != null) 'asOf': asOf})));

  // ---- small lookups -------------------------------------------------------

  /// Product unit / pack size / sold-by, for `+10 x 500 g`.
  Future<PackInfo?> packOf(String productId) async {
    final r = await Future.wait<dynamic>([
      _client.get('/admin/products/$productId'),
      _client.get('/admin/products/$productId/pos').catchError((_) => null),
    ]);
    final j = Map<String, dynamic>.from(r[0] as Map);
    final pos = r[1] is Map ? Map<String, dynamic>.from(r[1] as Map) : const {};
    return PackInfo('${j['unit'] ?? ''}', '${j['packSize'] ?? ''}',
        weighed: pos['soldBy'] == 'WEIGHT');
  }

  /// True when the product is sold by weight (stock counted in grams).
  Future<bool> isWeighed(String productId) async {
    final j = Map<String, dynamic>.from(
        await _client.get('/admin/products/$productId/pos') as Map);
    return j['soldBy'] == 'WEIGHT';
  }

  /// Shop GST state code (decides IGST vs CGST+SGST); `24` when unknown.
  Future<String> shopStateCode() async {
    final j = Map<String, dynamic>.from(
        await _client.get('/admin/shop-settings') as Map);
    final s = '${j['stateCode'] ?? ''}'.trim();
    return s.length == 2 ? s : '24';
  }

  /// Shop default `purchase.gstMode` (REGULAR when unknown).
  Future<String> defaultGstMode() async {
    final raw = await _client.get('/admin/config');
    String mode = 'REGULAR';
    void scan(dynamic n) {
      if (n is Map) {
        if (n['key'] == 'purchase.gstMode' && n['value'] != null) {
          mode = '${n['value']}'.toUpperCase();
        }
        n.values.forEach(scan);
      } else if (n is List) {
        n.forEach(scan);
      }
    }

    scan(raw);
    return const ['REGULAR', 'COMPOSITION', 'NONE'].contains(mode)
        ? mode
        : 'REGULAR';
  }
}
