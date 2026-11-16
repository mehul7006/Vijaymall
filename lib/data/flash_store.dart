import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/api_exception.dart';
import 'api/api_service.dart';
import 'api/flash_dto.dart';

/// Customer-side cache of `GET /flash-sales/active` and `/upcoming`.
///
/// Screens listen to it; [bump] is called when a `catalog` frame with
/// `area: FLASH` arrives (and when a countdown reaches 0), which refetches.
class FlashStore extends ChangeNotifier {
  FlashStore._();
  static final FlashStore instance = FlashStore._();

  List<FlashPublicSale> active = const [];
  List<FlashPublicSale> upcoming = const [];
  bool loaded = false;
  bool _busy = false;
  DateTime? _lastFetch;

  /// Product (pack) id -> its running flash offer, for quick lookups.
  FlashPublicItem? itemFor(String packId) {
    for (final s in active) {
      for (final i in s.items) {
        if (i.productId == packId) return i;
      }
    }
    return null;
  }

  /// Refetch both lists. Never throws; a failure keeps what is shown.
  Future<void> refresh({bool force = false}) async {
    if (_busy) return;
    final last = _lastFetch;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _busy = true;
    try {
      final a = await Api.instance.flash.active();
      List<FlashPublicSale> u = const [];
      try {
        u = (await Api.instance.flash.upcoming()).sales;
      } on ApiException {
        // The teaser is optional.
      }
      active = a.sales;
      upcoming = u;
      loaded = true;
      _lastFetch = DateTime.now();
      notifyListeners();
    } on ApiException {
      // keep the last good lists
    } catch (_) {
      // offline prototype / network blip
    } finally {
      _busy = false;
    }
  }

  /// A `FLASH` live event or a finished countdown.
  void bump() => unawaited(refresh(force: true));
}
