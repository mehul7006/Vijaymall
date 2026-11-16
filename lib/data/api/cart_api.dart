import 'api_client.dart';
import 'dto.dart';

/// The signed-in customer's saved basket: `GET` / `PUT` / `DELETE
/// /api/v1/cart`.
///
/// The server keeps one basket per user (migration `V6__cart.sql`), so the
/// same customer sees the same items, applied coupon and coin preferences on
/// every device. Lines are **pack ids** — exactly what `POST /cart/quote`
/// accepts — so the client converts `(productId, variantIndex)` before
/// pushing.
///
/// `PUT` is a full replace (last write wins): the client holds the whole
/// basket and rewrites it on every mutation, which keeps the round trip at
/// one and the state free of partial-update races. Guests never reach this
/// class — `/cart` is authenticated — their basket stays on the device.
class CartApi {
  CartApi(this._client);

  final ApiClient _client;

  /// The stored basket, or an empty one when the user has never saved one.
  Future<SavedCartDto> get() async {
    final raw = await _client.get('/cart');
    if (raw is Map) {
      return SavedCartDto.fromJson(Map<String, dynamic>.from(raw));
    }
    return SavedCartDto();
  }

  /// Replace the stored basket with [items] (pack id + qty, clamped by the
  /// caller to `qty 1..99`, `<=100` lines). Returns what is now stored.
  Future<SavedCartDto> replace({
    required List<Map<String, dynamic>> items,
    String? couponCode,
    String coinMode = 'NONE',
    int? percent,
  }) async {
    final raw = await _client.put('/cart', body: {
      'items': items,
      if (couponCode != null && couponCode.isNotEmpty)
        'couponCode': couponCode,
      'coinMode': coinMode,
      if (percent != null) 'percent': percent,
    });
    if (raw is Map) {
      return SavedCartDto.fromJson(Map<String, dynamic>.from(raw));
    }
    return SavedCartDto(
      items: [
        for (final it in items)
          SavedCartLineDto(
            productId: it['productId']?.toString(),
            qty: (it['qty'] as num?)?.toInt() ?? 1,
          )
      ],
      couponCode: couponCode,
      coinMode: coinMode,
      percent: percent,
    );
  }

  /// Drop the stored basket (checkout success, "clear cart").
  Future<void> clear() => _client.delete('/cart');
}
