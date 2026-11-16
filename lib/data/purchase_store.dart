import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/api_service.dart';
import 'api/purchase_api.dart';
import 'api/purchase_dto.dart';

/// `10 x 500 g` style quantity text (leading `+` when [plus]).
///
/// * products sold by weight are stored in grams (ml): `2500` -> `2.5 kg`;
/// * packs sold by count: quantity x pack size (`10 x 500 g`, `2 x 1 kg`;
///   a bare pack number takes the unit: pack `1`, unit `kg` -> `3 x 1 kg`);
/// * no pack size: `10 pcs`;
/// * pack not known yet ([p] null): the plain number.
String qtyWithPack(int qty, PackInfo? p, {bool plus = true}) {
  final sign = plus && qty > 0 ? '+' : '';
  if (p == null) return '$sign$qty';
  final unit = p.unit.trim().toLowerCase();
  if (p.weighed) {
    final liquid = const ['l', 'ltr', 'ml'].contains(unit);
    if (qty.abs() >= 1000) {
      final big = qty / 1000;
      final t = big.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
      return '$sign$t ${liquid ? 'L' : 'kg'}';
    }
    return '$sign$qty ${liquid ? 'ml' : 'g'}';
  }
  var pack = normalizePack(p.packSize);
  final label = unit.isEmpty || unit == 'pc' || unit == 'pcs'
      ? 'pc'
      : (unit == 'ltr' || unit == 'l' ? 'L' : p.unit.trim());
  if (pack.isEmpty) return '$sign$qty ${label == 'pc' ? 'pcs' : label}';
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(pack)) pack = '$pack $label';
  return '$sign$qty x $pack';
}

/// `500g` -> `500 g`, `1kg` -> `1 kg`, `1L` -> `1 L`; other text unchanged.
String normalizePack(String raw) {
  final s = raw.trim();
  final m = RegExp(r'^(\d+(?:\.\d+)?)\s*([A-Za-z]+)$').firstMatch(s);
  if (m != null) return '${m.group(1)} ${m.group(2)}';
  return s;
}

/// Session state for the purchases module: product pack labels, the shop's
/// GST state, the default purchase GST mode and the payables header.
class PurchaseStore extends ChangeNotifier {
  PurchaseStore._();
  static final PurchaseStore instance = PurchaseStore._();

  PurchaseApi get api => PurchaseApi(Api.instance.client);

  final Map<String, PackInfo> _packs = {};
  final Set<String> _loading = {};

  String? _shopState;
  String? _defaultMode;
  PayablesDto? payables;

  /// Duplicate-invoice warnings of a just-saved purchase, shown once on its
  /// detail screen (the GET never repeats them).
  final Map<String, List<String>> postWarnings = {};

  PackInfo? packOf(String productId) => _packs[productId];

  void rememberPack(String productId, String? unit, String? packSize,
      {bool? weighed}) {
    _packs[productId] = PackInfo(unit ?? '', packSize ?? '',
        weighed: weighed ?? _packs[productId]?.weighed ?? false);
  }

  /// Quantity text for a product (`+10 x 500 g`); falls back to the plain
  /// number until the pack is known.
  String qty(String productId, int qty, {bool plus = true}) =>
      qtyWithPack(qty, _packs[productId], plus: plus);

  /// Fetch the pack of every id not yet known (a few at a time).
  Future<void> ensurePacks(Iterable<String> ids) async {
    final todo = ids
        .where((i) => i.isNotEmpty && !_packs.containsKey(i) && !_loading.contains(i))
        .toSet()
        .toList();
    if (todo.isEmpty) return;
    _loading.addAll(todo);
    var next = 0;
    Future<void> worker() async {
      while (next < todo.length) {
        final id = todo[next++];
        try {
          final p = await api.packOf(id);
          if (p != null) _packs[id] = p;
        } catch (_) {
          // The number alone is still shown.
        } finally {
          _loading.remove(id);
        }
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    notifyListeners();
  }

  Future<String> shopStateCode() async =>
      _shopState ??= await api.shopStateCode().catchError((_) => '24');

  Future<String> defaultGstMode() async =>
      _defaultMode ??= await api.defaultGstMode().catchError((_) => 'REGULAR');

  Future<PayablesDto?> loadPayables() async {
    try {
      payables = await api.payables();
      notifyListeners();
    } catch (_) {
      // keep the last figures
    }
    return payables;
  }
}
