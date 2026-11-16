import 'package:flutter/foundation.dart';

import 'api/lots_api.dart';
import 'api/lots_dto.dart';

/// Small cache for the stock-lots screens: the saved lot switches per variant
/// and the count of lots near expiry (for a badge on the menu entry).
class LotsStore extends ChangeNotifier {
  LotsStore._();
  static final LotsStore instance = LotsStore._();

  final Map<String, LotSettings> _settings = {};
  int? expiringCount;
  bool expiringTruncated = false;

  LotSettings? settingsFor(String variantId) => _settings[variantId];

  /// Reads `GET lot-settings` (also refreshes the cache). Throws on failure.
  Future<LotSettings> loadSettings(String variantId) async {
    final s = await LotsApi.instance.settings(variantId);
    _settings[variantId] = s;
    notifyListeners();
    return s;
  }

  Future<LotSettings> saveSettings(String variantId,
      {required bool lotPriced, required bool trackExpiry}) async {
    final s = await LotsApi.instance.saveSettings(variantId,
        lotPriced: lotPriced, trackExpiry: trackExpiry);
    _settings[variantId] = s;
    notifyListeners();
    return s;
  }

  /// Refreshes the near-expiry count. Never throws.
  Future<void> refreshExpiring() async {
    try {
      final r = await LotsApi.instance.expiring();
      expiringCount = r.lots.length;
      expiringTruncated = r.truncated;
      notifyListeners();
    } catch (_) {
      // optional badge
    }
  }
}
