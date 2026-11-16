/// DTOs for the flash-sales module (`40-flash-sales.md`).
///
/// Money is integer paise. Instants are parsed with [parseIst] so every
/// [DateTime] here is an India wall-clock value (UTC-flagged).
library;

import '../ist.dart';

int _i(dynamic v, [int d = 0]) => (v as num?)?.toInt() ?? d;
int? _iN(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

/// Serialises an India wall-clock value (see `ist.dart`) as the UTC instant
/// the backend expects (`2026-11-09T04:30:00.000Z`).
String istToWire(DateTime ist) =>
    DateTime.utc(ist.year, ist.month, ist.day, ist.hour, ist.minute, ist.second)
        .subtract(istOffset)
        .toIso8601String();

/// Server-vs-device clock offset learned from `now` of the flash lists, so
/// countdowns never trust the phone clock (doc: "Countdown").
class FlashClock {
  FlashClock._();
  static Duration offset = Duration.zero;

  /// Server "now" (UTC instant).
  static DateTime serverNowUtc() => DateTime.now().toUtc().add(offset);

  static void sync(DateTime? serverNowUtc) {
    if (serverNowUtc == null) return;
    offset = serverNowUtc.toUtc().difference(DateTime.now().toUtc());
  }

  /// Seconds from the (server-corrected) clock until [endIst] (an IST value
  /// from [parseIst]); never negative.
  static int secondsUntil(DateTime? endIst) {
    if (endIst == null) return 0;
    final endUtc = endIst.subtract(istOffset);
    final s = endUtc.difference(serverNowUtc()).inSeconds;
    return s < 0 ? 0 : s;
  }
}

/// `Offer` object carried as `flash` on products / variants.
class FlashOffer {
  final String flashSaleId;
  final String name;
  final int listPricePaise;
  final int salePricePaise;
  final int discountPercent;

  /// null = no cap, 0 = sold out.
  final int? unitsLeft;

  /// 0 = no limit.
  final int perCustomerLimit;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const FlashOffer({
    this.flashSaleId = '',
    this.name = '',
    this.listPricePaise = 0,
    this.salePricePaise = 0,
    this.discountPercent = 0,
    this.unitsLeft,
    this.perCustomerLimit = 0,
    this.startsAt,
    this.endsAt,
  });

  FlashOffer.fromJson(Map<String, dynamic> j)
      : flashSaleId = _s(j['flashSaleId']),
        name = _s(j['name']),
        listPricePaise = _i(j['listPricePaise']),
        salePricePaise = _i(j['salePricePaise']),
        discountPercent = _i(j['discountPercent']),
        unitsLeft = _iN(j['unitsLeft']),
        perCustomerLimit = _i(j['perCustomerLimit']),
        startsAt = parseIst(j['startsAt']?.toString()),
        endsAt = parseIst(j['endsAt']?.toString());

  static FlashOffer? maybe(dynamic raw) {
    if (raw is! Map) return null;
    final o = FlashOffer.fromJson(Map<String, dynamic>.from(raw));
    return o.salePricePaise > 0 ? o : null;
  }

  bool get soldOut => unitsLeft != null && unitsLeft! <= 0;
  bool get lowStock => unitsLeft != null && unitsLeft! > 0 && unitsLeft! <= 5;
}

// ---------------------------------------------------------------------------
// Public lists
// ---------------------------------------------------------------------------

class FlashPublicItem {
  final String productId;
  final String nameEn;
  final String nameGu;
  final String imageUrl;
  final String unitLabel;
  final int listPricePaise;
  final int salePricePaise;
  final int discountPercent;
  final int? unitsLeft;
  final int perCustomerLimit;
  final bool inStock;

  FlashPublicItem.fromJson(Map<String, dynamic> j)
      : productId = _s(j['productId']),
        nameEn = _s(j['nameEn']),
        nameGu = _s(j['nameGu']),
        imageUrl = _s(j['imageUrl']),
        unitLabel = _s(j['unitLabel']),
        listPricePaise = _i(j['listPricePaise']),
        salePricePaise = _i(j['salePricePaise']),
        discountPercent = _i(j['discountPercent']),
        unitsLeft = _iN(j['unitsLeft']),
        perCustomerLimit = _i(j['perCustomerLimit']),
        inStock = j['inStock'] as bool? ?? true;

  bool get soldOut => unitsLeft != null && unitsLeft! <= 0;
}

class FlashPublicSale {
  final String id;
  final String name;
  final String description;
  final String bannerText;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int secondsToEnd;
  final int secondsToStart;
  final List<FlashPublicItem> items;

  /// When this response arrived; countdowns subtract the elapsed time.
  final Stopwatch _age = Stopwatch()..start();

  FlashPublicSale.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        description = _s(j['description']),
        bannerText = _s(j['bannerText']),
        startsAt = parseIst(j['startsAt']?.toString()),
        endsAt = parseIst(j['endsAt']?.toString()),
        secondsToEnd = _i(j['secondsToEnd']),
        secondsToStart = _i(j['secondsToStart']),
        items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => FlashPublicItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();

  int get remainingToEnd {
    final r = secondsToEnd - _age.elapsed.inSeconds;
    return r < 0 ? 0 : r;
  }

  int get remainingToStart {
    final r = secondsToStart - _age.elapsed.inSeconds;
    return r < 0 ? 0 : r;
  }

  String get title => bannerText.isNotEmpty ? bannerText : name;
}

class FlashPublicDto {
  final DateTime? now;
  final List<FlashPublicSale> sales;

  FlashPublicDto.fromJson(Map<String, dynamic> j)
      : now = DateTime.tryParse(_s(j['now'])),
        sales = (j['sales'] as List? ?? [])
            .whereType<Map>()
            .map((e) => FlashPublicSale.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

// ---------------------------------------------------------------------------
// Staff
// ---------------------------------------------------------------------------

class FlashItemView {
  final String id;
  final String productId;
  final String nameEn;
  final int listPricePaise;
  final int? salePricePaise;
  final int? discountPercent;
  final String? discountKind;
  final int discountValue;
  final String effectiveKind;
  final int effectiveValue;
  final int? maxQty;
  final int soldQty;
  final int? unitsLeft;
  final int? perCustomerLimit;
  final int effectivePerCustomerLimit;

  FlashItemView.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        productId = _s(j['productId']),
        nameEn = _s(j['nameEn']),
        listPricePaise = _i(j['listPricePaise']),
        salePricePaise = _iN(j['salePricePaise']),
        discountPercent = _iN(j['discountPercent']),
        discountKind = j['discountKind']?.toString(),
        discountValue = _i(j['discountValue']),
        effectiveKind = _s(j['effectiveKind']),
        effectiveValue = _i(j['effectiveValue']),
        maxQty = _iN(j['maxQty']),
        soldQty = _i(j['soldQty']),
        unitsLeft = _iN(j['unitsLeft']),
        perCustomerLimit = _iN(j['perCustomerLimit']),
        effectivePerCustomerLimit = _i(j['effectivePerCustomerLimit']);

  /// Own discount override (null/NONE = follows the sale).
  bool get hasOwnDiscount =>
      discountKind != null && discountKind!.isNotEmpty && discountKind != 'NONE';

  /// No units sold yet, so every setting may still change.
  bool get untouched => soldQty == 0;
}

class FlashSaleView {
  final String id;
  final String name;
  final String description;
  final String bannerText;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String channel;
  final String discountKind;
  final int discountValue;
  final int perCustomerLimit;
  final List<FlashItemView> items;

  FlashSaleView.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        description = _s(j['description']),
        bannerText = _s(j['bannerText']),
        status = _s(j['status']).toUpperCase(),
        startsAt = parseIst(j['startsAt']?.toString()),
        endsAt = parseIst(j['endsAt']?.toString()),
        channel = _s(j['channel']).isEmpty ? 'BOTH' : _s(j['channel']),
        discountKind =
            _s(j['discountKind']).isEmpty ? 'NONE' : _s(j['discountKind']),
        discountValue = _i(j['discountValue']),
        perCustomerLimit = _i(j['perCustomerLimit']),
        items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => FlashItemView.fromJson(Map<String, dynamic>.from(e)))
            .toList();

  bool get isScheduled => status == 'SCHEDULED';
  bool get isActive => status == 'ACTIVE';
  bool get isClosed => status == 'ENDED' || status == 'CANCELLED';
}

class FlashSaleRow {
  final String id;
  final String name;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String channel;
  final int itemCount;

  FlashSaleRow.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        status = _s(j['status']).toUpperCase(),
        startsAt = parseIst(j['startsAt']?.toString()),
        endsAt = parseIst(j['endsAt']?.toString()),
        channel = _s(j['channel']),
        itemCount = j['items'] is num ? _i(j['items']) : 0;
}

class FlashSalePage {
  final List<FlashSaleRow> items;
  final int page;
  final int size;
  final int total;

  FlashSalePage.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => FlashSaleRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = _i(j['page']),
        size = _i(j['size']),
        total = _i(j['total']);
}

class FlashItemReport {
  final String productId;
  final String nameEn;
  final int units;
  final int revenuePaise;
  final int discountPaise;
  final int? maxQty;
  final double? sellThroughPercent;

  FlashItemReport.fromJson(Map<String, dynamic> j)
      : productId = _s(j['productId']),
        nameEn = _s(j['nameEn']),
        units = _i(j['units']),
        revenuePaise = _i(j['revenuePaise']),
        discountPaise = _i(j['discountPaise']),
        maxQty = _iN(j['maxQty']),
        sellThroughPercent = (j['sellThroughPercent'] as num?)?.toDouble();
}

class FlashChannelReport {
  final String channel;
  final int units;
  final int revenuePaise;
  final int discountPaise;

  FlashChannelReport.fromJson(Map<String, dynamic> j)
      : channel = _s(j['channel']),
        units = _i(j['units']),
        revenuePaise = _i(j['revenuePaise']),
        discountPaise = _i(j['discountPaise']);
}

class FlashHourReport {
  final String hour;
  final int units;
  final int revenuePaise;

  FlashHourReport.fromJson(Map<String, dynamic> j)
      : hour = _s(j['hour']),
        units = _i(j['units']),
        revenuePaise = _i(j['revenuePaise']);
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) f) =>
    (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => f(Map<String, dynamic>.from(e)))
        .toList();

class FlashSaleReport {
  final String saleId;
  final String name;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int unitsSold;
  final int orders;
  final int bills;
  final int revenuePaise;
  final int discountPaise;
  final double avgDiscountPercent;
  final int customers;
  final double? sellThroughPercent;
  final List<FlashItemReport> byItem;
  final List<FlashChannelReport> byChannel;
  final List<FlashHourReport> byHour;

  FlashSaleReport.fromJson(Map<String, dynamic> j)
      : saleId = _s(j['saleId']),
        name = _s(j['name']),
        status = _s(j['status']).toUpperCase(),
        startsAt = parseIst(j['startsAt']?.toString()),
        endsAt = parseIst(j['endsAt']?.toString()),
        unitsSold = _i(j['unitsSold']),
        orders = _i(j['orders']),
        bills = _i(j['bills']),
        revenuePaise = _i(j['revenuePaise']),
        discountPaise = _i(j['discountPaise']),
        avgDiscountPercent = _d(j['avgDiscountPercent']),
        customers = _i(j['customers']),
        sellThroughPercent = (j['sellThroughPercent'] as num?)?.toDouble(),
        byItem = _list(j['byItem'], FlashItemReport.fromJson),
        byChannel = _list(j['byChannel'], FlashChannelReport.fromJson),
        byHour = _list(j['byHour'], FlashHourReport.fromJson);
}

class FlashSaleSummary {
  final String saleId;
  final String name;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int unitsSold;
  final int orders;
  final int bills;
  final int revenuePaise;
  final int discountPaise;
  final double avgDiscountPercent;
  final int customers;

  FlashSaleSummary.fromJson(Map<String, dynamic> j)
      : saleId = _s(j['saleId']),
        name = _s(j['name']),
        status = _s(j['status']).toUpperCase(),
        startsAt = parseIst(j['startsAt']?.toString()),
        endsAt = parseIst(j['endsAt']?.toString()),
        unitsSold = _i(j['unitsSold']),
        orders = _i(j['orders']),
        bills = _i(j['bills']),
        revenuePaise = _i(j['revenuePaise']),
        discountPaise = _i(j['discountPaise']),
        avgDiscountPercent = _d(j['avgDiscountPercent']),
        customers = _i(j['customers']);
}

class FlashPeriodReport {
  final String from;
  final String to;
  final int sales;
  final int unitsSold;
  final int orders;
  final int bills;
  final int revenuePaise;
  final int discountPaise;
  final double avgDiscountPercent;
  final int customers;
  final List<FlashSaleSummary> bySale;
  final List<FlashItemReport> bestItems;

  FlashPeriodReport.fromJson(Map<String, dynamic> j)
      : from = _s(j['from']),
        to = _s(j['to']),
        sales = _i(j['sales']),
        unitsSold = _i(j['unitsSold']),
        orders = _i(j['orders']),
        bills = _i(j['bills']),
        revenuePaise = _i(j['revenuePaise']),
        discountPaise = _i(j['discountPaise']),
        avgDiscountPercent = _d(j['avgDiscountPercent']),
        customers = _i(j['customers']),
        bySale = _list(j['bySale'], FlashSaleSummary.fromJson),
        bestItems = _list(j['bestItems'], FlashItemReport.fromJson);
}

// ---------------------------------------------------------------------------
// Request drafts
// ---------------------------------------------------------------------------

/// One product line of the create form / add-item sheet / item edit.
class FlashItemDraft {
  String productId;
  String name;
  int listPricePaise;

  /// `''`/`NONE` = follow the sale's default.
  String discountKind;

  /// PERCENT: whole percent; FIXED_PRICE: paise.
  int discountValue;
  int? maxQty;

  /// null = follow the sale.
  int? perCustomerLimit;

  FlashItemDraft({
    required this.productId,
    this.name = '',
    this.listPricePaise = 0,
    this.discountKind = 'NONE',
    this.discountValue = 0,
    this.maxQty,
    this.perCustomerLimit,
  });

  factory FlashItemDraft.fromView(FlashItemView v) => FlashItemDraft(
        productId: v.productId,
        name: v.nameEn,
        listPricePaise: v.listPricePaise,
        discountKind: v.hasOwnDiscount ? v.discountKind! : 'NONE',
        discountValue: v.hasOwnDiscount ? v.discountValue : 0,
        maxQty: v.maxQty,
        perCustomerLimit: v.perCustomerLimit,
      );

  bool get hasOwn => discountKind != 'NONE' && discountKind.isNotEmpty;

  /// Body of `POST /items`, an entry of create `items[]` and `PUT /items/{id}`
  /// (the PUT replaces the whole item, so the full state is always sent).
  Map<String, dynamic> toJson({bool withProduct = true}) => {
        if (withProduct) 'productId': productId,
        if (hasOwn) 'discountKind': discountKind,
        if (hasOwn) 'discountValue': discountValue,
        if (maxQty != null) 'maxQty': maxQty,
        if (perCustomerLimit != null) 'perCustomerLimit': perCustomerLimit,
      };
}
