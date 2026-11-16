import 'api/api_service.dart';
import 'models.dart';

/// GST slab (percent) per pack id, read once from `GET /pos/products`
/// (`gstPercent`; the admin product list does not carry it). Used to show the
/// rate on the inventory list. Failures leave it empty (the rate is simply
/// not shown).
class GstCache {
  GstCache._();

  static final Map<String, int> byPackId = {};
  static bool _loading = false;
  static DateTime? _at;

  /// Loads (at most every 2 minutes). Returns true when something changed.
  static Future<bool> load({bool force = false}) async {
    if (_loading) return false;
    final at = _at;
    if (!force && at != null && DateTime.now().difference(at).inSeconds < 120) {
      return false;
    }
    _loading = true;
    try {
      final fresh = <String, int>{};
      for (var page = 0; page < 40; page++) {
        final r = await Api.instance.pos.getProducts(page: page, size: 50);
        for (final p in r.items) {
          final id = p.productId;
          if (id != null) fresh[id] = p.gstPercent;
        }
        if (r.hasMore == false || r.items.length < 50) break;
      }
      byPackId
        ..clear()
        ..addAll(fresh);
      _at = DateTime.now();
      return true;
    } catch (_) {
      return false;
    } finally {
      _loading = false;
    }
  }

  /// "GST 5%" / "GST 5-12%" for a product's packs, or '' when unknown.
  static String labelFor(Product p) {
    final rates = <int>{
      for (final v in p.variants)
        if (v.backendId != null && byPackId.containsKey(v.backendId))
          byPackId[v.backendId]!
    };
    if (rates.isEmpty) return '';
    final l = rates.toList()..sort();
    return l.length == 1 ? 'GST ${l.first}%' : 'GST ${l.first}-${l.last}%';
  }
}
