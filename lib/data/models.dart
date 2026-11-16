/// Data models — direct port of assets/data.js structures.
library;

import 'api/flash_dto.dart';

class Category {
  String id;
  String name;
  String nameGu;
  String icon;
  String tone;

  Category({
    required this.id,
    required this.name,
    required this.nameGu,
    required this.icon,
    required this.tone,
  });
}

/// A sellable pack of a product. Mutable, like the JS prototype objects —
/// `stock` is edited in place by cart/order logic and the admin restock flow.
///
/// Integration note: each pack maps to **one backend product** (the backend
/// has no variant concept). [backendId] holds that backend product UUID for
/// the pack; it is null for packs that have not been persisted yet.
class Variant {
  String label;
  num price;
  num mrp;
  String unit;
  int stock;
  String? backendId;
  bool active;

  /// Running flash-sale offer for this pack. While it is set, [price] is the
  /// flash price the server charges and [listPrice] is the normal price.
  FlashOffer? flash;
  num? listPrice;

  Variant({
    required this.label,
    required this.price,
    required this.mrp,
    required this.unit,
    this.stock = 0,
    this.backendId,
    this.active = true,
    this.flash,
    this.listPrice,
  });

  /// The struck-through reference price: the normal price during a flash
  /// sale, else the printed MRP.
  num get strike => flash != null ? (listPrice ?? price) : mrp;

  Variant copy() => Variant(
      label: label,
      price: price,
      mrp: mrp,
      unit: unit,
      stock: stock,
      backendId: backendId,
      active: active,
      flash: flash,
      listPrice: listPrice);
}

/// Catalogue product. Mutable fields mirror the prototype's STATE.products
/// (admin edits and stock sync write in place).
class Product {
  String id;
  String name;
  String nameGu;
  String category;
  String unit;
  String desc;
  String descGu;
  double rating;
  int reviews;
  String art;
  String tone;
  int stock;
  int lowStock;
  bool available;
  bool earnsCoins;
  bool allowCoins;
  bool hotSale;
  List<Variant> variants;
  int defaultVariant;

  Product({
    required this.id,
    required this.name,
    required this.nameGu,
    required this.category,
    required this.unit,
    required this.desc,
    required this.descGu,
    required this.rating,
    required this.reviews,
    required this.art,
    required this.tone,
    required this.stock,
    required this.lowStock,
    required this.available,
    required this.earnsCoins,
    required this.allowCoins,
    this.hotSale = false,
    required this.variants,
    required this.defaultVariant,
  });

  Product deepCopy() => Product(
        id: id,
        name: name,
        nameGu: nameGu,
        category: category,
        unit: unit,
        desc: desc,
        descGu: descGu,
        rating: rating,
        reviews: reviews,
        art: art,
        tone: tone,
        stock: stock,
        lowStock: lowStock,
        available: available,
        earnsCoins: earnsCoins,
        allowCoins: allowCoins,
        hotSale: hotSale,
        variants: variants.map((v) => v.copy()).toList(),
        defaultVariant: defaultVariant,
      );

  bool get isLowStock => stock > 0 && stock <= lowStock;
  bool get isOutOfStock => stock <= 0;
}

class Coupon {
  String code;
  String desc;
  String type; // 'flat' | 'percent'
  num value;
  num? maxDiscount;
  num min;

  /// Legacy single scope: `'all'` or one category id. Kept as the first of
  /// [categoryIds] so old rows and demo data still read correctly.
  String scope;

  /// Every category this coupon covers (backend `categoryIds`). Empty = all
  /// categories — the store-wide default.
  List<String> categoryIds;
  bool active;
  String starts;
  String expires;
  int uses;
  int maxUses;
  bool worksWithCoins;
  bool firstOrderOnly;

  /// Item targeting (`productIds` = single packs, `productGroupIds` = whole
  /// products with every pack) and their display names (id -> name). Empty =
  /// no item limit. The server's `appliesTo` text is in [appliesText].
  List<String> productIds;
  List<String> productGroupIds;
  Map<String, String> itemNames;
  String appliesText;

  Coupon({
    required this.code,
    required this.desc,
    required this.type,
    required this.value,
    this.maxDiscount,
    required this.min,
    required this.scope,
    this.categoryIds = const <String>[],
    required this.active,
    required this.starts,
    required this.expires,
    required this.uses,
    required this.maxUses,
    required this.worksWithCoins,
    required this.firstOrderOnly,
    this.productIds = const <String>[],
    this.productGroupIds = const <String>[],
    this.itemNames = const <String, String>{},
    this.appliesText = '',
  });

  /// True when the coupon applies to [categoryId] — a stored list wins, then
  /// the single [scope] (empty scope in the list means "every category").
  bool coversCategory(String categoryId) {
    if (categoryIds.isNotEmpty) return categoryIds.contains(categoryId);
    return scope.isEmpty || scope == 'all' || scope == categoryId;
  }

  Coupon copyWith({
    String? desc,
    String? type,
    num? value,
    num? maxDiscount,
    num? min,
    String? scope,
    List<String>? categoryIds,
    bool? active,
    String? starts,
    String? expires,
    int? uses,
    int? maxUses,
    bool? worksWithCoins,
    bool? firstOrderOnly,
    List<String>? productIds,
    List<String>? productGroupIds,
  }) {
    return Coupon(
      code: code,
      productIds: productIds ?? this.productIds,
      productGroupIds: productGroupIds ?? this.productGroupIds,
      itemNames: itemNames,
      appliesText: appliesText,
      desc: desc ?? this.desc,
      type: type ?? this.type,
      value: value ?? this.value,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      min: min ?? this.min,
      scope: scope ?? this.scope,
      categoryIds: categoryIds ?? this.categoryIds,
      active: active ?? this.active,
      starts: starts ?? this.starts,
      expires: expires ?? this.expires,
      uses: uses ?? this.uses,
      maxUses: maxUses ?? this.maxUses,
      worksWithCoins: worksWithCoins ?? this.worksWithCoins,
      firstOrderOnly: firstOrderOnly ?? this.firstOrderOnly,
    );
  }
}

class CoinRule {
  String id;
  String name;
  num spend;
  int coins;
  String mode; // 'pro-rata' | 'slab'
  String scope;
  bool active;
  String starts;
  String expires;
  bool everGreen;

  CoinRule({
    required this.id,
    required this.name,
    required this.spend,
    required this.coins,
    required this.mode,
    required this.scope,
    required this.active,
    required this.starts,
    required this.expires,
    required this.everGreen,
  });

  CoinRule copyWith({
    String? name,
    int? spend,
    int? coins,
    String? mode,
    String? scope,
    bool? active,
    String? starts,
    String? expires,
    bool? everGreen,
  }) {
    return CoinRule(
      id: id,
      name: name ?? this.name,
      spend: spend ?? this.spend,
      coins: coins ?? this.coins,
      mode: mode ?? this.mode,
      scope: scope ?? this.scope,
      active: active ?? this.active,
      starts: starts ?? this.starts,
      expires: expires ?? this.expires,
      everGreen: everGreen ?? this.everGreen,
    );
  }
}

class CoinSettings {
  num coinValue;
  int maxPercent;
  int expiryMonths;

  CoinSettings({
    required this.coinValue,
    required this.maxPercent,
    required this.expiryMonths,
  });

  CoinSettings copyWith({num? coinValue, int? maxPercent, int? expiryMonths}) => CoinSettings(
        coinValue: coinValue ?? this.coinValue,
        maxPercent: maxPercent ?? this.maxPercent,
        expiryMonths: expiryMonths ?? this.expiryMonths,
      );
}

class HotSale {
  bool live;
  String eyebrow;
  String title;
  String starts;
  String ends;
  List<String> featured;

  HotSale({
    required this.live,
    required this.eyebrow,
    required this.title,
    required this.starts,
    required this.ends,
    required this.featured,
  });

  HotSale copyWith({
    bool? live,
    String? eyebrow,
    String? title,
    String? starts,
    String? ends,
    List<String>? featured,
  }) {
    return HotSale(
      live: live ?? this.live,
      eyebrow: eyebrow ?? this.eyebrow,
      title: title ?? this.title,
      starts: starts ?? this.starts,
      ends: ends ?? this.ends,
      featured: featured ?? this.featured,
    );
  }
}

class Address {
  String id;
  String label;

  /// Street line (`line1` on the wire) — the backend stores `line1`, `area`
  /// and `pincode` as separate required fields.
  String detail;

  /// Locality / area name. Required by the backend's address schema.
  String area;

  /// 6-digit PIN code. Required by the backend's address schema.
  String pincode;

  String phone;

  /// Backend `isDefault` - the saved address new orders pre-select.
  bool isDefault;

  Address({
    required this.id,
    required this.label,
    required this.detail,
    required this.phone,
    this.area = '',
    this.pincode = '',
    this.isDefault = false,
  });

  /// The full delivery line the UI shows: street, area, pincode.
  String get full => [detail, area, pincode]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');

  /// True when the row carries everything the backend requires to deliver.
  bool get isComplete => area.trim().isNotEmpty && pincode.trim().isNotEmpty;
}

class CartItem {
  String productId;
  int variantIndex;
  int qty;

  CartItem({
    required this.productId,
    required this.variantIndex,
    this.qty = 1,
  });
}

/// Snapshot of a product line inside an order (immutable once placed).
class OrderItem {
  String productId;
  int variantIndex;
  String name;
  String nameGu;
  String unit;
  num price;
  int qty;
  bool earnsCoins;
  bool allowCoins;
  String art;
  String tone;

  /// Picture snapshotted on the order line (`imageUrl`); empty when none.
  String imageUrl;

  OrderItem({
    this.imageUrl = '',
    required this.productId,
    required this.variantIndex,
    required this.name,
    required this.nameGu,
    required this.unit,
    required this.price,
    required this.qty,
    required this.earnsCoins,
    required this.allowCoins,
    required this.art,
    required this.tone,
  });
}

class StatusEvent {
  String status;
  DateTime at;

  StatusEvent({required this.status, required this.at});
}

class Bill {
  num subtotal;
  String couponCode;
  num couponDiscount;
  int coinsUsed;
  num delivery;
  num total;

  Bill({
    required this.subtotal,
    required this.couponCode,
    required this.couponDiscount,
    required this.coinsUsed,
    required this.delivery,
    required this.total,
  });
}

class DeliveryPartner {
  String name;
  String role;
  String phone;

  DeliveryPartner({
    required this.name,
    required this.role,
    required this.phone,
  });
}

class Order {
  String number;
  String customer;
  String phone;
  String customerEmail;
  List<OrderItem> items;
  String mode; // 'delivery' | 'pickup'
  String address;
  String slot;
  String payment;
  String paymentState; // Pending | Paid | Refunded
  String status;
  List<StatusEvent> statusHistory;
  DateTime placedAt;
  DateTime updatedAt;
  Bill bill;
  int coinsUsed;
  int coinsEarned;
  String coinRule;
  String cancelReason;
  DeliveryPartner? partner;
  bool stockReserved;
  String createdBy;

  /// Backend `PAYMENT_PENDING`: an ONLINE order waiting for its Razorpay
  /// payment. The wire status is shown as "Placed"; this flag drives the
  /// "Pay now / Cancel" card and the "confirming payment" state.
  bool awaitingPayment = false;

  /// The order's `paymentSession` (a `PaymentSessionDto`) while
  /// [awaitingPayment]; null once the payment is closed.
  dynamic paySession;

  /// Wire `paymentStatus` as the server sent it (`NONE`, `INITIATED`,
  /// `CAPTURED`, `REFUNDED`, `FAILED`).
  String payWire = '';

  /// Who cancelled (`CUSTOMER` / `SHOP` / `SYSTEM`) and why in machine form
  /// (`CUSTOMER_CANCELLED`, `REJECTED_BY_SHOP`, `CANCELLED_BY_SHOP`,
  /// `PAYMENT_TIMEOUT`, `PAYMENT_FAILED`). Empty unless cancelled.
  String cancelledBy = '';
  String cancelCode = '';

  /// When an unpaid ONLINE order is auto-cancelled (`paymentExpiresAt`).
  DateTime? paymentExpiresAt;

  Order({
    required this.number,
    required this.customer,
    required this.phone,
    required this.customerEmail,
    required this.items,
    required this.mode,
    required this.address,
    required this.slot,
    required this.payment,
    required this.paymentState,
    required this.status,
    required this.statusHistory,
    required this.placedAt,
    required this.updatedAt,
    required this.bill,
    required this.coinsUsed,
    required this.coinsEarned,
    required this.coinRule,
    required this.cancelReason,
    this.partner,
    required this.stockReserved,
    required this.createdBy,
  });

  bool get isCancelled => status == 'Cancelled';
  bool get isTerminal => status == 'Delivered' || status == 'Picked Up' || status == 'Cancelled';

  Order copyWith({
    String? status,
    List<StatusEvent>? statusHistory,
    DateTime? updatedAt,
    String? paymentState,
    String? cancelReason,
    DeliveryPartner? partner,
    bool? stockReserved,
    String? address,
    String? slot,
    String? payment,
    String? customerEmail,
    String? customer,
    String? phone,
    Bill? bill,
    int? coinsUsed,
    int? coinsEarned,
  }) {
    final copy = Order(
      number: number,
      customer: customer ?? this.customer,
      phone: phone ?? this.phone,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items,
      mode: mode,
      address: address ?? this.address,
      slot: slot ?? this.slot,
      payment: payment ?? this.payment,
      paymentState: paymentState ?? this.paymentState,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      placedAt: placedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bill: bill ?? this.bill,
      coinsUsed: coinsUsed ?? this.coinsUsed,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      coinRule: coinRule,
      cancelReason: cancelReason ?? this.cancelReason,
      partner: partner ?? this.partner,
      stockReserved: stockReserved ?? this.stockReserved,
      createdBy: createdBy,
    );
    copy.awaitingPayment = awaitingPayment;
    copy.paySession = paySession;
    copy.payWire = payWire;
    copy.cancelledBy = cancelledBy;
    copy.cancelCode = cancelCode;
    copy.paymentExpiresAt = paymentExpiresAt;
    return copy;
  }
}

class LedgerEntry {
  String id;
  String title;
  String sub;
  int coins;
  String status; // pending | spent | credited
  String type; // earn | spend | bonus
  String orderNumber;
  DateTime date;

  LedgerEntry({
    required this.id,
    required this.title,
    required this.sub,
    required this.coins,
    required this.status,
    required this.type,
    required this.orderNumber,
    required this.date,
  });
}

class StockMove {
  String id;
  String productId;
  String productName;
  int variantIndex;
  String variantLabel;
  int qty;
  DateTime at;
  String note;

  StockMove({
    required this.id,
    required this.productId,
    required this.productName,
    required this.variantIndex,
    required this.variantLabel,
    required this.qty,
    required this.at,
    required this.note,
  });
}

class WeekSale {
  String day;
  num amount;

  WeekSale({required this.day, required this.amount});
}

class StoreInfo {
  String name;
  String nameGu;
  String phone;
  String phoneHref;
  String address;
  String promise;

  /// URL of the shop logo from `GET /shop-settings`. Empty until the backend
  /// ships the field (see `BACKEND_REQUEST_shop_identity.md`) — every screen
  /// falls back to the drawn logo while it is empty.
  String logo;

  /// Opening hours as the admin typed them (`9 AM – 9 PM`). Empty until the
  /// backend ships `openHours`; screens hide the pill rather than fake it.
  String openHours;

  /// Gujarati texts from the shop profile (empty = fall back to English).
  String addressGu;
  String promiseGu;

  /// Address / tagline in the app's language (Gujarati falls back to English).
  String addressFor(bool gu) =>
      gu && addressGu.trim().isNotEmpty ? addressGu : address;
  String promiseFor(bool gu) =>
      gu && promiseGu.trim().isNotEmpty ? promiseGu : promise;

  StoreInfo({
    this.addressGu = '',
    this.promiseGu = '',
    required this.name,
    required this.nameGu,
    required this.phone,
    required this.phoneHref,
    required this.address,
    required this.promise,
    this.logo = '',
    this.openHours = '',
  });
}
