/// Data-transfer objects mirroring the backend OpenAPI (`/v3/api-docs`)
/// schemas. Every field name matches the wire format exactly so the JSON
/// mapping stays trivially auditable against Swagger.
///
/// Conventions on the wire:
///  * money is **paise** (`int64`) — e.g. `pricePaise: 24900` = ₹249
///  * dates are ISO-8601 strings
///  * statuses are SCREAMING_SNAKE_CASE (e.g. `OUT_FOR_DELIVERY`)
///  * ids are UUID strings
library;

import '../ist.dart';
import 'pos_dto.dart';
import 'flash_dto.dart';

// ---------------------------------------------------------------------------
// Auth / user
// ---------------------------------------------------------------------------

class UserDto {
  String? id;
  String? email;
  String? name;
  String? mobile;
  String? role;

  UserDto({this.id, this.email, this.name, this.mobile, this.role});

  UserDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        email = j['email']?.toString(),
        name = j['name']?.toString(),
        mobile = j['mobile']?.toString(),
        role = j['role']?.toString();

  bool get isAdmin => (role ?? '').toUpperCase() == 'ADMIN';
}

class AuthResultDto {
  String? accessToken;
  String? refreshToken;
  int expiresInSeconds;
  UserDto? user;

  AuthResultDto({this.accessToken, this.refreshToken, this.expiresInSeconds = 0, this.user});

  AuthResultDto.fromJson(Map<String, dynamic> j)
      : accessToken = j['accessToken']?.toString(),
        refreshToken = j['refreshToken']?.toString(),
        expiresInSeconds = (j['expiresInSeconds'] as num?)?.toInt() ?? 0,
        user = j['user'] is Map
            ? UserDto.fromJson(Map<String, dynamic>.from(j['user'] as Map))
            : null;
}

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

class CategoryDto {
  String? id;
  String? nameEn;
  String? nameGu;
  String? imageUrl;
  int sortOrder;

  /// Only the admin list carries it; the public list has active rows only.
  bool active;

  CategoryDto(
      {this.id,
      this.nameEn,
      this.nameGu,
      this.imageUrl,
      this.sortOrder = 0,
      this.active = true});

  CategoryDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        nameEn = j['nameEn']?.toString(),
        nameGu = j['nameGu']?.toString(),
        imageUrl = j['imageUrl']?.toString(),
        sortOrder = (j['sortOrder'] as num?)?.toInt() ?? 0,
        active = j['active'] as bool? ?? true;
}

class AdminProductDto {
  String? id;
  String? categoryId;
  String? nameEn;
  String? nameGu;
  String? description;
  int mrpPaise;
  int pricePaise;
  String? unit;
  String? packSize;
  String? imageUrl;
  bool inStock;
  int qtyAvailable;
  bool hotSale;
  bool earnsCoins;
  bool coinRedeemable;
  int qtyOnHand;
  int lowThreshold;
  bool active;
  String? hotStart;
  String? hotEnd;
  String? productGroupId;
  double rating;
  int reviewCount;

  AdminProductDto({
    this.id,
    this.categoryId,
    this.nameEn,
    this.nameGu,
    this.description,
    this.mrpPaise = 0,
    this.pricePaise = 0,
    this.unit,
    this.packSize,
    this.imageUrl,
    this.inStock = false,
    this.qtyAvailable = 0,
    this.hotSale = false,
    this.earnsCoins = true,
    this.coinRedeemable = true,
    this.qtyOnHand = 0,
    this.lowThreshold = 0,
    this.active = true,
    this.hotStart,
    this.hotEnd,
    this.productGroupId,
    this.rating = 0,
    this.reviewCount = 0,
  });

  AdminProductDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        categoryId = j['categoryId']?.toString(),
        nameEn = j['nameEn']?.toString(),
        nameGu = j['nameGu']?.toString(),
        description = j['description']?.toString(),
        mrpPaise = (j['mrpPaise'] as num?)?.toInt() ?? 0,
        pricePaise = (j['pricePaise'] as num?)?.toInt() ?? 0,
        unit = j['unit']?.toString(),
        packSize = j['packSize']?.toString(),
        imageUrl = j['imageUrl']?.toString(),
        inStock = j['inStock'] as bool? ?? false,
        qtyAvailable = (j['qtyAvailable'] as num?)?.toInt() ?? 0,
        hotSale = j['hotSale'] as bool? ?? false,
        earnsCoins = j['earnsCoins'] as bool? ?? true,
        coinRedeemable = j['coinRedeemable'] as bool? ?? true,
        qtyOnHand = (j['qtyOnHand'] as num?)?.toInt() ?? 0,
        lowThreshold = (j['lowThreshold'] as num?)?.toInt() ?? 0,
        active = j['active'] as bool? ?? true,
        hotStart = j['hotStart']?.toString(),
        hotEnd = j['hotEnd']?.toString(),
        productGroupId = j['productGroupId']?.toString(),
        rating = (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount = (j['reviewCount'] as num?)?.toInt() ?? 0;
}

class PageAdminProductDto {
  List<AdminProductDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageAdminProductDto({this.items = const [], this.page = 0, this.size = 20, this.total = 0});

  PageAdminProductDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => AdminProductDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

class PosAttributesDto {
  String? productId;
  String? soldBy; // UNIT | WEIGHT
  String? plu;
  int gstPercent;
  String? hsn;
  bool posOnly;
  List<String> barcodes;

  PosAttributesDto({
    this.productId,
    this.soldBy,
    this.plu,
    this.gstPercent = 0,
    this.hsn,
    this.posOnly = false,
    this.barcodes = const [],
  });

  PosAttributesDto.fromJson(Map<String, dynamic> j)
      : productId = j['productId']?.toString(),
        soldBy = j['soldBy']?.toString(),
        plu = j['plu']?.toString(),
        gstPercent = (j['gstPercent'] as num?)?.toInt() ?? 0,
        hsn = j['hsn']?.toString(),
        posOnly = j['posOnly'] as bool? ?? false,
        barcodes = (j['barcodes'] as List? ?? []).map((e) => e.toString()).toList();
}

// ---------------------------------------------------------------------------
// Orders (admin view)
// ---------------------------------------------------------------------------

class AddressDto {
  String? id;
  String? label;
  String? line1;
  String? area;
  String? pincode;
  bool isDefault;

  /// Optional contact number (blank or 10 digits).
  String? phone;

  AddressDto({this.id, this.label, this.line1, this.area, this.pincode, this.isDefault = false, this.phone});

  AddressDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        label = j['label']?.toString(),
        line1 = j['line1']?.toString(),
        area = j['area']?.toString(),
        pincode = j['pincode']?.toString(),
        phone = j['phone']?.toString(),
        isDefault = j['isDefault'] as bool? ?? false;
}

class OrderItemDto {
  String? productId;
  int qty;

  /// This line's share of the order's coupon discount (0 outside the
  /// coupon's categories). Older orders have no field and read as 0.
  int couponDiscountPaise;

  /// Frozen at order time (`name`, `nameGu`, `unitLabel`, `unitPricePaise`,
  /// `lineTotalPaise`) so the order still reads right after the product is
  /// edited or hidden.
  String? name;
  String? nameGu;
  String? unitLabel;
  int unitPricePaise;
  int lineTotalPaise;

  /// Picture snapshotted when the order was placed (null for lines without).
  String? imageUrl;

  OrderItemDto({
    this.imageUrl,
    this.productId,
    this.qty = 0,
    this.couponDiscountPaise = 0,
    this.name,
    this.nameGu,
    this.unitLabel,
    this.unitPricePaise = 0,
    this.lineTotalPaise = 0,
  });

  OrderItemDto.fromJson(Map<String, dynamic> j)
      : productId = j['productId']?.toString(),
        name = j['name']?.toString(),
        nameGu = j['nameGu']?.toString(),
        unitLabel = j['unitLabel']?.toString(),
        imageUrl = j['imageUrl']?.toString(),
        unitPricePaise = (j['unitPricePaise'] as num?)?.toInt() ?? 0,
        lineTotalPaise = (j['lineTotalPaise'] as num?)?.toInt() ?? 0,
        qty = (j['qty'] as num?)?.toInt() ?? 0,
        couponDiscountPaise =
            (j['couponDiscountPaise'] as num?)?.toInt() ?? 0;
}

class StepDto {
  String? status;
  String? at;

  StepDto({this.status, this.at});

  StepDto.fromJson(Map<String, dynamic> j)
      : status = j['status']?.toString(),
        at = j['at']?.toString();
}

class AdminSummaryDto {
  String? id;
  String? orderNo;
  String? status;
  String? fulfilment;
  int totalPaise;
  int itemCount;
  String? placedAt;
  String? customerName;
  String? customerEmail;
  String? customerMobile;

  /// `CUSTOMER` / `SHOP` / `SYSTEM` and the machine reason, both null unless
  /// the order is cancelled.
  String? cancelledBy;
  String? cancelCode;

  AdminSummaryDto({
    this.cancelledBy,
    this.cancelCode,
    this.id,
    this.orderNo,
    this.status,
    this.fulfilment,
    this.totalPaise = 0,
    this.itemCount = 0,
    this.placedAt,
    this.customerName,
    this.customerEmail,
    this.customerMobile,
  });

  AdminSummaryDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        orderNo = j['orderNo']?.toString(),
        status = j['status']?.toString(),
        fulfilment = j['fulfilment']?.toString(),
        totalPaise = (j['totalPaise'] as num?)?.toInt() ?? 0,
        itemCount = (j['itemCount'] as num?)?.toInt() ?? 0,
        placedAt = j['placedAt']?.toString(),
        customerName = j['customerName']?.toString(),
        customerEmail = j['customerEmail']?.toString(),
        customerMobile = j['customerMobile']?.toString(),
        cancelledBy = j['cancelledBy']?.toString(),
        cancelCode = j['cancelCode']?.toString();

  DateTime? get placedDateTime => parseIst(placedAt ?? '');
}

class PageAdminSummaryDto {
  List<AdminSummaryDto> items;
  int page;
  int size;
  int total;

  /// `false` when [total] is capped at 10,000 ("10,000+"); null-safe default
  /// true for older servers.
  bool totalExact;

  /// Exact "is there another page" flag. Null when the server predates it.
  bool? hasMore;

  PageAdminSummaryDto({
    this.items = const [],
    this.page = 0,
    this.size = 20,
    this.total = 0,
    this.totalExact = true,
    this.hasMore,
  });

  PageAdminSummaryDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => AdminSummaryDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

class AdminViewDto {
  String? id;
  String? orderNo;
  String? status;
  String? fulfilment;
  String? paymentMethod;
  String? paymentStatus;
  List<OrderItemDto> items;
  int subtotalPaise;
  String? couponCode;
  int couponDiscountPaise;
  int coinsUsed;
  int coinDiscountPaise;
  int deliveryFeePaise;
  int totalPaise;
  int coinsEarned;
  AddressDto? address;
  List<StepDto> timeline;
  String? placedAt;
  String? slot;
  String? cancelReason;
  String? cancelledBy;
  String? cancelCode;

  /// ISO instant the server cancels an unpaid ONLINE order (PAYMENT_PENDING).
  String? paymentExpiresAt;
  String? customerName;
  String? customerEmail;
  String? customerMobile;

  /// The customer's coin balance as the backend left it after this order —
  /// adopted into the wallet so a just-placed order never shows stale coins.
  /// Null when the response predates the field.
  int? coinBalance;

  /// `paymentSession` — present only while the order is `PAYMENT_PENDING`:
  /// `{type:"RAZORPAY", payload:{keyId, razorpayOrderId, amountPaise,
  /// currency}}`. Null otherwise.
  PaymentSessionDto? paymentSession;

  AdminViewDto({
    this.paymentSession,
    this.id,
    this.orderNo,
    this.status,
    this.fulfilment,
    this.paymentMethod,
    this.paymentStatus,
    this.items = const [],
    this.subtotalPaise = 0,
    this.couponCode,
    this.couponDiscountPaise = 0,
    this.coinsUsed = 0,
    this.coinDiscountPaise = 0,
    this.deliveryFeePaise = 0,
    this.totalPaise = 0,
    this.coinsEarned = 0,
    this.address,
    this.timeline = const [],
    this.placedAt,
    this.slot,
    this.cancelReason,
    this.cancelledBy,
    this.cancelCode,
    this.paymentExpiresAt,
    this.customerName,
    this.customerEmail,
    this.customerMobile,
    this.coinBalance,
  });

  AdminViewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        orderNo = j['orderNo']?.toString(),
        status = j['status']?.toString(),
        fulfilment = j['fulfilment']?.toString(),
        paymentMethod = j['paymentMethod']?.toString(),
        paymentStatus = j['paymentStatus']?.toString(),
        items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => OrderItemDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        subtotalPaise = (j['subtotalPaise'] as num?)?.toInt() ?? 0,
        couponCode = j['couponCode']?.toString(),
        couponDiscountPaise = (j['couponDiscountPaise'] as num?)?.toInt() ?? 0,
        coinsUsed = (j['coinsUsed'] as num?)?.toInt() ?? 0,
        coinDiscountPaise = (j['coinDiscountPaise'] as num?)?.toInt() ?? 0,
        deliveryFeePaise = (j['deliveryFeePaise'] as num?)?.toInt() ?? 0,
        totalPaise = (j['totalPaise'] as num?)?.toInt() ?? 0,
        coinsEarned = (j['coinsEarned'] as num?)?.toInt() ?? 0,
        address = j['address'] is Map
            ? AddressDto.fromJson(Map<String, dynamic>.from(j['address'] as Map))
            : null,
        timeline = (j['timeline'] as List? ?? [])
            .whereType<Map>()
            .map((e) => StepDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        placedAt = j['placedAt']?.toString(),
        slot = j['slot']?.toString(),
        cancelReason = j['cancelReason']?.toString(),
        cancelledBy = j['cancelledBy']?.toString(),
        cancelCode = j['cancelCode']?.toString(),
        paymentExpiresAt = j['paymentExpiresAt']?.toString(),
        customerName = j['customerName']?.toString(),
        customerEmail = j['customerEmail']?.toString(),
        customerMobile = j['customerMobile']?.toString(),
        coinBalance = (j['coinBalance'] as num?)?.toInt(),
        paymentSession = j['paymentSession'] is Map
            ? PaymentSessionDto.fromJson(
                Map<String, dynamic>.from(j['paymentSession'] as Map))
            : null;

  DateTime? get placedDateTime => parseIst(placedAt ?? '');
}

/// `OrderView.paymentSession`: what the app needs to open Razorpay Checkout.
class PaymentSessionDto {
  String type;
  String keyId;
  String razorpayOrderId;
  int amountPaise;
  String currency;

  PaymentSessionDto({
    this.type = '',
    this.keyId = '',
    this.razorpayOrderId = '',
    this.amountPaise = 0,
    this.currency = 'INR',
  });

  PaymentSessionDto.fromJson(Map<String, dynamic> j)
      : type = j['type']?.toString() ?? '',
        keyId = (j['payload'] is Map ? j['payload']['keyId'] : null)
                ?.toString() ??
            '',
        razorpayOrderId =
            (j['payload'] is Map ? j['payload']['razorpayOrderId'] : null)
                    ?.toString() ??
                '',
        amountPaise = ((j['payload'] is Map ? j['payload']['amountPaise'] : null)
                    as num?)
                ?.toInt() ??
            0,
        currency = (j['payload'] is Map ? j['payload']['currency'] : null)
                ?.toString() ??
            'INR';

  bool get usable => keyId.isNotEmpty && razorpayOrderId.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

class DayDto {
  String? date;
  int salesPaise;

  DayDto({this.date, this.salesPaise = 0});

  DayDto.fromJson(Map<String, dynamic> j)
      : date = j['date']?.toString(),
        salesPaise = (j['salesPaise'] as num?)?.toInt() ?? 0;
}

class LowItemDto {
  String? productId;
  String? name;
  int qty;

  LowItemDto({this.productId, this.name, this.qty = 0});

  LowItemDto.fromJson(Map<String, dynamic> j)
      : productId = j['productId']?.toString(),
        name = j['name']?.toString(),
        qty = (j['qty'] as num?)?.toInt() ?? 0;
}

class DashboardDto {
  int salesTodayPaise;
  int ordersToday;
  int newOrders;
  int coinsIssuedToday;
  List<DayDto> last7Days;
  List<LowItemDto> lowStock;
  int posSalesTodayPaise;
  int posBillsToday;
  int posRefundsTodayPaise;

  /// Refunds given today on returned online orders (listed apart, not
  /// subtracted from `salesTodayPaise`).
  int onlineRefundsTodayPaise;

  /// Online orders in PLACED, CONFIRMED, PACKED, OUT_FOR_DELIVERY or
  /// READY_FOR_PICKUP (includes `newOrders`); null when the server omits it.
  int? needsAction;

  DashboardDto({
    this.salesTodayPaise = 0,
    this.ordersToday = 0,
    this.newOrders = 0,
    this.coinsIssuedToday = 0,
    this.last7Days = const [],
    this.lowStock = const [],
    this.posSalesTodayPaise = 0,
    this.posBillsToday = 0,
    this.posRefundsTodayPaise = 0,
    this.onlineRefundsTodayPaise = 0,
    this.needsAction,
  });

  DashboardDto.fromJson(Map<String, dynamic> j)
      : salesTodayPaise = (j['salesTodayPaise'] as num?)?.toInt() ?? 0,
        ordersToday = (j['ordersToday'] as num?)?.toInt() ?? 0,
        newOrders = (j['newOrders'] as num?)?.toInt() ?? 0,
        coinsIssuedToday = (j['coinsIssuedToday'] as num?)?.toInt() ?? 0,
        last7Days = (j['last7Days'] as List? ?? [])
            .whereType<Map>()
            .map((e) => DayDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        lowStock = (j['lowStock'] as List? ?? [])
            .whereType<Map>()
            .map((e) => LowItemDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        posSalesTodayPaise = (j['posSalesTodayPaise'] as num?)?.toInt() ?? 0,
        posBillsToday = (j['posBillsToday'] as num?)?.toInt() ?? 0,
        posRefundsTodayPaise = (j['posRefundsTodayPaise'] as num?)?.toInt() ?? 0,
        onlineRefundsTodayPaise =
            (j['onlineRefundsTodayPaise'] as num?)?.toInt() ?? 0,
        needsAction = (j['needsAction'] as num?)?.toInt();
}

// ---------------------------------------------------------------------------
// Coupons, coins, banners, shop, staff, settings
// ---------------------------------------------------------------------------

/// Reads a JSON array of strings, falling back to a single legacy field so
/// rows written before `categoryIds` existed still carry their category.
List<String> _stringList(Object? raw, [String? fallback]) {
  if (raw is List) {
    final out = <String>[];
    for (final e in raw) {
      final s = e?.toString();
      if (s != null && s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    // An empty list next to a legacy single id still means "that category"
    // (a backend that drops `categoryIds` but keeps `categoryId`).
    if (out.isNotEmpty || fallback == null || fallback.isEmpty) return out;
    return <String>[fallback];
  }
  final single = fallback ?? raw?.toString();
  return (single == null || single.isEmpty) ? const <String>[] : <String>[single];
}

class CouponDto {
  String? id;
  String? code;
  String? kind; // e.g. FLAT | PERCENT (backend-defined)
  int value;
  int minOrderPaise;
  int? maxDiscountPaise;
  String? categoryId;

  /// Every category the coupon covers (backend: `categoryIds`). Empty list =
  /// every category; [categoryId] is kept as the first entry for older
  /// readers.
  List<String> categoryIds;
  int perUserLimit;
  int totalLimit;
  int usedCount;
  String? startAt;
  String? endAt;
  bool active;
  bool? worksWithCoins;
  bool? firstOrderOnly;

  /// Item targeting: single packs / whole products, with names for display
  /// (from `appliesTo`), and the plain-language summary.
  List<String> productIds;
  List<String> productGroupIds;
  Map<String, String> itemNames;
  String appliesToText;

  CouponDto({
    this.id,
    this.code,
    this.kind,
    this.value = 0,
    this.minOrderPaise = 0,
    this.maxDiscountPaise,
    this.categoryId,
    this.categoryIds = const <String>[],
    this.perUserLimit = 0,
    this.totalLimit = 0,
    this.usedCount = 0,
    this.startAt,
    this.endAt,
    this.active = true,
    this.worksWithCoins,
    this.firstOrderOnly,
    this.productIds = const <String>[],
    this.productGroupIds = const <String>[],
    this.itemNames = const <String, String>{},
    this.appliesToText = '',
  });

  CouponDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        code = j['code']?.toString(),
        kind = j['kind']?.toString(),
        value = (j['value'] as num?)?.toInt() ?? 0,
        minOrderPaise = (j['minOrderPaise'] as num?)?.toInt() ?? 0,
        maxDiscountPaise = (j['maxDiscountPaise'] as num?)?.toInt(),
        categoryId = j['categoryId']?.toString(),
        categoryIds = _stringList(j['categoryIds'], j['categoryId']?.toString()),
        perUserLimit = (j['perUserLimit'] as num?)?.toInt() ?? 0,
        totalLimit = (j['totalLimit'] as num?)?.toInt() ?? 0,
        usedCount = (j['usedCount'] as num?)?.toInt() ?? 0,
        startAt = j['startAt']?.toString(),
        endAt = j['endAt']?.toString(),
        active = j['active'] as bool? ?? true,
        worksWithCoins = j['worksWithCoins'] as bool?,
        firstOrderOnly = j['firstOrderOnly'] as bool?,
        productIds = _stringList(j['productIds']),
        productGroupIds = _stringList(j['productGroupIds']),
        itemNames = _namedMap(j['appliesTo']),
        appliesToText = j['appliesTo'] is Map
            ? ((j['appliesTo'] as Map)['text'] ?? '').toString()
            : (j['appliesToText'] ?? '').toString();
}

/// `appliesTo.products` / `.productGroups` (`[{id, name}]`) -> id -> name.
Map<String, String> _namedMap(Object? applies) {
  final out = <String, String>{};
  if (applies is Map) {
    for (final key in const ['products', 'productGroups']) {
      final l = applies[key];
      if (l is List) {
        for (final e in l) {
          if (e is Map && e['id'] != null) {
            out[e['id'].toString()] = (e['name'] ?? '').toString();
          }
        }
      }
    }
  }
  return out;
}

class RuleViewDto {
  String? id;
  String? name;
  int spendPaise;
  int coins;
  String? mode; // PRO_RATA | SLAB
  int? minOrderPaise;
  String? startAt;
  String? endAt;
  bool active;

  RuleViewDto({
    this.id,
    this.name,
    this.spendPaise = 0,
    this.coins = 0,
    this.mode,
    this.minOrderPaise,
    this.startAt,
    this.endAt,
    this.active = true,
  });

  RuleViewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        name = j['name']?.toString(),
        spendPaise = (j['spendPaise'] as num?)?.toInt() ?? 0,
        coins = (j['coins'] as num?)?.toInt() ?? 0,
        mode = j['mode']?.toString(),
        minOrderPaise = (j['minOrderPaise'] as num?)?.toInt(),
        startAt = j['startAt']?.toString(),
        endAt = j['endAt']?.toString(),
        active = j['active'] as bool? ?? true;
}

class CoinSettingsDto {
  int paisePerCoin;
  int maxRedeemPercent;
  int expiryMonths;

  CoinSettingsDto({this.paisePerCoin = 100, this.maxRedeemPercent = 50, this.expiryMonths = 12});

  CoinSettingsDto.fromJson(Map<String, dynamic> j)
      : paisePerCoin = (j['paisePerCoin'] as num?)?.toInt() ?? 100,
        maxRedeemPercent = (j['maxRedeemPercent'] as num?)?.toInt() ?? 50,
        expiryMonths = (j['expiryMonths'] as num?)?.toInt() ?? 12;
}

class HotBannerDto {
  String? id;
  String? title;
  String? subtitle;
  String? imageUrl;
  String? startAt;
  String? endAt;
  bool active;

  HotBannerDto({
    this.id,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.startAt,
    this.endAt,
    this.active = true,
  });

  HotBannerDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        title = j['title']?.toString(),
        subtitle = j['subtitle']?.toString(),
        imageUrl = j['imageUrl']?.toString(),
        startAt = j['startAt']?.toString(),
        endAt = j['endAt']?.toString(),
        active = j['active'] as bool? ?? true;
}

class ShopSettingDto {
  String? shopName;
  String? address;
  String? phone;
  String? gstin;
  String? stateCode;
  String? upiId;
  String? invoicePrefix;
  String? receiptFooter;
  String? weighedPrefix;
  String? weighedMode;

  /// `GET /pos/shop` `roundOffMode`: `NONE` or `NEAREST_RUPEE` (the till's
  /// bill total already includes the round-off the quote reports).
  String? roundOffMode;

  /// Free-text shop blurb shown on the storefront (backend: max 500 chars).
  String? details;

  /// URL of the shop logo. Requested from the backend (see
  /// `BACKEND_REQUEST_shop_identity.md`); until it exists the app falls back
  /// to its own drawn logo, so this is only rendered when non-empty.
  String? logoUrl;

  /// Opening hours as the admin typed them, e.g. `9 AM – 9 PM`. Same story
  /// as [logoUrl]: rendered only when the backend starts sending it.
  String? openHours;

  /// Customer-facing promise line ("Free Home Delivery"). The admin payload
  /// carries it as its own field; the public payload maps it into
  /// [receiptFooter] because that is what the store card reads.
  String? promise;

  /// Gujarati texts and the short name (empty = fall back to English) and
  /// the app icons made from the logo (`iconUrl` 512, `icon192Url` 192).
  String? shortName;
  String? shopNameGu;
  String? addressGu;
  String? promiseGu;
  String? detailsGu;
  String? iconUrl;
  String? icon192Url;

  /// Public `GET /shop-settings` extras: contact links, today's hours, and the
  /// admin's "pause online orders" switch (`onlineOrdersOpen` false = block
  /// checkout and show [onlineOrdersMessage] as is).
  String? email;
  String? whatsapp;
  String? mapUrl;
  String? holidayNote;
  bool? openNow;
  bool onlineOrdersOpen = true;
  String onlineOrdersMessage = '';

  ShopSettingDto({
    this.shopName,
    this.address,
    this.phone,
    this.gstin,
    this.stateCode,
    this.upiId,
    this.invoicePrefix,
    this.receiptFooter,
    this.weighedPrefix,
    this.weighedMode,
    this.details,
    this.logoUrl,
    this.openHours,
    this.promise,
  });

  ShopSettingDto.fromJson(Map<String, dynamic> j)
      : shopName = j['shopName']?.toString(),
        address = j['address']?.toString(),
        phone = j['phone']?.toString(),
        gstin = j['gstin']?.toString(),
        stateCode = j['stateCode']?.toString(),
        upiId = j['upiId']?.toString(),
        invoicePrefix = j['invoicePrefix']?.toString(),
        receiptFooter = j['receiptFooter']?.toString(),
        weighedPrefix = j['weighedPrefix']?.toString(),
        weighedMode = j['weighedMode']?.toString(),
        roundOffMode = j['roundOffMode']?.toString(),
        details = j['details']?.toString(),
        logoUrl = j['logoUrl']?.toString(),
        openHours = j['openHours']?.toString(),
        promise = j['promise']?.toString(),
        shortName = j['shortName']?.toString(),
        shopNameGu = j['shopNameGu']?.toString(),
        addressGu = j['addressGu']?.toString(),
        promiseGu = j['promiseGu']?.toString(),
        detailsGu = j['detailsGu']?.toString(),
        iconUrl = j['iconUrl']?.toString(),
        icon192Url = j['icon192Url']?.toString();
}

class SettingDto {
  String? code;
  bool enabled;

  /// Backend: whether this method can actually take money right now — an
  /// enabled method with no credentials (e.g. no UPI id) is offered to the
  /// shopper but fails checkout with `PAYMENT_NOT_CONFIGURED`.
  bool configured;

  SettingDto({this.code, this.enabled = false, this.configured = true});

  SettingDto.fromJson(Map<String, dynamic> j)
      : code = j['code']?.toString(),
        enabled = j['enabled'] as bool? ?? false,
        configured = j['configured'] as bool? ?? true;
}

class StaffViewDto {
  String? id;
  String? email;
  String? name;
  String? mobile;

  /// `StaffView.active` (false = blocked). Older servers omit it: treat as on.
  bool active;

  StaffViewDto({this.id, this.email, this.name, this.mobile, this.active = true});

  StaffViewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        email = j['email']?.toString(),
        name = j['name']?.toString(),
        mobile = j['mobile']?.toString(),
        active = j['active'] is bool ? j['active'] as bool : true;
}

// ---------------------------------------------------------------------------
// Customer-facing catalog (public `Product` schema — no qtyOnHand/active)
// ---------------------------------------------------------------------------

class PublicProductDto {
  String? id;
  String? categoryId;
  String? nameEn;
  String? nameGu;
  String? description;
  int mrpPaise;
  int pricePaise;
  String? unit;
  String? packSize;
  String? imageUrl;
  bool inStock;
  int qtyAvailable;
  bool hotSale;
  bool earnsCoins;
  bool coinRedeemable;
  String? productGroupId;
  double rating;
  int reviewCount;

  /// Running flash-sale offer for this pack (`flash`), or null.
  FlashOffer? flash;

  PublicProductDto({
    this.id,
    this.categoryId,
    this.nameEn,
    this.nameGu,
    this.description,
    this.mrpPaise = 0,
    this.pricePaise = 0,
    this.unit,
    this.packSize,
    this.imageUrl,
    this.inStock = false,
    this.qtyAvailable = 0,
    this.hotSale = false,
    this.earnsCoins = true,
    this.coinRedeemable = true,
    this.productGroupId,
    this.rating = 0,
    this.reviewCount = 0,
  });

  PublicProductDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        categoryId = j['categoryId']?.toString(),
        nameEn = j['nameEn']?.toString(),
        nameGu = j['nameGu']?.toString(),
        description = j['description']?.toString(),
        mrpPaise = (j['mrpPaise'] as num?)?.toInt() ?? 0,
        pricePaise = (j['pricePaise'] as num?)?.toInt() ?? 0,
        unit = j['unit']?.toString(),
        packSize = j['packSize']?.toString(),
        imageUrl = j['imageUrl']?.toString(),
        inStock = j['inStock'] as bool? ?? false,
        qtyAvailable = (j['qtyAvailable'] as num?)?.toInt() ?? 0,
        hotSale = j['hotSale'] as bool? ?? false,
        earnsCoins = j['earnsCoins'] as bool? ?? true,
        coinRedeemable = j['coinRedeemable'] as bool? ?? true,
        productGroupId = j['productGroupId']?.toString(),
        rating = (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount = (j['reviewCount'] as num?)?.toInt() ?? 0,
        flash = FlashOffer.maybe(j['flash']);
}

class PageProductDto {
  List<PublicProductDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageProductDto({this.items = const [], this.page = 0, this.size = 20, this.total = 0});

  PageProductDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PublicProductDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

/// `GET /hot-sale` → `{ banners: [HotBanner], products: [Product] }`.
class PublicHotSaleDto {
  List<HotBannerDto> banners;
  List<PublicProductDto> products;

  /// Paging of the products part (`GET /hot-sale?page&size`).
  int page = 0;
  int size = 20;
  int total = 0;

  /// `totalExact` / `hasMore` of the products part. `hasMore` is always exact;
  /// null when an older server does not send it.
  bool totalExact = true;
  bool? hasMore;

  PublicHotSaleDto({this.banners = const [], this.products = const []});

  PublicHotSaleDto.fromJson(Map<String, dynamic> j)
      : banners = (j['banners'] as List? ?? [])
            .whereType<Map>()
            .map((e) => HotBannerDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        products = (j['products'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PublicProductDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] as bool? ?? true,
        hasMore = j['hasMore'] as bool?;
}

// ---------------------------------------------------------------------------
// Cart quote
// ---------------------------------------------------------------------------

class QuoteLineDto {
  String? productId;
  String? name;
  int qty;
  int unitPricePaise;
  int lineTotalPaise;
  bool coinRedeemable;
  bool earnsCoins;

  /// Category this line belongs to (present when a coupon is applied, so the
  /// UI can tell which lines the discount touched).
  String? categoryId;

  /// This line's share of the order's coupon discount — 0 for lines outside
  /// the coupon's categories.
  int couponDiscountPaise;

  /// Flash sale this line was priced under (null = normal price). A product
  /// can come back as two lines: sale units, then normal-price units.
  String? flashSaleId;
  int listPricePaise;
  int flashDiscountPaise;

  /// Gujarati name and pack label ("5 kg") straight from the server quote.
  String? nameGu;
  String? unitLabel;

  QuoteLineDto({
    this.nameGu,
    this.unitLabel,
    this.productId,
    this.name,
    this.qty = 0,
    this.unitPricePaise = 0,
    this.lineTotalPaise = 0,
    this.coinRedeemable = true,
    this.earnsCoins = true,
    this.categoryId,
    this.couponDiscountPaise = 0,
    this.flashSaleId,
    this.listPricePaise = 0,
    this.flashDiscountPaise = 0,
  });

  QuoteLineDto.fromJson(Map<String, dynamic> j)
      : productId = j['productId']?.toString(),
        name = j['name']?.toString(),
        qty = (j['qty'] as num?)?.toInt() ?? 0,
        unitPricePaise = (j['unitPricePaise'] as num?)?.toInt() ?? 0,
        lineTotalPaise = (j['lineTotalPaise'] as num?)?.toInt() ?? 0,
        coinRedeemable = j['coinRedeemable'] as bool? ?? true,
        earnsCoins = j['earnsCoins'] as bool? ?? true,
        categoryId = j['categoryId']?.toString(),
        couponDiscountPaise = (j['couponDiscountPaise'] as num?)?.toInt() ?? 0,
        flashSaleId = j['flashSaleId']?.toString(),
        listPricePaise = (j['listPricePaise'] as num?)?.toInt() ?? 0,
        flashDiscountPaise = (j['flashDiscountPaise'] as num?)?.toInt() ?? 0,
        nameGu = j['nameGu']?.toString(),
        unitLabel = j['unitLabel']?.toString();
}

/// One entry of the quote's `couponByCategory`: how much of the coupon
/// discount landed on each category it covered.
class CouponCategoryShareDto {
  String? categoryId;
  int subtotalPaise;
  int discountPaise;

  CouponCategoryShareDto({
    this.categoryId,
    this.subtotalPaise = 0,
    this.discountPaise = 0,
  });

  CouponCategoryShareDto.fromJson(Map<String, dynamic> j)
      : categoryId = j['categoryId']?.toString(),
        subtotalPaise = (j['subtotalPaise'] as num?)?.toInt() ?? 0,
        discountPaise = (j['discountPaise'] as num?)?.toInt() ?? 0;
}

class QuoteDto {
  List<QuoteLineDto> lines;
  int subtotalPaise;
  String? couponCode;
  int couponDiscountPaise;
  int coinsUsed;
  int coinDiscountPaise;
  int deliveryFeePaise;
  int totalPaise;
  int coinsToEarn;
  int customerCoinBalance;
  List<String> warnings;

  /// Per-category split of [couponDiscountPaise] when the applied coupon is
  /// limited to categories (backend: `couponByCategory`).
  List<CouponCategoryShareDto> couponByCategory;

  QuoteDto({
    this.lines = const [],
    this.subtotalPaise = 0,
    this.couponCode,
    this.couponDiscountPaise = 0,
    this.coinsUsed = 0,
    this.coinDiscountPaise = 0,
    this.deliveryFeePaise = 0,
    this.totalPaise = 0,
    this.coinsToEarn = 0,
    this.customerCoinBalance = 0,
    this.warnings = const [],
    this.couponByCategory = const [],
  });

  QuoteDto.fromJson(Map<String, dynamic> j)
      : lines = (j['lines'] as List? ?? [])
            .whereType<Map>()
            .map((e) => QuoteLineDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        subtotalPaise = (j['subtotalPaise'] as num?)?.toInt() ?? 0,
        couponCode = j['couponCode']?.toString(),
        couponDiscountPaise = (j['couponDiscountPaise'] as num?)?.toInt() ?? 0,
        coinsUsed = (j['coinsUsed'] as num?)?.toInt() ?? 0,
        coinDiscountPaise = (j['coinDiscountPaise'] as num?)?.toInt() ?? 0,
        deliveryFeePaise = (j['deliveryFeePaise'] as num?)?.toInt() ?? 0,
        totalPaise = (j['totalPaise'] as num?)?.toInt() ?? 0,
        coinsToEarn = (j['coinsToEarn'] as num?)?.toInt() ?? 0,
        customerCoinBalance = (j['customerCoinBalance'] as num?)?.toInt() ?? 0,
        warnings = (j['warnings'] as List? ?? []).map((e) => e.toString()).toList(),
        couponByCategory = (j['couponByCategory'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                CouponCategoryShareDto.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

// ---------------------------------------------------------------------------
// Customer orders (summary list)
// ---------------------------------------------------------------------------

class SummaryDto {
  String? id;
  String? orderNo;
  String? status;
  String? fulfilment;
  int totalPaise;
  int itemCount;
  String? placedAt;
  String? cancelledBy;
  String? cancelCode;

  SummaryDto({
    this.cancelledBy,
    this.cancelCode,
    this.id,
    this.orderNo,
    this.status,
    this.fulfilment,
    this.totalPaise = 0,
    this.itemCount = 0,
    this.placedAt,
  });

  SummaryDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        orderNo = j['orderNo']?.toString(),
        status = j['status']?.toString(),
        fulfilment = j['fulfilment']?.toString(),
        totalPaise = (j['totalPaise'] as num?)?.toInt() ?? 0,
        itemCount = (j['itemCount'] as num?)?.toInt() ?? 0,
        placedAt = j['placedAt']?.toString(),
        cancelledBy = j['cancelledBy']?.toString(),
        cancelCode = j['cancelCode']?.toString();

  DateTime? get placedDateTime => parseIst(placedAt ?? '');
}

class PageSummaryDto {
  List<SummaryDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageSummaryDto({this.items = const [], this.page = 0, this.size = 20, this.total = 0});

  PageSummaryDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => SummaryDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

// ---------------------------------------------------------------------------
// Wallet
// ---------------------------------------------------------------------------

class WalletViewDto {
  int coins;
  int valuePaise;
  int paisePerCoin;
  int maxRedeemPercent;

  /// Months after which earned coins expire (`GET /wallet`).
  int expiryMonths;
  List<RuleViewDto> rules;

  WalletViewDto({
    this.coins = 0,
    this.valuePaise = 0,
    this.paisePerCoin = 100,
    this.maxRedeemPercent = 50,
    this.expiryMonths = 12,
    this.rules = const [],
  });

  WalletViewDto.fromJson(Map<String, dynamic> j)
      : coins = (j['coins'] as num?)?.toInt() ?? 0,
        valuePaise = (j['valuePaise'] as num?)?.toInt() ?? 0,
        paisePerCoin = (j['paisePerCoin'] as num?)?.toInt() ?? 100,
        maxRedeemPercent = (j['maxRedeemPercent'] as num?)?.toInt() ?? 50,
        expiryMonths = (j['expiryMonths'] as num?)?.toInt() ?? 12,
        rules = (j['rules'] as List? ?? [])
            .whereType<Map>()
            .map((e) => RuleViewDto.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

class LedgerViewDto {
  String? id;
  String? kind;
  int coins;
  String? orderNo;
  String? createdAt;
  String? expiresAt;

  LedgerViewDto({
    this.id,
    this.kind,
    this.coins = 0,
    this.orderNo,
    this.createdAt,
    this.expiresAt,
  });

  LedgerViewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        kind = j['kind']?.toString(),
        coins = (j['coins'] as num?)?.toInt() ?? 0,
        orderNo = j['orderNo']?.toString(),
        createdAt = j['createdAt']?.toString(),
        expiresAt = j['expiresAt']?.toString();

  DateTime? get createdDateTime => parseIst(createdAt ?? '');
}

class PageLedgerViewDto {
  List<LedgerViewDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageLedgerViewDto({this.items = const [], this.page = 0, this.size = 20, this.total = 0});

  PageLedgerViewDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => LedgerViewDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

// ---------------------------------------------------------------------------
// Customer credit / udhar (`GET /credit`, `GET /credit/ledger`)
// ---------------------------------------------------------------------------

/// What the signed-in customer owes the shop right now.
///
/// Backend `CreditService.AccountView` — `limitPaise == 0` means credit is
/// not enabled for this customer, and `balancePaise` is what they owe now.
class CreditAccountDto {
  String? customerId;
  String? name;
  String? mobile;
  int balancePaise;
  int limitPaise;
  int availablePaise;

  /// `blocked`: the customer may not buy on credit at all (`CUSTOMER_BLOCKED`).
  bool blocked;

  CreditAccountDto({
    this.customerId,
    this.name,
    this.mobile,
    this.balancePaise = 0,
    this.limitPaise = 0,
    this.availablePaise = 0,
    this.blocked = false,
  });

  CreditAccountDto.fromJson(Map<String, dynamic> j)
      : customerId = j['customerId']?.toString(),
        name = j['name']?.toString(),
        mobile = j['mobile']?.toString(),
        balancePaise = (j['balancePaise'] as num?)?.toInt() ?? 0,
        limitPaise = (j['limitPaise'] as num?)?.toInt() ?? 0,
        availablePaise = (j['availablePaise'] as num?)?.toInt() ?? 0,
        blocked = j['blocked'] as bool? ?? false;
}

/// One row of the credit ledger. `deltaPaise > 0` = the customer owes more,
/// `< 0` = they paid some back.
class CreditLedgerEntryDto {
  String? id;
  String? kind;
  int deltaPaise;
  int balanceAfterPaise;
  String? refNo;
  String? note;
  String? at;

  CreditLedgerEntryDto({
    this.id,
    this.kind,
    this.deltaPaise = 0,
    this.balanceAfterPaise = 0,
    this.refNo,
    this.note,
    this.at,
  });

  CreditLedgerEntryDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        kind = j['kind']?.toString(),
        deltaPaise = (j['deltaPaise'] as num?)?.toInt() ?? 0,
        balanceAfterPaise = (j['balanceAfterPaise'] as num?)?.toInt() ?? 0,
        refNo = j['refNo']?.toString(),
        note = j['note']?.toString(),
        at = j['at']?.toString();
}

class PageCreditLedgerDto {
  List<CreditLedgerEntryDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageCreditLedgerDto({this.items = const [], this.page = 0, this.size = 20, this.total = 0});

  PageCreditLedgerDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => CreditLedgerEntryDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

// ---------------------------------------------------------------------------
// POS (point of sale)
// ---------------------------------------------------------------------------

/// `GET /pos/products` item (also the barcode-scan payload).
class PosProductDto {
  String? productId;
  String? name;
  String? nameGu;
  int pricePaise;
  int mrpPaise;
  String? soldBy; // UNIT | WEIGHT
  int gstPercent;
  String? hsn;
  String? plu;
  bool posOnly;
  int qtyOnHand;
  String? imageUrl;
  bool coinRedeemable;
  bool earnsCoins;
  List<String> barcodes;

  /// Pack/variant detail the till needs to tell two rows of the same product
  /// apart. The backend sends all five (see `PosViews.PosProduct`), and
  /// [displayName] is its own composed label — `Name (Variant, 500 g)` — which
  /// is what the search chips and the till line show.
  String? variantName;
  String? packSize;
  String? unit;
  String? unitLabel;
  String? displayName;

  /// Lot the next unit comes from (guide 74); null without stock.
  LotInfoDto? lot;

  PosProductDto({
    this.productId,
    this.name,
    this.nameGu,
    this.pricePaise = 0,
    this.mrpPaise = 0,
    this.soldBy,
    this.gstPercent = 0,
    this.hsn,
    this.plu,
    this.posOnly = false,
    this.qtyOnHand = 0,
    this.imageUrl,
    this.coinRedeemable = true,
    this.earnsCoins = true,
    this.barcodes = const [],
    this.variantName,
    this.packSize,
    this.unit,
    this.unitLabel,
    this.displayName,
    this.lot,
  });

  PosProductDto.fromJson(Map<String, dynamic> j)
      : productId = j['productId']?.toString(),
        name = j['name']?.toString(),
        nameGu = j['nameGu']?.toString(),
        pricePaise = (j['pricePaise'] as num?)?.toInt() ?? 0,
        mrpPaise = (j['mrpPaise'] as num?)?.toInt() ?? 0,
        soldBy = j['soldBy']?.toString(),
        gstPercent = (j['gstPercent'] as num?)?.toInt() ?? 0,
        hsn = j['hsn']?.toString(),
        plu = j['plu']?.toString(),
        posOnly = j['posOnly'] as bool? ?? false,
        qtyOnHand = (j['qtyOnHand'] as num?)?.toInt() ?? 0,
        imageUrl = j['imageUrl']?.toString(),
        coinRedeemable = j['coinRedeemable'] as bool? ?? true,
        earnsCoins = j['earnsCoins'] as bool? ?? true,
        variantName = j['variantName']?.toString(),
        packSize = j['packSize']?.toString(),
        unit = j['unit']?.toString(),
        unitLabel = j['unitLabel']?.toString(),
        displayName = j['displayName']?.toString(),
        lot = j['lot'] is Map
            ? LotInfoDto.fromJson(Map<String, dynamic>.from(j['lot'] as Map))
            : null,
        barcodes = (j['barcodes'] as List? ?? []).map((e) => e.toString()).toList();
}

class PagePosProductDto {
  List<PosProductDto> items;
  int page;
  int size;
  int total;

  /// `hasMore` is always exact: page until it is false. Null when an older
  /// backend does not send it (callers fall back to `page*size < total`).
  bool? hasMore;
  bool totalExact;

  PagePosProductDto(
      {this.items = const [],
      this.page = 0,
      this.size = 20,
      this.total = 0,
      this.hasMore,
      this.totalExact = true});

  PagePosProductDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PosProductDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null,
        totalExact = j['totalExact'] is bool ? j['totalExact'] as bool : true;
}

/// One line of a POS bill (`POST /pos/quote` response).
class BillLineDto {
  String? productId;
  String? name;
  String? soldBy;
  int qty;
  int unitPricePaise;
  int linePaise;
  int discountPaise;
  int netPaise;
  int gstPercent;

  BillLineDto({
    this.productId,
    this.name,
    this.soldBy,
    this.qty = 0,
    this.unitPricePaise = 0,
    this.linePaise = 0,
    this.discountPaise = 0,
    this.netPaise = 0,
    this.gstPercent = 0,
  });

  BillLineDto.fromJson(Map<String, dynamic> j)
      : productId = j['productId']?.toString(),
        name = j['name']?.toString(),
        soldBy = j['soldBy']?.toString(),
        qty = (j['qty'] as num?)?.toInt() ?? 0,
        unitPricePaise = (j['unitPricePaise'] as num?)?.toInt() ?? 0,
        linePaise = (j['linePaise'] as num?)?.toInt() ?? 0,
        discountPaise = (j['discountPaise'] as num?)?.toInt() ?? 0,
        netPaise = (j['netPaise'] as num?)?.toInt() ?? 0,
        gstPercent = (j['gstPercent'] as num?)?.toInt() ?? 0;
}

/// Server-side POS bill (`POST /pos/quote` → `BillView`).
class PosBillViewDto {
  List<BillLineDto> lines;
  int subtotalPaise;
  String? couponCode;
  int couponDiscountPaise;
  int coinsUsed;
  int coinDiscountPaise;
  int totalPaise;
  int taxablePaise;
  int cgstPaise;
  int sgstPaise;
  int coinsToEarn;
  int customerCoinBalance;
  List<String> warnings;

  /// Rounding added to reach a whole rupee (negative = taken off); 0 when the
  /// shop's `gst.roundOff` is NONE. [totalPaise] already includes it.
  int roundOffPaise;

  /// Manual discount the quote applied (`manualDiscount` echoed as paise).
  int manualDiscountPaise;

  PosBillViewDto({
    this.lines = const [],
    this.subtotalPaise = 0,
    this.couponCode,
    this.couponDiscountPaise = 0,
    this.coinsUsed = 0,
    this.coinDiscountPaise = 0,
    this.totalPaise = 0,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
    this.coinsToEarn = 0,
    this.customerCoinBalance = 0,
    this.warnings = const [],
    this.roundOffPaise = 0,
    this.manualDiscountPaise = 0,
  });

  PosBillViewDto.fromJson(Map<String, dynamic> j)
      : lines = (j['lines'] as List? ?? [])
            .whereType<Map>()
            .map((e) => BillLineDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        subtotalPaise = (j['subtotalPaise'] as num?)?.toInt() ?? 0,
        couponCode = j['couponCode']?.toString(),
        couponDiscountPaise = (j['couponDiscountPaise'] as num?)?.toInt() ?? 0,
        coinsUsed = (j['coinsUsed'] as num?)?.toInt() ?? 0,
        coinDiscountPaise = (j['coinDiscountPaise'] as num?)?.toInt() ?? 0,
        totalPaise = (j['totalPaise'] as num?)?.toInt() ?? 0,
        taxablePaise = (j['taxablePaise'] as num?)?.toInt() ?? 0,
        cgstPaise = (j['cgstPaise'] as num?)?.toInt() ?? 0,
        sgstPaise = (j['sgstPaise'] as num?)?.toInt() ?? 0,
        coinsToEarn = (j['coinsToEarn'] as num?)?.toInt() ?? 0,
        customerCoinBalance = (j['customerCoinBalance'] as num?)?.toInt() ?? 0,
        warnings = (j['warnings'] as List? ?? []).map((e) => e.toString()).toList(),
        roundOffPaise = (j['roundOffPaise'] as num?)?.toInt() ?? 0,
        manualDiscountPaise = (j['manualDiscountPaise'] as num?)?.toInt() ?? 0;
}

/// The cart payload shared by `POST /pos/sales`, `/pos/quote` and holds.
class PosCartDto {
  List<OrderItemDto> items;
  String? customerMobile;
  String? couponCode;
  String? coinMode; // NONE | ALL | PERCENT
  int? percent;

  PosCartDto({
    this.items = const [],
    this.customerMobile,
    this.couponCode,
    this.coinMode,
    this.percent,
  });

  PosCartDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => OrderItemDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        customerMobile = j['customerMobile']?.toString(),
        couponCode = j['couponCode']?.toString(),
        coinMode = j['coinMode']?.toString(),
        percent = (j['percent'] as num?)?.toInt();

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => {'productId': e.productId, 'qty': e.qty}).toList(),
        if (customerMobile != null && customerMobile!.isNotEmpty)
          'customerMobile': customerMobile,
        if (couponCode != null && couponCode!.isNotEmpty) 'couponCode': couponCode,
        if (coinMode != null) 'coinMode': coinMode,
        if (percent != null && coinMode == 'PERCENT') 'percent': percent,
      };
}

class SaleItemRecordDto {
  String? id;
  String? productId;
  String? name;
  String? soldBy;
  int qty;
  int unitPricePaise;
  int linePaise;
  int discountPaise;
  int netPaise;
  int gstPercent;
  String? hsn;
  int taxablePaise;
  int cgstPaise;
  int sgstPaise;
  int returnedQty;
  int couponSharePaise;

  SaleItemRecordDto({
    this.id,
    this.productId,
    this.name,
    this.soldBy,
    this.qty = 0,
    this.unitPricePaise = 0,
    this.linePaise = 0,
    this.discountPaise = 0,
    this.netPaise = 0,
    this.gstPercent = 0,
    this.hsn,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
    this.returnedQty = 0,
    this.couponSharePaise = 0,
  });

  SaleItemRecordDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        productId = j['productId']?.toString(),
        name = j['name']?.toString(),
        soldBy = j['soldBy']?.toString(),
        qty = (j['qty'] as num?)?.toInt() ?? 0,
        unitPricePaise = (j['unitPricePaise'] as num?)?.toInt() ?? 0,
        linePaise = (j['linePaise'] as num?)?.toInt() ?? 0,
        discountPaise = (j['discountPaise'] as num?)?.toInt() ?? 0,
        netPaise = (j['netPaise'] as num?)?.toInt() ?? 0,
        gstPercent = (j['gstPercent'] as num?)?.toInt() ?? 0,
        hsn = j['hsn']?.toString(),
        taxablePaise = (j['taxablePaise'] as num?)?.toInt() ?? 0,
        cgstPaise = (j['cgstPaise'] as num?)?.toInt() ?? 0,
        sgstPaise = (j['sgstPaise'] as num?)?.toInt() ?? 0,
        returnedQty = (j['returnedQty'] as num?)?.toInt() ?? 0,
        couponSharePaise = (j['couponSharePaise'] as num?)?.toInt() ?? 0;
}

class PaymentRecordDto {
  String? mode;
  int amountPaise;
  String? reference;
  String? terminalPaymentId;
  String? moneyAccountId;

  PaymentRecordDto(
      {this.mode,
      this.amountPaise = 0,
      this.reference,
      this.terminalPaymentId,
      this.moneyAccountId});

  PaymentRecordDto.fromJson(Map<String, dynamic> j)
      : mode = j['mode']?.toString(),
        amountPaise = (j['amountPaise'] as num?)?.toInt() ?? 0,
        reference = j['reference']?.toString(),
        terminalPaymentId = j['terminalPaymentId']?.toString(),
        moneyAccountId = j['moneyAccountId']?.toString();
}

/// A completed POS sale (`POST/GET /pos/sales`).
class SaleRecordDto {
  String? id;
  String? invoiceNo;
  String? cashierId;
  String? customerId;
  String? customerMobile;
  int subtotalPaise;
  String? couponCode;
  int couponDiscountPaise;
  int coinsUsed;
  int coinDiscountPaise;
  int totalPaise;
  int taxablePaise;
  int cgstPaise;
  int sgstPaise;
  int coinsEarned;
  int tenderedPaise;
  int changePaise;
  String? createdAt;
  List<SaleItemRecordDto> items;
  List<PaymentRecordDto> payments;

  /// NONE | CASH | UPI | CARD | SPLIT | CREDIT | HYBRID.
  String? paymentType;
  int manualDiscountPaise;
  String? manualDiscountReason;
  String? manualDiscountApprover;
  int roundOffPaise;

  SaleRecordDto({
    this.id,
    this.invoiceNo,
    this.cashierId,
    this.customerId,
    this.customerMobile,
    this.subtotalPaise = 0,
    this.couponCode,
    this.couponDiscountPaise = 0,
    this.coinsUsed = 0,
    this.coinDiscountPaise = 0,
    this.totalPaise = 0,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
    this.coinsEarned = 0,
    this.tenderedPaise = 0,
    this.changePaise = 0,
    this.createdAt,
    this.items = const [],
    this.payments = const [],
    this.paymentType,
    this.manualDiscountPaise = 0,
    this.manualDiscountReason,
    this.manualDiscountApprover,
    this.roundOffPaise = 0,
  });

  /// Part of the bill left on the customer's udhar (`CREDIT` payment line).
  int get creditPaise => payments
      .where((p) => (p.mode ?? '').toUpperCase() == 'CREDIT')
      .fold<int>(0, (s, p) => s + p.amountPaise);

  SaleRecordDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        invoiceNo = j['invoiceNo']?.toString(),
        cashierId = j['cashierId']?.toString(),
        customerId = j['customerId']?.toString(),
        customerMobile = j['customerMobile']?.toString(),
        subtotalPaise = (j['subtotalPaise'] as num?)?.toInt() ?? 0,
        couponCode = j['couponCode']?.toString(),
        couponDiscountPaise = (j['couponDiscountPaise'] as num?)?.toInt() ?? 0,
        coinsUsed = (j['coinsUsed'] as num?)?.toInt() ?? 0,
        coinDiscountPaise = (j['coinDiscountPaise'] as num?)?.toInt() ?? 0,
        totalPaise = (j['totalPaise'] as num?)?.toInt() ?? 0,
        taxablePaise = (j['taxablePaise'] as num?)?.toInt() ?? 0,
        cgstPaise = (j['cgstPaise'] as num?)?.toInt() ?? 0,
        sgstPaise = (j['sgstPaise'] as num?)?.toInt() ?? 0,
        coinsEarned = (j['coinsEarned'] as num?)?.toInt() ?? 0,
        tenderedPaise = (j['tenderedPaise'] as num?)?.toInt() ?? 0,
        changePaise = (j['changePaise'] as num?)?.toInt() ?? 0,
        createdAt = j['createdAt']?.toString(),
        items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => SaleItemRecordDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        payments = (j['payments'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PaymentRecordDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        paymentType = j['paymentType']?.toString(),
        manualDiscountPaise = (j['manualDiscountPaise'] as num?)?.toInt() ?? 0,
        manualDiscountReason = j['manualDiscountReason']?.toString(),
        manualDiscountApprover = j['manualDiscountApprover']?.toString(),
        roundOffPaise = (j['roundOffPaise'] as num?)?.toInt() ?? 0;

  DateTime? get createdDateTime => parseIst(createdAt ?? '');
}

/// A parked (held) cart (`GET/POST /pos/holds`).
class HoldViewDto {
  String? id;
  String? label;
  String? customerMobile;
  String? cashierId;
  String? createdAt;
  PosCartDto? cart;

  /// When the server removes this parked ticket by itself; null = never.
  String? expiresAt;

  HoldViewDto(
      {this.id,
      this.label,
      this.customerMobile,
      this.cashierId,
      this.createdAt,
      this.cart,
      this.expiresAt});

  HoldViewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        label = j['label']?.toString(),
        customerMobile = j['customerMobile']?.toString(),
        cashierId = j['cashierId']?.toString(),
        createdAt = j['createdAt']?.toString(),
        expiresAt = j['expiresAt']?.toString(),
        cart = j['cart'] is Map
            ? PosCartDto.fromJson(Map<String, dynamic>.from(j['cart'] as Map))
            : null;
}

/// `GET /pos/reports/day` — one day of till totals.
class DayReportDto {
  String? date;
  int bills;
  int salesPaise;
  int taxablePaise;
  int cgstPaise;
  int sgstPaise;
  int coinsRedeemed;
  int creditNotes;
  int refundsPaise;
  int netPaise;
  Map<String, int> paidByMode;
  Map<String, int> refundedByMode;
  int cashExpectedPaise;
  int creditGivenPaise;
  int creditReturnedPaise;
  int creditRecoveredPaise;
  Map<String, int> creditRecoveredByMode;

  DayReportDto({
    this.date,
    this.bills = 0,
    this.salesPaise = 0,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
    this.coinsRedeemed = 0,
    this.creditNotes = 0,
    this.refundsPaise = 0,
    this.netPaise = 0,
    this.paidByMode = const {},
    this.refundedByMode = const {},
    this.cashExpectedPaise = 0,
    this.creditGivenPaise = 0,
    this.creditReturnedPaise = 0,
    this.creditRecoveredPaise = 0,
    this.creditRecoveredByMode = const {},
  });

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is! Map) return <String, int>{};
    return raw.map((k, v) => MapEntry(k.toString(), ((v as num?)?.toInt() ?? 0)));
  }

  DayReportDto.fromJson(Map<String, dynamic> j)
      : date = j['date']?.toString(),
        bills = (j['bills'] as num?)?.toInt() ?? 0,
        salesPaise = (j['salesPaise'] as num?)?.toInt() ?? 0,
        taxablePaise = (j['taxablePaise'] as num?)?.toInt() ?? 0,
        cgstPaise = (j['cgstPaise'] as num?)?.toInt() ?? 0,
        sgstPaise = (j['sgstPaise'] as num?)?.toInt() ?? 0,
        coinsRedeemed = (j['coinsRedeemed'] as num?)?.toInt() ?? 0,
        creditNotes = (j['creditNotes'] as num?)?.toInt() ?? 0,
        refundsPaise = (j['refundsPaise'] as num?)?.toInt() ?? 0,
        netPaise = (j['netPaise'] as num?)?.toInt() ?? 0,
        paidByMode = _intMap(j['paidByMode']),
        refundedByMode = _intMap(j['refundedByMode']),
        cashExpectedPaise = (j['cashExpectedPaise'] as num?)?.toInt() ?? 0,
        creditGivenPaise = (j['creditGivenPaise'] as num?)?.toInt() ?? 0,
        creditReturnedPaise = (j['creditReturnedPaise'] as num?)?.toInt() ?? 0,
        creditRecoveredPaise = (j['creditRecoveredPaise'] as num?)?.toInt() ?? 0,
        creditRecoveredByMode = _intMap(j['creditRecoveredByMode']);
}

/// Printable receipt (`GET /pos/sales/{id}/receipt`) — monospaced text.
class ReceiptDto {
  int width;
  String text;

  ReceiptDto({this.width = 32, this.text = ''});

  ReceiptDto.fromJson(Map<String, dynamic> j)
      : width = (j['width'] as num?)?.toInt() ?? 32,
        text = j['text']?.toString() ?? '';
}

/// `GET /pos/barcode/{code}` -> product + the quantity the code implies
/// (1 for a pack barcode, **grams** for a weighed scale label) + line price.
class PosScanDto {
  PosProductDto product;
  int qty;
  int linePaise;
  LotInfoDto? lot;

  PosScanDto({required this.product, this.qty = 1, this.linePaise = 0, this.lot});

  factory PosScanDto.fromJson(Map<String, dynamic> j) {
    final p = j['product'];
    return PosScanDto(
      product: PosProductDto.fromJson(
          p is Map ? Map<String, dynamic>.from(p) : j),
      qty: (j['qty'] as num?)?.toInt() ?? 1,
      linePaise: (j['linePaise'] as num?)?.toInt() ?? 0,
      lot: j['lot'] is Map
          ? LotInfoDto.fromJson(Map<String, dynamic>.from(j['lot'] as Map))
          : null,
    );
  }
}

/// `ShiftView` of the cash-drawer endpoints (`/pos/shifts/*`).
class ShiftViewDto {
  String? id;
  String? cashierId;
  String? openedAt;
  int openingFloatPaise;
  String? closedAt;
  int expectedCashPaise;
  int? countedCashPaise;
  int? variancePaise;
  String note;
  bool open;

  ShiftViewDto({
    this.id,
    this.cashierId,
    this.openedAt,
    this.openingFloatPaise = 0,
    this.closedAt,
    this.expectedCashPaise = 0,
    this.countedCashPaise,
    this.variancePaise,
    this.note = '',
    this.open = true,
  });

  ShiftViewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        cashierId = j['cashierId']?.toString(),
        openedAt = j['openedAt']?.toString(),
        openingFloatPaise = (j['openingFloatPaise'] as num?)?.toInt() ?? 0,
        closedAt = j['closedAt']?.toString(),
        expectedCashPaise = (j['expectedCashPaise'] as num?)?.toInt() ?? 0,
        countedCashPaise = (j['countedCashPaise'] as num?)?.toInt(),
        variancePaise = (j['variancePaise'] as num?)?.toInt(),
        note = j['note']?.toString() ?? '',
        open = j['open'] as bool? ?? true;
}

// ---------------------------------------------------------------------------
// Notifications inbox (`/me/notifications`)
// ---------------------------------------------------------------------------

/// One inbox row (`Row` schema): `{id, title, body, kind, ref, read, createdAt}`.
class NotificationRowDto {
  String? id;
  String? title;
  String? body;
  String? kind;
  String? ref;
  bool read;
  String? createdAt;

  /// Announcements only (60 section 1): the broadcast this row came from.
  String? broadcastId;

  NotificationRowDto({
    this.id,
    this.title,
    this.body,
    this.kind,
    this.ref,
    this.read = false,
    this.createdAt,
  });

  NotificationRowDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        title = j['title']?.toString(),
        body = j['body']?.toString(),
        kind = j['kind']?.toString(),
        ref = j['ref']?.toString(),
        read = j['read'] as bool? ?? false,
        broadcastId = j['broadcastId']?.toString(),
        createdAt = j['createdAt']?.toString();

  DateTime? get createdDateTime => parseIst(createdAt ?? '');
}

/// `GET /me/notifications` → paged inbox with an unread count.
class InboxDto {
  List<NotificationRowDto> items;
  int page;
  int size;
  int total;
  int unread;
  bool? hasMore;

  InboxDto({
    this.items = const [],
    this.page = 0,
    this.size = 20,
    this.total = 0,
    this.unread = 0,
  });

  InboxDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                NotificationRowDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        unread = (j['unread'] as num?)?.toInt() ?? 0,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

// ---------------------------------------------------------------------------
// Reviews (`/products/{productId}/reviews`)
// ---------------------------------------------------------------------------

class ReviewDto {
  String? id;
  int rating;
  String? comment;
  String? reviewer;
  String? createdAt;

  /// True when the review was written for a delivered order.
  bool verified;

  ReviewDto({
    this.id,
    this.rating = 0,
    this.comment,
    this.reviewer,
    this.createdAt,
    this.verified = false,
  });

  ReviewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        rating = (j['rating'] as num?)?.toInt() ?? 0,
        comment = j['comment']?.toString(),
        reviewer = j['reviewer']?.toString(),
        createdAt = j['createdAt']?.toString(),
        verified = j['verified'] == true;

  DateTime? get createdDateTime => parseIst(createdAt ?? '');
}

/// `GET /products/{id}/reviews` → paged reviews + aggregate rating.
class ReviewListDto {
  List<ReviewDto> items;
  int page;
  int size;
  int total;
  double rating;
  int reviewCount;

  ReviewListDto({
    this.items = const [],
    this.page = 0,
    this.size = 20,
    this.total = 0,
    this.rating = 0,
    this.reviewCount = 0,
  });

  ReviewListDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ReviewDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        rating = (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount = (j['reviewCount'] as num?)?.toInt() ?? 0;
}

// ---------------------------------------------------------------------------
// Stock movements (`/admin/stock-movements`)
// ---------------------------------------------------------------------------

/// One movement: `{id, productId, name, packLabel, delta, reason, at,
/// cashierId, refId, ref}`. `delta` is signed (positive = stock in, negative
/// = sold). `ref` is the order/counter-bill number behind the change (the
/// same `VSM-1001` a customer sees) and is null for a manual adjustment.
class StockMovementDto {
  String? id;
  String? productId;
  String? name;
  String? packLabel;
  int delta;
  String? reason;
  String? at;
  String? cashierId;
  String? refId;
  String? ref;

  StockMovementDto({
    this.id,
    this.productId,
    this.name,
    this.packLabel,
    this.delta = 0,
    this.reason,
    this.at,
    this.cashierId,
    this.refId,
    this.ref,
  });

  StockMovementDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        productId = j['productId']?.toString(),
        name = j['name']?.toString(),
        packLabel = j['packLabel']?.toString(),
        delta = (j['delta'] as num?)?.toInt() ?? 0,
        reason = j['reason']?.toString(),
        at = j['at']?.toString(),
        cashierId = j['cashierId']?.toString(),
        refId = j['refId']?.toString(),
        ref = j['ref']?.toString();

  DateTime? get atDateTime => parseIst(at ?? '');
}

class PageStockMovementDto {
  List<StockMovementDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageStockMovementDto({
    this.items = const [],
    this.page = 0,
    this.size = 20,
    this.total = 0,
  });

  PageStockMovementDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => StockMovementDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

// ---------------------------------------------------------------------------
// Period report (`/admin/reports/summary`)
// ---------------------------------------------------------------------------

/// Parsed result of `GET /admin/reports/summary?period=|from=|to=`.
///
/// The OpenAPI spec declares the 200 response as a single order-shaped
/// `Summary`, which cannot be right for a period report; the client therefore
/// parses defensively: a JSON array, a `{items: [...]}` page, or a single
/// object are all accepted, and optional aggregate fields are read when the
/// backend grows them.
class ReportSummaryDto {
  List<SummaryDto> orders;
  int? salesPaise;
  int? orderCount;
  Map<String, int> salesByDay;
  List<LowItemDto> topProducts;

  /// Online / counter split and credit figures of the documented payload
  /// (`onlineSalesPaise`, `posSalesPaise`, `posBills`, `posRefundsPaise`,
  /// `coinsIssued`, `creditGivenPaise`, `creditRecoveredPaise`,
  /// `outstandingCreditPaise`). Null when the server did not send them.
  int? onlineSalesPaise;
  int? onlineOrders;
  int? posSalesPaise;
  int? posBills;
  int? posRefundsPaise;

  /// Refunds on returned online orders in the period (listed apart, not
  /// subtracted from `salesPaise`).
  int? onlineRefundsPaise;
  int? coinsIssued;
  int? creditGivenPaise;
  int? creditRecoveredPaise;
  int? outstandingCreditPaise;

  ReportSummaryDto({
    this.orders = const [],
    this.salesPaise,
    this.orderCount,
    this.salesByDay = const {},
    this.topProducts = const [],
    this.onlineSalesPaise,
    this.onlineOrders,
    this.posSalesPaise,
    this.posBills,
    this.posRefundsPaise,
    this.onlineRefundsPaise,
    this.coinsIssued,
    this.creditGivenPaise,
    this.creditRecoveredPaise,
    this.outstandingCreditPaise,
  });

  factory ReportSummaryDto.fromAny(dynamic raw) {
    if (raw is List) {
      return ReportSummaryDto(orders: _summaries(raw));
    }
    if (raw is Map) {
      final j = Map<String, dynamic>.from(raw);
      final items = j['items'] ?? j['orders'];
      return ReportSummaryDto(
        orders: items is List ? _summaries(items) : const [],
        salesPaise: (j['salesPaise'] as num?)?.toInt() ??
            (j['revenuePaise'] as num?)?.toInt(),
        // Documented payload: `orders` is the order COUNT (online + counter).
        orderCount: (j['orders'] as num?)?.toInt() ??
            (j['orderCount'] as num?)?.toInt() ??
            (j['ordersToday'] as num?)?.toInt(),
        // Documented payload: `byDay` is `[{date, salesPaise, orders}]`.
        salesByDay: j['byDay'] is Map
            ? (j['byDay'] as Map).map((k, v) =>
                MapEntry(k.toString(), ((v as num?)?.toInt() ?? 0)))
            : j['byDay'] is List
                ? {
                    for (final e in (j['byDay'] as List).whereType<Map>())
                      '${e['date']}': (e['salesPaise'] as num?)?.toInt() ?? 0,
                  }
                : const {},
        onlineSalesPaise: (j['onlineSalesPaise'] as num?)?.toInt(),
        onlineOrders: (j['onlineOrders'] as num?)?.toInt(),
        posSalesPaise: (j['posSalesPaise'] as num?)?.toInt(),
        posBills: (j['posBills'] as num?)?.toInt(),
        posRefundsPaise: (j['posRefundsPaise'] as num?)?.toInt(),
        onlineRefundsPaise: (j['onlineRefundsPaise'] as num?)?.toInt(),
        coinsIssued: (j['coinsIssued'] as num?)?.toInt(),
        creditGivenPaise: (j['creditGivenPaise'] as num?)?.toInt(),
        creditRecoveredPaise: (j['creditRecoveredPaise'] as num?)?.toInt(),
        outstandingCreditPaise: (j['outstandingCreditPaise'] as num?)?.toInt(),
        topProducts: j['topProducts'] is List
            ? (j['topProducts'] as List)
                .whereType<Map>()
                .map((e) => LowItemDto.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
    }
    return ReportSummaryDto();
  }

  static List<SummaryDto> _summaries(List raw) => raw
      .whereType<Map>()
      .map((e) => SummaryDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

// ---------------------------------------------------------------------------
// Saved basket (`GET/PUT/DELETE /cart`) + public offers (`GET /coupons`)
// ---------------------------------------------------------------------------

/// One line of the server-side basket: a pack id (backend product id) + qty.
class SavedCartLineDto {
  String? productId;
  int qty;

  SavedCartLineDto({this.productId, this.qty = 1});

  SavedCartLineDto.fromJson(Map<String, dynamic> j)
      : productId = j['productId']?.toString(),
        qty = (j['qty'] as num?)?.toInt() ?? 1;
}

/// `GET /api/v1/cart` → `Cart { items, couponCode, coinMode, percent,
/// updatedAt }`. An empty basket is `200 {items: []}`, never 404.
class SavedCartDto {
  List<SavedCartLineDto> items;
  String? couponCode;
  String? coinMode; // NONE | ALL | PERCENT
  int? percent;
  String? updatedAt;

  SavedCartDto({
    this.items = const [],
    this.couponCode,
    this.coinMode,
    this.percent,
    this.updatedAt,
  });

  SavedCartDto.fromJson(Map<String, dynamic> j)
      : items = j['items'] is List
            ? (j['items'] as List)
                .whereType<Map>()
                .map((e) =>
                    SavedCartLineDto.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        couponCode = j['couponCode']?.toString(),
        coinMode = j['coinMode']?.toString(),
        percent = (j['percent'] as num?)?.toInt(),
        updatedAt = j['updatedAt']?.toString();

  bool get isEmpty => items.isEmpty;
}

/// One row of the public offers list (`GET /api/v1/coupons`).
///
/// `value` is **paise for FLAT and a percent for PERCENT**; `0` means
/// "no minimum" / "no cap". Internal fields (id, total limit, used count)
/// are deliberately withheld, so a browsed offer carries `uses: 0`.
class PublicCouponDto {
  String? code;
  String? kind; // FLAT | PERCENT
  int value;
  int minOrderPaise;
  int maxDiscountPaise;
  String? categoryId;
  List<String> categoryIds;
  String? startAt;
  String? endAt;
  bool worksWithCoins;
  bool firstOrderOnly;

  /// Item targeting as the server words it (`appliesToText`, e.g. "All
  /// items" / "Mango Pickle"), plus the ids for the product / group targets.
  String appliesToText;
  List<String> productIds;
  List<String> productGroupIds;

  PublicCouponDto({
    this.code,
    this.kind,
    this.value = 0,
    this.minOrderPaise = 0,
    this.maxDiscountPaise = 0,
    this.categoryId,
    this.categoryIds = const <String>[],
    this.startAt,
    this.endAt,
    this.worksWithCoins = true,
    this.firstOrderOnly = false,
    this.appliesToText = '',
    this.productIds = const <String>[],
    this.productGroupIds = const <String>[],
  });

  PublicCouponDto.fromJson(Map<String, dynamic> j)
      : code = j['code']?.toString(),
        kind = j['kind']?.toString(),
        value = (j['value'] as num?)?.toInt() ?? 0,
        minOrderPaise = (j['minOrderPaise'] as num?)?.toInt() ?? 0,
        maxDiscountPaise = (j['maxDiscountPaise'] as num?)?.toInt() ?? 0,
        categoryId = j['categoryId']?.toString(),
        categoryIds = _stringList(j['categoryIds'], j['categoryId']?.toString()),
        startAt = j['startAt']?.toString(),
        endAt = j['endAt']?.toString(),
        worksWithCoins = j['worksWithCoins'] != false,
        firstOrderOnly = j['firstOrderOnly'] == true,
        appliesToText = (j['appliesToText'] ?? '').toString(),
        productIds = _stringList(j['productIds']),
        productGroupIds = _stringList(j['productGroupIds']);
}

// ---------------------------------------------------------------------------
// Units of measure (`GET /units`, `GET|POST|PUT|DELETE /admin/units`)
// ---------------------------------------------------------------------------

/// One unit a product can be sold in. `code` is what `product.unit` stores —
/// the backend rejects a product whose unit is not an active row here, which
/// is why the product form picks from this list instead of free-typing.
class UnitDto {
  String code;
  String nameEn;
  String nameGu;

  /// `UNIT` (counted) or `WEIGHT` (priced per 1000 base units).
  String soldBy;
  int sortOrder;
  bool active;

  UnitDto({
    required this.code,
    this.nameEn = '',
    this.nameGu = '',
    this.soldBy = 'UNIT',
    this.sortOrder = 0,
    this.active = true,
  });

  UnitDto.fromJson(Map<String, dynamic> j)
      : code = j['code']?.toString() ?? '',
        nameEn = j['nameEn']?.toString() ?? '',
        nameGu = j['nameGu']?.toString() ?? '',
        soldBy = j['soldBy']?.toString() ?? 'UNIT',
        sortOrder = (j['sortOrder'] as num?)?.toInt() ?? 0,
        active = j['active'] as bool? ?? true;

  /// English name, falling back to the code so a row is never blank.
  String get label => nameEn.isNotEmpty ? nameEn : code;
}

// ---------------------------------------------------------------------------
// Admin credit (udhar): `/admin/credit/*`, `/admin/reports/credit`
// ---------------------------------------------------------------------------

/// One customer row of `GET /admin/credit/accounts`.
class DebtorDto {
  String? customerId;
  String? name;
  String? mobile;
  int balancePaise;
  int limitPaise;
  String? lastSaleAt;
  String? lastPaymentAt;

  /// The customer account is blocked: no credit sales (`blocked`).
  bool blocked;

  /// `availablePaise` as the server sent it (null in the report's debtors).
  int? serverAvailablePaise;

  DebtorDto({
    this.customerId,
    this.name,
    this.mobile,
    this.balancePaise = 0,
    this.limitPaise = 0,
    this.lastSaleAt,
    this.lastPaymentAt,
    this.blocked = false,
    this.serverAvailablePaise,
  });

  /// Credit still free to use: the server's `availablePaise`, else
  /// limit - owed (never below zero).
  int get availablePaise {
    if (serverAvailablePaise != null) return serverAvailablePaise!;
    final left = limitPaise - balancePaise;
    return left < 0 ? 0 : left;
  }

  /// Credit is on for this customer (a limit above zero).
  bool get creditEligible => limitPaise > 0;

  DebtorDto.fromJson(Map<String, dynamic> j)
      : customerId = j['customerId']?.toString(),
        name = j['name']?.toString(),
        mobile = j['mobile']?.toString(),
        balancePaise = (j['balancePaise'] as num?)?.toInt() ?? 0,
        limitPaise = (j['limitPaise'] as num?)?.toInt() ?? 0,
        lastSaleAt = j['lastSaleAt']?.toString(),
        lastPaymentAt = j['lastPaymentAt']?.toString(),
        blocked = j['blocked'] == true,
        serverAvailablePaise = (j['availablePaise'] as num?)?.toInt();
}

class PageDebtorDto {
  List<DebtorDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageDebtorDto({this.items = const [], this.page = 0, this.size = 20, this.total = 0});

  PageDebtorDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => DebtorDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

class CreditDayRowDto {
  String? date;
  int creditGivenPaise;
  int recoveredPaise;

  CreditDayRowDto({this.date, this.creditGivenPaise = 0, this.recoveredPaise = 0});

  CreditDayRowDto.fromJson(Map<String, dynamic> j)
      : date = j['date']?.toString(),
        creditGivenPaise = (j['creditGivenPaise'] as num?)?.toInt() ?? 0,
        recoveredPaise = (j['recoveredPaise'] as num?)?.toInt() ?? 0;
}

/// `GET /admin/reports/credit`.
class CreditReportDto {
  String? from;
  String? to;
  int outstandingPaise;
  int customersWithDues;
  int givenPaise;
  int returnedPaise;
  int recoveredPaise;
  int writtenOffPaise;
  int addedPaise;
  Map<String, int> recoveredByMode;
  List<CreditDayRowDto> byDay;
  List<DebtorDto> topDebtors;

  CreditReportDto({
    this.from,
    this.to,
    this.outstandingPaise = 0,
    this.customersWithDues = 0,
    this.givenPaise = 0,
    this.returnedPaise = 0,
    this.recoveredPaise = 0,
    this.writtenOffPaise = 0,
    this.addedPaise = 0,
    this.recoveredByMode = const {},
    this.byDay = const [],
    this.topDebtors = const [],
  });

  CreditReportDto.fromJson(Map<String, dynamic> j)
      : from = j['from']?.toString(),
        to = j['to']?.toString(),
        outstandingPaise = (j['outstandingPaise'] as num?)?.toInt() ?? 0,
        customersWithDues = (j['customersWithDues'] as num?)?.toInt() ?? 0,
        givenPaise = (j['givenPaise'] as num?)?.toInt() ?? 0,
        returnedPaise = (j['returnedPaise'] as num?)?.toInt() ?? 0,
        recoveredPaise = (j['recoveredPaise'] as num?)?.toInt() ?? 0,
        writtenOffPaise = (j['writtenOffPaise'] as num?)?.toInt() ?? 0,
        addedPaise = (j['addedPaise'] as num?)?.toInt() ?? 0,
        recoveredByMode = {
          if (j['recoveredByMode'] is Map)
            for (final e in (j['recoveredByMode'] as Map).entries)
              '${e.key}': (e.value as num?)?.toInt() ?? 0,
        },
        byDay = (j['byDay'] as List? ?? [])
            .whereType<Map>()
            .map((e) => CreditDayRowDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        topDebtors = (j['topDebtors'] as List? ?? [])
            .whereType<Map>()
            .map((e) => DebtorDto.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

// ---------------------------------------------------------------------------
// POS returns + credit collection
// ---------------------------------------------------------------------------

class ReturnItemRecordDto {
  String? saleItemId;
  int qty;
  int refundPaise;
  int taxablePaise;
  int cgstPaise;
  int sgstPaise;

  ReturnItemRecordDto({
    this.saleItemId,
    this.qty = 0,
    this.refundPaise = 0,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
  });

  ReturnItemRecordDto.fromJson(Map<String, dynamic> j)
      : saleItemId = j['saleItemId']?.toString(),
        qty = (j['qty'] as num?)?.toInt() ?? 0,
        refundPaise = (j['refundPaise'] as num?)?.toInt() ?? 0,
        taxablePaise = (j['taxablePaise'] as num?)?.toInt() ?? 0,
        cgstPaise = (j['cgstPaise'] as num?)?.toInt() ?? 0,
        sgstPaise = (j['sgstPaise'] as num?)?.toInt() ?? 0;
}

/// `GET/POST /pos/sales/{id}/returns` - a credit note.
class ReturnRecordDto {
  String? id;
  String? creditNoteNo;
  String? saleId;
  String? cashierId;
  String? reason;
  int refundPaise;
  int taxablePaise;
  int cgstPaise;
  int sgstPaise;
  int coinsClawedBack;
  int coinsRestored;
  String? createdAt;
  List<ReturnItemRecordDto> items;
  List<PaymentRecordDto> refunds;
  int creditAdjustedPaise;
  int couponClawbackPaise;

  ReturnRecordDto({
    this.id,
    this.creditNoteNo,
    this.saleId,
    this.cashierId,
    this.reason,
    this.refundPaise = 0,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
    this.coinsClawedBack = 0,
    this.coinsRestored = 0,
    this.createdAt,
    this.items = const [],
    this.refunds = const [],
    this.creditAdjustedPaise = 0,
    this.couponClawbackPaise = 0,
  });

  ReturnRecordDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        creditNoteNo = j['creditNoteNo']?.toString(),
        saleId = j['saleId']?.toString(),
        cashierId = j['cashierId']?.toString(),
        reason = j['reason']?.toString(),
        refundPaise = (j['refundPaise'] as num?)?.toInt() ?? 0,
        taxablePaise = (j['taxablePaise'] as num?)?.toInt() ?? 0,
        cgstPaise = (j['cgstPaise'] as num?)?.toInt() ?? 0,
        sgstPaise = (j['sgstPaise'] as num?)?.toInt() ?? 0,
        coinsClawedBack = (j['coinsClawedBack'] as num?)?.toInt() ?? 0,
        coinsRestored = (j['coinsRestored'] as num?)?.toInt() ?? 0,
        createdAt = j['createdAt']?.toString(),
        items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ReturnItemRecordDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        refunds = (j['refunds'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PaymentRecordDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        creditAdjustedPaise = (j['creditAdjustedPaise'] as num?)?.toInt() ?? 0,
        couponClawbackPaise = (j['couponClawbackPaise'] as num?)?.toInt() ?? 0;
}

/// `POST /pos/credit/payments` receipt.
class CreditReceiptDto {
  String? id;
  String? receiptNo;
  String? customerId;
  String? customerMobile;
  int amountPaise;
  List<PaymentRecordDto> payments;
  int balanceDuePaise;
  String? note;
  String? at;

  CreditReceiptDto({
    this.id,
    this.receiptNo,
    this.customerId,
    this.customerMobile,
    this.amountPaise = 0,
    this.payments = const [],
    this.balanceDuePaise = 0,
    this.note,
    this.at,
  });

  CreditReceiptDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        receiptNo = j['receiptNo']?.toString(),
        customerId = j['customerId']?.toString(),
        customerMobile = j['customerMobile']?.toString(),
        amountPaise = (j['amountPaise'] as num?)?.toInt() ?? 0,
        payments = (j['payments'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PaymentRecordDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        balanceDuePaise = (j['balanceDuePaise'] as num?)?.toInt() ?? 0,
        note = j['note']?.toString(),
        at = j['at']?.toString();
}

/// `GET /products/{id}/reviews/mine` - can the caller review, and what did
/// they already write.
class MyReviewDto {
  bool canReview;
  ReviewDto? review;

  MyReviewDto({this.canReview = false, this.review});

  MyReviewDto.fromJson(Map<String, dynamic> j)
      : canReview = j['canReview'] == true,
        review = j['review'] is Map
            ? ReviewDto.fromJson(Map<String, dynamic>.from(j['review'] as Map))
            : null;
}

/// One row of `POST /cart/coupons`: a coupon tried on the current cart.
class CouponOptionDto {
  String code;
  bool applicable;

  /// What this coupon saves on this cart (paise); exactly what the quote
  /// would give. Never computed on the device.
  int discountPaise;

  /// `MIN_ORDER`, `CATEGORY`, `EXPIRED`, ... when not applicable.
  String? reason;

  /// Ready-to-show sentence when not applicable.
  String? message;
  int shortfallPaise;
  bool worksWithCoins;

  /// Plain-language limit ("Only on Dairy and Amul Milk") and the cart lines
  /// the discount lands on (`name`, `discountPaise`).
  String appliesToText;
  List<({String name, int discountPaise})> coveredLines;

  CouponOptionDto.fromJson(Map<String, dynamic> j)
      : code = (j['code']?.toString() ?? '').toUpperCase(),
        applicable = j['applicable'] == true,
        discountPaise = (j['discountPaise'] as num?)?.toInt() ?? 0,
        reason = j['reason']?.toString(),
        message = j['message']?.toString(),
        shortfallPaise = (j['shortfallPaise'] as num?)?.toInt() ?? 0,
        worksWithCoins = j['worksWithCoins'] != false,
        appliesToText = (j['appliesToText'] ?? '').toString(),
        coveredLines = [
          for (final e in (j['coveredLines'] as List? ?? const []))
            if (e is Map)
              (
                name: (e['name'] ?? '').toString(),
                discountPaise: (e['discountPaise'] as num?)?.toInt() ?? 0
              )
        ];
}
