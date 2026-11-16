/// DTOs for stock lots, expiry, valuation and margin (`74-stock-lots-and-pricing.md`,
/// playbook P5). Money is integer paise; a lot's `unitCost` is paise per unit
/// with up to four decimals (a double, display only - never summed here).
library;

int _i(dynamic v, [int d = 0]) => (v as num?)?.toInt() ?? d;
int? _iN(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
String? _sN(dynamic v) {
  final t = v?.toString();
  return (t == null || t.isEmpty) ? null : t;
}

/// Paging part of `{items, page, size, total, totalExact, hasMore}`.
class LotPageInfo {
  final int page, size, total;
  final bool totalExact, hasMore;
  const LotPageInfo(
      this.page, this.size, this.total, this.totalExact, this.hasMore);

  factory LotPageInfo.fromJson(Map<String, dynamic> j) => LotPageInfo(
        _i(j['page']),
        _i(j['size']),
        _i(j['total']),
        j['totalExact'] != false,
        j['hasMore'] == true,
      );

  /// `10,000+` when the count is not exact.
  String get totalText => totalExact ? '$total' : '$total+';
}

class LotRow {
  final String id, productId, productName, source, batchNo;
  final String? receivedAt, expiryDate, purchaseItemId;
  final int qtyReceived, qtyRemaining;

  /// Paise per unit (up to 4 decimals).
  final double unitCost;
  final bool costKnown;
  final int? mrpPaise, pricePaise;

  const LotRow({
    required this.id,
    required this.productId,
    required this.productName,
    required this.source,
    required this.batchNo,
    required this.receivedAt,
    required this.expiryDate,
    required this.purchaseItemId,
    required this.qtyReceived,
    required this.qtyRemaining,
    required this.unitCost,
    required this.costKnown,
    required this.mrpPaise,
    required this.pricePaise,
  });

  /// Display arithmetic only (not sent by the server).
  int get qtySold => qtyReceived - qtyRemaining;

  factory LotRow.fromJson(Map<String, dynamic> j) => LotRow(
        id: _s(j['id']),
        productId: _s(j['productId']),
        productName: _s(j['productName']),
        source: _s(j['source']),
        batchNo: _s(j['batchNo']),
        receivedAt: _sN(j['receivedAt']),
        expiryDate: _sN(j['expiryDate']),
        purchaseItemId: _sN(j['purchaseItemId']),
        qtyReceived: _i(j['qtyReceived']),
        qtyRemaining: _i(j['qtyRemaining']),
        unitCost: _d(j['unitCost']),
        costKnown: j['costKnown'] != false,
        mrpPaise: _iN(j['mrpPaise']),
        pricePaise: _iN(j['pricePaise']),
      );
}

class LotPage {
  final List<LotRow> items;
  final LotPageInfo info;
  const LotPage(this.items, this.info);

  factory LotPage.fromJson(Map<String, dynamic> j) => LotPage([
        for (final e in (j['items'] as List? ?? const []))
          LotRow.fromJson(Map<String, dynamic>.from(e as Map))
      ], LotPageInfo.fromJson(j));
}

class LotSettings {
  final String variantId;
  final bool lotPriced, trackExpiry;
  const LotSettings(this.variantId, this.lotPriced, this.trackExpiry);

  factory LotSettings.fromJson(Map<String, dynamic> j) => LotSettings(
      _s(j['variantId']), j['lotPriced'] == true, j['trackExpiry'] == true);
}

class ExpiringResult {
  final int days;
  final String until;
  final bool truncated;
  final List<LotRow> lots;
  const ExpiringResult(this.days, this.until, this.truncated, this.lots);

  factory ExpiringResult.fromJson(Map<String, dynamic> j) =>
      ExpiringResult(_i(j['days']), _s(j['until']), j['truncated'] == true, [
        for (final e in (j['lots'] as List? ?? const []))
          LotRow.fromJson(Map<String, dynamic>.from(e as Map))
      ]);
}

class WriteOffResult {
  final String lotId;
  final int unitsWrittenOff;
  const WriteOffResult(this.lotId, this.unitsWrittenOff);

  factory WriteOffResult.fromJson(Map<String, dynamic> j) =>
      WriteOffResult(_s(j['lotId']), _i(j['unitsWrittenOff']));
}

class ValuationTotal {
  final int qty, valuePaise, costUnknownProducts, costUnknownQty;
  const ValuationTotal(
      this.qty, this.valuePaise, this.costUnknownProducts, this.costUnknownQty);

  factory ValuationTotal.fromJson(Map<String, dynamic> j) => ValuationTotal(
      _i(j['qty']),
      _i(j['valuePaise']),
      _i(j['costUnknownProducts']),
      _i(j['costUnknownQty']));
}

class ValuationRow {
  final String id, name;
  final int qty, valuePaise, costUnknownQty;
  const ValuationRow(
      this.id, this.name, this.qty, this.valuePaise, this.costUnknownQty);

  factory ValuationRow.fromJson(Map<String, dynamic> j) => ValuationRow(
      _s(j['id']),
      _s(j['name']),
      _i(j['qty']),
      _i(j['valuePaise']),
      _i(j['costUnknownQty']));
}

class Valuation {
  final ValuationTotal total;
  final List<ValuationRow> rows;
  final LotPageInfo info;
  const Valuation(this.total, this.rows, this.info);

  factory Valuation.fromJson(Map<String, dynamic> j) {
    final r = Map<String, dynamic>.from((j['rows'] as Map?) ?? const {});
    return Valuation(
        ValuationTotal.fromJson(
            Map<String, dynamic>.from((j['total'] as Map?) ?? const {})),
        [
          for (final e in (r['items'] as List? ?? const []))
            ValuationRow.fromJson(Map<String, dynamic>.from(e as Map))
        ],
        LotPageInfo.fromJson(r));
  }
}

class MarginRow {
  final String key, name;
  final int revenuePaise, costPaise, marginPaise, uncostedLines;

  /// null when revenue is 0.
  final double? marginPercent;
  const MarginRow({
    required this.key,
    required this.name,
    required this.revenuePaise,
    required this.costPaise,
    required this.marginPaise,
    required this.uncostedLines,
    required this.marginPercent,
  });

  factory MarginRow.fromJson(Map<String, dynamic> j) => MarginRow(
        key: _s(j['key']),
        name: _s(j['name']),
        revenuePaise: _i(j['revenuePaise']),
        costPaise: _i(j['costPaise']),
        marginPaise: _i(j['marginPaise']),
        uncostedLines: _i(j['uncostedLines']),
        marginPercent: (j['marginPercent'] as num?)?.toDouble(),
      );
}

class MarginPage {
  final List<MarginRow> items;
  final LotPageInfo info;
  const MarginPage(this.items, this.info);

  factory MarginPage.fromJson(Map<String, dynamic> j) => MarginPage([
        for (final e in (j['items'] as List? ?? const []))
          MarginRow.fromJson(Map<String, dynamic>.from(e as Map))
      ], LotPageInfo.fromJson(j));
}

class LotDrift {
  final String productId, name;
  final int onHand, inLots;
  const LotDrift(this.productId, this.name, this.onHand, this.inLots);

  factory LotDrift.fromJson(Map<String, dynamic> j) => LotDrift(
      _s(j['productId']), _s(j['name']), _i(j['onHand']), _i(j['inLots']));
}

class LotCheck {
  final List<LotDrift> drifts;
  final bool truncated;
  const LotCheck(this.drifts, this.truncated);

  factory LotCheck.fromJson(Map<String, dynamic> j) => LotCheck([
        for (final e in (j['drifts'] as List? ?? const []))
          LotDrift.fromJson(Map<String, dynamic>.from(e as Map))
      ], j['truncated'] == true);
}
