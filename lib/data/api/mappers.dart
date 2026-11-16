import '../ist.dart';
import '../models.dart';
import '../seed_data.dart' as seedData;
import 'api_service.dart' show paiseToRupees, statusFromWire, fulfilFromWire, coinModeFromWire, couponKindFromWire;
import 'dto.dart';

/// Maps backend DTOs into the app's existing UI models.
///
/// The backend stores **one product row per pack** (no variant concept), so a
/// frontend [Product] (which groups several packs) is rebuilt by grouping rows
/// that share `categoryId` + `nameEn` and differ by `packSize`.

const List<String> _tones = ['mint', 'peach', 'gold', 'rose', 'sky', 'amber', 'lilac', 'sand'];
const List<String> _catIcons = ['bag', 'bolt', 'gift', 'heart', 'home'];

String _toneFor(String seed) {
  var h = 0;
  for (final r in seed.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return _tones[h % _tones.length];
}

String _iconFor(String seed) {
  var h = 0;
  for (final r in seed.runes) {
    h = (h * 17 + r) & 0x7fffffff;
  }
  return _catIcons[h % _catIcons.length];
}

/// A resolved cart/order line: a specific pack (backend product) of a grouped
/// frontend product.
class PackRef {
  final Product product;
  final int variantIndex;
  final Variant variant;
  const PackRef(this.product, this.variantIndex, this.variant);
}

/// Grouping key for one backend pack row. The backend's `productGroupId`
/// (same product, different packs) is authoritative; rows without one fall
/// back to the legacy `categoryId` + `nameEn` rule.
String adminGroupKey(AdminProductDto pack) {
  final gid = pack.productGroupId;
  if (gid != null && gid.isNotEmpty) return 'grp::$gid';
  return '${pack.categoryId ?? ''}::${pack.nameEn ?? ''}';
}

/// Grouping key for a public catalog pack row (same rule as [adminGroupKey]).
String publicGroupKey(PublicProductDto pack) {
  final gid = pack.productGroupId;
  if (gid != null && gid.isNotEmpty) return 'grp::$gid';
  return '${pack.categoryId ?? ''}::${pack.nameEn ?? ''}';
}

/// Index every pack by its backend product id so cart/order lines that only
/// carry a `productId` can be resolved to a name/price/pack.
Map<String, PackRef> buildPackIndex(List<Product> products) {
  final index = <String, PackRef>{};
  for (final p in products) {
    for (var i = 0; i < p.variants.length; i++) {
      final v = p.variants[i];
      final id = v.backendId;
      if (id != null && id.isNotEmpty) {
        index[id] = PackRef(p, i, v);
      }
    }
  }
  return index;
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

Category categoryFromDto(CategoryDto dto, int index) {
  final name = dto.nameEn ?? 'Category';
  return Category(
    id: dto.id ?? 'cat-$index',
    name: name,
    nameGu: (dto.nameGu ?? "").trim().isEmpty ? name : dto.nameGu!,
    icon: _iconFor(name),
    tone: _tones[index % _tones.length],
  );
}

List<Category> categoriesFromDtos(List<CategoryDto> dtos) =>
    dtos.asMap().entries.map((e) => categoryFromDto(e.value, e.key)).toList();

// ---------------------------------------------------------------------------
// Products (group packs -> products)
// ---------------------------------------------------------------------------

Product _groupToProduct(List<AdminProductDto> packs, String groupId) {
  final first = packs.first;
  final name = first.nameEn ?? 'Product';
  final variants = <Variant>[];
  var stock = 0;
  var anyActive = false;
  var anyInStock = false;
  var earns = false;
  var redeemable = false;
  var anyHot = false;
  var low = first.lowThreshold;

  for (final pack in packs) {
    final label = (pack.packSize != null && pack.packSize!.isNotEmpty)
        ? pack.packSize!
        : (pack.unit ?? '');
    final q = pack.qtyOnHand;
    stock += q;
    if (pack.active) anyActive = true;
    if (pack.inStock || q > 0) anyInStock = true;
    if (pack.earnsCoins) earns = true;
    if (pack.coinRedeemable) redeemable = true;
    if (pack.hotSale) anyHot = true;
    variants.add(Variant(
      label: label.isEmpty ? (pack.unit ?? 'Unit') : label,
      price: paiseToRupees(pack.pricePaise),
      mrp: paiseToRupees(pack.mrpPaise),
      unit: pack.unit ?? label,
      stock: q,
      backendId: pack.id,
      active: pack.active,
    ));
  }

  return Product(
    id: groupId,
    name: name,
    nameGu: (first.nameGu ?? "").trim().isEmpty ? name : first.nameGu!,
    category: first.categoryId ?? '',
    unit: variants.isNotEmpty ? variants.first.unit : '',
    desc: first.description ?? '',
    descGu: first.description ?? '',
    // The backend carries one rating/reviewCount per pack; a grouped product
    // shows the highest rating and the summed review count of its packs.
    rating: packs.fold<double>(0, (best, p) => p.rating > best ? p.rating : best),
    reviews: packs.fold<int>(0, (sum, p) => sum + p.reviewCount),
    // The picture lives on each pack; the card shows the first one that has
    // one (the backend picks the same "first non-empty" rule). Hardcoding ''
    // here used to wipe a freshly uploaded photo on the next list refresh.
    art: packs.map((p) => p.imageUrl ?? '').firstWhere(
          (u) => u.isNotEmpty,
          orElse: () => '',
        ),
    tone: _toneFor(name),
    stock: stock,
    lowStock: low,
    available: anyActive && anyInStock,
    earnsCoins: earns,
    allowCoins: redeemable,
    hotSale: anyHot,
    variants: variants,
    defaultVariant: 0,
  );
}

/// Group per-pack backend rows into frontend products. [usedIds] accumulates
/// generated group ids to keep them unique within this batch.
List<Product> productsFromBackend(List<AdminProductDto> packs, {Set<String>? usedIds}) {
  final used = usedIds ?? <String>{};
  final groups = <String, List<AdminProductDto>>{};
  final order = <String>[];
  for (final pack in packs) {
    final key = adminGroupKey(pack);
    if (!groups.containsKey(key)) {
      groups[key] = [];
      order.add(key);
    }
    groups[key]!.add(pack);
  }

  final out = <Product>[];
  for (final key in order) {
    var base = _slug(groups[key]!.first.nameEn ?? 'item');
    var id = base;
    var n = 2;
    while (used.contains(id)) {
      id = '$base-$n';
      n++;
    }
    used.add(id);
    out.add(_groupToProduct(groups[key]!, id));
  }
  return out;
}

String _slug(String input) {
  var s = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'item' : s;
}

// ---------------------------------------------------------------------------
// Coupons / coins / banners / shop
// ---------------------------------------------------------------------------

Coupon couponFromDto(CouponDto dto) {
  final type = couponKindFromWire(dto.kind);
  final min = paiseToRupees(dto.minOrderPaise);
  // The backend stores "no cap" as 0; a 0 cap must not reach the model, where
  // it would read as "max Rs 0" and cap every discount to nothing.
  final maxDisc = (dto.maxDiscountPaise == null || dto.maxDiscountPaise == 0)
      ? null
      : paiseToRupees(dto.maxDiscountPaise!);
  // Backend `value` is **paise for FLAT** and a plain percent for PERCENT
  // (`Coupon`/`CouponMath`), while this model speaks rupees.
  final value = type == 'flat' ? paiseToRupees(dto.value) : dto.value;
  final desc = type == 'flat'
      ? '₹$value off on orders above ₹$min'
      : '$value% off${maxDisc != null ? ' · max ₹$maxDisc' : ''}';
  return Coupon(
    code: dto.code ?? '',
    desc: desc,
    type: type,
    value: value,
    maxDiscount: maxDisc,
    min: min,
    scope: dto.categoryIds.isNotEmpty
        ? dto.categoryIds.first
        : (dto.categoryId ?? 'all'),
    categoryIds: List<String>.of(dto.categoryIds),
    active: dto.active,
    starts: _dayKey(dto.startAt),
    expires: _dayKey(dto.endAt),
    uses: dto.usedCount,
    maxUses: dto.totalLimit > 0 ? dto.totalLimit : 999999,
    // Real flags from the backend; `perUserLimit == 1` remains the fallback
    // for rows written before the flags existed.
    worksWithCoins: dto.worksWithCoins ?? true,
    firstOrderOnly: dto.firstOrderOnly ?? dto.perUserLimit == 1,
    productIds: List<String>.of(dto.productIds),
    productGroupIds: List<String>.of(dto.productGroupIds),
    itemNames: Map<String, String>.of(dto.itemNames),
    appliesText: dto.appliesToText,
  );
}

List<Coupon> couponsFromDtos(List<CouponDto> dtos) =>
    dtos.map(couponFromDto).toList();

/// One row of the public offers list (`GET /coupons`) -> a browsable coupon.
///
/// The endpoint withholds the internal id, the total limit and the used
/// count, and it already filters out inactive/not-yet-started/ended/used-up
/// codes — so this row is always `active`, shows `uses: 0` and carries no
/// usage ceiling. Applying the code still goes through `POST /cart/quote`,
/// which is what proves it works for *this* customer; this row only exists so
/// the sheet can list offers and pre-check the minimum cart value.
///
/// `value` follows the same rule as [couponFromDto]: paise for `FLAT`,
/// percent for `PERCENT`.
Coupon publicCouponFromDto(PublicCouponDto dto) {
  final type = couponKindFromWire(dto.kind);
  final value = type == 'flat' ? paiseToRupees(dto.value) : dto.value;
  final min = paiseToRupees(dto.minOrderPaise);
  final maxDisc =
      dto.maxDiscountPaise > 0 ? paiseToRupees(dto.maxDiscountPaise) : null;
  final desc = type == 'flat'
      ? '₹$value off on orders above ₹$min'
      : '$value% off${maxDisc != null ? ' · max ₹$maxDisc' : ''}';
  return Coupon(
    code: dto.code ?? '',
    desc: desc,
    type: type,
    value: value,
    maxDiscount: maxDisc,
    min: min,
    scope: dto.categoryIds.isNotEmpty
        ? dto.categoryIds.first
        : (dto.categoryId ?? 'all'),
    categoryIds: List<String>.of(dto.categoryIds),
    active: true,
    starts: _dayKey(dto.startAt),
    expires: _dayKey(dto.endAt),
    uses: 0,
    maxUses: 1 << 30,
    worksWithCoins: dto.worksWithCoins,
    firstOrderOnly: dto.firstOrderOnly,
    productIds: List<String>.of(dto.productIds),
    productGroupIds: List<String>.of(dto.productGroupIds),
    appliesText: dto.appliesToText,
  );
}

List<Coupon> publicCouponsFromDtos(List<PublicCouponDto> dtos) =>
    dtos.map(publicCouponFromDto).toList();

CoinRule ruleFromDto(RuleViewDto dto) {
  final start = _dayKey(dto.startAt);
  final end = _dayKey(dto.endAt);
  return CoinRule(
    id: dto.id ?? '',
    name: dto.name ?? 'Rule',
    spend: paiseToRupees(dto.spendPaise),
    coins: dto.coins,
    mode: coinModeFromWire(dto.mode),
    scope: 'All items',
    active: dto.active,
    starts: start,
    expires: end,
    everGreen: start.isEmpty && end.isEmpty,
  );
}

List<CoinRule> coinRulesFromDtos(List<RuleViewDto> dtos) =>
    dtos.map(ruleFromDto).toList();

CoinSettings coinSettingsFromDto(CoinSettingsDto dto) => CoinSettings(
      coinValue: dto.paisePerCoin <= 0 ? 1 : dto.paisePerCoin / 100,
      maxPercent: dto.maxRedeemPercent,
      expiryMonths: dto.expiryMonths,
    );

HotSale hotSaleFromBanners(List<HotBannerDto> banners, List<Product> products) {
  final now = istNow();
  final live = banners.any((b) {
    if (!b.active) return false;
    final start = parseIst(b.startAt ?? '');
    final end = parseIst(b.endAt ?? '');
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  });
  final primary = banners.firstWhere((b) => b.active, orElse: () => HotBannerDto());
  final featured = products.where((p) => p.hotSale).map((p) => p.id).toList();
  return HotSale(
    live: live || banners.isNotEmpty,
    eyebrow: 'HOT SALE',
    title: primary.title ?? 'Fresh deals today',
    starts: _dayKey(primary.startAt),
    ends: _dayKey(primary.endAt),
    featured: featured,
  );
}

StoreInfo storeFromShop(ShopSettingDto dto) => StoreInfo(
      // Offline fallbacks only: a live profile always carries a name.
      name: (dto.shopName ?? '').isEmpty ? seedData.defaultStore.name : dto.shopName!,
      nameGu: (dto.shopNameGu ?? '').trim().isNotEmpty
          ? dto.shopNameGu!.trim()
          : (dto.shopName ?? '').isEmpty
              ? seedData.defaultStore.nameGu
              : dto.shopName!,
      phone: dto.phone ?? '',
      phoneHref: (dto.phone ?? '').replaceAll(RegExp(r'\D'), ''),
      address: dto.address ?? '',
      // The admin payload carries `promise` on its own; the public one maps
      // it onto `receiptFooter` (see `CatalogApi.getPublicShop`).
      promise: () {
        final p = dto.promise ?? dto.receiptFooter ?? '';
        return p.isEmpty ? 'Fresh groceries, delivered free.' : p;
      }(),
      logo: dto.logoUrl ?? '',
      openHours: dto.openHours ?? '',
      addressGu: (dto.addressGu ?? '').trim(),
      promiseGu: (dto.promiseGu ?? '').trim(),
    );

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

Order orderFromView(AdminViewDto dto, Map<String, PackRef> packs) {
  final placed = dto.placedDateTime ?? istNow();
  final items = <OrderItem>[];
  for (final it in dto.items) {
    final ref = it.productId == null ? null : packs[it.productId!];
    final p = ref?.product;
    final v = ref?.variant;
    items.add(OrderItem(
      productId: it.productId ?? '',
      variantIndex: ref?.variantIndex ?? -1,
      name: p?.name ?? ((it.name ?? '').isNotEmpty ? it.name! : 'Item'),
      nameGu: p?.nameGu ??
          ((it.nameGu ?? '').isNotEmpty ? it.nameGu! : (it.name ?? 'Item')),
      unit: v?.unit ?? v?.label ?? it.unitLabel ?? '',
      // The price the customer was charged, frozen on the order line.
      price: it.unitPricePaise > 0
          ? paiseToRupees(it.unitPricePaise)
          : (v?.price ?? 0),
      qty: it.qty,
      earnsCoins: p?.earnsCoins ?? false,
      allowCoins: p?.allowCoins ?? false,
      // The picture snapshotted on the line wins (it is what was bought);
      // fall back to the catalog product's art / illustration key.
      art: (it.imageUrl ?? '').trim().isNotEmpty
          ? it.imageUrl!.trim()
          : (p?.art ?? ''),
      tone: p?.tone ?? 'mint',
      imageUrl: (it.imageUrl ?? '').trim(),
    ));
  }
  final status = statusFromWire(dto.status);
  final history = dto.timeline
      .map((s) => StatusEvent(
            status: statusFromWire(s.status),
            at: parseIst(s.at ?? '') ?? placed,
          ))
      .toList();
  final built = Order(
    number: dto.orderNo ?? dto.id ?? '',
    customer: dto.customerName ?? '',
    phone: dto.customerMobile ?? '',
    customerEmail: dto.customerEmail ?? '',
    items: items,
    mode: fulfilFromWire(dto.fulfilment),
    address: _addressText(dto.address),
    slot: dto.slot ?? '',
    payment: _paymentLabel(dto.paymentMethod, fulfilment: dto.fulfilment),
    paymentState: _paymentStateLabel(dto.paymentStatus),
    status: status,
    statusHistory: history.isEmpty
        ? [StatusEvent(status: status, at: placed)]
        : history,
    placedAt: placed,
    updatedAt: placed,
    bill: Bill(
      subtotal: paiseToRupees(dto.subtotalPaise),
      couponCode: dto.couponCode ?? '',
      couponDiscount: paiseToRupees(dto.couponDiscountPaise),
      coinsUsed: dto.coinsUsed,
      delivery: paiseToRupees(dto.deliveryFeePaise),
      total: paiseToRupees(dto.totalPaise),
    ),
    coinsUsed: dto.coinsUsed,
    coinsEarned: dto.coinsEarned,
    coinRule: '',
    // Leave it empty when the server sent none: a placeholder here would
    // defeat AppState._carryCancelReasons and hide the store's real remark.
    cancelReason: (dto.cancelReason ?? '').trim(),
    partner: null,
    stockReserved: status != 'Cancelled',
    createdBy: 'customer',
  );
  built.payWire = (dto.paymentStatus ?? '').toUpperCase();
  built.cancelledBy = (dto.cancelledBy ?? '').toUpperCase();
  built.cancelCode = (dto.cancelCode ?? '').toUpperCase();
  built.paymentExpiresAt = parseIst(dto.paymentExpiresAt ?? '');
  built.awaitingPayment =
      (dto.status ?? '').toUpperCase() == 'PAYMENT_PENDING';
  built.paySession = dto.paymentSession;
  return built;
}

String orderStatusFromSummary(AdminSummaryDto dto) => statusFromWire(dto.status);

Order orderFromSummary(AdminSummaryDto dto, Map<String, PackRef> packs) {
  final placed = dto.placedDateTime ?? istNow();
  final status = statusFromWire(dto.status);
  return Order(
    number: dto.orderNo ?? dto.id ?? '',
    customer: dto.customerName ?? '',
    phone: dto.customerMobile ?? '',
    customerEmail: dto.customerEmail ?? '',
    items: [],
    mode: fulfilFromWire(dto.fulfilment),
    address: '',
    slot: '',
    payment: '',
    paymentState: '',
    status: status,
    statusHistory: [StatusEvent(status: status, at: placed)],
    placedAt: placed,
    updatedAt: placed,
    bill: Bill(
      subtotal: paiseToRupees(dto.totalPaise),
      couponCode: '',
      couponDiscount: 0,
      coinsUsed: 0,
      delivery: 0,
      total: paiseToRupees(dto.totalPaise),
    ),
    coinsUsed: 0,
    coinsEarned: 0,
    coinRule: '',
    cancelReason: '',
    partner: null,
    stockReserved: status != 'Cancelled',
    createdBy: 'customer',
  )
    ..awaitingPayment = (dto.status ?? '').toUpperCase() == 'PAYMENT_PENDING'
    ..cancelledBy = (dto.cancelledBy ?? '').toUpperCase()
    ..cancelCode = (dto.cancelCode ?? '').toUpperCase();
}

String _addressText(AddressDto? a) {
  if (a == null) return '';
  return [a.line1, a.area, a.pincode].where((s) => (s ?? '').isNotEmpty).join(', ');
}

/// Backend `paymentMethod` is only ever `COD` or `ONLINE` (`CREDIT`/`HYBRID`
/// are counter-only). COD on a pickup order is "pay at store".
String _paymentLabel(String? method, {String? fulfilment}) {
  final m = (method ?? '').toUpperCase();
  if (m == 'ONLINE') return 'UPI / Card';
  if (m == 'COD') {
    return (fulfilment ?? '').toUpperCase() == 'PICKUP'
        ? 'Pay at store'
        : 'Cash on delivery';
  }
  if (m.contains('UPI') || m.contains('CARD')) return 'UPI / Card';
  if (m.contains('NET') || m.contains('BANK')) return 'Net banking';
  if (m.contains('STORE') || m.contains('PICKUP')) return 'Pay at store';
  if (m.contains('CASH')) return 'Cash on delivery';
  if (m == 'CREDIT') return 'Credit';
  if (m == 'HYBRID') return 'Cash + credit';
  return method ?? '';
}

/// Backend `paymentStatus`: NONE | INITIATED | CAPTURED | REFUNDED | FAILED.
String _paymentStateLabel(String? s) {
  final m = (s ?? '').toUpperCase();
  if (m == 'CAPTURED' || m.contains('PAID')) return 'Paid';
  if (m == 'REFUNDED' || m.contains('REFUND')) return 'Refunded';
  if (m == 'FAILED') return 'Failed';
  if (m == 'NONE' || m == 'INITIATED' || m.contains('PENDING')) return 'Pending';
  return s ?? '';
}

/// ISO timestamp -> `yyyy-MM-dd` (or '' when absent). Local, to avoid an
/// import cycle with `app_state.dart`.
///
/// `.toLocal()` matters: `DateTime.parse` keeps a `Z` timestamp as UTC, so a
/// coupon ending at `2026-01-01T18:30:00Z` would otherwise be read as
/// 18:30 of the 1st *here* — and a coupon that already expired a few hours
/// ago in India could still read as "today", or worse, a fresh one as expired.
String _dayKey(String? iso) {
  final parsed = parseIst(iso ?? '');
  if (parsed == null) return '';
  // Shop calendar days are India time (UTC+5:30) whatever the device zone
  // is; `_isoDay` in AppState writes them the same way.
  final d = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p2(d.month)}-${p2(d.day)}';
}

// ---------------------------------------------------------------------------
// Customer (public) catalog mappers
// ---------------------------------------------------------------------------

/// Group public per-pack rows into frontend products (same grouping rule as
/// the admin mapper: `categoryId` + `nameEn`, differing by `packSize`).
Product _groupPublicToProduct(List<PublicProductDto> packs, String groupId) {
  final first = packs.first;
  final name = first.nameEn ?? 'Product';
  final variants = <Variant>[];
  var stock = 0;
  var anyInStock = false;
  var earns = false;
  var redeemable = false;
  var anyHot = false;

  for (final pack in packs) {
    final label = (pack.packSize != null && pack.packSize!.isNotEmpty)
        ? pack.packSize!
        : (pack.unit ?? '');
    stock += pack.qtyAvailable;
    if (pack.inStock || pack.qtyAvailable > 0) anyInStock = true;
    if (pack.earnsCoins) earns = true;
    if (pack.coinRedeemable) redeemable = true;
    if (pack.hotSale) anyHot = true;
    variants.add(Variant(
      label: label.isEmpty ? (pack.unit ?? 'Unit') : label,
      price: paiseToRupees(
          pack.flash?.salePricePaise ?? pack.pricePaise),
      mrp: paiseToRupees(pack.mrpPaise),
      unit: pack.unit ?? label,
      stock: pack.qtyAvailable,
      backendId: pack.id,
      active: pack.inStock,
      // A running flash sale: the server charges the flash price, so it is
      // the price shown; the normal price is struck through.
      flash: pack.flash,
      listPrice: pack.flash == null
          ? null
          : paiseToRupees(pack.flash!.listPricePaise),
    ));
  }

  return Product(
    id: groupId,
    name: name,
    nameGu: (first.nameGu ?? "").trim().isEmpty ? name : first.nameGu!,
    category: first.categoryId ?? '',
    unit: variants.isNotEmpty ? variants.first.unit : '',
    desc: first.description ?? '',
    descGu: first.description ?? '',
    rating: packs.fold<double>(0, (best, p) => p.rating > best ? p.rating : best),
    reviews: packs.fold<int>(0, (sum, p) => sum + p.reviewCount),
    art: first.imageUrl ?? '',
    tone: _toneFor(name),
    stock: stock,
    lowStock: 0,
    available: anyInStock,
    earnsCoins: earns,
    allowCoins: redeemable,
    hotSale: anyHot,
    variants: variants,
    defaultVariant: 0,
  );
}

/// Build the customer catalog from public `/products` rows.
List<Product> productsFromPublic(List<PublicProductDto> packs,
    {Set<String>? usedIds}) {
  final used = usedIds ?? <String>{};
  final groups = <String, List<PublicProductDto>>{};
  final order = <String>[];
  for (final pack in packs) {
    final key = publicGroupKey(pack);
    if (!groups.containsKey(key)) {
      groups[key] = [];
      order.add(key);
    }
    groups[key]!.add(pack);
  }

  final out = <Product>[];
  for (final key in order) {
    var base = _slug(groups[key]!.first.nameEn ?? 'item');
    var id = base;
    var n = 2;
    while (used.contains(id)) {
      id = '$base-$n';
      n++;
    }
    used.add(id);
    out.add(_groupPublicToProduct(groups[key]!, id));
  }
  return out;
}

/// Merge `GET /hot-sale` into the loaded catalog: flag products that appear in
/// the hot list (matched by backend pack id) and append ones not yet loaded,
/// then rebuild the [HotSale] hero from the banners.
///
/// Returns the rebuilt [HotSale]; [products] is updated in place (flagging)
/// and extended with newly discovered products.
HotSale hotSaleFromPublicDto(PublicHotSaleDto dto, List<Product> products) {
  final known = buildPackIndex(products);
  for (final pack in dto.products) {
    final id = pack.id;
    if (id == null) continue;
    final ref = known[id];
    if (ref != null) {
      ref.product.hotSale = true;
    } else {
      final fresh = productsFromPublic([pack], usedIds: {
        for (final p in products) p.id,
      });
      for (final p in fresh) {
        p.hotSale = true;
        products.add(p);
      }
    }
  }
  return hotSaleFromBanners(dto.banners, products);
}

// ---------------------------------------------------------------------------
// Customer wallet / addresses / orders mappers
// ---------------------------------------------------------------------------

/// `GET /wallet` -> the app's [CoinSettings] (value + redeem cap).
/// The `/wallet` payload carries no expiry, so we keep the default 12 months
/// (the admin `/coins/settings` endpoint remains authoritative when loaded).
CoinSettings walletSettingsFromDto(WalletViewDto dto) => CoinSettings(
      coinValue: dto.paisePerCoin <= 0 ? 1 : dto.paisePerCoin / 100,
      maxPercent: dto.maxRedeemPercent,
      expiryMonths: dto.expiryMonths <= 0 ? 12 : dto.expiryMonths,
    );

String _ledgerTitle(String? kind) {
  final k = (kind ?? '').toUpperCase();
  if (k.contains('REDEEM') || k.contains('SPEND')) return 'Coins redeemed';
  // Backend kinds: EARN, REDEEM, REVERSE, ADJUST, EXPIRE.
  if (k.contains('REVERSE') || k.contains('REVERSAL') || k.contains('REFUND')) {
    return 'Coins returned';
  }
  if (k.contains('ADJUST')) return 'Coins adjusted';
  if (k.contains('BONUS')) return 'Bonus coins';
  if (k.contains('EXPIRY') || k.contains('EXPIRE')) return 'Coins expired';
  return 'Coins earned';
}

String _expiryDay(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// `GET /wallet/ledger` -> the wallet screen's ledger rows.
List<LedgerEntry> ledgerFromDtos(List<LedgerViewDto> dtos) {
  // A coin refund into a new lot is stored as an `ADJUST` row with 0 coins;
  // the guide says to hide those.
  return dtos.where((d) => d.coins != 0).map((d) {
    final k = (d.kind ?? '').toUpperCase();
    final negative = d.coins < 0 ||
        k.contains('REDEEM') ||
        k.contains('SPEND') ||
        k.contains('EXPIR');
    final isRefund =
        k.contains('REVERSE') || k.contains('REVERSAL') || k.contains('REFUND');
    return LedgerEntry(
      id: d.id ?? '',
      title: _ledgerTitle(d.kind),
      sub: [
        if ((d.orderNo ?? '').isNotEmpty) 'Order #${d.orderNo}',
        // Rows that created a lot of coins carry the day they lapse.
        if (!negative && d.coins > 0 && parseIst(d.expiresAt ?? '') != null)
          'expires ${_expiryDay(parseIst(d.expiresAt!)!)}',
      ].join(' · '),
      coins: negative && d.coins > 0 ? -d.coins : d.coins,
      status: isRefund ? 'credited' : (negative ? 'spent' : 'credited'),
      type: isRefund ? 'refund' : (negative ? 'spend' : 'earn'),
      orderNumber: d.orderNo ?? '',
      date: d.createdDateTime ?? istNow(),
    );
  }).toList();
}

String _addrPhone(String? p) {
  final d = (p ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length == 10 ? '${d.substring(0, 5)} ${d.substring(5)}' : d;
}

/// `GET /me/addresses` -> the app's flat [Address] rows.
/// The backend splits `line1/area/pincode` (all required); the UI shows them
/// composed through [Address.full].
List<Address> addressesFromDtos(List<AddressDto> dtos) {
  return dtos
      .map((d) => Address(
            id: d.id ?? '',
            label: (d.label ?? '').isEmpty ? 'Address' : d.label!,
            detail: d.line1 ?? '',
            area: d.area ?? '',
            pincode: d.pincode ?? '',
            phone: _addrPhone(d.phone),
            isDefault: d.isDefault,
          ))
      .toList();
}

/// `GET /orders` (customer) summary -> the app's [Order] row.
Order customerOrderFromSummary(SummaryDto dto, Map<String, PackRef> packs) {
  final placed = dto.placedDateTime ?? istNow();
  final status = statusFromWire(dto.status);
  return Order(
    number: dto.orderNo ?? dto.id ?? '',
    customer: '',
    phone: '',
    customerEmail: '',
    items: List.filled(
        dto.itemCount.clamp(0, 1000),
        OrderItem(
          productId: '',
          variantIndex: -1,
          name: 'Item',
          nameGu: 'Item',
          unit: '',
          price: 0,
          qty: 1,
          earnsCoins: false,
          allowCoins: false,
          art: '',
          tone: 'mint',
        ),
        growable: false),
    mode: fulfilFromWire(dto.fulfilment),
    address: '',
    slot: '',
    payment: '',
    paymentState: '',
    status: status,
    statusHistory: [StatusEvent(status: status, at: placed)],
    placedAt: placed,
    updatedAt: placed,
    bill: Bill(
      subtotal: paiseToRupees(dto.totalPaise),
      couponCode: '',
      couponDiscount: 0,
      coinsUsed: 0,
      delivery: 0,
      total: paiseToRupees(dto.totalPaise),
    ),
    coinsUsed: 0,
    coinsEarned: 0,
    coinRule: '',
    cancelReason: '',
    partner: null,
    stockReserved: status != 'Cancelled',
    createdBy: 'customer',
  )
    ..cancelledBy = (dto.cancelledBy ?? '').toUpperCase()
    ..cancelCode = (dto.cancelCode ?? '').toUpperCase();
}

/// orderNo -> backend UUID for the customer's order list.
Map<String, String> orderIdsFromSummaries(List<SummaryDto> dtos) => {
      for (final s in dtos) (s.orderNo ?? s.id ?? ''): (s.id ?? ''),
    };
