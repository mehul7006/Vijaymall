import 'dart:convert';

import '../local_store.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'dto.dart';
import 'dto_ops.dart';

/// Customer commerce: `POST /cart/quote` and the `/orders` endpoints.
class OrdersApi {
  OrdersApi(this._client);

  final ApiClient _client;

  /// `POST /cart/quote` → authoritative server-side pricing for a cart.
  ///
  /// [items] is `{productId (pack id), qty}`. [coinMode] is
  /// NONE | ALL | PERCENT; [percent] only applies for PERCENT.
  Future<QuoteDto> quote({
    required List<Map<String, dynamic>> items,
    String? couponCode,
    String? coinMode,
    int? percent,
    String? fulfilment,
  }) async {
    final raw = await _client.post('/cart/quote', body: {
      'items': items,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      // Swagger: coinMode is NONE | ALL | PERCENT. The backend answers a bare
      // 400 when it is missing, so always send it ("no coins" = NONE).
      'coinMode': coinMode ?? 'NONE',
      if (percent != null && coinMode == 'PERCENT') 'percent': percent,
      if (fulfilment != null) 'fulfilment': fulfilment,
    });
    return QuoteDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /cart/coupons` → every coupon on offer tried on this exact cart
  /// (usable first, biggest saving first). Same body as the quote; any
  /// `couponCode` is ignored by the server.
  Future<List<CouponOptionDto>> couponOptions({
    required List<Map<String, dynamic>> items,
    String? coinMode,
    int? percent,
    String? fulfilment,
  }) async {
    final raw = await _client.post('/cart/coupons', body: {
      'items': items,
      'coinMode': coinMode ?? 'NONE',
      if (percent != null && coinMode == 'PERCENT') 'percent': percent,
      if (fulfilment != null) 'fulfilment': fulfilment,
    }) as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => CouponOptionDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /orders` → the placed order (`View`). Sends an `Idempotency-Key`.
  /// [slot] is the chosen delivery/pickup slot (echoed back on the order).
  Future<AdminViewDto> placeOrder({
    required List<Map<String, dynamic>> items,
    String? couponCode,
    String? coinMode,
    int? percent,
    String? fulfilment,
    String? addressId,
    required String paymentMethod,
    int? expectedTotalPaise,
    String? slot,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'items': items,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      'coinMode': coinMode ?? 'NONE',
      if (percent != null && coinMode == 'PERCENT') 'percent': percent,
      if (fulfilment != null) 'fulfilment': fulfilment,
      if (addressId != null && addressId.isNotEmpty) 'addressId': addressId,
      'paymentMethod': paymentMethod,
      if (expectedTotalPaise != null) 'expectedTotalPaise': expectedTotalPaise,
      if (slot != null && slot.isNotEmpty) 'slot': slot,
    };
    // P1 section 5.4 step 3/6: the key of one place-order action is persisted
    // (browser storage) so a reload or crash after the request left retries
    // with the SAME key. A different cart/body is a different action.
    final fp = jsonEncode(body);
    var key = idempotencyKey;
    if (key == null || key.isEmpty) {
      try {
        final saved = LocalStore.get('vsm.pendingOrderKey');
        if (saved != null) {
          final m = jsonDecode(saved);
          if (m is Map && m['fp'] == fp) key = m['key']?.toString();
        }
      } catch (_) {}
      key ??= newIdempotencyKey();
      LocalStore.set(
          'vsm.pendingOrderKey', jsonEncode({'fp': fp, 'key': key}));
    }
    final dynamic raw;
    try {
      raw = await _client.post(
        '/orders',
        headers: {'Idempotency-Key': key},
        body: body,
      );
    } on ApiException catch (e) {
      // Unknown outcome (network, timeout, 5xx, 401, 429) keeps the key; a
      // definite refusal (400/404/409/422) kills it.
      final keep = e.statusCode == 0 ||
          e.statusCode >= 500 ||
          e.statusCode == 401 ||
          e.statusCode == 408 ||
          e.statusCode == 429;
      if (!keep) LocalStore.remove('vsm.pendingOrderKey');
      rethrow;
    }
    LocalStore.remove('vsm.pendingOrderKey');
    return AdminViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /orders` → paged summary list for the signed-in customer.
  Future<PageSummaryDto> listOrders({int page = 0, int size = 50}) async {
    final raw = await _client.get('/orders', query: {
      'page': '$page',
      'size': '$size',
    });
    return PageSummaryDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /orders/{id}` → full order (`View`).
  Future<AdminViewDto> getOrder(String id) async {
    final raw = await _client.get('/orders/$id');
    return AdminViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /orders/{id}/returns` - goods returned + refunds the shop recorded
  /// on this order (oldest first, empty when none).
  Future<List<OrderReturnDto>> listReturns(String id) async {
    final raw = await _client.get('/orders/$id/returns') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => OrderReturnDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /orders/{id}/reorder` - which lines of an old order can be bought
  /// again today (current price + stock).
  Future<ReorderDto> reorder(String id) async {
    final raw = await _client.get('/orders/$id/reorder');
    return ReorderDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /orders/{id}/cancel` with an optional `{reason}` (max 200 chars).
  /// The backend echoes it back as `View.cancelReason`.
  Future<AdminViewDto> cancelOrder(String id, {String? reason}) async {
    final raw = await _client.post(
      '/orders/$id/cancel',
      body: reason == null ? null : {'reason': reason},
    );
    return AdminViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }
}
