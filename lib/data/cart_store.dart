import 'dart:convert';

import 'local_store.dart';

/// One persisted basket line: `[productId, variantIndex, qty]`.
class StoredLine {
  const StoredLine(this.productId, this.variantIndex, this.qty);

  final String productId;
  final int variantIndex;
  final int qty;
}

/// The coupon sitting on the cart when it was persisted.
///
/// The applied code is the only proof this device has that it once
/// validated — re-adopting it after a refresh keeps the basket intact until
/// the next `POST /cart/quote` re-checks it against the store. For a
/// signed-in session the server basket (`GET /cart`) carries the code too
/// and wins on restore; this copy is what a *guest* relies on.
class StoredCoupon {
  const StoredCoupon({
    required this.code,
    required this.paise,
    required this.desc,
    required this.worksWithCoins,
  });

  /// Last server-observed discount, in paise.
  final int paise;

  final String code;
  final String desc;

  /// False when the backend warned `Coins cannot be used together with
  /// coupon …` for this code.
  final bool worksWithCoins;
}

/// Device basket persisted across refreshes (live web builds only).
///
/// The account basket lives on the server (`GET/PUT/DELETE /cart`, available
/// once signed in) and follows the customer to any device; this store is
/// what keeps a **guest** basket — and a signed-in one across a cold start
/// before the server answers — alive through a refresh. Storage is
/// best-effort: a full/blocked `localStorage` never breaks the cart, it just
/// means the next launch starts empty again.
class CartStore {
  CartStore._();

  /// Bump the suffix when the JSON shape changes so old rows are dropped.
  static const String key = 'vsm.cart.v1';

  static List<StoredLine> lines = const [];
  static StoredCoupon? coupon;

  /// Read the persisted basket once at startup (see `main()`).
  static Future<void> load() async {
    lines = const [];
    coupon = null;
    String? raw;
    try {
      raw = LocalStore.get(key);
    } catch (_) {
      return;
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final items = decoded['items'];
      if (items is List) {
        final out = <StoredLine>[];
        for (final it in items) {
          if (it is! List || it.length < 3) continue;
          final id = it[0]?.toString() ?? '';
          final variant = (it[1] as num?)?.toInt() ?? 0;
          final qty = (it[2] as num?)?.toInt() ?? 0;
          if (id.isEmpty || qty <= 0) continue;
          out.add(StoredLine(id, variant, qty));
        }
        lines = out;
      }

      final c = decoded['coupon'];
      if (c is Map) {
        final code = c['code']?.toString().trim() ?? '';
        if (code.isNotEmpty) {
          coupon = StoredCoupon(
            code: code.toUpperCase(),
            paise: (c['paise'] as num?)?.toInt() ?? 0,
            desc: c['desc']?.toString() ?? '',
            worksWithCoins: c['coins'] == true,
          );
        }
      }
    } catch (_) {
      // Corrupt row → start with an empty basket rather than crashing.
      lines = const [];
      coupon = null;
      LocalStore.remove(key);
    }
  }

  static void save({
    required List<StoredLine> items,
    StoredCoupon? coupon,
  }) {
    try {
      LocalStore.set(
        key,
        jsonEncode({
          'items': [
            for (final l in items) [l.productId, l.variantIndex, l.qty],
          ],
          if (coupon != null)
            'coupon': {
              'code': coupon.code,
              'paise': coupon.paise,
              'desc': coupon.desc,
              'coins': coupon.worksWithCoins,
            },
        }),
      );
    } catch (_) {
      // Best-effort persistence; the in-memory cart keeps working.
    }
  }

  static void clear() {
    try {
      LocalStore.remove(key);
    } catch (_) {
      // Ignore.
    }
    lines = const [];
    coupon = null;
  }
}
