import '../validators.dart';

/// Wire models of the GST and HSN master (`GET /gst/*`, see the GST master
/// API contract). All rates are percentages as JSON numbers (5, 18, 0.25).

double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

String _str(dynamic v) => v == null ? '' : '$v'.trim();

bool? _bool(dynamic v) => v is bool ? v : null;

/// One rate row of the master (a `best` / `choices` / `alternatives` entry of
/// `/gst/suggest`, or an item of `/gst/hsn`).
class GstHsnRow {
  final String rowId;
  final String hsn;
  final String description;

  /// `classificationConditions` (only on `/gst/hsn` rows).
  final String conditions;

  /// Total (IGST) percent; null when the server sent none.
  final double? rate;
  final double cessRate;

  /// TAXABLE / NIL / EXEMPT / NON_GST.
  final String taxType;

  /// VERIFIED or VERIFY_PRODUCT.
  final String status;

  /// ANY, PACKED_LABELLED, LOOSE, PRICE_UPTO_2500 ... (server `condition`).
  final String conditionKey;
  final String conditionLabel;
  final String chapter;
  final String tariffDescription;
  final String schedule;
  final String notification;
  final String sourceReference;

  /// yyyy-mm-dd.
  final String effectiveFrom;
  final String note;
  final String matchedName;
  final double score;

  /// `acceptedForBilling` when the server states it on the row, else null.
  final bool? acceptedForBilling;

  const GstHsnRow({
    this.rowId = '',
    required this.hsn,
    required this.description,
    this.conditions = '',
    required this.rate,
    this.cessRate = 0,
    required this.taxType,
    required this.status,
    this.conditionKey = 'ANY',
    this.conditionLabel = '',
    this.chapter = '',
    this.tariffDescription = '',
    this.schedule = '',
    this.notification = '',
    this.sourceReference = '',
    this.effectiveFrom = '',
    this.note = '',
    this.matchedName = '',
    this.score = 0,
    this.acceptedForBilling,
  });

  factory GstHsnRow.fromJson(Map<String, dynamic> j) {
    final desc = _str(j['description']);
    return GstHsnRow(
      rowId: _str(j['rowId']),
      hsn: _str(j['hsn']),
      description: desc.isNotEmpty ? desc : _str(j['productDescription']),
      conditions: _str(j['classificationConditions']),
      rate: _num(j['gstPercent']) ?? _num(j['igstRate']),
      cessRate: _num(j['cessRate']) ?? 0,
      taxType: _str(j['taxType']),
      status: _str(j['verification']),
      conditionKey: _str(j['condition']).isEmpty ? 'ANY' : _str(j['condition']),
      conditionLabel: _str(j['conditionLabel']),
      chapter: _str(j['chapter']),
      tariffDescription: _str(j['tariffDescription']),
      schedule: _str(j['schedule']),
      notification: _str(j['notificationReference']),
      sourceReference: _str(j['sourceReference']),
      effectiveFrom: _str(j['effectiveFrom']),
      note: _str(j['note']),
      matchedName: _str(j['matchedName']),
      score: _num(j['score']) ?? 0,
      acceptedForBilling: _bool(j['acceptedForBilling']),
    );
  }

  bool get verified => status == 'VERIFIED';

  /// A price-band row (`PRICE_UPTO_2500` ...); only used to hint that the
  /// price decides the band.
  bool get isPriceRow => conditionKey.startsWith('PRICE_');
}

/// A selectable rate from `GET /gst/rates`.
class GstRateOption {
  final String code; // GST_5
  final double percent;
  final String taxType; // TAXABLE / NIL / EXEMPT / NON_GST
  final bool isSpecial;

  /// `acceptedForBilling`: false for a rate the billing engine cannot store.
  final bool serverAccepts;

  const GstRateOption({
    required this.code,
    required this.percent,
    required this.taxType,
    required this.isSpecial,
    required this.serverAccepts,
  });

  factory GstRateOption.fromJson(Map<String, dynamic> j) {
    final p = _num(j['gstPercent']) ?? _num(j['igstRate']) ?? 0;
    final code = _str(j['code']);
    final slab = p == p.roundToDouble() && Validators.gstSlabs.contains(p.round());
    return GstRateOption(
      code: code,
      percent: p,
      taxType: _str(j['taxType']),
      isSpecial: code.contains('SPECIAL'),
      serverAccepts: _bool(j['acceptedForBilling']) ?? slab,
    );
  }

  /// "5%", "0.25%", "1.5%".
  String get label => '${fmtPercent(percent)}%';
}

/// One way a product can be taxed (packed / loose, price band ...).
class GstChoice {
  final String key; // PACKED_LABELLED
  final String label; // "Packed and labelled"
  final double? rate;
  final GstHsnRow row;
  const GstChoice(this.key, this.label, this.rate, this.row);
}

/// What the master suggests for a product name (one `best` / alternative).
class GstSuggestion {
  final String hsn;

  /// Null when the server gave no rate.
  final double? ratePercent;
  final String taxType;

  /// "Basmati Rice -> HSN 1006, 5%".
  final String reason;

  /// VERIFIED / VERIFY_PRODUCT.
  final String verification;
  final String description;
  final String matchedName;

  /// Notification, e.g. "09/2025-Central Tax (Rate)"; empty when unknown.
  final String notification;
  final String sourceReference;

  /// yyyy-mm-dd; empty when unknown.
  final String effectiveFrom;
  final String conditionKey;
  final String conditionLabel;
  final String note;

  /// `acceptedForBilling` of the row when the server states it.
  final bool? acceptedForBilling;

  /// Other conditions of the same HSN (two or more, default first); empty
  /// when the rate is unambiguous.
  final List<GstChoice> choices;

  /// Other likely HSN matches, best first.
  final List<GstSuggestion> alternatives;

  const GstSuggestion({
    required this.hsn,
    required this.ratePercent,
    required this.taxType,
    required this.reason,
    required this.verification,
    required this.description,
    required this.matchedName,
    this.notification = '',
    this.sourceReference = '',
    this.effectiveFrom = '',
    this.conditionKey = '',
    this.conditionLabel = '',
    this.note = '',
    this.acceptedForBilling,
    this.choices = const [],
    this.alternatives = const [],
  });

  factory GstSuggestion.fromRow(GstHsnRow r,
      {List<GstChoice> choices = const [],
      List<GstSuggestion> alternatives = const []}) {
    final name = r.matchedName.isNotEmpty ? r.matchedName : r.description;
    final rate = r.rate;
    return GstSuggestion(
      hsn: r.hsn,
      ratePercent: rate,
      taxType: r.taxType,
      reason: rate == null
          ? '$name -> HSN ${r.hsn}'
          : '$name -> HSN ${r.hsn}, ${fmtPercent(rate)}%',
      verification: r.status,
      description: r.description,
      matchedName: name,
      notification: r.notification,
      sourceReference: r.sourceReference,
      effectiveFrom: r.effectiveFrom,
      conditionKey: r.conditionKey == 'ANY' ? '' : r.conditionKey,
      conditionLabel: r.conditionLabel,
      note: r.note,
      acceptedForBilling: r.acceptedForBilling,
      choices: choices,
      alternatives: alternatives,
    );
  }

  /// Parses the `/gst/suggest` body; null when `best` is null (no match).
  static GstSuggestion? fromResponse(Map<String, dynamic> j) {
    final best = j['best'];
    if (best is! Map) return null;
    final bestRow = GstHsnRow.fromJson(Map<String, dynamic>.from(best));
    if (bestRow.hsn.isEmpty) return null;

    List<GstHsnRow> rows(dynamic v) => [
          if (v is List)
            for (final e in v)
              if (e is Map) GstHsnRow.fromJson(Map<String, dynamic>.from(e))
        ];

    // The contract's `choices` are the conditions of the same HSN; make sure
    // the default row is part of the list (once) so the picker can show all.
    final others = rows(j['choices']).where((r) => r.hsn.isNotEmpty).toList();
    var choices = <GstChoice>[];
    if (others.isNotEmpty) {
      bool same(GstHsnRow a, GstHsnRow b) => a.rowId.isNotEmpty && b.rowId.isNotEmpty
          ? a.rowId == b.rowId
          : (a.hsn == b.hsn && a.conditionKey == b.conditionKey);
      final all = <GstHsnRow>[bestRow];
      for (final r in others) {
        if (!all.any((x) => same(x, r))) all.add(r);
      }
      if (all.length > 1) {
        choices = [
          for (final r in all) GstChoice(r.conditionKey, r.conditionLabel, r.rate, r)
        ];
      }
    }
    final alts = [
      for (final r in rows(j['alternatives']))
        if (r.hsn.isNotEmpty) GstSuggestion.fromRow(r)
    ];
    return GstSuggestion.fromRow(bestRow, choices: choices, alternatives: alts);
  }

  bool get verified => verification == 'VERIFIED';

  /// The rate as a whole number the billing engine accepts, else null.
  int? get serverRate {
    final r = ratePercent;
    if (r == null || acceptedForBilling == false || r != r.roundToDouble()) {
      return null;
    }
    final i = r.round();
    return Validators.gstSlabs.contains(i) ? i : null;
  }

  GstSuggestion copyWith({
    double? ratePercent,
    String? conditionKey,
    String? conditionLabel,
    String? notification,
    String? sourceReference,
    String? effectiveFrom,
    String? verification,
    String? taxType,
    String? description,
    String? reason,
    bool? acceptedForBilling,
    List<GstSuggestion>? alternatives,
  }) =>
      GstSuggestion(
        hsn: hsn,
        ratePercent: ratePercent ?? this.ratePercent,
        taxType: taxType ?? this.taxType,
        reason: reason ?? this.reason,
        verification: verification ?? this.verification,
        description: description ?? this.description,
        matchedName: matchedName,
        notification: notification ?? this.notification,
        sourceReference: sourceReference ?? this.sourceReference,
        effectiveFrom: effectiveFrom ?? this.effectiveFrom,
        conditionKey: conditionKey ?? this.conditionKey,
        conditionLabel: conditionLabel ?? this.conditionLabel,
        note: note,
        acceptedForBilling: acceptedForBilling ?? this.acceptedForBilling,
        choices: choices,
        alternatives: alternatives ?? this.alternatives,
      );
}

/// Entry for an HSN picker list.
class GstHsnHit {
  final String hsn;
  final String description;
  final double? rate;
  final String status;
  final String conditionKey;
  final String conditionLabel;
  final String notification;
  final String effectiveFrom;
  const GstHsnHit(
    this.hsn,
    this.description,
    this.rate,
    this.status, {
    this.conditionKey = '',
    this.conditionLabel = '',
    this.notification = '',
    this.effectiveFrom = '',
  });

  factory GstHsnHit.fromRow(GstHsnRow h) => GstHsnHit(
        h.hsn,
        h.description,
        h.rate,
        h.status,
        conditionKey: h.conditionKey,
        conditionLabel: h.conditionLabel,
        notification: h.notification,
        effectiveFrom: h.effectiveFrom,
      );
}

/// `GET /gst/hsn` page.
class GstHsnPage {
  final List<GstHsnRow> items;
  final int page;
  final int size;
  final int total;

  /// False when [total] is a capped count (show "10,000+").
  final bool totalExact;
  final bool hasMore;

  const GstHsnPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
    required this.totalExact,
    required this.hasMore,
  });

  factory GstHsnPage.fromJson(Map<String, dynamic> j) {
    final items = [
      if (j['items'] is List)
        for (final e in j['items'] as List)
          if (e is Map) GstHsnRow.fromJson(Map<String, dynamic>.from(e))
    ];
    return GstHsnPage(
      items: items,
      page: (_num(j['page']) ?? 0).toInt(),
      size: (_num(j['size']) ?? items.length).toInt(),
      total: (_num(j['total']) ?? items.length).toInt(),
      totalExact: _bool(j['totalExact']) ?? true,
      hasMore: _bool(j['hasMore']) ?? false,
    );
  }
}

/// "5", "0.25", "1.5" (no trailing zeros).
String fmtPercent(double v) {
  if (v == v.roundToDouble()) return '${v.round()}';
  var s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
