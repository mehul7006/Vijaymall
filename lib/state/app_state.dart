/// Core app state — port of the `STATE` + commerce logic in assets/app.js.
///
/// All formulas, guards and exact message strings come from
/// `E:\Vijay mall Qoder\logic-spec.md` (digest of app.js §2).
library;

import '../data/ist.dart';
import '../data/validators.dart';
import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../data/api/api_config.dart';
import '../data/api/api_exception.dart';
import '../data/api/api_service.dart';
import '../data/api/dto.dart';
import '../data/api/mappers.dart';
import '../data/api/orders_stream.dart';
import '../data/api/pos_api.dart' show normalizePayMode;
import '../data/cart_store.dart';
import '../data/flash_store.dart';
import '../data/models.dart';
import '../data/razorpay_checkout.dart';
import '../data/seed_data.dart' as seed;
import '../data/store_profile_cache.dart';
import 'gu_strings.dart';

/// Outcome of a status move or a cancellation.
///
/// `ok` is what tells the caller to toast it as a success or as a failure —
/// without it a refusal would be styled exactly like a completed move, which
/// is how a rejected backend call used to read as "moved successfully".
typedef StageResult = ({bool ok, String message});

// ---------------------------------------------------------------------------
// Helpers (app.js primitives)
// ---------------------------------------------------------------------------

/// `money()` — ₹ with Indian digit grouping.
String money(num value) {
  // Work in whole paise so Rs 125.50 keeps its decimals; whole rupees show
  // no decimals (Rs 126), matching the backend's paise totals exactly.
  final paise = (value * 100).round();
  final n = paise ~/ 100;
  final frac = paise.abs() % 100;
  final neg = paise < 0;
  var s = n.abs().toString();
  String out;
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final buf = <String>[];
    while (rest.length > 2) {
      buf.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) buf.insert(0, rest);
    out = '${buf.join(',')},$last3';
  } else {
    out = s;
  }
  final dec = frac == 0 ? '' : '.${frac.toString().padLeft(2, '0')}';
  return '₹${neg ? '-' : ''}$out$dec';
}

/// `digits()` — last 10 digits of anything.
String digits(String? v) {
  final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length <= 10 ? d : d.substring(d.length - 10);
}

String pad2(int n) => n.toString().padLeft(2, '0');

String localDayKey(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// `formatDate()` → `24 Oct`
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// `whenLabel()` relative timestamp.
String whenLabel(DateTime value) {
  final diff = istNow().difference(value);
  final mins = diff.inMinutes;
  if (mins < 2) return 'Just now';
  if (mins < 60) return '$mins min ago';
  if (mins < 1440) return '${mins ~/ 60} hr ago';
  if (mins < 2880) return 'Yesterday';
  return formatDate(value);
}

/// `T(en, gu)` — bilingual label picker.
String tr(String en, String gu, String lang) => lang == 'gu' ? gu : en;

int discountPct(Variant v) {
  // During a flash sale the reference is the normal price (the server's
  // whole-percent figure), not the printed MRP.
  if (v.flash != null) return v.flash!.discountPercent;
  return v.mrp > v.price ? (((v.mrp - v.price) / v.mrp) * 100).round() : 0;
}

/// Shared date-window status for coupons and coin rules.
String dateStatus({
  required bool active,
  required String starts,
  required String expires,
  bool everGreen = false,
}) {
  if (!active) return 'inactive';
  if (everGreen) return 'active';
  final today = localDayKey(istNow());
  if (starts.isNotEmpty && today.compareTo(starts) < 0) return 'scheduled';
  if (expires.isNotEmpty && today.compareTo(expires) > 0) return 'expired';
  return 'active';
}

// ---------------------------------------------------------------------------
// Flow state (prototype's `ui` object, flow-level subset)
// ---------------------------------------------------------------------------

class FlowState {
  String checkoutPayment = 'cod'; // cod | upi | store
  String checkoutMode = 'delivery'; // delivery | pickup
  String selectedAddressId = 'home';
  String selectedSlot = 'Today · 6:00 – 8:00 PM';
  int pdQty = 1;
  int? pdVariant;

  // cart sheets
  String coinCustom = '';
  int coinPercent = 50;

  // shop filters
  String shopSort = 'popular';
  bool shopStock = false;
  bool shopCoins = false;
  String shopQuery = '';

  // admin
  String invCat = 'all';
  String invQuery = '';
  String reportPeriod = 'week'; // week | month | quarter
}

// ---------------------------------------------------------------------------
// Cart detail row
// ---------------------------------------------------------------------------

class CartLine {
  final String productId;
  final int variantIndex;
  final int qty;
  final Product p;
  final Variant v;
  final num lineTotal;

  const CartLine({
    required this.productId,
    required this.variantIndex,
    required this.qty,
    required this.p,
    required this.v,
    required this.lineTotal,
  });
}

class CouponResult {
  final bool ok;
  final num discount;
  final String message;
  final Coupon? coupon;
  final num scopeBase;

  const CouponResult({
    required this.ok,
    required this.discount,
    required this.message,
    this.coupon,
    this.scopeBase = 0,
  });
}

class CartTotals {
  final List<CartLine> details;
  final num subtotal;
  final CouponResult? coupon;
  final bool couponOk;
  final num discount;
  final num payable;
  final num eligibleRaw;
  final double eligibleBase;
  final num cap;
  final int balance;
  final num coinValue;
  final int coinsUsed;
  final num coinDiscount;
  final num total;
  final double earnRatio;
  final int coinsEarned;
  final CoinRule? earnRule;
  final bool canUseCoins;

  const CartTotals({
    required this.details,
    required this.subtotal,
    required this.coupon,
    required this.couponOk,
    required this.discount,
    required this.payable,
    required this.eligibleRaw,
    required this.eligibleBase,
    required this.cap,
    required this.balance,
    required this.coinValue,
    required this.coinsUsed,
    required this.coinDiscount,
    required this.total,
    required this.earnRatio,
    required this.coinsEarned,
    required this.earnRule,
    required this.canUseCoins,
  });
}

// ---------------------------------------------------------------------------
// AppState
// ---------------------------------------------------------------------------

class AppState extends ChangeNotifier {
  AppState({DateTime? bootTime}) : _bootTime = bootTime ?? istNow() {
    resetAll();
    // The store profile (name, logo, address, ...) is cached on the client and
    // painted from the cache before the first frame; follow every change.
    StoreProfileHub.instance.addListener(_onStoreProfileChanged);
  }

  /// Feeds the legacy `seed.store` readers (and the online-orders switch)
  /// from the single store profile; falls back to the seed brand only when no
  /// profile has ever loaded.
  void _applyStoreProfile() {
    final p = StoreProfileHub.instance.profile;
    if (p == null || !p.hasName) {
      seed.store = seed.defaultStore;
      return;
    }
    seed.store = p.toStoreInfo();
    onlineOrdersOpen = p.onlineOrdersOpen;
    onlineOrdersMessage = p.onlineOrdersMessage;
  }

  void _onStoreProfileChanged() {
    _applyStoreProfile();
    notifyListeners();
  }

  /// Revalidates the store profile with the server. [force] is the hard
  /// refresh: the cached payload, ETag and logo bytes are dropped and the
  /// profile is refetched without `If-None-Match`. Returns true when the
  /// data changed (or was force-refreshed).
  Future<bool> refreshStoreProfile({bool force = false}) async {
    final changed = await StoreProfileHub.instance.refresh(force: force);
    if (isBackendAdmin) {
      try {
        shopSettings = await Api.instance.admin.getShop();
        notifyListeners();
      } catch (_) {}
    }
    return changed;
  }

  final DateTime _bootTime;

  String lang = 'en';
  bool signedIn = false;

  /// Profile identity. Live builds start empty and are filled from the
  /// backend `/me` payload after sign-in; only the offline prototype is
  /// pre-filled with a demo person.
  String userName = ApiConfig.isLive ? '' : 'Mahipal H.';
  String userPhone = ApiConfig.isLive ? '' : '97140 12345';
  bool isAdmin = false;

  /// Admin area access. The offline prototype opens it directly; a live
  /// build requires a real ADMIN JWT (`isBackendAdmin`).
  bool adminSignedIn = !ApiConfig.isLive;
  bool notificationsOn = true;
  final Set<String> wishlist = <String>{};

  late List<Product> products;
  late List<Category> categories;
  late List<Coupon> coupons;
  late List<CoinRule> coinRules;
  late CoinSettings coinSettings;
  late HotSale hotSale;
  late List<Address> addresses;
  late List<Order> orders;
  late List<LedgerEntry> ledger;
  late List<StockMove> stockMoves;
  late List<WeekSale> weekSales;

  // --- backend integration -----------------------------------------------
  /// Signed-in user's email/role from the backend JWT session.
  String? userEmail;
  String? userRole;

  /// Backend product-id -> grouped product/pack lookup (cart + order lines).
  Map<String, PackRef> packIndex = {};

  /// orderNo -> backend order UUID (needed for status/cancel calls).
  Map<String, String> orderIdsByNo = {};

  /// Last `/admin/dashboard` payload (reports + POS KPIs).
  DashboardDto? adminDashboard;

  /// Last backend error message, surfaced as a toast by the watcher in
  /// `main.dart`.
  ///
  /// Assigning it notifies listeners on purpose. Almost every caller writes
  /// it from a background `unawaited(...)` that never calls
  /// `notifyListeners()` again, and without this the watcher would not run —
  /// which is exactly how a rejected backend call could sit unnoticed while
  /// the screen already claimed success.
  String? get apiLastError => _apiLastError;
  set apiLastError(String? value) {
    if (_apiLastError == value) return;
    _apiLastError = value;
    notifyListeners();
  }

  String? _apiLastError;

  // --- customer wallet (authoritative balances from `/wallet`) -------------
  /// Coin balance as reported by the backend `/wallet` endpoint. When a real
  /// backend session is active this is the source of truth (the local ledger
  /// is only a display list of entries).
  int walletCoins = 0;

  /// Rupee value of [walletCoins] as reported by the backend.
  int walletValuePaise = 0;

  /// True once `/wallet` has been loaded for the current session.
  bool walletLoaded = false;

  // --- customer credit / udhar (`/credit`, `/credit/ledger`) ---------------
  /// The signed-in customer's credit account as the backend reports it, or
  /// null when it has never been read this session. `limitPaise == 0` means
  /// credit is not enabled for them.
  CreditAccountDto? creditAccount;

  /// Newest-first credit ledger rows (what they took, what they paid back).
  List<CreditLedgerEntryDto> creditLedger = [];

  /// True once `/credit` has been read for the current session.
  bool creditLoaded = false;

  /// Enabled payment methods from `/payment-methods` (codes like UPI/COD).
  List<SettingDto> paymentMethods = [];

  /// Backend id of the hot-sale banner being edited (null → create on save).
  String? bannerId;

  /// Staff roster from `GET /admin/staff` (admin sessions only).
  List<StaffViewDto> adminStaff = [];

  /// Raw shop-settings payload (form source for the settings editor).
  ShopSettingDto? shopSettings;

  /// `GET /shop-settings` -> `onlineOrdersOpen` / `onlineOrdersMessage`.
  /// False while the admin has paused online ordering: checkout is blocked
  /// and [onlineOrdersMessage] is shown as is (the server answers 422
  /// `ORDERS_PAUSED` otherwise).
  bool onlineOrdersOpen = true;
  String onlineOrdersMessage = '';

  // --- units of measure (`/units`, `/admin/units`) -------------------------
  /// Every unit the store sells in, from the public `GET /units`. The product
  /// editor picks from this list because the backend rejects a product whose
  /// `unit` is not an active row ("unknown unit 'X'").
  List<UnitDto> units = [];

  /// `GET /admin/units`: every unit, switched-off ones included (admin list).
  List<UnitDto> adminUnits = [];

  /// True once `GET /units` has been read this session.
  bool unitsLoaded = false;

  // --- notifications inbox (`/me/notifications`) ---------------------------
  /// Latest inbox rows from the backend (customer sessions).
  List<NotificationRowDto> inboxItems = [];
  int inboxUnread = 0;
  bool inboxLoaded = false;

  // --- admin stock movements (`/admin/stock-movements`) --------------------
  /// Signed stock movements from the backend (admin sessions). Non-empty
  /// means the stock report is served from these instead of local state.
  List<StockMovementDto> adminStockMoves = [];

  // --- admin period report (`/admin/reports/summary`) ----------------------
  /// Latest period summary (orders + optional aggregates) for the reports
  /// screen, keyed by the period that was requested.
  ReportSummaryDto? adminReport;
  String? adminReportPeriod;
  bool adminReportLoaded = false;

  // --- cart quote warnings (`POST /cart/quote`) ----------------------------
  /// Server-side quote warnings for the current cart (coupon skipped, coins
  /// above cap, …), shown in checkout before the order is placed.
  List<String> cartQuoteWarnings = [];

  // --- persisted basket (see `CartStore`) ----------------------------------
  /// Basket read from [CartStore] at startup, waiting for the catalog so the
  /// lines can be validated against real products/stock.
  List<StoredLine> _pendingCart = CartStore.lines;

  /// Coupon that came back with [_pendingCart], re-adopted once loaded.
  StoredCoupon? _pendingCoupon = CartStore.coupon;

  /// True once [_applyPendingCart] has run for this launch. Gates
  /// [_persistCart] so we never overwrite the stored basket with the empty
  /// one a `resetAll()` produces before the catalog is loaded.
  bool _cartRestored = false;

  /// Coupon row adopted from a successful `POST /cart/quote`.
  ///
  /// A customer session has no coupon catalog (`GET /admin/coupons` is
  /// admin-only and there is no public listing endpoint), so the row proven
  /// by the quote is what keeps `cartTotals()`/`couponCheck()` working.
  Coupon? _adoptedCoupon;

  /// [Coupon.value] in paise, kept so the row round-trips through
  /// [CartStore] without re-deriving it from rupees.
  int _adoptedCouponPaise = 0;

  /// True when a real backend JWT is present (email-OTP sign-in succeeded).
  bool get backendMode => Api.instance.session.hasTokens;

  /// True once the persisted session has been **resolved** at launch — either
  /// adopted from `GET /me`, or dropped because it was expired/revoked.
  ///
  /// Anything that gates on identity has to wait for this. `GET /me` is a
  /// network call, so on the very first frame after a refresh a real admin is
  /// indistinguishable from a signed-out visitor; judging [isAdminAllowed]
  /// that early is what used to bounce a perfectly valid admin session out of
  /// `#/admin/*` to `/signin` on every reload.
  bool sessionSettled = false;

  /// Marks [sessionSettled] and rebuilds, so gated screens can render.
  void settleSession() {
    if (sessionSettled) return;
    sessionSettled = true;
    notifyListeners();
  }

  /// True when the backend session carries the ADMIN role.
  bool get isBackendAdmin =>
      backendMode && (userRole ?? '').toUpperCase() == 'ADMIN';

  /// True when the backend session may work the shop's orders — the ADMIN
  /// role or the counter role (CASHIER), mirroring `SecurityConfig`, which
  /// now opens `/admin/orders/**` to `ROLE_ADMIN` **and** `ROLE_CASHIER`
  /// while every other admin page stays admin-only.
  bool get isBackendStaff =>
      backendMode &&
      const ['ADMIN', 'CASHIER'].contains((userRole ?? '').toUpperCase());

  /// True when this session may open `#/admin/*`.
  ///
  /// A live build admits a backend session carrying ADMIN **or** CASHIER
  /// (counter staff only get the Orders pages — see `_AdminGuard`), so a
  /// regular customer never reaches the store's admin data; the offline
  /// prototype keeps using its local [adminSignedIn] flag.
  bool get isAdminAllowed =>
      ApiConfig.isLive ? (isBackendAdmin || isBackendStaff) : adminSignedIn;

  /// True when this session may open the **admin-only** pages (dashboard,
  /// inventory, coupons, reports, settings, staff, POS setup …). CASHIER is
  /// excluded: the backend answers 403 on those for a counter role, and a
  /// page that can only fail does not belong behind their navigation.
  bool get adminPagesAllowed =>
      ApiConfig.isLive ? isBackendAdmin : adminSignedIn;

  List<CartItem> cartItems = [];
  String cartCoupon = '';
  bool useCoins = false;
  String coinMode = 'all'; // all | percent | custom

  final FlowState flow = FlowState();

  /// `freshState()` + `ensureVariantStocks()` + the prototype's initial cart.
  ///
  /// A live build (`ApiConfig.isLive`) starts empty: every list below is
  /// filled by the backend, so no prototype/demo record is ever seeded.
  void resetAll() {
    final now = _bootTime;
    final demo = !ApiConfig.isLive;
    products =
        demo ? seed.products.map((p) => p.deepCopy()).toList() : <Product>[];
    categories = demo ? List.of(seed.categories) : <Category>[];
    coupons =
        demo ? seed.coupons.map((c) => c.copyWith()).toList() : <Coupon>[];
    coinRules =
        demo ? seed.coinRules.map((r) => r.copyWith()).toList() : <CoinRule>[];
    // Neutral runtime fallback: the wallet/admin endpoints overwrite this
    // with the store's real coin value and redeem cap.
    coinSettings = demo
        ? seed.coinSettings
        : CoinSettings(coinValue: 1, maxPercent: 0, expiryMonths: 12);
    // No live banner until an admin publishes one (`hotSale.live` gates the
    // whole hero section).
    hotSale = demo
        ? seed.hotSale
        : HotSale(
            live: false,
            eyebrow: '',
            title: '',
            starts: '',
            ends: '',
            featured: const <String>[],
          );
    addresses = demo ? List.of(seed.addresses) : <Address>[];
    orders = demo ? seed.seedOrders(now) : <Order>[];
    _extraOrders = [];
    ledger = demo ? seed.seedLedger(now) : <LedgerEntry>[];
    stockMoves = demo ? seed.seedStockMoves(now) : <StockMove>[];
    weekSales = demo ? List.of(seed.weekSales) : <WeekSale>[];
    lang = 'en';
    GuLang.active = false;
    signedIn = false;
    isAdmin = false;
    adminSignedIn = !ApiConfig.isLive;
    notificationsOn = true;
    wishlist.clear();

    // Backend session state (fresh demo boot has no wallet/addresses synced).
    walletCoins = 0;
    walletValuePaise = 0;
    walletLoaded = false;
    creditAccount = null;
    creditLedger = [];
    creditLoaded = false;
    paymentMethods = [];
    bannerId = null;
    adminStaff = [];
    shopSettings = null;
    inboxItems = [];
    inboxUnread = 0;
    inboxLoaded = false;
    adminStockMoves = [];
    adminReport = null;
    adminReportPeriod = null;
    adminReportLoaded = false;
    cartQuoteWarnings = [];
    _adoptedCoupon = null;
    _orderDetailCache.clear();
    _ordersBackoffUntil = null;
    _adoptedCouponPaise = 0;
    posProducts = [];
    posBill = null;
    posHolds = [];
    posDayReport = null;
    posShift = null;
    posShiftLoaded = false;
    posShop = null;
    userEmail = null;
    userRole = null;

    // Store details come from the cached store profile (seed defaults only
    // when no profile has ever loaded).
    _applyStoreProfile();

    ensureVariantStocks();

    // Initial cart from the prototype's fresh state — offline demo only; a
    // live build always starts with an empty basket.
    cartItems = demo
        ? [
            CartItem(productId: 'almonds', variantIndex: 1, qty: 1),
            CartItem(productId: 'rice', variantIndex: 1, qty: 1),
            CartItem(productId: 'kulfi', variantIndex: 1, qty: 1),
            CartItem(productId: 'pickle', variantIndex: 0, qty: 1),
          ]
        : <CartItem>[];
    cartCoupon = demo ? 'FESTIVE50' : '';
    useCoins = demo;
    coinMode = 'all';
    flow.coinCustom = '';
    flow.coinPercent = 50;
    notifyListeners();
  }

  void _changed() {
    // Guest baskets are written through to `CartStore` on every mutation so
    // a browser refresh never loses them; a signed-in basket is not written
    // here at all — see `_persistCart`.
    _persistCart();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Basket persistence (`CartStore` for guests, the server for accounts)
  // -------------------------------------------------------------------------

  /// A basket mutation.
  ///
  /// A **guest** basket is written to this device (the backend refuses to
  /// store one without a JWT, so `localStorage` is its only home). A
  /// **signed-in** basket is never written locally: `GET/PUT/DELETE /cart`
  /// is the single source of truth and mirrors it to every device, so a
  /// local copy would just be a second, stale version of the same data.
  ///
  /// Either way a failed server mirror never rolls back what the user sees —
  /// it surfaces through [apiLastError], which the global watcher toasts.
  void _cartChanged({bool requote = true}) {
    _persistCart();
    _pushCartToServer();
    notifyListeners();
    // A coupon's discount depends on which lines are in the basket (category
    // scope, minimum, percent), so re-price it after every basket change.
    if (requote && backendMode && cartCoupon.isNotEmpty && cartItems.isNotEmpty) {
      unawaited(refreshCartQuoteWarnings());
    }
  }

  /// Bumped per re-quote so a slow, stale response can't overwrite a newer one.
  int _quoteSeq = 0;

  /// Both coupon kinds of removal share this: drop the code, tell the user.
  void _dropCouponWithMessage(String message) {
    cartCoupon = '';
    _adoptedCoupon = null;
    _adoptedCouponPaise = 0;
    cartQuoteWarnings = [message];
    apiLastError = message;
    _cartChanged(requote: false);
  }

  /// True when this session has an account basket to mirror into.
  bool get _canPushCart => ApiConfig.isLive && _cartRestored && backendMode;

  Future<void>? _cartPushInFlight;
  bool _cartPushDirty = false;

  /// Queue a `PUT /cart`. Serialised: one call is in flight at a time and it
  /// re-reads the basket if something changed while it was running, so a fast
  /// run of +/- taps can't land out of order.
  void _pushCartToServer() {
    if (!_canPushCart) return;
    _cartPushDirty = true;
    if (_cartPushInFlight != null) return;
    final run = _pushCartLoop();
    _cartPushInFlight = run;
    unawaited(run.whenComplete(() => _cartPushInFlight = null));
  }

  Future<void> _pushCartLoop() async {
    while (_cartPushDirty && _canPushCart) {
      _cartPushDirty = false;
      try {
        await Api.instance.cart.replace(
          items: _serverCartItems(),
          couponCode: cartCoupon.isEmpty ? null : cartCoupon,
          coinMode: _wireCoinMode(),
          percent: _wireCoinPercent(),
        );
        // The server has acknowledged this exact basket, so any device copy
        // left over from a guest session is now redundant — drop it rather
        // than keep a second source of truth around. Only ever cleared
        // *after* a 2xx, so a failed push never loses the basket.
        CartStore.clear();
      } on ApiException catch (e) {
        // Stop rather than spin; the next mutation tries again.
        apiLastError = e.message;
        break;
      } catch (_) {
        apiLastError = 'Could not save your basket to your account.';
        break;
      }
    }
  }

  /// Write the guest basket through to the device store.
  ///
  /// Signed-in sessions are skipped on purpose: their basket lives on the
  /// server only (see [_cartChanged]).
  void _persistCart() {
    if (!ApiConfig.isLive || !_cartRestored || backendMode) return;
    final coupon = _adoptedCoupon;
    CartStore.save(
      items: [
        for (final it in cartItems)
          StoredLine(it.productId, it.variantIndex, it.qty),
      ],
      coupon: (coupon == null || cartCoupon.isEmpty)
          ? null
          : StoredCoupon(
              code: cartCoupon,
              paise: _adoptedCouponPaise,
              desc: coupon.desc,
              worksWithCoins: coupon.worksWithCoins,
            ),
    );
  }

  /// Drop lines whose product vanished or sold out, clamp each quantity to
  /// what is left and merge duplicates.
  ///
  /// Shared by the device restore, the server restore and the sign-in merge,
  /// so every path into [cartItems] is reconciled the same way.
  List<CartItem> _reconcileCart(Iterable<CartItem> lines) {
    final kept = <CartItem>[];
    for (final line in lines) {
      final p = productById(line.productId);
      if (p == null || !p.available) continue;
      final vi = (line.variantIndex >= 0 && line.variantIndex < p.variants.length)
          ? line.variantIndex
          : p.defaultVariant;
      final available = variantStock(p, vi);
      if (available <= 0) continue;
      final qty =
          line.qty < 1 ? 1 : (line.qty > available ? available : line.qty);
      final idx = kept.indexWhere(
          (it) => it.productId == line.productId && it.variantIndex == vi);
      if (idx >= 0) {
        kept[idx] = CartItem(
          productId: line.productId,
          variantIndex: vi,
          qty: kept[idx].qty + qty,
        );
      } else {
        kept.add(
            CartItem(productId: line.productId, variantIndex: vi, qty: qty));
      }
    }
    return kept;
  }

  /// Restore the basket once the catalog is loaded: the account's copy for a
  /// signed-in session, the device's copy for a guest.
  ///
  /// The server is the authority whenever a session exists — that is what
  /// makes a basket follow a customer to a second device. A guest basket
  /// still sitting on this device is folded in first (max(qty), never
  /// summed) so signing in never silently drops items; the device copy is
  /// then dropped, because from here the account owns the basket.
  ///
  /// Runs once per launch from every live bootstrap; the offline prototype
  /// keeps its seeded basket and never touches either store.
  Future<void> _applyPendingCart() async {
    if (_cartRestored) return;
    _cartRestored = true;
    if (!ApiConfig.isLive) return;

    final pending = _pendingCart;
    final pendingCoupon = _pendingCoupon;
    _pendingCart = const [];
    _pendingCoupon = null;

    final local = _reconcileCart([
      for (final line in pending)
        CartItem(
            productId: line.productId,
            variantIndex: line.variantIndex,
            qty: line.qty),
    ]);

    if (backendMode) {
      try {
        final server = await Api.instance.cart.get();
        final serverCode = (server.couponCode ?? '').trim().toUpperCase();
        final hasServer = server.items.isNotEmpty || serverCode.isNotEmpty;
        final hasLocal =
            local.isNotEmpty || (pendingCoupon?.code.isNotEmpty ?? false);

        if (hasServer) {
          // The account already owns a basket: adopt it as the authority,
          // then fold in anything this device still carries as a guest.
          _adoptServerCart(server);
          if (hasLocal) {
            cartItems = _unionLines(local, cartItems);
            _finishCartRestore();
            _pushCartToServer(); // acked below, which drops the device copy
          } else {
            _finishCartRestore();
            CartStore.clear(); // nothing of ours is on the device any more
          }
        } else {
          // The account has no basket yet: seed it from this device.
          cartItems = local;
          _adoptLocalCoupon(pendingCoupon);
          _finishCartRestore();
          if (local.isNotEmpty || cartCoupon.isNotEmpty) {
            _pushCartToServer(); // acked below, which drops the device copy
          } else {
            CartStore.clear();
          }
        }
        return;
      } on ApiException {
        // Unreachable / rejected: keep the device basket instead of wiping
        // the screen (the error itself is reported by the callers that need
        // it; a restore is not worth toasting over).
      } catch (_) {
        // Same — never let a basket restore break the bootstrap.
      }
    }

    cartItems = local;
    _adoptLocalCoupon(pendingCoupon);
    _finishCartRestore();
  }

  /// Union two baskets by line, taking the **larger** quantity — never the
  /// sum, so signing in twice on the same device can't double anything.
  List<CartItem> _unionLines(List<CartItem> a, List<CartItem> b) {
    final merged = <String, CartItem>{
      for (final it in a) '${it.productId}#${it.variantIndex}': it,
    };
    for (final it in b) {
      final key = '${it.productId}#${it.variantIndex}';
      final here = merged[key];
      if (here == null) {
        merged[key] = it;
      } else if (it.qty > here.qty) {
        merged[key] = it;
      }
    }
    return _reconcileCart(merged.values);
  }

  /// Common tail of [_applyPendingCart]: re-price the coupon against the
  /// current stock and settle the listeners.
  void _finishCartRestore() {
    if (backendMode && cartItems.isNotEmpty) {
      unawaited(refreshCartQuoteWarnings());
    }
    _changed();
  }

  /// Re-adopt the coupon row stored with the device basket, or clear it.
  void _adoptLocalCoupon(StoredCoupon? coupon) {
    if (coupon == null || coupon.code.isEmpty) {
      cartCoupon = '';
      _adoptedCoupon = null;
      _adoptedCouponPaise = 0;
      return;
    }
    _adoptCouponRow(
      code: coupon.code,
      paise: coupon.paise,
      desc:
          coupon.desc.isEmpty ? 'Applied at checkout' : coupon.desc,
      worksWithCoins: coupon.worksWithCoins,
    );
    cartCoupon = coupon.code;
  }

  /// Take over the basket the server stored for this account: pack ids are
  /// resolved back to local lines, then the coupon and coin preferences it
  /// carried are adopted so `cartTotals()` prices them.
  void _adoptServerCart(SavedCartDto cart) {
    final lines = <CartItem>[];
    for (final l in cart.items) {
      final id = l.productId?.trim() ?? '';
      if (id.isEmpty) continue;
      final ref = packIndex[id];
      if (ref == null) continue; // product no longer exists
      lines.add(CartItem(
          productId: ref.product.id, variantIndex: ref.variantIndex, qty: l.qty));
    }
    cartItems = _reconcileCart(lines);

    final code = (cart.couponCode ?? '').trim().toUpperCase();
    cartCoupon = code;
    if (code.isEmpty) {
      _adoptedCoupon = null;
      _adoptedCouponPaise = 0;
    } else if (coupons.any((c) => c.code == code)) {
      // The browsed offer row already carries the real rules — leave it in
      // charge rather than shadowing it with a flat stand-in.
      _adoptedCoupon = null;
      _adoptedCouponPaise = 0;
    } else {
      // Placeholder: the next `POST /cart/quote` fills in the real amount
      // (see `refreshCartQuoteWarnings`).
      _adoptCouponRow(
        code: code,
        paise: 0,
        desc: 'Applied at checkout',
        worksWithCoins: true,
      );
    }

    final mode = (cart.coinMode ?? 'NONE').toUpperCase();
    useCoins = mode != 'NONE';
    coinMode = mode == 'PERCENT' ? 'percent' : 'all';
    if (mode == 'PERCENT') {
      final p = cart.percent ?? flow.coinPercent;
      flow.coinPercent = p < 0 ? 0 : (p > 100 ? 100 : p);
    }
  }

  /// Sign-in from a guest session: this device's basket becomes the seed of
  /// the account's basket, and the union is pushed back so the account has it.
  ///
  /// Lines are unioned by **max(qty)**, never summed, so signing in twice on
  /// the same device can't double anything. Whatever is already applied here
  /// (a coupon just validated, the coin preferences in use) wins over the
  /// server's, because it is the more recent decision.
  Future<void> _mergeCartOnSignIn() async {
    if (!_cartRestored || !ApiConfig.isLive || !backendMode) return;
    try {
      final server = await Api.instance.cart.get();

      // Union by max(qty), never summed, so signing in twice on the same
      // device can't double anything. This device's basket is the base: it
      // holds the most recent decision.
      final serverLines = <CartItem>[];
      for (final l in server.items) {
        final id = l.productId?.trim() ?? '';
        final ref = id.isEmpty ? null : packIndex[id];
        if (ref == null) continue; // blank id or product no longer exists
        serverLines.add(CartItem(
            productId: ref.product.id,
            variantIndex: ref.variantIndex,
            qty: l.qty));
      }
      cartItems = _unionLines(cartItems, serverLines);

      if (cartCoupon.isEmpty) {
        final serverCode = (server.couponCode ?? '').trim().toUpperCase();
        if (serverCode.isNotEmpty) {
          cartCoupon = serverCode;
          if (!coupons.any((c) => c.code == serverCode)) {
            _adoptCouponRow(
              code: serverCode,
              paise: 0,
              desc: 'Applied at checkout',
              worksWithCoins: true,
            );
          }
        }
      }

      final serverMode = (server.coinMode ?? 'NONE').toUpperCase();
      if (!useCoins && serverMode != 'NONE') {
        useCoins = true;
        coinMode = serverMode == 'PERCENT' ? 'percent' : 'all';
        if (serverMode == 'PERCENT') {
          final p = server.percent ?? flow.coinPercent;
          flow.coinPercent = p < 0 ? 0 : (p > 100 ? 100 : p);
        }
      }

      _changed();
      _pushCartToServer();
    } on ApiException {
      // The guest basket stays as it is; the next mutation pushes it.
    } catch (_) {
      // Best effort — a sign-in must never fail over basket merging.
    }
  }

  /// Offers a customer may browse: the public `GET /coupons`.
  ///
  /// Loaded before the basket is restored so a coupon already sitting on the
  /// account basket prices straight away. Failure is silent: the sheet keeps
  /// its "no live offers" note and applying a code still works.
  Future<void> loadPublicOffers() async {
    if (!ApiConfig.isLive || isBackendAdmin) return;
    try {
      final rows = await Api.instance.catalog.listOffers();
      coupons = publicCouponsFromDtos(rows);
      _changed();
    } on ApiException {
      // Keep whatever we had (a guest starts with none).
    } catch (_) {
      // Same.
    }
  }

  /// Build the lenient local coupon row for a code the server accepted.
  void _adoptCouponRow({
    required String code,
    required int paise,
    required String desc,
    required bool worksWithCoins,
    List<String> categoryIds = const <String>[],
  }) {
    _adoptedCouponPaise = paise;
    _adoptedCoupon = Coupon(
      code: code,
      desc: desc,
      type: 'flat',
      value: paiseToRupees(paise),
      min: 0,
      scope: categoryIds.isNotEmpty ? categoryIds.first : 'all',
      categoryIds: List<String>.of(categoryIds),
      active: true,
      starts: '',
      expires: '',
      uses: 0,
      maxUses: 1 << 30,
      worksWithCoins: worksWithCoins,
      firstOrderOnly: false,
    );
  }

  /// Validate [code] against the store (`POST /cart/quote`) and put it on the
  /// cart. Returns an error message, or null on success.
  ///
  /// There is no public coupon endpoint, so the quote is the only way a
  /// customer session can prove a code is usable. A rejected quote comes back
  /// as 422 `COUPON_INVALID` with a machine reason in `details.reason`, which
  /// [_couponInvalidMessage] turns into a sentence.
  Future<String?> applyCouponFromServer(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return 'Enter a coupon code.';

    // Offline prototype: the seeded catalog is the only source of truth.
    // (A live guest also lands here and is told to sign in — the quote
    // endpoint is authenticated, so only a session can prove a code.)
    if (!ApiConfig.isLive) {
      final check = couponCheck(clean);
      if (!check.ok) return check.message;
      setCoupon(clean);
      return null;
    }
    if (cartItems.isEmpty) return 'Add items to apply a coupon.';

    final items = _serverCartItems();
    if (items.isEmpty) return 'These items are not available to order online.';
    if (items.any((i) => (i['qty'] as int) > 99)) {
      return 'You can order at most 99 of one item at a time.';
    }

    try {
      final q = await Api.instance.orders.quote(
        items: items,
        couponCode: clean,
        coinMode: _wireCoinMode(),
        percent: _wireCoinPercent(),
        fulfilment: fulfilToWire(flow.checkoutMode),
      );
      final accepted = q.couponCode?.trim().toUpperCase();
      if (accepted != clean) return 'That coupon code is not valid.';

      final coinsBlocked = q.warnings
          .any((w) => w.startsWith('Coins cannot be used together'));
      _adoptCouponRow(
        code: clean,
        paise: q.couponDiscountPaise,
        desc: 'Applied at checkout',
        worksWithCoins: !coinsBlocked,
        categoryIds: _quoteCouponCategories(q),
      );
      cartCoupon = clean;
      cartQuoteWarnings = q.warnings;
      _cartChanged(requote: false);
      return null;
    } on ApiException catch (e) {
      if (e.code == 'COUPON_INVALID') return _couponInvalidMessage(e);
      return e.message;
    } catch (_) {
      return 'The coupon could not be checked right now. Try again.';
    }
  }

  /// `POST /cart/coupons` result for the current cart, by upper-case code.
  Map<String, CouponOptionDto> couponOptions = const {};
  bool couponOptionsLoading = false;

  /// Preview what every coupon saves on the cart (server computed) for the
  /// coupons sheet. Failure keeps the device-side check as a fallback.
  Future<void> loadCouponOptions() async {
    if (!ApiConfig.isLive || isBackendAdmin || cartItems.isEmpty) {
      couponOptions = const {};
      return;
    }
    final items = _serverCartItems();
    if (items.isEmpty) return;
    couponOptionsLoading = true;
    notifyListeners();
    try {
      final list = await Api.instance.orders.couponOptions(
        items: items,
        coinMode: _wireCoinMode(),
        percent: _wireCoinPercent(),
        fulfilment: fulfilToWire(flow.checkoutMode),
      );
      couponOptions = {for (final o in list) o.code: o};
    } catch (_) {
      couponOptions = const {};
    } finally {
      couponOptionsLoading = false;
      notifyListeners();
    }
  }

  /// Category ids the quote actually discounted (empty = coupon is not
  /// category-limited, or the server did not say).
  List<String> _quoteCouponCategories(QuoteDto q) {
    final ids = <String>[];
    for (final s in q.couponByCategory) {
      final id = s.categoryId ?? '';
      if (id.isNotEmpty && s.discountPaise > 0 && !ids.contains(id)) ids.add(id);
    }
    if (ids.isEmpty) {
      for (final l in q.lines) {
        final id = l.categoryId ?? '';
        if (id.isNotEmpty && l.couponDiscountPaise > 0 && !ids.contains(id)) {
          ids.add(id);
        }
      }
    }
    return ids;
  }

  /// Human sentence for a 422 `COUPON_INVALID` (backend `details.reason`).
  String _couponInvalidMessage(ApiException e) {
    var reason = '';
    final payload = e.payload;
    if (payload is Map) {
      final details = payload['details'];
      if (details is Map) reason = details['reason']?.toString() ?? '';
    }
    // The backend now sends a plain, ready-to-show sentence (with the
    // shortfall for a minimum order): show it as is.
    if (e.message.trim().isNotEmpty) return e.message.trim();
    switch (reason) {
      case 'EXPIRED':
        return 'This coupon has expired.';
      case 'MIN_ORDER':
        return 'This coupon needs a higher minimum cart value.';
      case 'CATEGORY':
        return 'This coupon does not apply to the items in your cart.';
      case 'LIMIT_REACHED':
        return 'This coupon has reached its usage limit.';
      case 'FIRST_ORDER_ONLY':
        return 'This coupon is valid on your first order only.';
      default:
        return e.message.isEmpty ? 'This coupon cannot be used.' : e.message;
    }
  }

  /// The basket on the wire for `POST /cart/quote` and `PUT /cart`: pack id
  /// (backend product id) + qty, deduped and clamped to the backend's
  /// `1..99` per line (the backend's `@Max(99)` on `PUT /cart`, `POST /cart/quote`
  /// and `POST /orders`) and `100` lines.
  List<Map<String, dynamic>> _serverCartItems() {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final it in cartItems) {
      if (items.length >= 100) break;
      final product = productById(it.productId);
      final packId = (product != null &&
              it.variantIndex >= 0 &&
              it.variantIndex < product.variants.length)
          ? product.variants[it.variantIndex].backendId
          : null;
      if (packId == null || packId.isEmpty || !seen.add(packId)) continue;
      var qty = it.qty;
      if (qty < 1) qty = 1;
      if (qty > 99) qty = 99;
      items.add({'productId': packId, 'qty': qty});
    }
    return items;
  }

  /// Coin mode on the wire for a quote: NONE | ALL | PERCENT.
  String _wireCoinMode() => !useCoins
      ? 'NONE'
      : coinMode == 'percent' || coinMode == 'custom' ? 'PERCENT' : 'ALL';

  int? _wireCoinPercent() {
    if (_wireCoinMode() != 'PERCENT') return null;
    // The server's `percent` is a share of the MAXIMUM redeemable coins
    // (floor(max * percent / 100)), while the app's "x% of my coins" is a
    // share of the wallet balance and "custom" is a coin COUNT. Translate the
    // coins the cart screen shows into the smallest server percent that gives
    // exactly that many, so the quote/order matches the on-screen total.
    final t = cartTotals();
    final maxCoins = t.balance < t.cap ? t.balance : t.cap;
    if (maxCoins <= 0 || t.coinsUsed <= 0) return 0;
    final pct = (t.coinsUsed * 100 + maxCoins - 1) ~/ maxCoins;
    return pct < 0 ? 0 : (pct > 100 ? 100 : pct);
  }


  // -------------------------------------------------------------------------
  // Lookups & stock primitives
  // -------------------------------------------------------------------------

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Variant variantOf(Product p, int index) {
    if (index >= 0 && index < p.variants.length) return p.variants[index];
    if (p.variants.isEmpty) {
      return Variant(label: '', price: 0, mrp: 0, unit: '', stock: 0);
    }
    return p.variants[p.defaultVariant < p.variants.length
        ? p.defaultVariant
        : 0];
  }

  /// `orderItemVariantIndex(p, it)` — match an order line to a variant index.
  int orderItemVariantIndex(Product p, OrderItem it) {
    if (it.variantIndex < 0 || it.variantIndex >= p.variants.length) {
      final match = p.variants.indexWhere(
          (v) => v.unit == it.unit || v.label == it.unit);
      return match >= 0 ? match : p.defaultVariant;
    }
    return it.variantIndex;
  }

  int variantStock(Product p, int index) {
    final v = variantOf(p, index);
    final s = v.stock.round();
    return s < 0 ? 0 : s;
  }

  /// `syncProductStock(p)`
  int syncProductStock(Product p) {
    var sum = 0;
    for (final v in p.variants) {
      final s = v.stock.round();
      v.stock = s < 0 ? 0 : s;
      sum += v.stock;
    }
    p.stock = sum;
    if (p.stock == 0 && p.available) p.available = false;
    return p.stock;
  }

  /// `ensureVariantStocks()` — distribute product stock into pack stocks.
  void ensureVariantStocks() {
    for (final p in products) {
      final missing = p.variants.any((v) => !v.stock.isFinite);
      // stock is non-null in Dart; emulate the JS migration by splitting
      // the seed product-level stock the same way the prototype does.
      final total = p.stock < 0 ? 0 : p.stock;
      final def =
          (p.defaultVariant >= 0 && p.defaultVariant < p.variants.length)
              ? p.defaultVariant
              : 0;
      final others = p.variants.length - 1;
      final base = others > 0 ? total ~/ 2 : total;
      final share = others > 0 ? (total - base) ~/ others : 0;
      var rest = others > 0 ? total - base - share * others : 0;
      for (var i = 0; i < p.variants.length; i++) {
        final v = p.variants[i];
        if (missing || v.stock == 0) {
          if (i == def) {
            v.stock = base;
          } else {
            v.stock = share + (rest > 0 ? 1 : 0);
            if (rest > 0) rest -= 1;
          }
        } else {
          v.stock = v.stock < 0 ? 0 : v.stock;
        }
      }
      syncProductStock(p);
    }
  }

  int cartCount() => cartItems.fold<int>(0, (sum, it) => sum + it.qty);

  /// Spendable coin balance.
  ///
  /// In backend mode the server's `/wallet` figure is authoritative; in demo
  /// mode it is derived from the local ledger.
  int coinBalance() {
    if (backendMode && walletLoaded) return walletCoins;
    return ledger.where((l) => l.status != 'pending').fold<int>(0, (s, l) => s + l.coins);
  }

  /// Coins earned but not yet credited.
  ///
  /// The backend only exposes settled balance via `/wallet`, so this is 0 in
  /// backend mode (pending earns arrive in the ledger after delivery).
  int coinPending() {
    if (backendMode && walletLoaded) return 0;
    return ledger.where((l) => l.status == 'pending').fold<int>(0, (s, l) => s + l.coins);
  }

  // -------------------------------------------------------------------------
  // Cart details
  // -------------------------------------------------------------------------

  List<CartLine> cartDetails() {
    final out = <CartLine>[];
    for (final it in cartItems) {
      final p = productById(it.productId);
      if (p == null) continue;
      final vi = (it.variantIndex < p.variants.length)
          ? it.variantIndex
          : p.defaultVariant;
      final v = variantOf(p, vi);
      out.add(CartLine(
        productId: it.productId,
        variantIndex: vi,
        qty: it.qty,
        p: p,
        v: v,
        lineTotal: v.price * it.qty,
      ));
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Coupons
  // -------------------------------------------------------------------------

  String scopeLabel(String scope) {
    if (scope == 'all') return 'All items';
    for (final c in categories) {
      if (c.id == scope) return c.name;
    }
    return scope;
  }

  /// Human label for a set of category ids: "All items" for none,
  /// "Groceries" for one, "Groceries + 2 more" for several.
  String scopeLabelOf(List<String> ids) {
    if (ids.isEmpty) return 'All items';
    if (ids.length == 1) return scopeLabel(ids.first);
    return '${scopeLabel(ids.first)} + ${ids.length - 1} more';
  }

  /// Human label for a coupon's scope — see [scopeLabelOf].
  String couponScopeLabel(Coupon c) => scopeLabelOf(
      c.categoryIds.isNotEmpty
          ? c.categoryIds
          : (c.scope.isEmpty || c.scope == 'all'
              ? const <String>[]
              : <String>[c.scope]));

  String couponDateStatus(Coupon c) => dateStatus(
      active: c.active, starts: c.starts, expires: c.expires);

  CouponResult couponCheck(String code, [List<CartLine>? details]) {
    final items = details ?? cartDetails();
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      return const CouponResult(
          ok: false, discount: 0, message: 'Enter a coupon code.');
    }
    Coupon? coupon;
    for (final c in coupons) {
      if (c.code == clean) coupon = c;
    }
    // Customer live sessions have no coupon catalog; fall back to the row a
    // successful `POST /cart/quote` adopted (kept across refreshes).
    coupon ??= (_adoptedCoupon != null && _adoptedCoupon!.code == clean)
        ? _adoptedCoupon
        : null;
    if (coupon == null) {
      return const CouponResult(
          ok: false, discount: 0, message: 'That coupon code is not valid.');
    }
    final status = couponDateStatus(coupon);
    if (status == 'inactive') {
      return CouponResult(
          ok: false,
          discount: 0,
          coupon: coupon,
          message: 'This coupon is currently paused.');
    }
    if (status == 'expired') {
      return CouponResult(
          ok: false,
          discount: 0,
          coupon: coupon,
          message: 'This coupon has expired.');
    }
    if (status == 'scheduled') {
      return CouponResult(
          ok: false,
          discount: 0,
          coupon: coupon,
          message:
              'This coupon starts on ${formatDate(DateTime.parse(coupon.starts))}.');
    }
    if (coupon.uses >= coupon.maxUses) {
      return CouponResult(
          ok: false,
          discount: 0,
          coupon: coupon,
          message: 'This coupon has reached its usage limit.');
    }
    if (coupon.firstOrderOnly) {
      final prior = orders.any(
          (o) => (digits(o.phone) == digits(userPhone) || o.customer == userName) &&
              o.status != 'Cancelled');
      if (prior) {
        return CouponResult(
            ok: false,
            discount: 0,
            coupon: coupon,
            message: 'This coupon is valid on your first order only.');
      }
    }
    if (items.isEmpty) {
      return CouponResult(
          ok: false,
          discount: 0,
          coupon: coupon,
          message: 'Add items to apply a coupon.');
    }
    final subtotal = items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final appliedCoupon = coupon;
    // Backend rule: only lines in the coupon's categories get discounted, and
    // the minimum order is checked against those lines. An empty category
    // list means every category.
    final scopeBase = items
        .where((it) => appliedCoupon.coversCategory(it.p.category))
        .fold<num>(0, (sum, it) => sum + it.lineTotal);
    if (scopeBase == 0) {
      return CouponResult(
          ok: false,
          discount: 0,
          coupon: coupon,
          message:
              'This coupon only works on ${couponScopeLabel(coupon)}.');
    }
    if (subtotal < coupon.min) {
      return CouponResult(
          ok: false,
          discount: 0,
          coupon: coupon,
          message: 'Add ${money(coupon.min - subtotal)} more to use this coupon.');
    }
    var discount = coupon.type == 'flat'
        ? (coupon.value < scopeBase ? coupon.value : scopeBase)
        : paiseToRupees((scopeBase * coupon.value).round());
    if (coupon.maxDiscount != null && discount > coupon.maxDiscount!) {
      discount = coupon.maxDiscount!;
    }
    return CouponResult(
      ok: true,
      discount: discount,
      coupon: coupon,
      scopeBase: scopeBase,
      message: 'Coupon applied. You saved ${money(discount)}.',
    );
  }

  // -------------------------------------------------------------------------
  // Coin earning rules
  // -------------------------------------------------------------------------

  String ruleWindowStatus(CoinRule rule) => dateStatus(
        active: rule.active,
        starts: rule.starts,
        expires: rule.expires,
        everGreen: rule.everGreen,
      );

  int ruleCoins(CoinRule rule, double amount) {
    if (rule.spend <= 0) return 0;
    if (rule.mode == 'slab') {
      return (amount / rule.spend).floor() * rule.coins;
    }
    return ((amount / rule.spend) * rule.coins).floor();
  }

  ({CoinRule? rule, int coins}) bestEarnRule(double amount) {
    CoinRule? bestRule;
    var best = 0;
    for (final rule in coinRules) {
      if (ruleWindowStatus(rule) != 'active') continue;
      final coins = ruleCoins(rule, amount);
      if (coins > best) {
        best = coins;
        bestRule = rule;
      }
    }
    if (bestRule == null) {
      for (final r in coinRules) {
        if (r.id == 'standard') {
          bestRule = r;
          break;
        }
      }
      bestRule ??= coinRules.isNotEmpty ? coinRules.first : null;
    }
    return (rule: bestRule, coins: best);
  }

  // -------------------------------------------------------------------------
  // cartTotals() — single source of truth
  // -------------------------------------------------------------------------

  CartTotals cartTotals() {
    final details = cartDetails();
    final subtotal = details.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final coupon =
        cartCoupon.isNotEmpty ? couponCheck(cartCoupon, details) : null;
    final couponOk = coupon != null && coupon.ok;
    var discount = couponOk ? coupon.discount : 0;
    if (discount > subtotal) discount = subtotal;
    final payable = subtotal - discount > 0 ? subtotal - discount : 0;
    final coinValue = coinSettings.coinValue > 0 ? coinSettings.coinValue : 1;
    final balance = coinBalance();
    final eligibleRaw = details
        .where((it) => it.p.allowCoins)
        .fold<num>(0, (sum, it) => sum + it.lineTotal);
    final eligibleBase = subtotal > 0 ? eligibleRaw * (payable / subtotal) : 0.0;
    var cap = ((eligibleBase * coinSettings.maxPercent) / 100).floor();
    if (cap < 0) cap = 0;
    final canUse = !couponOk || coupon.coupon!.worksWithCoins;

    var desired = 0;
    if (useCoins && canUse && eligibleRaw > 0) {
      if (coinMode == 'all') {
        desired = balance;
      } else if (coinMode == 'percent') {
        desired = ((balance * flow.coinPercent) / 100).floor();
      } else {
        desired = int.tryParse(flow.coinCustom.trim()) ?? 0;
      }
    }
    var coinsUsed = desired.clamp(0, balance < cap ? balance : cap);
    final coinDiscount = coinsUsed * coinValue;
    var total = subtotal - discount - coinDiscount;
    if (total < 0) total = 0;
    final earnRaw = details
        .where((it) => it.p.earnsCoins)
        .fold<num>(0, (sum, it) => sum + it.lineTotal);
    final earnRatio = subtotal > 0 ? earnRaw / subtotal : 0.0;
    final earn = bestEarnRule(total * earnRatio);

    return CartTotals(
      details: details,
      subtotal: subtotal,
      coupon: coupon,
      couponOk: couponOk,
      discount: discount,
      payable: payable,
      eligibleRaw: eligibleRaw,
      eligibleBase: eligibleBase,
      cap: cap,
      balance: balance,
      coinValue: coinValue,
      coinsUsed: coinsUsed,
      coinDiscount: coinDiscount,
      total: total,
      earnRatio: earnRatio,
      coinsEarned: earn.coins,
      earnRule: earn.rule,
      canUseCoins: canUse,
    );
  }

  // -------------------------------------------------------------------------
  // Cart mutation
  // -------------------------------------------------------------------------

  /// Returns an error message, or null on success.
  String? addToCart(String productId, int variantIndex, int qty) {
    final p = productById(productId);
    if (p == null) return null;
    if (!p.available || p.stock <= 0) return 'This item is out of stock';
    final vi = (variantIndex >= 0 && variantIndex < p.variants.length)
        ? variantIndex
        : p.defaultVariant;
    final available = variantStock(p, vi);
    if (available <= 0) return '${p.variants[vi].label} is out of stock';
    final idx = cartItems
        .indexWhere((it) => it.productId == productId && it.variantIndex == vi);
    final existingQty = idx >= 0 ? cartItems[idx].qty : 0;
    // The backend stores at most 100 lines (`PUT /cart`) and prices 1..99 per
    // line; `_serverCartItems` would silently drop a 101st line.
    if (idx < 0 && cartItems.length >= 100) {
      return 'Your basket is full (100 items). Remove something to add more.';
    }
    if (existingQty + qty > 99) return 'You can add at most 99 of one item';
    if (existingQty + qty > available) {
      return 'Only $available left of ${p.variants[vi].label}';
    }
    final lotCap = lotCapFor(productId, vi);
    if (lotCap != null && existingQty + qty > lotCap) {
      return '${gt('Only')} $lotCap ${gt('available at this price, order the rest after it sells')}';
    }
    if (idx >= 0) {
      cartItems[idx] = CartItem(
          productId: productId, variantIndex: vi, qty: existingQty + qty);
    } else {
      cartItems.add(CartItem(productId: productId, variantIndex: vi, qty: qty));
    }
    _cartChanged();
    return null;
  }

  String? setQty(int index, int delta) {
    if (index < 0 || index >= cartItems.length) return null;
    final it = cartItems[index];
    final p = productById(it.productId);
    final next = it.qty + delta;
    if (next <= 0) {
      cartItems.removeAt(index);
      _cartChanged();
      return null;
    }
    if (p == null) return null;
    final available = variantStock(p, it.variantIndex);
    if (next > available) return 'Only $available left in this pack';
    final lotCap = delta > 0 ? lotCapFor(it.productId, it.variantIndex) : null;
    if (lotCap != null && next > lotCap) {
      return '${gt('Only')} $lotCap ${gt('available at this price, order the rest after it sells')}';
    }
    cartItems[index] = CartItem(
        productId: it.productId, variantIndex: it.variantIndex, qty: next);
    _cartChanged();
    return null;
  }

  void removeLine(int index) {
    if (index < 0 || index >= cartItems.length) return;
    cartItems.removeAt(index);
    _cartChanged();
  }

  void setCoupon(String code) {
    cartCoupon = code;
    _cartChanged();
  }

  void clearCoupon() {
    cartCoupon = '';
    _cartChanged();
  }

  void setUseCoins(bool v) {
    useCoins = v;
    _cartChanged();
  }

  void setCoinMode(String mode) {
    coinMode = mode;
    _cartChanged();
  }

  void setCoinPercent(int v) {
    flow.coinPercent = v;
    _cartChanged();
  }

  void setCoinCustom(String v) {
    flow.coinCustom = v;
    _cartChanged();
  }

  /// Empty the basket — locally and on the account.
  ///
  /// The account's copy has to go too, otherwise the next device would still
  /// show what this one has just checked out. `DELETE /cart` is used rather
  /// than a `PUT` with no lines so the row disappears altogether.
  void resetCart() {
    cartItems = [];
    cartCoupon = '';
    useCoins = false;
    coinMode = 'all';
    flow.coinPercent = 50;
    flow.coinCustom = '';
    _changed();
    if (ApiConfig.isLive && _cartRestored && backendMode) {
      unawaited(() async {
        try {
          await Api.instance.cart.clear();
        } on ApiException catch (e) {
          apiLastError = e.message;
        } catch (_) {
          // The local basket is already clear; a failed mirror only leaves
          // a stale row on the account, which the next mutation overwrites.
        }
      }());
    }
  }

  // -------------------------------------------------------------------------
  // Orders: numbering, stock reservation, placement
  // -------------------------------------------------------------------------

  String nextOrderNumber() {
    var max = 1000;
    for (final o in orders) {
      final n = int.tryParse(o.number.replaceAll(RegExp(r'\D'), ''));
      if (n != null && n > max) max = n;
    }
    return 'VSM-${max + 1}';
  }

  void _reserveStock(List<CartLine> details) {
    for (final it in details) {
      final v = variantOf(it.p, it.variantIndex);
      final s = v.stock < it.qty ? 0 : v.stock - it.qty;
      v.stock = s;
      syncProductStock(it.p);
    }
  }

  void restoreStock(Order order) {
    for (final it in order.items) {
      final p = productById(it.productId);
      if (p == null) continue;
      var vi = -1;
      if (it.variantIndex >= 0 && it.variantIndex < p.variants.length) {
        vi = it.variantIndex;
      } else {
        for (var i = 0; i < p.variants.length; i++) {
          if (p.variants[i].unit == it.unit) {
            vi = i;
            break;
          }
        }
      }
      if (vi < 0) vi = p.defaultVariant;
      final v = variantOf(p, vi);
      v.stock += it.qty;
      syncProductStock(p);
    }
  }

  /// The shopper's chosen payment, folded to `cash | upi | card | netbanking`.
  /// Cash on delivery and pay-at-store are the same option (`cash`).
  String get checkoutPayKey {
    final p = flow.checkoutPayment.toLowerCase();
    if (p == 'upi' || p == 'card' || p == 'netbanking') return p;
    return 'cash';
  }

  /// Payment options checkout may offer, driven by `GET /payment-methods`.
  ///
  /// The backend only knows two methods for the app: `COD` and `ONLINE`
  /// (Razorpay). Cash on delivery / pay-at-store is the single `cash` option
  /// (wire `COD`); every online choice is the single `upi` key (wire
  /// `ONLINE`: Razorpay Checkout lets the shopper pick UPI, card or net
  /// banking). `ONLINE` is offered only while the admin has it on **and** this
  /// build can open Razorpay Checkout, so a shopper is never left with an
  /// order they cannot pay. The offline prototype shows everything.
  List<String> checkoutPaymentKeys() {
    if (!ApiConfig.isLive) return const ['upi', 'card', 'netbanking', 'cash'];
    final onlineOn = paymentMethods.any(
        (m) => m.enabled && (m.code ?? '').toUpperCase() == 'ONLINE');
    final codOn = paymentMethods.isEmpty ||
        paymentMethods
            .any((m) => m.enabled && (m.code ?? '').toUpperCase() == 'COD');
    return [
      if (onlineOn && RazorpayCheckout.supported) 'upi',
      // Never an empty list: the server re-validates and answers 400
      // `paymentMethod` if cash was switched off meanwhile.
      if (codOn || !(onlineOn && RazorpayCheckout.supported)) 'cash',
    ];
  }

  /// The exact `paymentMethod` the backend accepts on `POST /orders`
  /// (`OrderService.doPlace`: only `COD` or `ONLINE`; `CREDIT`/`HYBRID` are
  /// counter-only). Pay-at-store on a pickup order is also `COD`.
  String get _wirePaymentMethod => checkoutPayKey == 'cash' ? 'COD' : 'ONLINE';

  /// Places the current cart. Returns the order number or an error string.
  ///
  /// In a live build the backend is asked *first*: the local order, stock and
  /// cart are only committed once `POST /orders` accepts the order, so a
  /// rejected request (400 validation, 409 stock, …) comes back as an error
  /// instead of a celebration screen.
  /// Field errors (`details.fields`) of the last rejected order, shown on
  /// checkout next to the address / slot / payment cards.
  Map<String, String> checkoutFieldErrors = const {};

  Future<({String? number, String? error})> placeOrder() async {
    checkoutFieldErrors = const {};
    ApiException.clearFields();
    final totals = cartTotals();
    if (totals.details.isEmpty) {
      return (number: null, error: 'Your cart is empty');
    }
    final short = totals.details
        .where((it) => !it.p.available || it.qty > variantStock(it.p, it.variantIndex))
        .toList();
    if (short.isNotEmpty) {
      final s = short.first;
      return (
        number: null,
        error:
            '${s.p.name} · ${s.v.unit} only has ${variantStock(s.p, s.variantIndex)} left'
      );
    }

    if (backendMode && !isBackendAdmin && !onlineOrdersOpen) {
      return (
        number: null,
        error: onlineOrdersMessage.isNotEmpty
            ? onlineOrdersMessage
            : 'We are not taking online orders right now. Please visit the shop or try again later.'
      );
    }

    // An option the admin has since switched off falls back to cash.
    if (!checkoutPaymentKeys().contains(checkoutPayKey)) {
      flow.checkoutPayment = 'cash';
    }
    final pay = checkoutPayKey;
    final payLabel = pay == 'cash'
        ? (flow.checkoutMode == 'pickup' ? 'Pay at store' : 'Cash on delivery')
        : pay == 'netbanking'
            ? 'Net banking'
            : 'UPI / Card';
    // No payment gateway yet: online orders are placed unpaid and the backend
    // decides when they become Paid.
    final payState = 'Pending';

    final localNumber = nextOrderNumber();

    final onServer = backendMode && !isBackendAdmin;
    // A live build must never show a success screen for an order the server
    // did not receive (it would vanish from My orders and the admin list).
    if (ApiConfig.isLive && !onServer) {
      return (
        number: null,
        error: isBackendAdmin
            ? 'Staff accounts cannot place customer orders. Sign in with a customer account.'
            : 'Please sign in to place your order.'
      );
    }
    ({String? error, String? orderNo, String? id})? placed;
    if (onServer && ApiConfig.isLive) {
      // Delivery orders need a complete address before the round trip: the
      // backend rejects `POST /orders` without a selected address, and a row
      // saved before `area`/`pincode` existed would 400 on `pincode`. Check
      // here so the user gets a clear message instead of a server error.
      if (flow.checkoutMode == 'delivery') {
        Address? selected;
        for (final a in addresses) {
          if (a.id == flow.selectedAddressId) {
            selected = a;
            break;
          }
        }
        if (selected == null) {
          return (number: null, error: 'Choose a delivery address first');
        }
        if (!selected.isComplete) {
          return (
            number: null,
            error:
                'Add the area and pincode to “${selected.label}” before ordering'
          );
        }
      }
      placed = await _placeOrderOnServer(totals);
      if (placed.error != null) return (number: null, error: placed.error);
    }
    // A live order keeps the number the server gave it, so the order list,
    // the live stream and the placed screen all agree on one identity.
    final number = (placed?.orderNo ?? '').isNotEmpty
        ? placed!.orderNo!
        : localNumber;

    _reserveStock(totals.details);
    final now = istNow();
    final statusEvent = StatusEvent(status: 'Placed', at: now);
    final address = flow.checkoutMode == 'delivery'
        ? (addresses.isEmpty
            ? ''
            : addresses
                .firstWhere((a) => a.id == flow.selectedAddressId,
                    orElse: () => addresses.first)
                .full)
        : seed.store.address;
    final slot = flow.checkoutMode == 'pickup' ? flow.selectedSlot : '';

    final order = Order(
      number: number,
      customer: userName,
      phone: userPhone,
      customerEmail: '',
      items: totals.details
          .map((it) => OrderItem(
                productId: it.productId,
                variantIndex: it.variantIndex,
                name: it.p.name,
                nameGu: it.p.nameGu,
                unit: it.v.unit,
                price: it.v.price,
                qty: it.qty,
                earnsCoins: it.p.earnsCoins,
                allowCoins: it.p.allowCoins,
                art: it.p.art,
                tone: it.p.tone,
              ))
          .toList(),
      mode: flow.checkoutMode,
      address: address,
      slot: slot,
      payment: payLabel,
      paymentState: payState,
      status: 'Placed',
      statusHistory: [statusEvent],
      placedAt: now,
      updatedAt: now,
      bill: Bill(
        subtotal: totals.subtotal,
        couponCode: totals.couponOk ? cartCoupon : '',
        couponDiscount: totals.discount,
        coinsUsed: totals.coinsUsed,
        // The order screen opens on this optimistic row: take the money the
        // server really charged (delivery fee, final total) when it answered.
        delivery: placed?.id != null && _lastPlacedView != null
            ? _lastPlacedView!.deliveryFeePaise / 100
            : 0,
        total: placed?.id != null && _lastPlacedView != null
            ? _lastPlacedView!.totalPaise / 100
            : totals.total,
      ),
      coinsUsed: totals.coinsUsed,
      coinsEarned: totals.coinsEarned,
      coinRule: totals.earnRule?.name ?? 'Standard rule',
      cancelReason: '',
      partner: null,
      stockReserved: true,
      createdBy: 'customer',
    );
    orders.insert(0, order);

    if (totals.coinsUsed > 0) {
      ledger.insert(
          0,
          LedgerEntry(
            id: 'lg-redeem-$number',
            title: 'Redeemed on #$number',
            sub: 'Coins used at checkout',
            coins: -totals.coinsUsed,
            status: 'spent',
            type: 'spend',
            orderNumber: number,
            date: now,
          ));
    }
    if (totals.coinsEarned > 0) {
      ledger.insert(
          0,
          LedgerEntry(
            id: 'lg-pending-$number',
            title: 'Order #$number',
            sub: 'Pending delivery',
            coins: totals.coinsEarned,
            status: 'pending',
            type: 'earn',
            orderNumber: number,
            date: now,
          ));
    }

    if (totals.couponOk && totals.coupon?.coupon != null) {
      final c = totals.coupon!.coupon!;
      final ci = coupons.indexWhere((x) => x.code == c.code);
      if (ci >= 0) coupons[ci].uses += 1;
    }

    resetCart();
    flow.pdQty = 1;
    _changed();

    // Backend mode: re-sync the customer's order list + wallet from the
    // authoritative sources once the server has the order.
    if (onServer) {
      if (ApiConfig.isLive) {
        // Swap the optimistic row for the server's own order so the bill
        // (coupon discount, coins, totals) is exactly what was charged, and
        // keep it visible even if the list refresh below comes back empty.
        final placedView = _lastPlacedView;
        Order? serverOrder;
        if (placedView != null) {
          try {
            serverOrder = orderFromView(placedView, packIndex);
            if (serverOrder.customer.isEmpty) serverOrder.customer = userName;
            if (serverOrder.phone.isEmpty) serverOrder.phone = userPhone;
            orders.removeWhere((o) => o.number == number);
            orders.insert(0, serverOrder);
            _changed();
          } catch (_) {
            serverOrder = null;
          }
        }
        await _syncPlacedOrder(number,
            serverNo: placed?.orderNo, serverId: placed?.id);
        if (serverOrder != null &&
            !orders.any((o) => o.number == serverOrder!.number)) {
          orders.insert(0, serverOrder);
          _changed();
        }
        // ONLINE order: the server created it as PAYMENT_PENDING with a
        // Razorpay session - open Checkout, then wait for the server to
        // confirm (never trust the SDK callback).
        final view = _lastPlacedView;
        _lastPlacedView = null;
        if (view != null &&
            (view.status ?? '').toUpperCase() == 'PAYMENT_PENDING') {
          final note = await payOrderOnline(number);
          if (note != null) apiLastError = note;
        }
      } else {
        unawaited(_apiPlaceCustomerOrder(totals, number));
      }
    }
    return (number: number, error: null);
  }

  // -------------------------------------------------------------------------
  // Order stages
  // -------------------------------------------------------------------------

  List<String> orderSteps(Order order) => order.mode == 'pickup'
      ? ['Placed', 'Confirmed', 'Packed', 'Ready for Pickup', 'Picked Up']
      : ['Placed', 'Confirmed', 'Packed', 'Out for Delivery', 'Delivered'];

  int currentStepIndex(Order order) {
    if (order.status == 'Cancelled') return -1;
    final steps = orderSteps(order);
    final idx = steps.indexOf(order.status);
    return idx == -1 ? 0 : idx;
  }

  /// Statuses a finished order can never leave again — mirrors the server's
  /// `OrderStatus.isFinal` (DELIVERED / PICKED_UP / CANCELLED).
  static bool isFinalStatus(String status) =>
      status == 'Delivered' || status == 'Picked Up' || status == 'Cancelled';

  /// Whether a **customer** may still cancel this order — mirrors the
  /// backend's `OrderStatus.customerCanCancel` (Payment Pending, Placed or
  /// Confirmed, i.e. anything before the shop starts packing). Owners get a
  /// wider window; see [cancelRejection].
  static bool customerCanCancel(Order order) =>
      const ['Payment Pending', 'Placed', 'Confirmed'].contains(order.status);

  /// Every stage this UI can put an order into: the server's `OrderStatus`
  /// names minus `PAYMENT_PENDING`, which only the payment flow may set.
  static const selectableStatuses = [
    'Placed',
    'Confirmed',
    'Packed',
    'Ready for Pickup',
    'Out for Delivery',
    'Delivered',
    'Picked Up',
    'Cancelled',
  ];

  /// The stage the shop would *probably* move [order] to next.
  ///
  /// It is only a suggestion — a sensible label for a "next step" button —
  /// never a restriction. The backend's `OrderStatus.next()` lets an open
  /// order move to **any** other stage in any order, so [stageMoveRejection]
  /// is what actually decides whether a move may be offered.
  String nextStatus(Order order) {
    switch (order.status) {
      case 'Placed':
        return 'Confirmed';
      case 'Confirmed':
        return 'Packed';
      case 'Packed':
        return order.mode == 'pickup' ? 'Ready for Pickup' : 'Out for Delivery';
      case 'Out for Delivery':
        return 'Delivered';
      case 'Ready for Pickup':
        return 'Picked Up';
      default:
        return '';
    }
  }

  static const activeStatuses = [
    'Placed',
    'Confirmed',
    'Packed',
    'Ready for Pickup',
    'Out for Delivery'
  ];

  bool isActiveOrder(Order o) => activeStatuses.contains(o.status);

  static const primaryLabels = {
    'Confirmed': 'Confirm order',
    'Packed': 'Mark as packed',
    'Out for Delivery': 'Send out for delivery',
    'Ready for Pickup': 'Mark ready for pickup',
    'Delivered': 'Mark delivered',
    'Picked Up': 'Mark picked up',
  };

  static const primaryShortLabels = {
    'Confirmed': 'Confirm',
    'Packed': 'Pack',
    'Out for Delivery': 'Dispatch',
    'Ready for Pickup': 'Ready',
    'Delivered': 'Deliver',
    'Picked Up': 'Picked up',
  };

  String primaryAction(Order order) => primaryLabels[nextStatus(order)] ?? '';

  String statusLabel(String status) {
    switch (status) {
      case 'Ready for Pickup':
        return 'Ready for pickup';
      case 'Out for Delivery':
        return 'Out for delivery';
      case 'Picked Up':
        return 'Picked up';
      default:
        return status;
    }
  }

  static const statusLabelGu = {
    'Placed': 'પ્લેસ થયો',
    'Confirmed': 'કન્ફર્મ',
    'Packed': 'પેક થયો',
    'Ready for Pickup': 'પિકઅપ માટે તૈયાર',
    'Out for Delivery': 'ડિલિવરી માટે નીકળ્યો',
    'Delivered': 'પહોંચાડાયો',
    'Picked Up': 'લઈ લીધો',
    'Cancelled': 'રદ',
  };

  static const payStateGu = {
    'Paid': 'ચૂકવાયું',
    'Pending': 'બાકી',
    'Refunded': 'પરત મળ્યું',
  };

  static const cancelReasons = [
    'Changed my mind',
    'Ordered by mistake',
    'Need a different address',
    'Found a better price'
  ];

  static const cancelReasonGu = {
    'Changed my mind': 'મન બદલાયું',
    'Ordered by mistake': 'ભૂલથી ઓર્ડર કર્યું',
    'Need a different address': 'બીજું સરનામું જોઈએ',
    'Found a better price': 'સારી કિંમત મળી',
  };

  /// Plain-language headline for a cancelled order, from the machine
  /// `cancelCode` (the backend sends the remark raw, never pre-worded).
  static String cancelHeadline(Order o, bool gu) {
    switch (o.cancelCode) {
      case 'CUSTOMER_CANCELLED':
        return gu ? 'તમે ઓર્ડર રદ કર્યો' : 'You cancelled this order';
      case 'REJECTED_BY_SHOP':
        return gu ? 'દુકાને ઓર્ડર નકાર્યો' : 'Rejected by the store';
      case 'CANCELLED_BY_SHOP':
        return gu ? 'દુકાને ઓર્ડર રદ કર્યો' : 'Cancelled by the store';
      case 'PAYMENT_TIMEOUT':
        return gu
            ? 'સમયસર ચુકવણી ન થતાં ઓર્ડર રદ થયો'
            : 'Cancelled: payment was not completed in time';
      case 'PAYMENT_FAILED':
        return gu
            ? 'ચુકવણી નિષ્ફળ થતાં ઓર્ડર રદ થયો'
            : 'Cancelled: the payment failed';
    }
    switch (o.cancelledBy) {
      case 'CUSTOMER':
        return gu ? 'તમે ઓર્ડર રદ કર્યો' : 'You cancelled this order';
      case 'SHOP':
        return gu ? 'દુકાને ઓર્ડર રદ કર્યો' : 'Cancelled by the store';
      case 'SYSTEM':
        return gu ? 'ઓર્ડર આપમેળે રદ થયો' : 'Cancelled automatically';
    }
    return gu ? 'આ ઓર્ડર રદ થયો' : 'This order was cancelled';
  }

  /// The raw remark typed by whoever cancelled (older orders may still carry
  /// the legacy "Rejected by shop: " prefix, which is dropped). Known
  /// customer chips are translated; free text is shown as written.
  static String cancelRemark(Order o, bool gu) {
    var r = o.cancelReason.trim();
    const legacy = 'Rejected by shop:';
    if (r.toLowerCase().startsWith(legacy.toLowerCase())) {
      r = r.substring(legacy.length).trim();
    }
    if (r.isEmpty) return '';
    return gu ? (cancelReasonGu[r] ?? r) : r;
  }

  /// Headline plus remark ("Rejected by the store: out of stock").
  static String cancelText(Order o, bool gu) {
    final head = cancelHeadline(o, gu);
    final rem = cancelRemark(o, gu);
    return rem.isEmpty ? head : '$head: $rem';
  }

  /// `orderEta` per mode/status.
  static const etaDelivery = {
    'Placed': 'Delivering today by 8:00 PM',
    'Confirmed': 'Store is packing your order',
    'Packed': 'Rider will pick up shortly',
    'Out for Delivery': 'Arriving in 15 – 25 minutes',
    'Delivered': 'Delivered',
  };

  static const etaPickup = {
    'Placed': 'Store will confirm within 15 minutes',
    'Confirmed': 'Your order is being packed',
    'Packed': 'Almost ready for pickup',
    'Ready for Pickup': 'Collect from the store today',
    'Picked Up': 'Picked up',
  };

  Order? orderByNumber(String number) {
    for (final o in orders) {
      if (o.number == number) return o;
    }
    return null;
  }

  int _orderIndex(String number) => orders.indexWhere((o) => o.number == number);

  bool creditOrderCoins(Order order) {
    final li = ledger.indexWhere(
        (l) => l.orderNumber == order.number && l.status == 'pending');
    if (li >= 0) {
      ledger[li].status = 'credited';
      ledger[li].sub = 'Coins credited';
      return true;
    }
    if (order.coinsEarned > 0 && digits(order.phone) == digits(userPhone)) {
      ledger.insert(
          0,
          LedgerEntry(
            id: 'lg-earn-${order.number}',
            title: 'Order #${order.number}',
            sub: 'Coins credited',
            coins: order.coinsEarned,
            status: 'credited',
            type: 'earn',
            orderNumber: order.number,
            date: istNow(),
          ));
      return true;
    }
    return false;
  }

  bool reverseOrderCoins(Order order) {
    final li = ledger.indexWhere((l) =>
        l.orderNumber == order.number &&
        l.type == 'earn' &&
        l.status == 'credited');
    if (li < 0) return false;
    ledger[li].status = 'pending';
    ledger[li].sub = 'Pending delivery';
    return true;
  }

  static DeliveryPartner get _deliveryPartner => DeliveryPartner(
    name: 'Ramesh',
    role: '${seed.store.name} rider',
    phone: '98250 11223',
  );

  /// One-step forward. Returns the outcome to toast, or null for a no-op.
  ///
  /// Thin wrapper over [changeOrderStage]: it exists so a caller can't reach
  /// the old fire-and-forget path (mutate locally, send the move in the
  /// background) where a rejected backend call looked like a success.
  Future<StageResult?> advanceOrder(String number) {
    final idx = _orderIndex(number);
    if (idx < 0) return Future.value(null);
    final next = nextStatus(orders[idx]);
    if (next.isEmpty) return Future.value(null);
    return changeOrderStage(number, next);
  }

  /// Why the backend would refuse this stage move, or null when it is allowed.
  ///
  /// Mirrors `OrderStatus.next(fulfilment)` on the server: an **open** order
  /// may be moved to any other stage in any order (the shop chooses the
  /// sequence), while a finished one — Delivered, Picked Up or Cancelled — is
  /// locked for good, and `PAYMENT_PENDING` is reserved for the payment flow.
  /// Refusing here keeps a doomed request off the wire; anything the backend
  /// still rejects comes back as 409 and is surfaced by [changeOrderStage]
  /// against the re-synced order, never as a success.
  /// Staff status-move refusal text: OUT_OF_STOCK lists the short products
  /// (`details.items`), other codes show the server's own message.
  String _stageErrorText(ApiException e) {
    if (e.code == 'OUT_OF_STOCK') {
      final d = e.details;
      final items = d == null ? null : d['items'];
      if (items is List && items.isNotEmpty) {
        final names = <String>[];
        for (final it in items.whereType<Map>()) {
          final ref = packIndex[it['productId']?.toString() ?? ''];
          final left = (it['available'] as num?)?.toInt();
          names.add('${ref?.product.name ?? gt('An item')}'
              '${left == null ? '' : ' ($left ${gt('left')})'}');
        }
        return '${e.message}: ${names.join(', ')}. ${gt('Reject the order if it cannot be filled.')}';
      }
    }
    return e.message;
  }

  String? stageMoveRejection(Order order, String target) {
    if (isFinalStatus(order.status)) {
      return 'Order ${order.number} has reached its final stage.';
    }
    // The server never offers PLACED again once an order moved on (stock may
    // already be set aside): 422 INVALID_TRANSITION.
    if (target == 'Placed' && order.status != 'Placed') {
      return 'Order ${order.number} cannot go back to Placed.';
    }
    // Cancelling an open order is always on offer — the backend reaches
    // CANCELLED from any non-final status.
    if (target == 'Cancelled') return null;
    if (!selectableStatuses.contains(target)) {
      return 'Order ${order.number} cannot be moved to $target.';
    }
    return null;
  }

  /// Owner stage jump. Returns the outcome to toast, or null for a no-op.
  ///
  /// Live builds are **server-first**: `POST /admin/orders/{id}/status` is
  /// awaited before the local order is touched, so a transition the backend
  /// rejects (or an unreachable server) leaves the screen exactly as it was
  /// and returns `{ok: false, reason}` instead of a success message.
  Future<StageResult?> changeOrderStage(String number, String target) async {
    final start = _orderIndex(number);
    if (start < 0) return null;
    final order = orders[start];
    if (order.status == 'Cancelled') return null;
    if (target == order.status) return null;
    final rejection = stageMoveRejection(order, target);
    if (rejection != null) return (ok: false, message: rejection);

    if (backendMode && orderIdsByNo.containsKey(number)) {
      final err = await _apiSetStatus(number, statusToWire(target));
      if (err != null) {
        // The server has a different truth than this screen: pull it back
        // down so the refusal is readable against the current stage.
        if (err.statusCode >= 400) unawaited(_resyncOrdersAfterMove());
        return (ok: false, message: _stageErrorText(err));
      }
      unawaited(_resyncOrdersAfterMove());
    }

    // The move landed (or there is no server copy of this order): apply it
    // locally. `_apiSetStatus` may have re-synced the list, so re-find the row.
    final idx = _orderIndex(number);
    if (idx < 0) return null;
    final moved = orders[idx];
    if (moved.status == target) {
      return (
        ok: true,
        message: 'Order $number is already ${statusLabel(target).toLowerCase()}',
      );
    }
    final steps = orderSteps(moved);
    final fromIdx = steps.indexOf(moved.status);
    final toIdx = steps.indexOf(target);
    final movingBack = fromIdx >= 0 && toIdx >= 0 && toIdx < fromIdx;
    final wasFinal = moved.status == 'Delivered' || moved.status == 'Picked Up';
    final nowFinal = target == 'Delivered' || target == 'Picked Up';
    final now = istNow();

    var detail = '';
    if (nowFinal && !wasFinal && moved.paymentState != 'Paid') {
      moved.paymentState = 'Paid';
      detail += ' · payment marked paid';
    }
    if (wasFinal &&
        !nowFinal &&
        moved.payment != 'UPI / Card' &&
        moved.paymentState == 'Paid') {
      moved.paymentState = 'Pending';
      detail += ' · cash payment marked pending';
    }
    if (moved.mode == 'delivery') {
      final outIdx = steps.indexOf('Out for Delivery');
      if (toIdx >= outIdx) {
        moved.partner ??= _deliveryPartner;
      } else {
        moved.partner = null;
      }
    }
    moved.status = target;
    moved.updatedAt = now;
    moved.statusHistory = List<StatusEvent>.of(moved.statusHistory)
      ..add(StatusEvent(status: target, at: now));

    if (nowFinal && !wasFinal) {
      if (creditOrderCoins(moved) && moved.coinsEarned > 0) {
        detail += ' · ${moved.coinsEarned} coins credited';
      }
    }
    if (wasFinal && !nowFinal) {
      final before = coinBalance();
      if (reverseOrderCoins(moved)) {
        final after = coinBalance();
        detail += ' · ${before - after} coins returned to pending';
      }
    }
    _changed();
    return (
      ok: true,
      message:
          'Order $number ${movingBack ? 'moved back' : 'moved'} to ${statusLabel(target)}$detail',
    );
  }

  /// Cancellation. Returns the outcome to toast, or null for a no-op.
  ///
  /// Like [changeOrderStage] this is server-first in a live build: the
  /// backend owns the transition (and the refund/coin/stock side effects), so
  /// the local order only flips after the server has accepted it.
  Future<StageResult?> cancelOrder(String number, String reason, String by) async {
    final start = _orderIndex(number);
    if (start < 0) return null;
    final order = orders[start];
    final refusal = cancelRejection(order, by);
    if (refusal != null) return (ok: false, message: refusal);

    if (backendMode && orderIdsByNo.containsKey(number)) {
      // Staff drive status via the admin endpoint; a plain customer cancels
      // through the customer `/orders/{id}/cancel` endpoint (a customer JWT
      // can't call `/admin/...`, and a staff JWT has no "my order" to cancel).
      // Staff cancel through `POST /admin/orders/{id}/reject`: it is the only
      // staff call that stores the remark as the customer-visible
      // `cancelReason` (raw text; `cancelCode` REJECTED_BY_SHOP). `/status`
      // CANCELLED with a note now stores it too, but `/reject` is the
      // recommended call.
      final err = isBackendStaff
          ? await _apiRejectOrder(number, reason)
          : await _apiCancelOrder(number, reason);
      if (err != null) {
        if (err.statusCode >= 400) {
          unawaited(_resyncOrdersAfterMove(admin: isBackendStaff));
        }
        return (ok: false, message: err.message);
      }
      unawaited(_resyncOrdersAfterMove(admin: isBackendStaff));
    }

    final idx = _orderIndex(number);
    if (idx < 0) return null;
    final order2 = orders[idx];
    if (order2.status == 'Cancelled') {
      return (ok: false, message: 'Order $number is already cancelled');
    }
    final now = istNow();
    order2.status = 'Cancelled';
    // Raw remark, exactly as the server now stores it; the wording comes
    // from cancelCode at display time.
    order2.cancelReason = reason.trim();
    order2.cancelledBy = isBackendStaff ? 'SHOP' : 'CUSTOMER';
    order2.cancelCode =
        isBackendStaff ? 'REJECTED_BY_SHOP' : 'CUSTOMER_CANCELLED';
    order2.updatedAt = now;
    order2.statusHistory = List<StatusEvent>.of(order2.statusHistory)
      ..add(StatusEvent(status: 'Cancelled', at: now));
    if (order2.paymentState == 'Paid' && order2.payment == 'UPI / Card') {
      order2.paymentState = 'Refunded';
    }
    if (order2.stockReserved) {
      restoreStock(order2);
      order2.stockReserved = false;
    }
    ledger.removeWhere(
        (l) => l.orderNumber == order2.number && l.status == 'pending');
    if (order2.coinsUsed > 0) {
      ledger.insert(
          0,
          LedgerEntry(
            id: 'lg-refund-$number-${now.millisecondsSinceEpoch}',
            title: 'Coins returned',
            sub: 'Order #$number cancelled',
            coins: order2.coinsUsed,
            status: 'credited',
            type: 'refund',
            orderNumber: number,
            date: now,
          ));
    }
    final coupon = coupons.where((c) => c.code == order2.bill.couponCode);
    if (coupon.isNotEmpty && coupon.first.uses > 0) {
      coupon.first.uses -= 1;
    }
    _changed();
    return (
      ok: true,
      message:
          'Order $number cancelled${order2.coinsUsed > 0 ? ' · ${order2.coinsUsed} coins returned' : ''}',
    );
  }

  /// Why this cancellation would be refused, or null when it may proceed.
  ///
  /// Mirrors the backend: `OrderStatus.isFinal` locks Delivered / Picked Up /
  /// Cancelled for good; a **customer** may only cancel while
  /// `customerCanCancel()` holds (Payment Pending, Placed or Confirmed — i.e.
  /// before the shop starts packing); an **owner** may cancel any order that
  /// is still open, because `OrderStatus.next()` offers CANCELLED from every
  /// non-final status.
  String? cancelRejection(Order order, String by) {
    if (order.status == 'Cancelled') return 'Order ${order.number} is already cancelled.';
    if (isFinalStatus(order.status)) {
      return 'Order ${order.number} is already complete and cannot be cancelled.';
    }
    if (by == 'customer' && !customerCanCancel(order)) {
      return 'Only a placed order can be cancelled from the app.';
    }
    return null;
  }

  /// P1 section 9: `GET /orders/{id}/reorder` decides what can be bought again
  /// (qty = min(requested, stock now)); lines with qty > 0 go into the cart.
  /// Falls back to the local [reorder] when the call is not possible.
  Future<String> reorderFromServer(String number) async {
    final id = orderIdsByNo[number];
    if (!backendMode || id == null || id.isEmpty) return reorder(number);
    try {
      final r = await Api.instance.orders.reorder(id);
      var added = 0;
      final notes = <String>[];
      for (final l in r.items) {
        final ref = packIndex[l.productId];
        if (!l.available || l.qty <= 0 || ref == null) {
          notes.add('${l.name}: ${gt('not available now')}');
          continue;
        }
        final li = cartItems.indexWhere((c) =>
            c.productId == ref.product.id && c.variantIndex == ref.variantIndex);
        final existing = li >= 0 ? cartItems[li].qty : 0;
        final qty = (existing + l.qty > 99) ? 99 - existing : l.qty;
        if (qty <= 0) continue;
        if (li >= 0) {
          cartItems[li] = CartItem(
              productId: ref.product.id,
              variantIndex: ref.variantIndex,
              qty: existing + qty);
        } else {
          cartItems.add(CartItem(
              productId: ref.product.id,
              variantIndex: ref.variantIndex,
              qty: qty));
        }
        added += qty;
        if (l.qty < l.requestedQty) {
          notes.add('${l.name}: ${gt('Only')} ${l.qty} ${gt('of')} ${l.requestedQty} ${gt('available')}');
        }
        if (l.priceChanged) {
          notes.add('${l.name}: ${gt('price is now')} ${_rupeeText(l.unitPricePaise)}');
        }
      }
      if (added == 0) return 'Those items are not available right now';
      cartCoupon = '';
      useCoins = false;
      _cartChanged();
      final tail = notes.isEmpty ? '' : ' · ${notes.join(' · ')}';
      return '$added item${added > 1 ? 's' : ''} added back to cart$tail';
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return reorder(number);
    }
  }

  /// Reorder a past order. Returns a toast message.
  String reorder(String number) {
    final order = orderByNumber(number);
    if (order == null) return 'Those items are not available right now';
    var added = 0;
    for (final it in order.items) {
      final p = productById(it.productId);
      if (p == null || !p.available || p.stock <= 0) continue;
      var vi = -1;
      for (var i = 0; i < p.variants.length; i++) {
        if (p.variants[i].unit == it.unit) {
          vi = i;
          break;
        }
      }
      if (vi < 0) vi = p.defaultVariant;
      final available = variantStock(p, vi);
      if (available <= 0) continue;
      final li = cartItems.indexWhere(
          (c) => c.productId == it.productId && c.variantIndex == vi);
      final existing = li >= 0 ? cartItems[li].qty : 0;
      final qty =
          (it.qty < available - existing) ? it.qty : available - existing;
      if (qty <= 0) continue;
      if (li >= 0) {
        cartItems[li] = CartItem(
            productId: it.productId, variantIndex: vi, qty: existing + qty);
      } else {
        cartItems
            .add(CartItem(productId: it.productId, variantIndex: vi, qty: qty));
      }
      added += qty;
    }
    if (added == 0) return 'Those items are not available right now';
    cartCoupon = '';
    useCoins = false;
    _changed();
    return '$added item${added > 1 ? 's' : ''} added back to cart';
  }

  // -------------------------------------------------------------------------
  // Language / session
  // -------------------------------------------------------------------------

  void setLang(String value) {
    lang = value;
    GuLang.active = value == 'gu';
    _changed();
  }

  void signIn(String name, String phone) {
    if (name.isNotEmpty) userName = name;
    userPhone = phone;
    signedIn = true;
    _changed();
  }

  void signOut() {
    signedIn = false;
    isAdmin = false;
    _stopLiveOrders(); // the stream is tied to this session's token
    if (backendMode) {
      // Ends the backend session (clears stored JWTs) in the background.
      unawaited(Api.instance.auth.logout());
      userEmail = null;
      userRole = null;
      // The account's basket stays on the server for its next sign-in. Drop
      // the local copy so it is not shown as a guest basket or merged into
      // whoever signs in next on this device (see `_mergeCartOnSignIn`).
      cartItems = [];
      cartCoupon = '';
      _adoptedCoupon = null;
      _adoptedCouponPaise = 0;
      useCoins = false;
      coinMode = 'all';
      cartQuoteWarnings = [];
      if (ApiConfig.isLive) CartStore.clear();
    }
    _changed();
  }

  /// `DELETE /me` — erase the signed-in customer's account (store/data
  /// protection requirement). Returns an error message (account kept, stay
  /// signed in) or null once the account is gone and the session is cleared.
  Future<String?> deleteMyAccount() async {
    if (!backendMode) {
      signOut();
      return null;
    }
    try {
      await Api.instance.auth.deleteAccount();
    } on ApiException catch (e) {
      final d = e.details;
      if (e.code == 'ACCOUNT_HAS_OPEN_ORDERS') {
        final n = d?['openOrders'];
        return 'You still have ${n ?? 'some'} open order${n == 1 ? '' : 's'}. '
            'Wait until they are delivered or cancel them first.';
      }
      if (e.code == 'ACCOUNT_HAS_DUES') {
        final owed = d?['owedPaise'];
        final amt = owed is num ? ' (Rs ${(owed / 100).toStringAsFixed(2)})' : '';
        return 'You owe the shop credit$amt. Please clear it at the shop first.';
      }
      return e.message;
    } catch (_) {
      return 'Could not delete the account. Check your connection and try again.';
    }
    // Success: every server token is revoked; wipe the local session too.
    await Api.instance.session.clear();
    _stopLiveOrders();
    userEmail = null;
    userRole = null;
    userName = '';
    userPhone = '';
    signedIn = false;
    isAdmin = false;
    adminSignedIn = !ApiConfig.isLive;
    walletCoins = 0;
    walletValuePaise = 0;
    apiLastError = null;
    cartItems = [];
    cartCoupon = '';
    _adoptedCoupon = null;
    _adoptedCouponPaise = 0;
    useCoins = false;
    cartQuoteWarnings = [];
    if (ApiConfig.isLive) CartStore.clear();
    _changed();
    return null;
  }

  void setAdmin(bool v) {
    isAdmin = v;
    _changed();
  }

  void adminSignIn() {
    adminSignedIn = true;
    isAdmin = true;
    _changed();
  }

  /// The API client's refresh was refused (refresh token expired/rotated/
  /// revoked): the stored tokens are already wiped, so drop the signed-in
  /// state and send the user to sign-in.
  void handleSessionExpired() {
    _stopLiveOrders();
    userEmail = null;
    userRole = null;
    signedIn = false;
    isAdmin = false;
    adminSignedIn = !ApiConfig.isLive;
    apiLastError = 'Your session has ended. Please sign in again.';
    _changed();
  }

  void adminSignOut() {
    adminSignedIn = false;
    isAdmin = false;
    _stopLiveOrders(); // the stream is tied to this session's token
    // Backend mode: end the ADMIN session too, so the next sign-in starts fresh.
    if (backendMode) {
      unawaited(Api.instance.auth.logout());
      userEmail = null;
      userRole = null;
    }
    _changed();
  }

  bool isSaved(String productId) => wishlist.contains(productId);

  /// Returns true when the product is now saved. Optimistic local toggle;
  /// in backend mode the change is also persisted to `/me/wishlist`.
  bool toggleWishlist(String productId) {
    final nowSaved = !wishlist.remove(productId);
    if (nowSaved) wishlist.add(productId);
    _changed();
    if (backendMode) unawaited(_apiSyncWishlist(productId, nowSaved));
    return nowSaved;
  }

  /// First backend pack id for a grouped product (wishlist rows are packs).
  String? _packIdFor(String productId) {
    for (final ref in packIndex.values) {
      if (ref.product.id == productId) return ref.variant.backendId;
    }
    return null;
  }

  /// `POST`/`DELETE /me/wishlist/{productId}` for the optimistic toggle.
  Future<void> _apiSyncWishlist(String productId, bool saved) async {
    final packId = _packIdFor(productId);
    if (packId == null || packId.isEmpty) return;
    try {
      if (saved) {
        await Api.instance.auth.addToWishlist(packId);
      } else {
        // The heart is per product but the server saves per pack: drop every
        // pack of it so the heart does not relight on the next reload.
        for (final id in {
          packId,
          for (final ref in packIndex.values)
            if (ref.product.id == productId && ref.variant.backendId != null)
              ref.variant.backendId!,
        }) {
          await Api.instance.auth.removeFromWishlist(id);
        }
      }
    } on ApiException catch (e) {
      // Roll the optimistic toggle back (e.g. 400 "wishlist is full") and
      // tell the user why.
      if (saved) {
        wishlist.remove(productId);
      } else {
        wishlist.add(productId);
      }
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Best-effort.
    }
  }

  /// `GET /me/wishlist` → the saved pack rows mapped back to grouped product
  /// ids so the heart buttons light up after a reload.
  Future<void> loadWishlist() async {
    if (!backendMode) return;
    try {
      final rows = await Api.instance.auth.wishlist();
      final ids = <String>{};
      for (final pack in rows) {
        final id = pack.id;
        if (id == null) continue;
        final ref = packIndex[id];
        if (ref != null) {
          ids.add(ref.product.id);
        } else {
          ids.add(id);
        }
      }
      wishlist
        ..clear()
        ..addAll(ids);
      _changed();
    } on ApiException {
      // Keep whatever we had.
    } catch (_) {
      // Best-effort.
    }
  }

  void setNotifications(bool v) {
    notificationsOn = v;
    _changed();
  }

  // --- notifications inbox (`/me/notifications`) ---------------------------

  /// `GET /me/notifications` → the inbox rows + unread count.
  Future<void> loadInbox({bool force = false}) async {
    if (!backendMode) return;
    if (inboxLoaded && !force) return;
    try {
      final inbox = await Api.instance.auth.notifications(size: 50);
      final all = [...inbox.items];
      for (var pg = 1;
          pg < 6 && (inbox.hasMore ?? all.length < inbox.total);
          pg++) {
        final next = await Api.instance.auth.notifications(page: pg, size: 50);
        all.addAll(next.items);
        if (!(next.hasMore ?? all.length < next.total) || next.items.isEmpty) {
          break;
        }
      }
      inboxItems = all;
      inboxUnread = inbox.unread;
      inboxLoaded = true;
      _changed();
    } on ApiException {
      // Keep the local/demo feed.
    } catch (_) {
      // Best-effort.
    }
  }

  /// `POST /me/notifications/{id}/read` — mark one row read.
  Future<void> markInboxRead(String id) async {
    if (!backendMode) return;
    final idx = inboxItems.indexWhere((n) => n.id == id);
    if (idx >= 0 && !inboxItems[idx].read) {
      inboxItems[idx].read = true;
      if (inboxUnread > 0) inboxUnread--;
      _changed();
    }
    try {
      await Api.instance.auth.markNotificationRead(id);
    } on ApiException catch (e) {
      // The server did not take it: show its truth again.
      apiLastError = e.message;
      await loadInbox(force: true);
    } catch (_) {
      await loadInbox(force: true);
    }
  }

  /// `POST /me/notifications/read-all` — clear the unread badge.
  Future<void> markAllInboxRead() async {
    if (!backendMode) return;
    for (final n in inboxItems) {
      n.read = true;
    }
    inboxUnread = 0;
    _changed();
    try {
      await Api.instance.auth.markAllNotificationsRead();
    } on ApiException catch (e) {
      apiLastError = e.message;
      await loadInbox(force: true);
    } catch (_) {
      await loadInbox(force: true);
    }
  }

  /// Set on a fresh OTP sign-in whose account is still bare (no name and/or
  /// no mobile) — a brand-new customer. `#/setup` collects the rest and then
  /// announces the store's first-order offer.
  ///
  /// Deliberately not persisted: localStorage holds the two JWTs and nothing
  /// else, and `GET /me` re-read on the next visit already says whether the
  /// profile is complete.
  bool needsProfileSetup = false;

  /// The store's first-order offer: an **active** backend coupon flagged
  /// `firstOrderOnly` (WELCOME10 today). The value comes from the coupon
  /// table, never from the client — if the shop isn't running one this is
  /// null and the setup flow simply finishes without an announcement.
  Coupon? get firstOrderOffer {
    for (final c in coupons) {
      if (c.firstOrderOnly && c.active && couponDateStatus(c) == 'active') {
        return c;
      }
    }
    return null;
  }

  /// First-time setup: `PUT /me`, then (when one is filled in)
  /// `POST /me/addresses`. Returns the first error, or null when everything
  /// landed.
  ///
  /// Server-first: nothing is reported saved until the backend answers 2xx,
  /// and validation mirrors it exactly — `ProfileService` wants a 10-digit
  /// mobile, `AddressInput` marks label/line1/area/pincode `@NotBlank` — so a
  /// doomed request never leaves the device. When the details save but the
  /// address does not, the message says precisely that instead of blaming the
  /// whole form.
  Future<String?> saveFirstProfile({
    required String name,
    required String mobile,
    String label = '',
    String line1 = '',
    String area = '',
    String pincode = '',
  }) async {
    final cleanName = name.trim();
    final cleanMobile = digits(mobile);
    if (cleanName.isEmpty) return 'Enter your name';
    if (!RegExp(r'^\d{10}$').hasMatch(cleanMobile)) {
      return 'Enter a 10-digit mobile number';
    }
    // The address block is optional; half of it is not.
    final wantAddress = [label, line1, area, pincode]
        .any((v) => v.trim().isNotEmpty);
    if (wantAddress) {
      if (line1.trim().isEmpty) return 'Add your flat / street / house number';
      if (area.trim().isEmpty) return 'Add the area / locality';
      if (!RegExp(r'^\d{6}$').hasMatch(pincode.trim())) {
        return 'Enter a valid 6-digit pincode';
      }
    }

    if (!backendMode) {
      userName = cleanName;
      userPhone = cleanMobile;
      needsProfileSetup = false;
      _changed();
      return null;
    }

    try {
      final user = await Api.instance.auth
          .updateProfile(name: cleanName, mobile: cleanMobile);
      // Adopt what the server actually stored (it trims and may reject a
      // changed, already-verified mobile number).
      userName = (user.name ?? cleanName).trim();
      userPhone = (user.mobile ?? cleanMobile).trim();
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save your details. Check your connection and try again.';
    }

    if (wantAddress) {
      try {
        await Api.instance.auth.addAddress(
          label: label.trim().isEmpty ? 'Home' : label.trim(),
          line1: line1.trim(),
          area: area.trim(),
          pincode: pincode.trim(),
        );
        await refreshAddresses();
      } on ApiException catch (e) {
        return 'Your details were saved, but the address could not be saved: '
            '${e.message}';
      } catch (_) {
        return 'Your details were saved, but the address could not be '
            'reached. Try again.';
      }
    }

    needsProfileSetup = false;
    _changed();
    return null;
  }

  /// Persist the edited profile to `PUT /me`. Returns an error message or
  /// null on success (the backend rejects a changed, already-verified
  /// mobile number — surfaced to the profile sheet).
  Future<String?> updateProfile({String? name, String? phone}) async {
    final prevName = userName;
    final prevPhone = userPhone;
    userName = name ?? userName;
    userPhone = phone ?? userPhone;
    _changed();
    if (!backendMode) return null;
    final err = await _apiUpdateProfile();
    if (err != null) {
      // Rejected (400 / 409 MOBILE_VERIFIED / offline): do not keep showing
      // the name / mobile the server refused.
      userName = prevName;
      userPhone = prevPhone;
      _changed();
    }
    return err;
  }

  // -------------------------------------------------------------------------
  // Addresses
  // -------------------------------------------------------------------------

  /// Saves a delivery address locally and (in backend mode) on the server.
  ///
  /// The backend's schema is `{label, line1, area, pincode, isDefault}` with
  /// `area` and `pincode` required, so both are collected and validated here
  /// — a missing one is reported before any request is made.
  String? addAddress(
    String label,
    String detail,
    String phone, {
    required String area,
    required String pincode,
  }) {
    if (detail.trim().isEmpty) return 'Add the full delivery address';
    if (area.trim().isEmpty) return 'Add the area / locality';
    if (!RegExp(r'^\d{6}$').hasMatch(pincode.trim())) {
      return 'Enter a valid 6-digit pincode';
    }
    // Phone is optional now: blank or exactly 10 digits.
    if (digits(phone).isNotEmpty && digits(phone).length != 10) {
      return 'Enter a valid 10-digit phone number';
    }
    final cleanLabel = label.trim().isEmpty ? 'Address' : label.trim();
    final cleanDetail = detail.trim();
    final cleanArea = area.trim();
    final cleanPin = pincode.trim();
    addresses.add(Address(
        id: 'addr${addresses.length + 1}',
        label: cleanLabel,
        detail: cleanDetail,
        area: cleanArea,
        pincode: cleanPin,
        phone: phone.trim()));
    _changed();
    // Backend mode: also persist to `/me/addresses`, then re-sync ids.
    if (backendMode) {
      ApiException.clearFields();
      addressSync = _apiAddAddress(
          cleanLabel, cleanDetail, cleanArea, cleanPin, digits(phone));
      unawaited(addressSync);
    }
    return null;
  }

  /// `PUT /me/addresses/{id}` with `isDefault: true` (the PUT is a full
  /// replacement, so the stored fields are sent back unchanged). Returns an
  /// error message or null.
  Future<String?> makeDefaultAddress(String id) async {
    final a = addresses.where((x) => x.id == id).toList();
    if (a.isEmpty || !backendMode || id.startsWith('addr')) return null;
    try {
      await Api.instance.auth.updateAddress(
        id,
        label: a.first.label,
        line1: a.first.detail,
        area: a.first.area,
        pincode: a.first.pincode,
        phone: digits(a.first.phone),
        isDefault: true,
      );
      await refreshAddresses();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not change the default address.';
    }
  }

  void removeAddress(String id) {
    final wasDefault = addresses.any((a) => a.id == id && a.isDefault);
    addresses.removeWhere((a) => a.id == id);
    if (flow.selectedAddressId == id && addresses.isNotEmpty) {
      flow.selectedAddressId = addresses.first.id;
    }
    _changed();
    // Backend mode: also delete on the server (skip un-synced temp rows).
    if (backendMode && !id.startsWith('addr')) {
      // The server promotes the next address itself when the default is
      // deleted; re-read the list so the app shows that instead of guessing.
      unawaited(_apiDeleteAddress(id).then((_) {
        if (wasDefault) return refreshAddresses();
        return null;
      }));
    }
  }

  void selectAddress(String id) {
    flow.selectedAddressId = id;
    _changed();
  }

  // -------------------------------------------------------------------------
  // KPI helpers
  // -------------------------------------------------------------------------

  List<Order> userOrders() {
    if (backendMode) {
      // `/orders` is already scoped to the signed-in customer, so the whole
      // list belongs to them (summaries carry no name/phone to filter on).
      // Staff sessions are different: they hold the *shop's* order list
      // (admin endpoint), so `#/orders` narrows it to the orders this
      // account placed — everything else lives on the admin Orders screen.
      final mine = (userEmail ?? '').toLowerCase();
      final list = isBackendStaff
          ? orders
              .where((o) =>
                  o.customerEmail.isNotEmpty &&
                  o.customerEmail.toLowerCase() == mine)
              .toList()
          : List<Order>.of(orders);
      return list..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    }
    final list = orders
        .where((o) =>
            digits(o.phone) == digits(userPhone) || o.customer == userName)
        .toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return list;
  }

  List<Order> liveOrders() {
    const priority = {
      'Placed': 0,
      'Confirmed': 1,
      'Packed': 2,
      'Ready for Pickup': 3,
      'Out for Delivery': 4,
    };
    final list = orders.where(isActiveOrder).toList()
      ..sort((a, b) {
        final pa = priority[a.status] ?? 9;
        final pb = priority[b.status] ?? 9;
        if (pa != pb) return pa.compareTo(pb);
        return b.placedAt.compareTo(a.placedAt);
      });
    return list;
  }

  /// Stock needing attention: an ACTIVE product at or below its low-stock
  /// threshold (out of stock included). Inactive products are a deliberate
  /// state, not an alert. The dashboard tile, banner, bell and the
  /// inventory "Low stock" chip all use this one definition.
  bool isLowStock(Product p) => p.available && p.stock <= p.lowStock;

  List<Product> lowStockProducts() => products.where(isLowStock).toList();

  List<Order> todayOrders() {
    final today = localDayKey(istNow());
    return orders
        .where((o) => localDayKey(o.placedAt) == today && o.status != 'Cancelled')
        .toList();
  }

  num dashboardSales() => todayOrders().fold<num>(0, (sum, o) => sum + o.bill.total);

  int newOrderCount() => orders.where((o) => o.status == 'Placed').length;

  int coinsIssued() => ledger
      .where((l) => l.status == 'credited' && l.coins > 0)
      .fold<int>(0, (s, l) => s + l.coins);

  List<Order> reportOrders(String period) {
    const days = {'week': 7, 'month': 30, 'quarter': 90};
    final cutoff = istNow().subtract(Duration(days: days[period] ?? 7));
    return orders
        .where((o) => o.status != 'Cancelled' && o.placedAt.isAfter(cutoff))
        .toList();
  }

  // -------------------------------------------------------------------------
  // Admin mutations
  // -------------------------------------------------------------------------

  /// Save product draft. Returns an error message, or null on success.
  /// [persistToServer] is false when the caller is about to await
  /// [saveProductToServer] itself — otherwise the pack would be posted twice
  /// (once here fire-and-forget, once by the caller) and a brand-new product
  /// would be created twice on the backend.
  String? saveProduct(Product draft, {String? existingId, bool persistToServer = true}) {
    if (draft.name.trim().isEmpty) return 'Give this product a name';
    for (final v in draft.variants) {
      if (v.label.trim().isEmpty || v.price <= 0) {
        return 'Add a pack name and selling price for each pack';
      }
      if (v.mrp > 0 && v.mrp < v.price) {
        return 'MRP for ${v.label} must be at least the selling price';
      }
    }
    final seen = <String>{};
    for (final v in draft.variants) {
      final key = v.label.trim().toLowerCase();
      if (seen.contains(key)) return '“${v.label}” is already a pack on this product';
      seen.add(key);
    }
    if (draft.variants.isEmpty) return 'Add at least one pack with a price';

    draft.name = draft.name.trim();
    draft.desc = draft.desc.trim().isEmpty
        ? 'Fresh from ${seed.store.name}, delivered free to your door.'
        : draft.desc.trim();
    if (draft.category.isEmpty) draft.category = 'grocery';
    if (draft.unit.isEmpty && draft.variants.isNotEmpty) {
      draft.unit = draft.variants[0].label;
    }
    if (draft.rating == 0) draft.rating = 4.6;

    if (existingId != null) {
      final idx = products.indexWhere((p) => p.id == existingId);
      if (idx >= 0) {
        draft.defaultVariant = draft.defaultVariant < draft.variants.length
            ? draft.defaultVariant
            : 0;
        draft.id = existingId;
        final prevStock = products[idx].stock;
        final prevAvailable = products[idx].available;
        products[idx] = draft;
        syncProductStock(draft);
        // Only a product that was out of stock comes back on sale by itself
        // when it is restocked; an admin who switched "Available for sale"
        // off (or left it off) must not have it silently re-enabled.
        if (prevStock <= 0 && draft.stock > 0 && draft.available == prevAvailable) {
          draft.available = true;
        }
        _changed();
        if (backendMode && persistToServer) unawaited(_apiSaveProduct(draft));
        return null;
      }
    }

    // create new product (slug id with -2 suffixing on collision)
    var slug = draft.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'item';
    var id = slug;
    var n = 2;
    while (productById(id) != null) {
      id = '$slug-$n';
      n++;
    }
    draft.id = id;
    if (draft.nameGu.trim().isEmpty) draft.nameGu = draft.name;
    draft.defaultVariant =
        draft.defaultVariant < draft.variants.length ? draft.defaultVariant : 0;
    syncProductStock(draft);
    draft.available = draft.stock > 0;
    if (!products.any((x) => identical(x, draft))) products.add(draft);
    for (var i = 0; i < draft.variants.length; i++) {
      final q = draft.variants[i].stock;
      if (q > 0) {
        stockMoves.insert(
            0,
            StockMove(
              id: 'stk-${istNow().millisecondsSinceEpoch}-$i',
              productId: id,
              productName: draft.name,
              variantIndex: i,
              variantLabel: draft.variants[i].label,
              qty: q,
              at: istNow(),
              note: 'Opening stock',
            ));
      }
    }
    _changed();
    if (backendMode && persistToServer) unawaited(_apiSaveProduct(draft));
    return null;
  }

  void logStockMove(String productId, int variantIndex, String variantLabel,
      int qty, String note) {
    if (qty <= 0) return;
    final p = productById(productId);
    stockMoves.insert(
        0,
        StockMove(
          id: 'stk-${istNow().millisecondsSinceEpoch}',
          productId: productId,
          productName: p?.name ?? '',
          variantIndex: variantIndex,
          variantLabel: variantLabel,
          qty: qty,
          at: istNow(),
          note: note,
        ));
  }

  /// Restock dialog. Returns a toast message or an error string.
  String? restock(String productId, List<int> addPerPack, {Variant? newPack}) {
    final p = productById(productId);
    if (p == null) return null;
    final wasOut = p.stock <= 0;
    var added = 0;
    for (var i = 0; i < addPerPack.length && i < p.variants.length; i++) {
      final qty = addPerPack[i];
      if (qty <= 0) continue;
      p.variants[i].stock += qty;
      logStockMove(productId, i, p.variants[i].label, qty, 'Supplier purchase');
      added += qty;
    }
    String? label;
    if (newPack != null) {
      if (newPack.label.trim().isEmpty || newPack.price <= 0) {
        return 'Add a name and price for the new pack';
      }
      if (newPack.stock <= 0) return 'Add the units received for the new pack';
      if (p.variants.any((v) =>
          v.label.trim().toLowerCase() == newPack.label.trim().toLowerCase())) {
        return '“${newPack.label}” already exists on this product';
      }
      if (newPack.mrp > 0 && newPack.mrp < newPack.price) {
        return 'New pack MRP must be at least the selling price';
      }
      final idx = p.variants.length;
      final pack = Variant(
        label: newPack.label.trim(),
        price: newPack.price,
        mrp: newPack.mrp > 0 ? newPack.mrp : newPack.price,
        // A unit is a unit *code*, not the pack label — the backend rejects
        // anything it does not know ("unknown unit '500 g'").
        unit: unitCodeFor(newPack.unit, fallback: p.unit),
        stock: newPack.stock,
      );
      p.variants.add(pack);
      logStockMove(productId, idx, pack.label, pack.stock, 'New pack received');
      added += pack.stock;
      label = pack.label;
    }
    if (added == 0) return 'Enter the quantity received';
    syncProductStock(p);
    if (wasOut && p.stock > 0) p.available = true;
    _changed();
    if (backendMode) unawaited(_apiRestock(productId, addPerPack));
    return label != null
        ? '$label pack added · +$added unit(s)'
        : 'Stock updated · +$added unit(s)';
  }

  /// Adds a category type. In demo mode the local slug id is used directly;
  /// against the backend the row is created first so the returned id is the
  /// server's UUID (product rows reference it) — on API failure the local
  /// row is rolled back.
  Future<({String? id, String? error})> addCategory(String name) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return (id: null, error: 'Give the new type a name');
    if (categories.any((c) => c.name.toLowerCase() == clean.toLowerCase())) {
      return (id: null, error: 'That type already exists');
    }
    var slug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'type';
    var id = slug;
    var n = 2;
    while (categories.any((c) => c.id == id)) {
      id = '$slug-$n';
      n++;
    }
    const tones = ['mint', 'peach', 'gold', 'rose', 'sky'];
    final local = Category(
      id: id,
      name: clean,
      nameGu: clean,
      icon: 'bag',
      tone: tones[categories.length % tones.length],
    );
    categories.add(local);
    _changed();

    if (!backendMode) return (id: local.id, error: null);

    // Backend mode: create the row and re-sync so ids come from the server.
    try {
      final dto =
          await Api.instance.admin.createCategory(nameEn: clean, nameGu: clean);
      categories = categoriesFromDtos(await Api.instance.catalog.getCategories());
      _changed();
      final serverId =
          categories.where((c) => c.name == clean).toList();
      return (
        id: dto.id ?? (serverId.isNotEmpty ? serverId.first.id : local.id),
        error: null,
      );
    } on ApiException catch (e) {
      // Roll back the optimistic local row — it can't be saved against the API.
      categories.removeWhere((c) => c.id == local.id);
      _changed();
      return (id: null, error: e.message);
    } catch (_) {
      categories.removeWhere((c) => c.id == local.id);
      _changed();
      return (id: null, error: 'Could not add the category.');
    }
  }

  // --- admin categories (GET/POST/PUT/DELETE /admin/categories) -----------

  /// Every category incl. hidden ones (`GET /admin/categories`); empty until
  /// the first admin load.
  List<CategoryDto> adminCategoryRows = <CategoryDto>[];

  /// Categories for the product and coupon pickers: the public (active) list,
  /// plus hidden ones from the admin list marked "(hidden)" so a product that
  /// still sits in a hidden category keeps a readable name.
  List<Category> get pickerCategories {
    if (adminCategoryRows.isEmpty) return categories;
    final byId = {for (final c in categories) c.id: c};
    final out = <Category>[];
    for (final d in adminCategoryRows) {
      final id = d.id;
      if (id == null) continue;
      final known = byId[id];
      if (known != null) {
        out.add(known);
      } else {
        final n = d.nameEn ?? d.nameGu ?? id;
        out.add(Category(
            id: id,
            name: d.active ? n : '$n (hidden)',
            nameGu: d.nameGu ?? n,
            icon: 'bag',
            tone: 'mint'));
      }
    }
    for (final c in categories) {
      if (!out.any((o) => o.id == c.id)) out.add(c);
    }
    return out;
  }

  Future<void> refreshAdminCategories() async {
    if (!backendMode) return;
    try {
      adminCategoryRows = await Api.instance.admin.listCategories();
      _changed();
    } catch (_) {
      // Keep the public list; the picker still works with active rows.
    }
  }

  Future<void> _reloadCategoriesAfterAdminEdit() async {
    await refreshAdminCategories();
    try {
      await _refreshCategoriesQuiet();
    } catch (_) {}
  }

  /// Create ([id] null) or update a category. Returns an error or null.
  Future<String?> saveAdminCategory({
    String? id,
    required String nameEn,
    required String nameGu,
    required bool active,
    int? sortOrder,
  }) async {
    final en = nameEn.trim();
    if (en.isEmpty) return 'Give the category a name';
    final gu = nameGu.trim().isEmpty ? en : nameGu.trim();
    try {
      if (id == null) {
        await Api.instance.admin.createCategory(
            nameEn: en,
            nameGu: gu,
            sortOrder: sortOrder ?? adminCategoryRows.length,
            active: active);
      } else {
        await Api.instance.admin.updateCategory(id,
            nameEn: en, nameGu: gu, sortOrder: sortOrder, active: active);
      }
      await _reloadCategoriesAfterAdminEdit();
      return null;
    } on ApiException catch (e) {
      return ApiException.fieldError(e.fields, ['nameEn', 'nameGu']) ??
          e.message;
    } catch (_) {
      return 'Could not save the category.';
    }
  }

  /// `DELETE /admin/categories/{id}`. 409 `CATEGORY_IN_USE` becomes a plain
  /// message ("move the products or hide it instead").
  Future<String?> deleteAdminCategory(String id) async {
    try {
      await Api.instance.admin.deleteCategory(id);
      await _reloadCategoriesAfterAdminEdit();
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 409 || (e.code ?? '') == 'CATEGORY_IN_USE') {
        return 'Products or coupons still use this category. Move them to '
            'another category, or switch this one off to hide it.';
      }
      return e.message;
    } catch (_) {
      return 'Could not delete the category.';
    }
  }

  /// `POST /admin/categories/{id}/image`. Returns an error or null.
  Future<String?> uploadAdminCategoryImage(
      String id, List<int> bytes, String filename) async {
    if (bytes.isEmpty) return 'The selected file is empty';
    if (bytes.length > 5 * 1024 * 1024) {
      return 'The photo is over 5 MB. Choose a smaller one.';
    }
    try {
      await Api.instance.admin.uploadCategoryImage(id, bytes, filename);
      await _reloadCategoriesAfterAdminEdit();
      return null;
    } on ApiException catch (e) {
      return uploadErrorMessage(e);
    } catch (_) {
      return 'Could not upload the image.';
    }
  }

  /// Saves the coin settings. Resolves to null on success, else the server's
  /// (or the network's) error text; the screen toasts success only then.
  Future<String?> saveCoinSettings(
      {required num coinValue,
      required int maxPercent,
      required int expiryMonths}) async {
    num cv = coinValue;
    if (cv < 0.01) cv = 0.01;
    var mp = maxPercent.round();
    if (mp > 100) mp = 100;
    // 0 is a valid share (the server accepts 0..100): it switches coin
    // redemption off, so it must not be raised to 1.
    if (mp < 0) mp = 0;
    var em = expiryMonths.round();
    if (em < 1) em = 1;
    final before = coinSettings;
    coinSettings = CoinSettings(coinValue: cv, maxPercent: mp, expiryMonths: em);
    _changed();
    if (!backendMode) return null;
    final err = await _apiSaveCoinSettings(
        coinValue: cv, maxPercent: mp, expiryMonths: em);
    if (err != null) {
      // Roll back to what the server still holds (or the previous values).
      coinSettings = before;
      try {
        coinSettings =
            coinSettingsFromDto(await Api.instance.admin.getCoinSettings());
      } catch (_) {}
      _changed();
    }
    return err;
  }

  /// The server call of the last [saveRule] (null offline); resolves to the
  /// error text when the backend refused it.
  Future<String?>? ruleSync;

  String? saveRule(CoinRule draft, {String? existingId}) {
    ruleSync = null;
    if (draft.name.trim().isEmpty || draft.spend <= 0 || draft.coins <= 0) {
      return 'Add a name, spend amount and coin payout';
    }
    if (draft.expires.isNotEmpty &&
        draft.starts.isNotEmpty &&
        draft.expires.compareTo(draft.starts) < 0) {
      return 'The rule end date must be after its start date';
    }
    draft.name = draft.name.trim();
    draft.mode = draft.mode == 'slab' ? 'slab' : 'pro-rata';
    draft.everGreen = draft.starts.isEmpty && draft.expires.isEmpty;
    draft.scope = 'All items';
    if (existingId != null) {
      final idx = coinRules.indexWhere((r) => r.id == existingId);
      if (idx >= 0) {
        draft.id = existingId;
        coinRules[idx] = draft;
        _changed();
        if (backendMode) ruleSync = _apiSaveRule(draft);
        return null;
      }
    }
    draft.id = 'rule-${istNow().millisecondsSinceEpoch.toRadixString(36)}';
    coinRules.add(draft);
    _changed();
    if (backendMode) ruleSync = _apiSaveRule(draft);
    return null;
  }

  void toggleRule(String id) {
    final idx = coinRules.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    coinRules[idx].active = !coinRules[idx].active;
    _changed();
    // Backend mode: persist the active flag (upsert resolves by rule id).
    if (backendMode) unawaited(_apiSaveRule(coinRules[idx]));
  }

  /// Only one coin rule may be on at a time (product-owner rule; the server
  /// does not enforce it). Switches every other rule off and persists that.
  Future<void> deactivateOtherRules(String? keepId) async {
    final others =
        coinRules.where((r) => r.active && r.id != keepId).toList();
    if (others.isEmpty) return;
    for (final r in others) {
      r.active = false;
    }
    _changed();
    if (backendMode) {
      for (final r in others) {
        await _apiSaveRule(r);
      }
    }
  }

  String? saveCoupon(Coupon draft, {String? existingCode}) {
    final code = draft.code.trim().toUpperCase().replaceAll(' ', '');
    if (!RegExp(r'^[A-Z0-9]{3,16}$').hasMatch(code)) {
      return 'Use 3–16 letters or numbers for the coupon code';
    }
    final dup = coupons.any((c) => c.code == code && c.code != existingCode);
    if (dup) return 'That coupon code already exists';
    if (draft.value <= 0 || (draft.type == 'percent' && draft.value > 100)) {
      return 'Enter a valid discount value';
    }
    if (draft.expires.isNotEmpty &&
        draft.starts.isNotEmpty &&
        draft.expires.compareTo(draft.starts) < 0) {
      return 'The coupon end date must be after its start date';
    }
    var maxUses = draft.maxUses.round();
    // Blank / 0 = unlimited (the backend's `totalLimit: 0`), kept as the
    // model's 999999 stand-in and sent back as 0.
    if (maxUses < 1 || maxUses >= 999999) maxUses = 999999;
    var min = draft.min.round();
    if (min < 0) min = 0;
    // Normalise the scope: an explicit list wins, otherwise the single picked
    // scope becomes a one-entry list, and "all"/empty becomes an empty list —
    // which is exactly what the backend stores as "every category".
    final ids = <String>[];
    for (final id in draft.categoryIds) {
      final s = id.trim();
      if (s.isEmpty || s == 'all' || ids.contains(s)) continue;
      ids.add(s);
    }
    if (ids.isEmpty &&
        draft.scope.isNotEmpty &&
        draft.scope != 'all' &&
        draft.scope != 'All items') {
      ids.add(draft.scope.trim());
    }
    final scope = ids.isNotEmpty ? ids.first : 'all';
    final scopeText = scopeLabelOf(ids);
    final desc = draft.type == 'flat'
        ? '₹${draft.value} off on orders above ₹$min'
        : '${draft.value}% off $scopeText${draft.maxDiscount != null && draft.maxDiscount! > 0 ? ' · max ₹${draft.maxDiscount}' : ''}';
    final clean = Coupon(
      code: code,
      desc: desc,
      type: draft.type,
      value: draft.value,
      maxDiscount: draft.type == 'percent' &&
              draft.maxDiscount != null &&
              draft.maxDiscount! > 0
          ? draft.maxDiscount
          : null,
      min: min,
      scope: scope,
      categoryIds: List<String>.of(ids),
      active: draft.active,
      starts: draft.starts,
      expires: draft.expires,
      uses: draft.uses,
      maxUses: maxUses,
      worksWithCoins: draft.worksWithCoins,
      firstOrderOnly: draft.firstOrderOnly,
      productIds: List<String>.of(draft.productIds),
      productGroupIds: List<String>.of(draft.productGroupIds),
      itemNames: draft.itemNames,
      appliesText: draft.appliesText,
    );
    if (existingCode != null) {
      final idx = coupons.indexWhere((c) => c.code == existingCode);
      if (idx >= 0) {
        coupons[idx] = clean;
        _changed();
        if (backendMode) {
          ApiException.clearFields();
          unawaited(couponSync = _apiSaveCoupon(clean));
        }
        return null;
      }
    }
    coupons.add(clean);
    _changed();
    if (backendMode) {
      ApiException.clearFields();
      unawaited(couponSync = _apiSaveCoupon(clean));
    }
    return null;
  }

  void toggleCoupon(String code) {
    final idx = coupons.indexWhere((c) => c.code == code);
    if (idx < 0) return;
    coupons[idx].active = !coupons[idx].active;
    _changed();
    // Backend mode: persist the active flag (upsert resolves by coupon code).
    if (backendMode) unawaited(_apiSaveCoupon(coupons[idx]));
  }

  String? saveHotSale({
    required bool live,
    required String eyebrow,
    required String title,
    required String starts,
    required String ends,
  }) {
    if (title.trim().isEmpty) return 'Add a headline for the sale banner';
    if (ends.compareTo(starts) < 0) {
      return 'The sale end date must be after the start date';
    }
    hotSale = hotSale.copyWith(
      live: live,
      eyebrow: eyebrow.trim().isEmpty ? 'HOT SALE' : eyebrow.trim(),
      title: title.trim(),
      starts: starts,
      ends: ends,
    );
    _changed();
    // Backend mode: upsert the hot banner row (`POST`/`PUT /admin/hot-banners`).
    if (backendMode) {
      unawaited(_apiSaveHotSale(
        live: live,
        title: hotSale.title,
        starts: starts,
        ends: ends,
      ));
    }
    return null;
  }

  /// Per-sale save used by the Hot sale screen: the window is an exact
  /// India date-time (not whole days). Awaits the banner write and returns an
  /// error message or null.
  Future<String?> saveHotSaleWindow({
    required bool live,
    required String title,
    required DateTime? startIst,
    required DateTime? endIst,
  }) async {
    if (title.trim().isEmpty) return 'Add a headline for the sale banner';
    if (title.trim().length > 200) {
      return 'The banner headline can be at most 200 characters';
    }
    if (startIst != null && endIst != null && endIst.isBefore(startIst)) {
      return 'The sale end must be after the start';
    }
    String day(DateTime? d) => d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String? iso(DateTime? d) => d == null
        ? null
        : d
            .subtract(const Duration(hours: 5, minutes: 30))
            .toIso8601String()
            .replaceFirst(RegExp(r'\.\d+'), '');
    hotSale = hotSale.copyWith(
        live: live, title: title.trim(), starts: day(startIst), ends: day(endIst));
    _changed();
    if (!backendMode) return null;
    apiLastError = null;
    await _apiSaveHotSale(
      live: live,
      title: title.trim(),
      starts: day(startIst),
      ends: day(endIst),
      startIso: iso(startIst),
      endIso: iso(endIst),
      exact: true,
    );
    return apiLastError;
  }

  void addFeatured(String productId) {
    final p = productById(productId);
    if (p == null) return;
    if (hotSale.featured.contains(productId)) return;
    hotSale = hotSale.copyWith(featured: [...hotSale.featured, productId]);
    // The backend's hot flag lives on each product row — keep it in sync.
    p.hotSale = true;
    _changed();
    if (backendMode && p.variants.any((v) => v.backendId != null)) {
      unawaited(_apiSaveProduct(p));
    }
  }

  void removeFeatured(String productId) {
    hotSale = hotSale.copyWith(
        featured: hotSale.featured.where((id) => id != productId).toList());
    final p = productById(productId);
    if (p != null) {
      p.hotSale = false;
      if (backendMode && p.variants.any((v) => v.backendId != null)) {
        unawaited(_apiSaveProduct(p));
      }
    }
    _changed();
  }

  // -------------------------------------------------------------------------
  // Backend integration (email-OTP auth + admin data via /api/v1)
  //
  // The app keeps its synchronous in-memory model so every existing screen
  // renders unchanged. When a real JWT is present (`backendMode`), admin reads
  // hydrate the same lists from the backend and the key mutations persist to
  // the backend in the background, then re-sync from the server.
  // -------------------------------------------------------------------------

  /// The last sign-in API failure (for 429 retry time, SMS_NOT_CONFIGURED
  /// and per-field highlighting). Null after a success.
  ApiException? lastAuthError;

  /// Sign-in: send an email OTP. Returns an error message or null on success.
  Future<String?> sendOtp(String email) async {
    final clean = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(clean)) {
      return 'Enter a valid email address';
    }
    lastAuthError = null;
    ApiException.clearFields();
    try {
      await Api.instance.auth.sendOtp(clean);
      apiLastError = null;
      return null;
    } on ApiException catch (e) {
      lastAuthError = e;
      return e.authMessage;
    } catch (_) {
      return 'Could not send the code. Check your connection.';
    }
  }

  /// Sign-in: verify the email OTP, store the JWT, and adopt the user.
  /// Returns an error message or null on success.
  Future<String?> verifyOtpSignIn(String email, String otp) async {
    lastAuthError = null;
    ApiException.clearFields();
    try {
      final result = await Api.instance.auth.verifyOtp(email, otp);
      await applyAuth(result, freshSignIn: true);
      return null;
    } on ApiException catch (e) {
      lastAuthError = e;
      return e.authMessage;
    } catch (_) {
      return 'Could not verify the code.';
    }
  }

  /// Sign-in: send an OTP to a mobile number (`POST /auth/otp/send-mobile`).
  /// Returns an error message or null on success. Until the backend has an
  /// SMS provider this returns the server's `SMS_NOT_CONFIGURED` message.
  Future<String?> sendMobileOtpSignIn(String mobile) async {
    final clean = mobile.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return 'Enter a 10-digit mobile number';
    }
    lastAuthError = null;
    ApiException.clearFields();
    try {
      await Api.instance.auth.sendMobileOtp(clean);
      apiLastError = null;
      return null;
    } on ApiException catch (e) {
      lastAuthError = e;
      return e.authMessage;
    } catch (_) {
      return 'Could not send the code. Check your connection.';
    }
  }

  /// Sign-in: verify the mobile OTP (`POST /auth/otp/verify-mobile`). A
  /// counter customer with the same number is claimed on first login, so
  /// coins earned at the counter carry over. Returns an error or null.
  Future<String?> verifyMobileOtpSignIn(String mobile, String otp) async {
    lastAuthError = null;
    ApiException.clearFields();
    try {
      final result = await Api.instance.auth.verifyMobileOtp(mobile, otp);
      await applyAuth(result, freshSignIn: true);
      return null;
    } on ApiException catch (e) {
      lastAuthError = e;
      return e.authMessage;
    } catch (_) {
      return 'Could not verify the code.';
    }
  }

  /// Adopt a backend auth result into the local session fields.
  ///
  /// [freshSignIn] is true only for a completed OTP sign-in (not for the
  /// `GET /me` restore at boot) — that is what opens the first-time setup.
  Future<void> applyAuth(AuthResultDto result, {bool freshSignIn = false}) async {
    final u = result.user;
    // The response is authoritative for *this* session: adopt it wholesale.
    // Filling only when present would leak the previous account's name and
    // mobile into a brand-new profile (seen as "Shop Admin" pre-filled on a
    // fresh sign-up straight after an admin session).
    userName = (u?.name ?? '').trim();
    userPhone = (u?.mobile ?? '').trim();
    userEmail = u?.email;
    userRole = u?.role;
    signedIn = true;
    isAdmin = u?.isAdmin ?? false;
    adminSignedIn = isAdmin; // admin area requires the backend ADMIN role
    // First-time login: a fresh sign-in to a still-bare profile — no name
    // and/or no mobile — means a brand-new customer, routed to `#/setup`
    // once. The flag is memory-only (localStorage stays JWT-only), so a
    // completed profile is never nagged again.
    needsProfileSetup = freshSignIn &&
        ApiConfig.isLive &&
        !isAdmin &&
        (userName.isEmpty || userPhone.isEmpty);
    apiLastError = null;
    _changed();
    // A guest basket already on this device becomes part of the account's
    // basket (union by quantity, never summed), and from here the account —
    // not the device — owns it. Skipped automatically when the basket has
    // not been restored yet; `_applyPendingCart` then does the first sync.
    unawaited(_mergeCartOnSignIn());
    // A **fresh** sign-in hydrates from the backend: an admin pulls the
    // panel data (previously a fresh admin sign-in loaded nothing — the
    // panel only filled in after a page refresh), a customer or counter
    // staff the storefront. A restored session bootstraps itself in
    // `bootstrapFromSession`, and both paths start the live order feed when
    // they finish.
    if (freshSignIn) {
      unawaited(isAdmin ? bootstrapAdmin() : bootstrapCustomer());
    }
  }

  // -------------------------------------------------------------------------
  // Customer bootstrap + refresh (storefront, wallet, orders, addresses)
  // -------------------------------------------------------------------------

  /// Load every customer collection from the backend: catalog, hot sale,
  /// wallet, addresses, orders, payment methods.
  Future<void> bootstrapCustomer() async {
    if (!backendMode || isBackendAdmin) return;
    try {
      apiLastError = null;

      // Categories
      categories =
          categoriesFromDtos(await Api.instance.catalog.getCategories());

      // Units of measure (public endpoint) — used by the product editor and
      // to keep `product.unit` a real unit code.
      await refreshUnits();

      // Products (public rows grouped by pack -> product cards)
      final packs = <PublicProductDto>[];
      var page = 0;
      var total = 1;
      while (packs.length < total && page < 60) {
        final p = await Api.instance.catalog.getProducts(page: page, size: 50);
        packs.addAll(p.items);
        total = p.hasMore == false ? packs.length : p.total;
        page++;
        if (p.items.isEmpty) break;
      }
      products = productsFromPublic(packs);
      packIndex = buildPackIndex(products);

      // Offers first: the basket waiting below may already carry a coupon
      // code, and it should price against the real rules immediately.
      await loadPublicOffers();

      // Restore the basket now that products/stock are known. A signed-in
      // session takes the server's copy (it follows the customer across
      // devices); a guest keeps this device's copy.
      await _applyPendingCart();

      // Hot sale (banners + featured products merged into the catalog)
      try {
        hotSale = hotSaleFromPublicDto(
            await Api.instance.catalog.getHotSale(), products);
      } on ApiException {
        // Hot-sale is decorative; don't fail the whole bootstrap for it.
      }

      // Store card (name / phone / address / promise). The customer screens
      // render `seed.store`, so without this a signed-in customer saw the
      // hardcoded prototype address until a `catalog`/`SHOP` live event
      // happened to arrive.
      await _refreshShopQuiet();

      // Wallet + ledger
      await refreshWallet();

      // Addresses + orders + payment methods + wishlist + inbox
      await refreshAddresses();
      // Counter staff work the *shop's* orders: `/orders` would only return
      // orders this staff account happened to place itself, so they read the
      // same admin list the Orders screen uses (backend opens
      // `/admin/orders/**` to CASHIER too).
      if (isBackendStaff) {
        await refreshAdminOrders();
      } else {
        await refreshCustomerOrders();
      }
      try {
        paymentMethods = await Api.instance.wallet.getPaymentMethods();
      } on ApiException {
        paymentMethods = [];
      }
      await loadWishlist();
      await loadInbox(force: true);
      // Udhar balance/limit for the wallet screen (read-only; own errors).
      if (!isBackendStaff) await refreshCredit();

      // The restored device basket was adopted above (a live build never
      // seeds one, so there is nothing else to reconcile here).
      signedIn = true;
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      apiLastError = 'Could not load data from the server.';
      _changed();
    }
    // Live order feed (SSE): starts even when a section failed, so status
    // changes still reach the screen — and its `ready` handshake re-reads
    // the order list the bootstrap may have missed.
    _startLiveOrders();
  }

  /// Refresh the wallet balance + ledger from `/wallet` and `/wallet/ledger`.
  Future<void> refreshWallet() async {
    if (!backendMode) return;
    try {
      final wallet = await Api.instance.wallet.getWallet();
      walletCoins = wallet.coins;
      walletValuePaise = wallet.valuePaise;
      walletLoaded = true;
      coinSettings = walletSettingsFromDto(wallet);
      // A customer's earn rules are the live ones `GET /wallet` lists (the
      // admin rule list is ADMIN only).
      if (!isBackendStaff) coinRules = coinRulesFromDtos(wallet.rules);
      // Newest first; follow `hasMore` (bounded) instead of stopping at 50.
      final rows = <LedgerViewDto>[];
      for (var pg = 0; pg < 10; pg++) {
        final r = await Api.instance.wallet.getLedger(page: pg, size: 50);
        rows.addAll(r.items);
        if (!(r.hasMore ?? rows.length < r.total) || r.items.isEmpty) break;
      }
      ledger = ledgerFromDtos(rows);
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep whatever we had.
    }
  }

  /// Refresh the customer's credit account + ledger from `/credit` and
  /// `/credit/ledger`. The live stream's `credit` event calls this so an
  /// udhar change at the counter shows up without a refresh.
  Future<void> refreshCredit() async {
    if (!backendMode) return;
    try {
      creditAccount = await Api.instance.credit.getAccount();
      creditLedger = (await Api.instance.credit.getLedger()).items;
      creditLoaded = true;
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep whatever we had.
    }
  }

  /// Refresh the customer's addresses from `/me/addresses`.
  Future<void> refreshAddresses() async {
    if (!backendMode) return;
    try {
      addresses = addressesFromDtos(await Api.instance.auth.addresses());
      if (flow.selectedAddressId.isEmpty ||
          !addresses.any((a) => a.id == flow.selectedAddressId)) {
        flow.selectedAddressId = addresses.isEmpty ? '' : addresses.first.id;
      }
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep the local list.
    }
  }

  // --- order list paging ("Load more") ------------------------------------

  /// Next server page to fetch (page 0 is always the refresh) and the
  /// server's total; rows from later pages are summary-only.
  int ordersNextPage = 1;
  int ordersServerTotal = 0;
  bool ordersLoadingMore = false;
  List<Order> _extraOrders = [];

  /// More orders exist on the server than are loaded.
  bool get canLoadMoreOrders =>
      backendMode && orders.length < ordersServerTotal && !ordersLoadingMore;

  /// Keeps already-loaded extra pages across a page-0 refresh.
  void _mergeExtraOrders(List<Order> views) {
    if (_extraOrders.isEmpty) {
      ordersNextPage = 1;
      return;
    }
    final seen = {for (final o in views) o.number};
    _extraOrders = _extraOrders.where((o) => !seen.contains(o.number)).toList();
    views.addAll(_extraOrders);
  }

  /// Loads the next page of the customer's own orders.
  Future<void> loadMoreCustomerOrders() async {
    if (!canLoadMoreOrders) return;
    ordersLoadingMore = true;
    _changed();
    try {
      final p = await Api.instance.orders
          .listOrders(page: ordersNextPage, size: 50);
      final have = {for (final o in orders) o.number};
      for (final s in p.items) {
        orderIdsByNo[s.orderNo ?? s.id ?? ''] = s.id ?? '';
        final o = customerOrderFromSummary(s, packIndex);
        if (have.add(o.number)) {
          orders.add(o);
          _extraOrders.add(o);
        }
      }
      ordersServerTotal = p.total;
      ordersNextPage++;
      if (p.items.isEmpty) ordersServerTotal = orders.length;
      if (p.hasMore == false) ordersServerTotal = orders.length;
    } on ApiException catch (e) {
      apiLastError = e.message;
    } catch (_) {}
    ordersLoadingMore = false;
    _changed();
  }

  /// Loads the next page of the admin order list (honours the search term).
  Future<void> loadMoreAdminOrders() async {
    if (!canLoadMoreOrders) return;
    ordersLoadingMore = true;
    _changed();
    try {
      final q = adminOrderQuery;
      final p = await Api.instance.admin.listOrders(
        page: ordersNextPage,
        size: 50,
        q: q.isEmpty ? null : q,
        status: adminOrderStatus.isEmpty ? null : statusToWire(adminOrderStatus),
      );
      final have = {for (final o in orders) o.number};
      for (final s in p.items) {
        orderIdsByNo[s.orderNo ?? s.id ?? ''] = s.id ?? '';
        final o = orderFromSummary(s, packIndex);
        if (have.add(o.number)) {
          orders.add(o);
          _extraOrders.add(o);
        }
      }
      ordersServerTotal = p.total;
      ordersNextPage++;
      if (p.items.isEmpty) ordersServerTotal = orders.length;
      if (p.hasMore == false) ordersServerTotal = orders.length;
    } on ApiException catch (e) {
      apiLastError = e.message;
    } catch (_) {}
    ordersLoadingMore = false;
    _changed();
  }

  /// Refresh the customer's orders from `/orders` (paged summary list).
  Future<void> refreshCustomerOrders() async {
    if (!backendMode) return;
    try {
      final p = await Api.instance.orders.listOrders(page: 0, size: 50);
      orderIdsByNo = orderIdsFromSummaries(p.items);
      // Summaries carry no line items; fetch the full view for each order so
      // the order-detail screen can render items. Cap to the newest 20.
      final views = <Order>[];
      int? balance;
      var stopFetching = _ordersBackingOff;
      for (final s in p.items.take(20)) {
        final id = s.id;
        if (id == null) continue;
        final key = '${s.status}|${s.totalPaise}';
        final hit = _orderDetailCache[id];
        if (hit != null && hit.key == key) {
          views.add(hit.order);
          continue;
        }
        if (stopFetching) {
          views.add(hit?.order ?? customerOrderFromSummary(s, packIndex));
          continue;
        }
        try {
          final v = await Api.instance.orders.getOrder(id);
          orderIdsByNo[v.orderNo ?? v.id ?? ''] = v.id ?? id;
          final full = orderFromView(v, packIndex);
          _orderDetailCache[id] = (key: key, order: full);
          views.add(full);
          // The backend returns the customer's coin balance with each order
          // row — adopt it (newest first) so coins never look stale.
          balance ??= v.coinBalance;
        } on ApiException catch (e) {
          _noteRateLimited(e);
          if (e.statusCode == 429) stopFetching = true;
          views.add(hit?.order ?? customerOrderFromSummary(s, packIndex));
        }
      }
      // Older orders beyond the cap keep the summary-only row.
      for (final s in p.items.skip(20)) {
        views.add(customerOrderFromSummary(s, packIndex));
      }
      ordersServerTotal = p.hasMore == false ? views.length : p.total;
      _mergeExtraOrders(views);
      _carryCancelReasons(views);
      orders = views;
      if (balance != null) {
        walletCoins = balance;
        walletLoaded = true;
      }
      _ordersSyncedAt = istNow();
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep the local list.
    }
  }

  /// Keep a store's cancellation remark across a list refresh.
  ///
  /// The backend only returns `cancelReason` on the **full** order view; the
  /// summary rows behind it (used for anything past the newest-20 cap, and
  /// for any detail fetch that failed) carry no such field, so a plain
  /// re-read used to blank the remark the customer is meant to read.
  void _carryCancelReasons(List<Order> fresh) {
    for (final o in fresh) {
      if (o.status != 'Cancelled' || o.cancelReason.isNotEmpty) continue;
      for (final old in orders) {
        if (old.number == o.number && old.cancelReason.isNotEmpty) {
          o.cancelReason = old.cancelReason;
          break;
        }
      }
    }
  }

  // --- customer background persistence -------------------------------------

  /// Guest browsing: pull the public catalog (categories, products, hot sale)
  /// without a JWT. Called on app start so signed-out visitors see live data;
  /// signed-in sessions go through [bootstrapCustomer] instead.
  Future<void> bootstrapGuest() async {
    if (backendMode) return;
    try {
      categories =
          categoriesFromDtos(await Api.instance.catalog.getCategories());

      final packs = <PublicProductDto>[];
      var page = 0;
      var total = 1;
      while (packs.length < total && page < 60) {
        final p = await Api.instance.catalog.getProducts(page: page, size: 50);
        packs.addAll(p.items);
        total = p.hasMore == false ? packs.length : p.total;
        page++;
        if (p.items.isEmpty) break;
      }
      products = productsFromPublic(packs);
      packIndex = buildPackIndex(products);

      // Public offers first so a restored coupon code can price straight away.
      await loadPublicOffers();

      // Store card: a signed-out visitor sees the same name/phone/address as
      // a signed-in one, not the prototype's hardcoded locality.
      await _refreshShopQuiet();

      // Restore this device's basket now that products/stock are known (a
      // guest has no account basket to read, so this is local-only).
      await _applyPendingCart();

      try {
        hotSale = hotSaleFromPublicDto(
            await Api.instance.catalog.getHotSale(), products);
      } on ApiException {
        // Hot-sale is decorative; don't fail the whole preload for it.
      }
      _changed();
    } catch (_) {
      // No fallback catalogue: a live build starts empty, so an unreachable
      // backend just leaves the shelves blank (the error surfaces through
      // the loaders that do report `apiLastError`).
    }
  }

  // --- admin stock movements + period report -------------------------------

  /// `GET /admin/stock-movements` — the newest pages of signed stock
  /// movements (positive = in, negative = sold). Powers the stock report.
  Future<void> loadStockMovements({int maxRows = 400}) async {
    if (!backendMode) return;
    try {
      final out = <StockMovementDto>[];
      var page = 0;
      var total = 1;
      const size = 50;
      while (out.length < total && out.length < maxRows && page < 10) {
        final p = await Api.instance.admin.stockMovements(page: page, size: size);
        out.addAll(p.items);
        total = p.hasMore == false ? out.length : p.total;
        page++;
        if (p.items.isEmpty) break;
      }
      adminStockMoves = out;
      _changed();
    } on ApiException {
      // The stock report falls back to local demo data.
    } catch (_) {
      // Best-effort.
    }
  }

  /// FAILED refunds waiting for a person (`GET /admin/refunds?status=FAILED`)
  /// and start-up settings that are UNSAFE or MISSING (`/admin/config/bootstrap`);
  /// the admin home shows a banner for each (20 guide: refunds / config badge).
  int failedRefunds = 0;
  int configProblems = 0;

  Future<void> refreshAdminOpsAlerts() async {
    if (!backendMode || !isBackendAdmin) return;
    try {
      failedRefunds =
          (await Api.instance.ops.listRefunds(status: 'FAILED', size: 1)).total;
    } catch (_) {}
    try {
      configProblems = (await Api.instance.ops.getBootstrap())
          .where((b) => b.needsAction)
          .length;
    } catch (_) {}
    _changed();
  }

  /// Server summaries for the "Today", "last 30 days" and "last 12 months"
  /// figures (counter bills included); null until they load.
  ReportSummaryDto? adminReportToday;
  ReportSummaryDto? adminReportMonth;
  ReportSummaryDto? adminReportYear;

  static String _ymdIst(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Loads the three range summaries the Reports screen shows next to the
  /// period figures (`from`/`to` are `yyyy-MM-dd`, at most 366 days).
  Future<void> loadReportExtras() async {
    if (!backendMode) return;
    final now = istNow();
    final today = _ymdIst(now);
    try {
      final r = await Future.wait([
        Api.instance.admin.reportSummary(from: today, to: today),
        Api.instance.admin.reportSummary(period: 'month'),
        Api.instance.admin.reportSummary(
            from: _ymdIst(now.subtract(const Duration(days: 364))), to: today),
      ]);
      adminReportToday = r[0];
      adminReportMonth = r[1];
      adminReportYear = r[2];
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
    } catch (_) {
      // Keep the local figures.
    }
  }

  /// `GET /admin/reports/summary?period=` — orders (and any aggregates) for
  /// the requested period; used by the reports screen.
  Future<void> loadReportSummary(String period) async {
    if (!backendMode) return;
    try {
      final r = await Api.instance.admin.reportSummary(period: period);
      adminReport = r;
      adminReportPeriod = period;
      adminReportLoaded = true;
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      adminReportLoaded = false;
      _changed();
    } catch (_) {
      adminReportLoaded = false;
    }
  }

  /// `POST /cart/quote` for the current cart — surfaces server warnings
  /// (coupon not applicable, `worksWithCoins: false`, coins above cap, …)
  /// in checkout before the order is placed.
  Future<void> refreshCartQuoteWarnings({bool retried = false}) async {
    if (!backendMode || cartItems.isEmpty) {
      if (cartQuoteWarnings.isNotEmpty) cartQuoteWarnings = [];
      cartQuoteTotalPaise = null;
      return;
    }
    final seq = ++_quoteSeq;
    final sentCoupon = cartCoupon;
    try {
      final items = _serverCartItems();
      if (items.isEmpty) return;
      final q = await Api.instance.orders.quote(
        items: items,
        couponCode: sentCoupon.isEmpty ? null : sentCoupon,
        coinMode: _wireCoinMode(),
        percent: _wireCoinPercent(),
        fulfilment: fulfilToWire(flow.checkoutMode),
      );
      // A newer basket change (or coupon change) superseded this answer.
      if (seq != _quoteSeq || sentCoupon != cartCoupon) return;
      cartQuoteWarnings = q.warnings;
      cartSaleSplit = _saleSplitOf(q);
      cartQuoteText = {
        for (final l in q.lines)
          if (l.productId != null)
            l.productId!: ((l.nameGu ?? '').trim(), (l.unitLabel ?? '').trim())
      };
      cartQuoteTotalPaise = q.totalPaise;
      cartQuoteDeliveryPaise = q.deliveryFeePaise;

      if (sentCoupon.isNotEmpty) {
        final accepted = q.couponCode?.trim().toUpperCase();
        if (accepted != sentCoupon) {
          // Server no longer honours the code for this basket.
          _dropCouponWithMessage(
              'Coupon $sentCoupon was removed: it does not apply to the items in your cart.');
          return;
        }
        // Keep the adopted row in step with the server (amount + the
        // categories actually discounted). A browsed public row carries the
        // real rules, so it is left in charge.
        if (!coupons.any((c) => c.code == sentCoupon)) {
          final coinsBlocked = q.warnings
              .any((w) => w.startsWith('Coins cannot be used together'));
          _adoptCouponRow(
            code: sentCoupon,
            paise: q.couponDiscountPaise,
            desc: _adoptedCoupon?.desc ?? 'Applied at checkout',
            // A warning is authoritative "no"; without one we keep what we had.
            worksWithCoins:
                coinsBlocked ? false : (_adoptedCoupon?.worksWithCoins ?? true),
            categoryIds: _quoteCouponCategories(q),
          );
        }
      }
      _changed();
    } on ApiException catch (e) {
      if (e.code == 'COUPON_INVALID') {
        if (seq != _quoteSeq || sentCoupon != cartCoupon) return;
        // The code stopped being usable for this basket (wrong category,
        // expired, min order, limit, …): remove it and say why.
        _dropCouponWithMessage(
            'Coupon $sentCoupon removed. ${_couponInvalidMessage(e)}');
        return;
      }
      if (e.code == 'QTY_EXCEEDS_LOT_PRICE') {
        if (seq != _quoteSeq) return;
        _applyLotCap(e);
        return;
      }
      // One saved line was deactivated: the server refuses the whole basket
      // (`product is not available: ID`). Remove that line, say so, retry.
      if (e.statusCode == 400 && !retried && _dropUnavailableLines(e.message)) {
        await refreshCartQuoteWarnings(retried: true);
        return;
      }
      // No warnings to show.
    } catch (_) {
      // Best-effort.
    }
  }

  /// Per-pack cap from a 422 `QTY_EXCEEDS_LOT_PRICE` (guide 74 s4, P5 s6):
  /// key `productId|variantIndex` -> (max units at the current lot price,
  /// when it was learned). The stepper stops at the cap; the cap is dropped
  /// after two minutes or when a catalog event says prices moved.
  final Map<String, (int, DateTime)> cartLotCap = {};

  /// Highest quantity the stepper may reach for a cart row, or null.
  int? lotCapFor(String productId, int variantIndex) {
    final c = cartLotCap['$productId|$variantIndex'];
    if (c == null) return null;
    if (DateTime.now().difference(c.$2) > const Duration(minutes: 2)) {
      cartLotCap.remove('$productId|$variantIndex');
      return null;
    }
    return c.$1;
  }

  /// Reads `details.items[{productId,maxQty}]` of a 422 `QTY_EXCEEDS_LOT_PRICE`,
  /// clamps the named basket rows to `maxQty`, remembers the cap for the
  /// stepper and shows the server's message. Returns that message.
  String _applyLotCap(ApiException e) {
    final d = e.details;
    final items = <Map>[
      if (d != null && d['items'] is List) ...(d['items'] as List).whereType<Map>(),
    ];
    for (final it in items) {
      final ref = packIndex['${it['productId']}'];
      final max = (it['maxQty'] as num?)?.toInt();
      if (ref == null || max == null) continue;
      cartLotCap['${ref.product.id}|${ref.variantIndex}'] = (max, DateTime.now());
      final li = cartItems.indexWhere((c) =>
          c.productId == ref.product.id && c.variantIndex == ref.variantIndex);
      if (li < 0 || cartItems[li].qty <= max) continue;
      if (max < 1) {
        cartItems.removeAt(li);
      } else {
        cartItems[li] = CartItem(
            productId: ref.product.id, variantIndex: ref.variantIndex, qty: max);
      }
    }
    cartQuoteWarnings = [e.message];
    apiLastError = e.message;
    _cartChanged();
    return e.message;
  }

  /// Server quote (total and delivery fee) last answered for the basket;
  /// null until one arrives. Shown at checkout next to the local bill.
  int? cartQuoteTotalPaise;
  int cartQuoteDeliveryPaise = 0;

  /// Per product id: (units at the flash-sale price, units in the basket) from
  /// the last quote, for the "1 of 3 at sale price" note on a cart line.
  Map<String, (int, int)> cartSaleSplit = const {};

  /// Per pack id: (Gujarati name, pack label) from the last quote lines
  /// (`nameGu`, `unitLabel`); empty strings when the server sent none.
  Map<String, (String, String)> cartQuoteText = const {};

  Map<String, (int, int)> _saleSplitOf(QuoteDto q) {
    final out = <String, (int, int)>{};
    for (final l in q.lines) {
      final id = l.productId;
      if (id == null) continue;
      final cur = out[id] ?? (0, 0);
      out[id] = (
        cur.$1 + ((l.flashSaleId ?? '').isNotEmpty ? l.qty : 0),
        cur.$2 + l.qty
      );
    }
    return out;
  }

  /// Removes basket lines named in a 400 "product is not available: <id>"
  /// answer and tells the customer which items went. False if none matched.
  bool _dropUnavailableLines(String message) {
    final ids = RegExp(
            r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
        .allMatches(message)
        .map((m) => m.group(0)!.toLowerCase())
        .toSet();
    if (ids.isEmpty || !message.toLowerCase().contains('not available')) {
      return false;
    }
    final names = <String>[];
    cartItems.removeWhere((it) {
      final p = productById(it.productId);
      final id = (p != null && it.variantIndex >= 0 && it.variantIndex < p.variants.length)
          ? p.variants[it.variantIndex].backendId?.toLowerCase()
          : null;
      if (id == null || !ids.contains(id)) return false;
      names.add(p!.name);
      return true;
    });
    if (names.isEmpty) return false;
    apiLastError = '${names.join(', ')} ${gt('is no longer available and was removed from your basket.')}';
    _cartChanged(requote: false);
    return true;
  }

  /// The `OrderView` `POST /orders` just answered with (carries the
  /// Razorpay `paymentSession` for ONLINE orders).
  AdminViewDto? _lastPlacedView;

  /// Quote total the customer was already told about after a flash offer
  /// changed under them; the next attempt at that same total goes through.
  int? _priceAckPaise;

  /// `POST /orders` with the current cart — the server-side half of checkout.
  ///
  /// Returns the backend's error message when the request is rejected, or the
  /// ids of the created order when it is accepted. No local state is touched
  /// here: the caller decides when to commit.
  Future<({String? error, String? orderNo, String? id})> _placeOrderOnServer(
      CartTotals totals) async {
    try {
      final items = <Map<String, dynamic>>[];
      for (final it in totals.details) {
        final packId = it.v.backendId;
        if (packId == null || packId.isEmpty) continue;
        items.add({'productId': packId, 'qty': it.qty});
      }
      // `POST /cart/quote` and `POST /orders` accept 1..99 per line (the
      // saved basket allows more, the quote does not).
      if (items.any((i) => (i['qty'] as int) > 99)) {
        return (
          error: 'You can order at most 99 of one item at a time.',
          orderNo: null,
          id: null,
        );
      }
      if (items.isEmpty) {
        return (
          error: 'These items are not available to order online.',
          orderNo: null,
          id: null,
        );
      }

      final payMethod = _wirePaymentMethod;
      final wireCoinMode = !useCoins
          ? 'NONE'
          : coinMode == 'percent' || coinMode == 'custom'
              ? 'PERCENT'
              : 'ALL';
      final wirePercent = _wireCoinPercent();
      final wireFulfilment = fulfilToWire(flow.checkoutMode);

      // Pre-flight: server-side quote — authoritative totals + warnings
      // (invalid coupon, coins above cap, …). Falls back to the local total
      // if the quote call itself fails.
      var expectedTotalPaise = rupeesToPaise(totals.total);
      String? quoteWarnings;
      try {
        final q = await Api.instance.orders.quote(
          items: items,
          couponCode: cartCoupon.isNotEmpty ? cartCoupon : null,
          coinMode: wireCoinMode,
          percent: wirePercent,
          fulfilment: wireFulfilment,
        );
        // The price (or a flash offer) moved since the customer saw the cart:
        // the fresh quote, without the delivery fee the local total never
        // includes, is dearer than the total on screen. Say so once and let
        // the second tap, which sees the same quote, confirm it. A lower
        // total just proceeds.
        if (q.totalPaise - q.deliveryFeePaise > expectedTotalPaise &&
            _priceAckPaise != q.totalPaise) {
          _priceAckPaise = q.totalPaise;
          unawaited(refreshStorefrontQuiet());
          return (
            error: '${gt('The price changed - total is now')} '
                '${_rupeeText(q.totalPaise)}. '
                '${gt('Tap Place order again to confirm.')}',
            orderNo: null,
            id: null,
          );
        }
        expectedTotalPaise = q.totalPaise;
        if (q.warnings.isNotEmpty) quoteWarnings = q.warnings.join(' · ');
      } on ApiException catch (e) {
        if (e.code == 'COUPON_INVALID') {
          // Fail fast: the server rejected the coupon, so `POST /orders`
          // would reject it too. Stay on checkout and say exactly why.
          return (error: _couponInvalidMessage(e), orderNo: null, id: null);
        }
        // Quote unavailable → still attempt the order with the local total.
      } catch (_) {
        // Quote unavailable → still attempt the order with the local total.
      }

      // `ApiClient.post(idempotency: true)` keeps one Idempotency-Key per
      // identical request while the outcome is unknown (timeout / 5xx), so a
      // retry replays the same order instead of creating a second one.
      final dto = await Api.instance.orders.placeOrder(
          items: items,
          couponCode: cartCoupon.isNotEmpty ? cartCoupon : null,
          coinMode: wireCoinMode,
          percent: wirePercent,
          fulfilment: wireFulfilment,
          addressId:
              flow.checkoutMode == 'delivery' ? flow.selectedAddressId : null,
          paymentMethod: payMethod,
          expectedTotalPaise: expectedTotalPaise,
          slot: flow.checkoutMode == 'pickup' ? flow.selectedSlot : null,
      );
      orderIdsByNo[dto.orderNo ?? dto.id ?? ''] = dto.id ?? '';
      _priceAckPaise = null;
      _lastPlacedView = dto;
      // Server quote warnings (coupon not applicable, coins above cap, …):
      // the order itself went through with adjusted totals.
      if (quoteWarnings != null) apiLastError = quoteWarnings;
      return (error: null, orderNo: dto.orderNo, id: dto.id);
    } on ApiException catch (e) {
      checkoutFieldErrors = ApiException.takeFields();
      return (error: _placeOrderErrorText(e), orderNo: null, id: null);
    } catch (_) {
      return (
        error: 'Your order could not be sent to the store.',
        orderNo: null,
        id: null,
      );
    }
  }

  /// Customer-facing text for a rejected `POST /orders`, by the documented
  /// error `code` (PRICE_CHANGED, OUT_OF_STOCK, ORDERS_PAUSED, ...).
  String _placeOrderErrorText(ApiException e) {
    Map? details;
    final pl = e.payload;
    if (pl is Map && pl['details'] is Map) details = pl['details'] as Map;
    switch (e.code) {
      case 'PRICE_CHANGED':
        final q = details?['quote'];
        final total = q is Map ? (q['totalPaise'] as num?)?.toInt() : null;
        // 40 flash guide step 5: the quote in `details.quote` replaces the
        // cart's quote (new prices and sale split) and the next tap confirms
        // exactly that total.
        if (q is Map) {
          try {
            final fresh = QuoteDto.fromJson(Map<String, dynamic>.from(q));
            cartSaleSplit = _saleSplitOf(fresh);
            cartQuoteTotalPaise = fresh.totalPaise;
            cartQuoteDeliveryPaise = fresh.deliveryFeePaise;
            _priceAckPaise = fresh.totalPaise;
          } catch (_) {}
        }
        // Prices are re-read so the next attempt sends the new total; the
        // customer's next tap is the explicit confirmation (P1 5.4).
        if (total != null) _priceAckPaise = total;
        unawaited(refreshStorefrontQuiet());
        return total == null
            ? 'Prices changed. Please review your cart and place the order again.'
            : 'Prices changed - the total is now ${_rupeeText(total)}. '
                'Please review and place the order again.';
      case 'OUT_OF_STOCK':
        final items = details?['items'];
        final names = <String>[];
        if (items is List) {
          for (final it in items.whereType<Map>()) {
            final ref = packIndex[it['productId']?.toString() ?? ''];
            final left = (it['available'] as num?)?.toInt();
            final label = ref?.product.name ?? 'An item';
            names.add(left == null ? label : '$label ($left left)');
          }
        }
        unawaited(refreshStorefrontQuiet());
        return names.isEmpty
            ? 'Some items just ran out of stock. Please update your cart.'
            : 'Not enough stock: ${names.join(', ')}. Please update your cart.';
      case 'ORDERS_PAUSED':
        return e.message; // the shop's own text, shown as is
      case 'COUPON_INVALID':
        return _couponInvalidMessage(e);
      case 'QTY_EXCEEDS_LOT_PRICE':
        return _applyLotCap(e);
      case 'PAYMENT_NOT_CONFIGURED':
        return 'Online payment is not available yet. Please choose cash to place your order.';
      case 'PAYMENT_PROVIDER_ERROR':
        return 'Online payment could not be started. Please try again or choose cash.';
    }
    return e.message;
  }

  String _rupeeText(int paise) {
    final r = paise / 100;
    return 'Rs ${r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2)}';
  }

  /// Opens Razorpay Checkout for a `PAYMENT_PENDING` order and waits for the
  /// **server** to confirm it (the SDK callback is never proof of payment).
  ///
  /// Returns a message for the shopper when the payment is not (yet) done, or
  /// null once the order left `PAYMENT_PENDING`. Also backs the "Pay now"
  /// button on the order page, which reopens Checkout with the same session.
  Future<String?> payOrderOnline(String number) async {
    final id = orderIdsByNo[number];
    if (id == null || id.isEmpty) return 'Order not found.';
    try {
      var v = await Api.instance.orders.getOrder(id);
      if ((v.status ?? '').toUpperCase() != 'PAYMENT_PENDING') {
        await _refetchLiveOrder(id);
        return null;
      }
      final session = v.paymentSession;
      if (session == null || !session.usable) {
        await _refetchLiveOrder(id);
        return 'Payment expired or failed. This order will be cancelled if it is not paid in time.';
      }
      final outcome = await RazorpayCheckout.open(
        keyId: session.keyId,
        razorpayOrderId: session.razorpayOrderId,
        amountPaise: session.amountPaise,
        currency: session.currency,
        name: seed.store.name,
        prefillName: userName,
        prefillContact: userPhone,
      );
      if (outcome == RazorpayOutcome.unsupported) {
        return 'Online payment is not available on this device. Cancel the order and choose cash.';
      }
      if (outcome != RazorpayOutcome.success) {
        await _refetchLiveOrder(id);
        return 'Payment not completed. Open the order to try again or cancel it.';
      }
      // Confirming: poll every 3 s for ~90 s (the SSE `order` event usually
      // lands first and refreshes the same row).
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(seconds: 3));
        v = await Api.instance.orders.getOrder(id);
        if ((v.status ?? '').toUpperCase() != 'PAYMENT_PENDING') break;
      }
      await _refetchLiveOrder(id);
      if ((v.status ?? '').toUpperCase() == 'PAYMENT_PENDING') {
        return 'We are still confirming your payment. You will be notified; do not pay again.';
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not confirm the payment. Check My orders before paying again.';
    }
  }

  /// Re-syncs the order list + wallet after a server-side placement, keeping
  /// the local order number so the open `/placed/{number}` screen still
  /// resolves to the real order.
  Future<void> _syncPlacedOrder(
    String localNumber, {
    String? serverNo,
    String? serverId,
  }) async {
    try {
      await refreshCustomerOrders();
      await refreshWallet();
      if (serverNo != null && serverNo.isNotEmpty && serverNo != localNumber) {
        final idx = orders.indexWhere((o) => o.number == serverNo);
        if (idx >= 0) {
          orders[idx].number = localNumber;
          orderIdsByNo[localNumber] = serverId ?? '';
        }
      }
      _changed();
    } catch (_) {
      // Best-effort: the optimistic local row stays visible on failure.
    }
  }

  /// Background placement for the offline prototype when a backend session
  /// happens to be active. Live builds place synchronously inside
  /// [placeOrder] so validation errors reach the UI.
  Future<void> _apiPlaceCustomerOrder(
      CartTotals totals, String localNumber) async {
    final res = await _placeOrderOnServer(totals);
    if (res.error != null) {
      apiLastError = res.error;
      _changed();
      return;
    }
    await _syncPlacedOrder(localNumber,
        serverNo: res.orderNo, serverId: res.id);
  }

  /// `POST /orders/{id}/cancel` for a customer-owned order. Returns the
  /// failure to show, or null once the server accepted the cancellation.
  ///
  /// Like [_apiSetStatus] it mutates nothing: a 409 `ILLEGAL_TRANSITION`
  /// (the shop already started packing) or a dead backend comes back as a
  /// message, so the sheet can't report a cancel that never happened.
  /// `POST /admin/orders/{id}/reject` (reason 1..200 chars, required).
  Future<ApiException?> _apiRejectOrder(String number, String reason) async {
    final id = orderIdsByNo[number];
    if (id == null) return null;
    var why = reason.trim();
    if (why.isEmpty) why = 'Cancelled by the store';
    if (why.length > 200) why = why.substring(0, 200);
    try {
      await Api.instance.admin.rejectOrder(id, why);
    } on ApiException catch (e) {
      return e;
    } catch (_) {
      return const ApiException(
          0, 'Could not cancel the order. Check your connection and try again.');
    }
    return null;
  }

  Future<ApiException?> _apiCancelOrder(String number, String reason) async {
    final id = orderIdsByNo[number];
    if (id == null) return null;
    try {
      await Api.instance.orders.cancelOrder(id,
          reason: reason.trim().isEmpty
              ? null
              : (reason.trim().length > 200
                  ? reason.trim().substring(0, 200)
                  : reason.trim()));
    } on ApiException catch (e) {
      return e;
    } catch (_) {
      return const ApiException(
          0, 'Could not cancel the order. Check your connection and try again.');
    }
    unawaited(_resyncOrdersAfterMove(admin: false));
    return null;
  }

  /// `POST /me/addresses` then re-sync the list (to pick up the real id).
  /// Sends the full backend schema — `area` and `pincode` are required there,
  /// so an empty value would be rejected with a 400.
  /// The server call of the last [addAddress]; resolves to the API error
  /// when the backend rejected it (so the sheet can highlight its fields).
  Future<ApiException?>? addressSync;

  /// Removes a locally-added address the server refused.
  void dropLocalAddress(String id) {
    addresses.removeWhere((a) => a.id == id);
    _changed();
  }

  Future<ApiException?> _apiAddAddress(
      String label, String detail, String area, String pincode,
      [String phone = '']) async {
    try {
      await Api.instance.auth.addAddress(
        label: label,
        line1: detail,
        area: area,
        pincode: pincode,
        phone: phone,
      );
      await refreshAddresses();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
      return e;
    } catch (_) {
      // Keep the local copy.
      return null;
    }
  }

  /// `DELETE /me/addresses/{id}`.
  Future<void> _apiDeleteAddress(String id) async {
    try {
      await Api.instance.auth.deleteAddress(id);
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Local copy is already gone.
    }
  }

  /// Restore a persisted session at boot and load admin data if applicable.
  Future<void> bootstrapFromSession() async {
    if (!backendMode) {
      // Nothing persisted to resolve: identity is settled immediately.
      settleSession();
      return;
    }
    try {
      final me = await Api.instance.auth.me();
      await applyAuth(AuthResultDto(
        accessToken: Api.instance.session.accessToken,
        user: me,
      ));
    } on ApiException catch (e) {
      if (e.needsAuth) {
        // The persisted refresh token is expired/revoked: drop the stale
        // session instead of booting a half-signed-in state, then continue
        // as a guest. The catalog and the device basket still load.
        await Api.instance.session.clear();
        _stopLiveOrders();
        userEmail = null;
        userRole = null;
        signedIn = false;
        isAdmin = false;
        adminSignedIn = !ApiConfig.isLive;
        _changed();
        settleSession();
        await bootstrapGuest();
        return;
      }
      // Transient failure (backend down, 5xx, timeout): keep the session and
      // fall through — the bootstrap below reports what it could not load.
    } catch (_) {
      // Unrecognised failure: leave the session as it is.
    }
    // Identity is now known (adopted, or a transient failure left it as it
    // was): release anything gated on it before the slower data bootstrap.
    settleSession();
    if (isAdmin) {
      await bootstrapAdmin();
    } else {
      await bootstrapCustomer();
    }
  }

  /// Load every admin collection from the backend into the local model.
  Future<void> bootstrapAdmin() async {
    if (!backendMode) return;
    try {
      apiLastError = null;

      // Categories
      final catRaw =
          await Api.instance.client.get('/categories') as List? ?? [];
      final catDtos = catRaw
          .whereType<Map>()
          .map((e) => CategoryDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      categories = categoriesFromDtos(catDtos);
      // Admin list (includes hidden categories) for pickers + Categories screen.
      await refreshAdminCategories();

      // Units of measure — the product editor's unit picker reads these.
      await refreshUnits();

      // Products (one backend row per pack -> grouped into products)
      final packs = <AdminProductDto>[];
      var page = 0;
      var total = 1;
      while (packs.length < total && page < 60) {
        final p = await Api.instance.admin.listProducts(page: page, size: 50);
        packs.addAll(p.items);
        total = p.hasMore == false ? packs.length : p.total;
        page++;
        if (p.items.isEmpty) break;
      }
      products = productsFromBackend(packs);
      packIndex = buildPackIndex(products);

      // Coupons first: an admin's saved basket may carry a coupon code and
      // it should match a real row rather than the flat stand-in.
      coupons = couponsFromDtos(await Api.instance.admin.listCoupons());

      // Keep the basket across an admin sign-in too (the account's copy wins
      // over this device's, exactly as for a customer).
      await _applyPendingCart();

      // Coins, banners
      coinRules = coinRulesFromDtos(await Api.instance.admin.listCoinRules());
      coinSettings =
          coinSettingsFromDto(await Api.instance.admin.getCoinSettings());
      final banners = await Api.instance.admin.listBanners();
      final activeBanner =
          banners.where((b) => b.active).toList();
      bannerId = banners.isEmpty
          ? null
          : ((activeBanner.isNotEmpty ? activeBanner.first : banners.first).id);
      hotSale = hotSaleFromBanners(banners, products);

      // Shop settings → the store info shown across admin + customer screens.
      try {
        shopSettings = await Api.instance.admin.getShop();
        unawaited(StoreProfileHub.instance.refresh());
      } on ApiException {
        // Keep the cached store details if the endpoint isn't reachable.
      }

      // Staff roster + full payment-method matrix (admin editors read these).
      try {
        adminStaff = await Api.instance.admin.listStaff();
      } on ApiException {
        adminStaff = [];
      }
      try {
        paymentMethods = await Api.instance.admin.listPaymentMethods();
      } on ApiException {
        paymentMethods = [];
      }

      // Orders + dashboard
      await refreshAdminOrders();
      adminDashboard = await Api.instance.admin.dashboard();
      weekSales = _weekFromDashboard(adminDashboard!);
      if (isBackendAdmin) unawaited(refreshAdminOpsAlerts());

      // Stock movement history (stock report screen).
      await loadStockMovements();

      // The demo's seeded cart has no meaning against the live backend.
      cartItems = [];
      cartCoupon = '';
      useCoins = false;
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      apiLastError = 'Could not load data from the server.';
      _changed();
    }
    // Live order feed (SSE) for admins + counter staff — see the customer
    // bootstrap for why it also starts after a partial failure.
    _startLiveOrders();
  }

  List<WeekSale> _weekFromDashboard(DashboardDto d) {
    const dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return d.last7Days.map((day) {
      final dt = DateTime.tryParse(day.date ?? '');
      final label = dt != null ? dow[dt.weekday % 7] : (day.date ?? '');
      return WeekSale(day: label, amount: paiseToRupees(day.salesPaise));
    }).toList();
  }

  /// Server-side search string currently applied to [refreshAdminOrders]
  /// (`GET /admin/orders?q=`). Empty = the full list. Stored here so a live
  /// SSE refresh mid-search does not wipe the results the admin is reading.
  String adminOrderQuery = '';

  /// Search the admin order list on the **server** (`q` matches order number,
  /// customer name or phone) and remember the term for later refreshes.
  Future<void> searchAdminOrders(String q) async {
    // The server refuses a search text over 100 characters (`fields.q`).
    final qt = q.trim();
    adminOrderQuery = qt.length > 100 ? qt.substring(0, 100) : qt;
    _extraOrders = [];
    try {
      await refreshAdminOrders();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep the list on screen.
    }
  }

  /// Status chip currently applied to the admin list as `GET /admin/orders
  /// ?status=` (model label such as 'Placed'; empty = all statuses).
  String adminOrderStatus = '';

  /// Filter the admin order list by status on the **server**, so a status that
  /// only exists on later pages is found and "Load more" pages within it.
  Future<void> filterAdminOrdersByStatus(String label) async {
    if (adminOrderStatus == label) return;
    adminOrderStatus = label;
    _extraOrders = [];
    try {
      await refreshAdminOrders();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep the list on screen.
    }
  }

  // --- admin order screen filters (day / view) ----------------------------
  // Filter state lives here, but it belongs to ONE visit of the orders
  // screen: [presetAdminOrderFilters] resets everything on entry and
  // [endAdminOrdersSession] on exit, so nothing survives a screen change.

  /// '' | 'action' (staff must act) | 'new' (placed in the last 24 hours).
  String adminOrderView = '';

  /// Selected calendar day (India date as a UTC-flagged midnight), or null.
  DateTime? adminOrderDay;

  /// True while pages are being fetched to reach the day / view.
  bool adminOrdersFilling = false;

  /// The page cap was hit before the whole day / view was reached.
  bool adminOrdersCapHit = false;

  /// Server total of need-action orders (sum of one `status=` count each),
  /// used when not every order is loaded.
  int? adminNeedActionServer;
  DateTime? _needActionAt;

  Object? _adminOrdersOwner;
  int _orderFillGen = 0;

  /// Statuses where staff must act. PAYMENT_PENDING waits for the customer;
  /// delivered / picked up / cancelled are finished.
  static const List<String> needActionStatuses = [
    'Placed',
    'Confirmed',
    'Packed',
    'Out for Delivery',
    'Ready for Pickup',
  ];

  bool orderNeedsAction(Order o) =>
      !o.awaitingPayment && needActionStatuses.contains(o.status);

  /// Need-action count: exact over the loaded orders, or the server's own
  /// per-status totals when more orders exist than are loaded.
  int needActionCount() {
    final local = orders.where(orderNeedsAction).length;
    final srv = adminNeedActionServer;
    if (srv != null && orders.length < ordersServerTotal) {
      return srv > local ? srv : local;
    }
    return local;
  }

  bool get adminOrderFiltersActive =>
      adminOrderStatus.isNotEmpty ||
      adminOrderQuery.isNotEmpty ||
      adminOrderView.isNotEmpty ||
      adminOrderDay != null;

  /// India calendar day from 'today' | 'yesterday' | 'YYYY-MM-DD' (null when
  /// absent, invalid or in the future).
  DateTime? parseOrderDay(String? s) {
    if (s == null || s.isEmpty) return null;
    final n = istNow();
    final today = DateTime.utc(n.year, n.month, n.day);
    DateTime? d;
    if (s == 'today') {
      d = today;
    } else if (s == 'yesterday') {
      d = today.subtract(const Duration(days: 1));
    } else {
      final p = DateTime.tryParse(s);
      if (p != null) d = DateTime.utc(p.year, p.month, p.day);
    }
    if (d == null || d.isAfter(today)) return null;
    return d;
  }

  /// Resets all order filters; returns true when the server list must be
  /// re-read because a status / search term was applied. No notification.
  bool _resetAdminOrderFilters() {
    _orderFillGen++;
    final needs = adminOrderStatus.isNotEmpty || adminOrderQuery.isNotEmpty;
    adminOrderStatus = '';
    adminOrderQuery = '';
    adminOrderView = '';
    adminOrderDay = null;
    adminOrdersFilling = false;
    adminOrdersCapHit = false;
    if (needs) _extraOrders = [];
    return needs;
  }

  /// Called from the orders screen's initState: clears any leftover filter
  /// and applies the deep-link preset. Returns true when [startAdminOrders]
  /// must refetch. Does not notify (safe during build).
  bool presetAdminOrderFilters(Object owner, {String? day, String? view}) {
    _adminOrdersOwner = owner;
    final needs = _resetAdminOrderFilters();
    if (view == 'action' || view == 'new') adminOrderView = view!;
    if (view != 'new') adminOrderDay = parseOrderDay(day);
    return needs;
  }

  /// Post-frame half of the preset: refetch if needed, then load the pages
  /// the preset needs.
  Future<void> startAdminOrders(Object owner, bool refetch) async {
    if (_adminOrdersOwner != owner) return;
    if (refetch) {
      try {
        await refreshAdminOrders();
      } catch (_) {}
    }
    if (_adminOrdersOwner != owner) return;
    await ensureAdminOrdersLoaded();
  }

  /// Orders screen left: reset (only if no newer visit has taken over).
  void endAdminOrdersSession(Object owner) {
    if (_adminOrdersOwner != owner) return;
    _adminOrdersOwner = null;
    if (_resetAdminOrderFilters()) {
      unawaited(refreshAdminOrders().catchError((_) {}));
    }
  }

  void setAdminOrderView(String view) {
    adminOrderView = view;
    if (view == 'new') adminOrderDay = null;
    if (view.isNotEmpty && adminOrderStatus.isNotEmpty) {
      adminOrderStatus = '';
      _extraOrders = [];
      unawaited(_refetchThenFill());
      return;
    }
    _changed();
    unawaited(ensureAdminOrdersLoaded());
  }

  void setAdminOrderDay(DateTime? day) {
    adminOrderDay = day;
    if (day != null && adminOrderView == 'new') adminOrderView = '';
    _changed();
    unawaited(ensureAdminOrdersLoaded());
  }

  Future<void> _refetchThenFill() async {
    try {
      await refreshAdminOrders();
    } catch (_) {}
    await ensureAdminOrdersLoaded();
  }

  /// A status chip replaces the view (statuses are filtered on the server).
  Future<void> setAdminOrderStatusChip(String label) async {
    adminOrderView = '';
    adminOrdersCapHit = false;
    if (adminOrderStatus == label) {
      _changed();
      return ensureAdminOrdersLoaded();
    }
    adminOrderStatus = label;
    _extraOrders = [];
    await _refetchThenFill();
  }

  /// Clears every filter of the orders screen (status, search, view, day).
  Future<void> clearAdminOrderFilters() async {
    final needs = _resetAdminOrderFilters();
    _changed();
    if (needs) {
      try {
        await refreshAdminOrders();
      } catch (_) {}
    }
  }

  Future<void> searchAdminOrdersAndFill(String q) async {
    await searchAdminOrders(q);
    await ensureAdminOrdersLoaded();
  }

  /// Loads whatever the active day / view needs. Day / 'new': the server's
  /// `date=` / `from=` filter (no client fill loop). 'action': one
  /// `needsAction=true` list.
  Future<void> ensureAdminOrdersLoaded() async {
    final gen = ++_orderFillGen;
    adminOrdersCapHit = false;
    if (!backendMode) {
      adminOrdersFilling = false;
      _changed();
      return;
    }
    DateTime? cutoff;
    if (adminOrderView == 'new') {
      cutoff = istNow().subtract(const Duration(hours: 24));
    } else if (adminOrderDay != null) {
      cutoff = adminOrderDay;
    }
    if (adminOrderView != 'action' && cutoff == null) {
      adminOrdersFilling = false;
      _changed();
      return;
    }
    adminOrdersFilling = true;
    _changed();
    try {
      if (adminOrderView == 'action') {
        await _loadAllNeedAction(gen);
      } else {
        // The server filters by placed date (`date=` for one India day,
        // `from=` for "last 24 hours"), so only the matching pages load.
        await _loadRangeFromServer(gen, cutoff!);
      }
    } catch (_) {}
    if (gen == _orderFillGen) {
      adminOrdersFilling = false;
      _changed();
    }
  }

  /// Pages `GET /admin/orders` with `date=YYYY-MM-DD` (a chosen day) or
  /// `from=` (the "new" view, last 24 h) and merges the rows into [orders].
  Future<void> _loadRangeFromServer(int gen, DateTime cutoff) async {
    final byDay = adminOrderView != 'new';
    final have = {for (final o in orders) o.number};
    var pg = 0;
    while (gen == _orderFillGen) {
      PageAdminSummaryDto p;
      try {
        p = await Api.instance.admin.listOrders(
          date: byDay ? _ymdIst(cutoff) : null,
          from: byDay
              ? null
              : '${_ymdIst(cutoff)}T${cutoff.hour.toString().padLeft(2, '0')}:'
                  '${cutoff.minute.toString().padLeft(2, '0')}:00',
          q: adminOrderQuery.isEmpty ? null : adminOrderQuery,
          page: pg,
          size: 50,
        );
      } on ApiException catch (e) {
        _noteRateLimited(e);
        break;
      }
      for (final s in p.items) {
        orderIdsByNo[s.orderNo ?? s.id ?? ''] = s.id ?? '';
        final o = orderFromSummary(s, packIndex);
        if (have.add(o.number)) {
          orders.add(o);
          _extraOrders.add(o);
        }
      }
      pg++;
      if (p.hasMore == false || p.items.isEmpty) break;
      if (pg >= 20) {
        adminOrdersCapHit = true;
        break;
      }
    }
  }

  Future<void> _loadAllNeedAction(int gen) async {
    final have = {for (final o in orders) o.number};
    var total = 0;
    var ok = true;
    {
      // One paged list: the server's `needsAction=true` covers the five
      // still-to-work statuses at once.
      var pg = 0;
      while (gen == _orderFillGen) {
        PageAdminSummaryDto p;
        try {
          p = await Api.instance.admin
              .listOrders(
                  needsAction: true,
                  q: adminOrderQuery.isEmpty ? null : adminOrderQuery,
                  page: pg,
                  size: 50);
        } catch (_) {
          ok = false;
          break;
        }
        if (pg == 0) total += p.total;
        for (final s in p.items) {
          orderIdsByNo[s.orderNo ?? s.id ?? ''] = s.id ?? '';
          final o = orderFromSummary(s, packIndex);
          if (have.add(o.number)) {
            orders.add(o);
            _extraOrders.add(o);
          }
        }
        pg++;
        if (p.hasMore == false || p.items.isEmpty) break;
        if (pg >= 6) {
          adminOrdersCapHit = true;
          break;
        }
      }
    }
    if (ok && gen == _orderFillGen && adminOrderQuery.isEmpty) {
      adminNeedActionServer = total;
      _needActionAt = DateTime.now();
    }
  }

  /// One `size=1` request per need-action status for the server totals.
  Future<void> _refreshNeedActionTotals() async {
    final at = _needActionAt;
    if (at != null && DateTime.now().difference(at).inSeconds < 10) return;
    _needActionAt = DateTime.now();
    var total = 0;
    try {
      final p = await Api.instance.admin
          .listOrders(needsAction: true, page: 0, size: 1);
      total += p.total;
      adminNeedActionServer = total;
    } catch (_) {}
  }

  /// True when the current [orders] are the server's answer to
  /// [adminOrderQuery]. `GET /admin/orders?q=` matches order number, name,
  /// mobile and e-mail on the server.
  bool adminOrdersServerFiltered = false;

  /// Full order views already fetched, keyed by order id. A list refresh only
  /// re-fetches an order whose status or total changed, so a refresh costs 0
  /// detail calls in the steady state instead of 20 (the backend allows 300
  /// calls a minute per address; the old loop plus live events hit 429).
  final Map<String, ({String key, Order order})> _orderDetailCache = {};

  /// While set, list refreshes keep summaries only (after a 429).
  DateTime? _ordersBackoffUntil;

  bool get _ordersBackingOff {
    final until = _ordersBackoffUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _noteRateLimited(ApiException e) {
    if (e.statusCode == 429) {
      // Honour the server's Retry-After (header / details.retryAfterSeconds),
      // bounded so a bad value can neither spin nor park the list for ages.
      final s = (e.retryAfterSeconds ?? 30).clamp(5, 300);
      _ordersBackoffUntil = DateTime.now().add(Duration(seconds: s));
    }
  }

  Future<void> refreshAdminOrders() async {
    final q = adminOrderQuery;
    // `q` now matches order number, customer name, mobile and e-mail on the
    // server, so the answer is final: no unfiltered re-read, no local filter.
    final p = await Api.instance.admin.listOrders(
      page: 0,
      size: 50,
      q: q.isEmpty ? null : q,
      status: adminOrderStatus.isEmpty ? null : statusToWire(adminOrderStatus),
    );
    adminOrdersServerFiltered = q.isNotEmpty || adminOrderStatus.isNotEmpty;
    orderIdsByNo = {
      for (final s in p.items) (s.orderNo ?? s.id ?? ''): (s.id ?? '')
    };
    // `GET /admin/orders` is a **summary**: no line items, no address, no
    // real timeline (and no customer name/mobile at all). Mapping it straight
    // into the model left the detail screen rendering "0 items" with empty
    // Customer/Items cards, so fetch the full view for the newest orders —
    // the same approach the customer list already uses. Anything beyond the
    // cap keeps its summary row, which is enough for the list itself.
    final views = <Order>[];
    var stopFetching = _ordersBackingOff;
    for (final s in p.items.take(20)) {
      final id = s.id;
      if (id == null) {
        views.add(orderFromSummary(s, packIndex));
        continue;
      }
      final key = '${s.status}|${s.totalPaise}';
      final hit = _orderDetailCache[id];
      if (hit != null && hit.key == key) {
        views.add(hit.order);
        continue;
      }
      if (stopFetching) {
        views.add(hit?.order ?? orderFromSummary(s, packIndex));
        continue;
      }
      try {
        final v = await Api.instance.admin.getOrder(id);
        orderIdsByNo[v.orderNo ?? v.id ?? ''] = v.id ?? id;
        final full = orderFromView(v, packIndex);
        _orderDetailCache[id] = (key: key, order: full);
        views.add(full);
      } on ApiException catch (e) {
        _noteRateLimited(e);
        if (e.statusCode == 429) stopFetching = true;
        views.add(hit?.order ?? orderFromSummary(s, packIndex));
      }
    }
    for (final s in p.items.skip(20)) {
      views.add(orderFromSummary(s, packIndex));
    }
    ordersServerTotal = p.hasMore == false ? views.length : p.total;
    _mergeExtraOrders(views);
    _carryCancelReasons(views);
    orders = views;
    _ordersSyncedAt = istNow();
    // More orders exist than are loaded: the dashboard tiles read the
    // server's own totals, so keep them fresh with the list.
    if (ordersServerTotal > views.length && !_ordersBackingOff) {
      try {
        adminDashboard = await Api.instance.admin.dashboard();
      } catch (_) {}
      await _refreshNeedActionTotals();
    }
    _changed();
  }

  Future<void> refreshAdminProducts() async {
    final packs = <AdminProductDto>[];
    var pg = 0;
    var total = 1;
    while (packs.length < total && pg < 60) {
      final p = await Api.instance.admin.listProducts(page: pg, size: 50);
      packs.addAll(p.items);
      total = p.hasMore == false ? packs.length : p.total;
      pg++;
      if (p.items.isEmpty) break;
    }
    products = productsFromBackend(packs);
    packIndex = buildPackIndex(products);
    _changed();
  }

  // --- live order updates (SSE: `GET /orders/stream` + `/admin/orders/stream`)

  /// The open Server-Sent Events connection, or null when none is wanted.
  OrdersStream? _liveOrders;

  /// Which endpoint it is on: staff/admin streams every order, a customer
  /// only their own.
  bool _liveOrdersStaff = false;

  /// When the order list last reached the server — the stream's `ready`
  /// handshake refetches, but not when a bootstrap just did the same work.
  DateTime? _ordersSyncedAt;

  /// Order ids with a full-row refetch in flight (one at a time each).
  final Set<String> _liveRefetching = <String>{};

  DateTime? _liveListRefetchAt;

  /// Subscribe to the backend's order event stream so a status change lands
  /// **on screen** — no logout, no page refresh (backend change #4).
  ///
  /// The stream lives ~10 minutes server-side and then closes; [OrdersStream]
  /// reconnects with a fresh token and every (re)connect re-reads the list
  /// once, so nothing that happened while the socket was down is missed.
  void _startLiveOrders() {
    if (!backendMode || !ApiConfig.isLive) return;
    final staff = isBackendStaff;
    if (_liveOrders != null && _liveOrdersStaff == staff) return;
    _liveOrders?.stop();
    final stream = OrdersStream(Api.instance.client);
    _liveOrders = stream;
    _liveOrdersStaff = staff;
    stream.start(
      endpoint: staff ? '/admin/orders/stream' : '/orders/stream',
      onEvent: _onLiveOrderEvent,
      // Until the first `ready` lands the feed is not proven — poll the
      // order list so a status change still shows up on a blocked network.
      onConnected: () {
        _liveConnected = true;
        _stopPolling();
      },
      onDisconnected: _liveStreamDown,
    );
    _startPolling();
  }

  /// Drop the feed: sign-out, a revoked session, or a role change re-picks
  /// its endpoint on the next [applyAuth].
  void _stopLiveOrders() {
    _liveOrders?.stop();
    _liveOrders = null;
    _liveOrdersStaff = false;
    _liveConnected = false;
    _livePoll?.cancel();
    _livePoll = null;
    _cancelDebounces();
  }

  void _onLiveOrderEvent(OrderStreamEvent e) {
    if (!backendMode) {
      _stopLiveOrders();
      return;
    }
    if (e.ready) {
      // (Re)connected: reload what the backend doc lists for `ready`.
      // Customer: orders + wallet + credit + current products.
      // Staff: orders + the current screen's list (their products/orders).
      // The 3-second guard only skips the very first connect, which lands
      // right after a bootstrap that just did the same work — every later
      // (re)connect reloads in full.
      _liveConnected = true;
      _stopPolling();
      final last = _ordersSyncedAt;
      if (last == null ||
          istNow().difference(last) > const Duration(seconds: 3)) {
        unawaited(_refreshOrdersQuiet());
      }
      if (!_liveOrdersStaff) {
        unawaited(refreshWallet());
        unawaited(refreshCredit());
      }
      unawaited(refreshStorefrontQuiet());
      return;
    }

    // Wallet moved (this customer's own event): the coin balance shown in the
    // header/wallet screen has to follow without a refresh.
    if (e.kind == LiveEvent.wallet) {
      unawaited(refreshWallet());
      return;
    }

    // Credit (udhar) moved at the counter: re-read the account + ledger.
    if (e.kind == LiveEvent.credit) {
      unawaited(refreshCredit());
      return;
    }

    // Stock moved (any listener gets these): re-read the catalog so shelves,
    // prices and "out of stock" badges are right on every open screen.
    // Debounced — the backend already batches a burst into one frame, but a
    // sale storm can still land several frames a second apart.
    if (e.kind == LiveEvent.stock) {
      _debounced('stock', () async {
        await refreshStorefrontQuiet();
        // `unitsLeft` on the flash strip changes with sales (no FLASH event).
        unawaited(FlashStore.instance.refresh());
        if (_liveOrdersStaff) await loadStockMovements();
        // The basket may now hold more than stock allows — re-price it.
        await refreshCartQuoteWarnings();
      });
      return;
    }

    // An admin changed something every screen shows: refetch exactly the
    // area named in the frame, public and admin sides alike.
    if (e.kind == LiveEvent.catalog) {
      final area = e.catalogArea;
      _debounced('catalog:$area', () => _refreshCatalogArea(area));
      return;
    }

    final no = (e.orderNo ?? '').trim();
    final wire = statusFromWire(e.status);
    if (no.isEmpty || wire.isEmpty) return;

    // 1) Apply the status straight away — this is what removes the refresh.
    final idx = _orderIndex(no);
    if (idx >= 0) {
      final order = orders[idx];
      if (order.status != wire) {
        order.status = wire;
        order.updatedAt = e.at ?? istNow();
        _changed();
      }
    }

    // 2) Then the full row (timeline, items, totals) — one in flight per id.
    var id = e.orderId ?? orderIdsByNo[no];
    if (id != null && id.isEmpty) id = null;
    if (id != null) {
      if (_liveRefetching.add(id)) {
        unawaited(_refetchLiveOrder(id)
            .whenComplete(() => _liveRefetching.remove(id)));
      }
      return;
    }
    // Unknown to this screen (a just-placed order on another device): pull
    // the list, rate-limited so a burst of events can't stampede it.
    if (idx < 0) _throttledListRefresh();
  }

  bool _ordersRefreshing = false;

  Future<void> _refreshOrdersQuiet() async {
    // One refresh at a time: a burst of live events collapses into one pass.
    if (_ordersRefreshing) return;
    _ordersRefreshing = true;
    try {
      if (_liveOrdersStaff) {
        await refreshAdminOrders();
      } else {
        await refreshCustomerOrders();
      }
    } on ApiException catch (e) {
      // A blocked/unreachable backend must not kill the poller or the
      // stream's `ready` reload — record it and retry on the next tick.
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep the list on screen; the next poll/event retries.
    } finally {
      _ordersRefreshing = false;
    }
  }

  /// True while a `stock`-event catalog refetch is in flight — a burst of
  /// movement frames collapses into one request.
  bool _storefrontRefreshing = false;

  /// Re-read the catalog after a `stock` live event so availability, prices
  /// and "out of stock" badges are right on every open screen without a
  /// refresh. Staff sessions re-read the admin list instead, which is what
  /// their inventory screens render from.
  Future<void> refreshStorefrontQuiet() async {
    if (!backendMode || _storefrontRefreshing) return;
    _storefrontRefreshing = true;
    try {
      if (_liveOrdersStaff) {
        await refreshAdminProducts();
        return;
      }
      final packs = <PublicProductDto>[];
      var page = 0;
      var total = 1;
      while (packs.length < total && page < 60) {
        final p =
            await Api.instance.catalog.getProducts(page: page, size: 50);
        packs.addAll(p.items);
        total = p.hasMore == false ? packs.length : p.total;
        page++;
        if (p.items.isEmpty) break;
      }
      products = productsFromPublic(packs);
      packIndex = buildPackIndex(products);
      // Hot sale rides along: a price/stock change must not leave the strip
      // on old rows (the backend doc lists products + hot-sale together).
      try {
        hotSale =
            hotSaleFromPublicDto(await Api.instance.catalog.getHotSale(), products);
      } on ApiException {
        // Decorative — the products above are already fresh.
      }
      _changed();
    } catch (_) {
      // Keep whatever is on screen — the next event or bootstrap retries.
    } finally {
      _storefrontRefreshing = false;
    }
  }

  void _throttledListRefresh() {
    final now = istNow();
    final last = _liveListRefetchAt;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _liveListRefetchAt = now;
    unawaited(_refreshOrdersQuiet());
  }

  // --- live-stream housekeeping: burst debounce + offline polling -----------

  /// Pending debounced catalog/stock refetches, keyed by work name (backend
  /// doc: ~300 ms debounce for `stock`/`catalog` bursts — a POS bill that
  /// moves 40 lines must cost one refetch, not 40). Separate keys so a
  /// `stock` frame arriving right after a `catalog` frame cannot cancel it:
  /// the backend flushes both into the same window.
  final Map<String, Timer> _liveDebounces = <String, Timer>{};

  /// Collapse a burst of frames of one kind into a single refetch that runs
  /// 300 ms after the *last* frame of that burst.
  void _debounced(String key, Future<void> Function() work) {
    _liveDebounces[key]?.cancel();
    _liveDebounces[key] = Timer(const Duration(milliseconds: 300), () {
      _liveDebounces.remove(key);
      unawaited(work());
    });
  }

  void _cancelDebounces() {
    for (final t in _liveDebounces.values) {
      t.cancel();
    }
    _liveDebounces.clear();
  }

  /// Re-read exactly the collection a `catalog` frame named. Every area is
  /// refetched on both sides of the app: a customer screen and an open admin
  /// screen must not disagree because only one of them heard the event.
  Future<void> _refreshCatalogArea(String area) async {
    if (!backendMode) return;
    try {
      switch (area.toUpperCase()) {
        case 'CATALOG':
          // Products, prices, categories, banners and variants.
          cartLotCap.clear(); // a lot may have rolled to the next price
          await refreshStorefrontQuiet();
          await _refreshCategoriesQuiet();
          await loadPublicOffers();
          if (isBackendAdmin) await _refreshBannersQuiet();
          break;
        case 'COUPONS':
          await loadPublicOffers();
          if (isBackendAdmin) {
            coupons =
                couponsFromDtos(await Api.instance.admin.listCoupons());
            _changed();
          }
          break;
        case 'UNITS':
          await reloadUnits();
          break;
        case 'SHOP':
          await _refreshShopQuiet();
          break;
        case 'FLASH':
          // A sale was created / started / ended / cancelled: prices on the
          // product lists and the home strip change together.
          await refreshStorefrontQuiet();
          FlashStore.instance.bump();
          // 40 customer flow step 6: re-run the quote if a basket exists.
          await refreshCartQuoteWarnings();
          break;
        case 'PAYMENT_METHODS':
          await _refreshPaymentMethodsQuiet();
          break;
        default:
          // Unknown area: fall back to the whole storefront so nothing stale
          // survives an area this build does not know about yet.
          await refreshStorefrontQuiet();
      }
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep what is on screen; the next frame retries.
    }
  }

  /// Re-read `GET /categories` without touching anything else on screen.
  Future<void> _refreshCategoriesQuiet() async {
    final raw =
        await Api.instance.client.get('/categories', authRequired: false);
    final dtos = (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => CategoryDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    categories = categoriesFromDtos(dtos);
    _changed();
  }

  /// Re-reads the store card (public `GET /shop-settings` / admin settings).
  Future<void> refreshShopDetails() => refreshStoreProfile(force: true);

  /// Re-read the store card: the admin's full settings for an admin session,
  /// the public `GET /shop-settings` for everyone else (no token needed, so
  /// a customer hears a `SHOP` change too). Never throws — the store card is
  /// decorative next to the catalog, and a caller must not abort its own
  /// bootstrap because this failed.
  Future<void> _refreshShopQuiet() async {
    try {
      // Identity always comes from the public profile (cached, conditional
      // GET); an admin additionally keeps the full settings as editor source.
      await StoreProfileHub.instance.refresh();
      if (isBackendAdmin) {
        shopSettings = await Api.instance.admin.getShop();
      }
      _applyStoreProfile();
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep the store details already on screen.
    }
  }

  /// Re-read the enabled payment methods (public set for customers, the full
  /// matrix for admins).
  Future<void> _refreshPaymentMethodsQuiet() async {
    paymentMethods = isBackendAdmin
        ? await Api.instance.admin.listPaymentMethods()
        : await Api.instance.wallet.getPaymentMethods();
    _changed();
  }

  /// Re-read the sale banners and rebuild the hot-sale strip (admin session).
  Future<void> _refreshBannersQuiet() async {
    final banners = await Api.instance.admin.listBanners();
    final active = banners.where((b) => b.active).toList();
    bannerId = banners.isEmpty
        ? null
        : ((active.isNotEmpty ? active.first : banners.first).id);
    hotSale = hotSaleFromBanners(banners, products);
    _changed();
  }

  // --- polling fallback ----------------------------------------------------

  /// True while the SSE feed is connected and has delivered `ready` — the
  /// signal to stop polling (backend doc: poll only while the stream cannot
  /// connect, stop once `ready` arrives).
  bool _liveConnected = false;

  /// Orders polled while the stream is down (30–60 s window).
  Timer? _livePoll;

  void _startPolling() {
    if (_livePoll != null || !backendMode || !ApiConfig.isLive) return;
    // 45 s: inside the backend's 30–60 s guidance, short enough that an
    // order status still lands without a refresh, long enough to stay quiet.
    _livePoll = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!backendMode || _liveConnected) {
        _stopPolling();
        return;
      }
      unawaited(_refreshOrdersQuiet());
    });
  }

  void _stopPolling() {
    _livePoll?.cancel();
    _livePoll = null;
  }

  /// Called when the stream *fails* to connect (OrdersStream backoff) so the
  /// order list keeps moving on a timer until `ready` arrives again.
  void _liveStreamDown() {
    if (_liveConnected) {
      _liveConnected = false;
      _changed();
    }
    _startPolling();
  }

  /// App went to the background: drop the socket and the poller (they only
  /// burn battery and server slots while nobody is looking).
  void pauseLiveOrders() {
    _stopPolling();
    _cancelDebounces();
    if (_liveOrders != null) {
      _liveOrders!.stop();
      _liveOrders = null;
      _liveOrdersStaff = false;
    }
  }

  /// App came back to the foreground: reconnect (a fresh `ready` reloads what
  /// changed while we were away) and restart the poller until it lands.
  void resumeLiveOrders() {
    // Tab focus / app resume: revalidate the store profile if it is stale.
    unawaited(StoreProfileHub.instance.revalidateIfStale());
    if (!backendMode || !ApiConfig.isLive) return;
    _liveConnected = false;
    _startLiveOrders();
    _startPolling();
  }

  /// Re-read one order after its stream event so history/items match the
  /// server, not just the status that arrived on the wire.
  Future<void> _refetchLiveOrder(String id) async {
    try {
      final v = _liveOrdersStaff
          ? await Api.instance.admin.getOrder(id)
          : await Api.instance.orders.getOrder(id);
      final no = v.orderNo ?? v.id ?? '';
      if (no.isEmpty) return;
      orderIdsByNo[no] = v.id ?? id;
      // A customer's own order row carries their current coin balance — the
      // stream already told us something changed, so keep the header honest.
      if (!_liveOrdersStaff && v.coinBalance != null) {
        walletCoins = v.coinBalance!;
        walletLoaded = true;
      }
      final mapped = orderFromView(v, packIndex);
      final idx = _orderIndex(no);
      if (idx >= 0) {
        orders[idx] = mapped;
      } else {
        orders = [mapped, ...orders];
      }
      _changed();
    } on ApiException {
      // The event itself already applied the status; a list refresh (next
      // event, reconnect or screen visit) carries the rest.
    } catch (_) {
      // Same.
    }
  }

  // --- background persistence (called from the existing sync mutations) ----

  /// `POST /admin/orders/{id}/status`. Returns null once the server accepted
  /// the move, or the failure the caller has to show.
  ///
  /// It deliberately mutates nothing: the local order only changes after this
  /// comes back clean, so a 409 `ILLEGAL_TRANSITION` / `VERSION_CONFLICT`
  /// (or an unreachable backend) can never look like a successful move.
  Future<ApiException?> _apiSetStatus(String number, String wireStatus,
      {String? note}) async {
    final id = orderIdsByNo[number];
    if (id == null) return null; // No server copy yet: a local-only move.
    try {
      await Api.instance.admin.setOrderStatus(id, wireStatus,
          note: note != null && note.length > 200
              ? note.substring(0, 200)
              : note);
    } on ApiException catch (e) {
      return e;
    } catch (_) {
      return const ApiException(0,
          'Could not update the order. Check your connection and try again.');
    }
    return null;
  }

  /// Re-read the order list after a move/cancel the server accepted.
  ///
  /// Best effort — the local row already says the same thing, so only the
  /// freshest history/ids can be late — but a failure still surfaces through
  /// [apiLastError] instead of vanishing.
  Future<void> _resyncOrdersAfterMove({bool admin = true}) async {
    try {
      if (admin) {
        await refreshAdminOrders();
      } else {
        await refreshCustomerOrders();
        await refreshWallet();
      }
    } on ApiException catch (e) {
      apiLastError = e.message;
    } catch (_) {
      apiLastError = 'Could not refresh the orders.';
    }
  }

  /// Saves the draft's pack rows on the backend, creating any row that does
  /// not exist yet, and returns the first error — or null when every row is
  /// stored. Callers that need the backend **ids now** (the photo upload
  /// attaches to a saved row) await this instead of the fire-and-forget path
  /// inside [saveProduct].
  Future<String?> saveProductToServer(Product p) =>
      backendMode ? _apiSaveProduct(p) : Future<String?>.value(null);

  /// Deletes a product (every pack) from inventory. Returns an error message,
  /// or null on success. [note] (when set) is the message to show.
  /// `DELETE /admin/products/{id}` answers 200 `{deleted, deactivated,
  /// reason}` per pack: never-used packs are removed, used ones are only
  /// switched off (hidden) by the server. The old "set active:false" fallback
  /// stays for 404/405/501 only (an older server without the endpoint).
  Future<({String? error, String? note})> deleteProduct(String productId) async {
    final p = productById(productId);
    if (p == null) return (error: 'Product not found', note: null);
    if (!backendMode) {
      products.removeWhere((x) => x.id == productId);
      _changed();
      return (error: null, note: null);
    }
    var removed = 0;
    var hidden = 0;
    String? hiddenReason;
    var fallback = false;
    try {
      for (final v in p.variants) {
        final id = v.backendId;
        if (id == null) continue;
        try {
          final r = await Api.instance.admin.deleteProduct(id);
          if (r.deactivated) {
            hidden++;
            hiddenReason ??= r.reason;
          } else {
            removed++;
          }
        } on ApiException catch (e) {
          if (e.statusCode == 404 || e.statusCode == 405 || e.statusCode == 501) {
            await Api.instance.admin.patchProduct(id, {'active': false});
            fallback = true;
            hidden++;
          } else {
            rethrow;
          }
        }
      }
      await refreshAdminProducts();
      String? note;
      if (fallback) {
        note = 'The server has no delete, so the item was switched off '
            'instead (hidden from customers).';
      } else if (hidden > 0) {
        note = 'Hidden from customers instead of deleted'
            '${removed > 0 ? ' ($hidden of ${removed + hidden} packs)' : ''}: '
            '${(hiddenReason ?? 'it has sales or stock history').replaceAll(RegExp(r'\.$'), '')}.';
      } else {
        note = 'Product deleted';
      }
      return (error: null, note: note);
    } on ApiException catch (e) {
      apiLastError = e.message;
      return (error: e.message, note: null);
    } catch (_) {
      return (error: 'Could not delete the product.', note: null);
    }
  }

  /// Saves in flight, per draft object. A double-tapped Save (or Save racing
  /// the photo upload) used to start two saves before either row had a
  /// backend id, so BOTH created the product -- 2 packs showed as 4 rows.
  /// Now a second save for the same draft waits for the first and then sees
  /// the ids it stored (so it updates instead of creating).
  final Map<Product, Future<String?>> _saveInFlight = {};

  Future<String?> _apiSaveProduct(Product p) {
    final prev = _saveInFlight[p] ?? Future<String?>.value(null);
    late final Future<String?> next;
    next = prev.catchError((_) => null).then((_) => _apiSaveProductNow(p)).whenComplete(() {
      if (identical(_saveInFlight[p], next)) _saveInFlight.remove(p);
    });
    _saveInFlight[p] = next;
    return next;
  }

  /// Field errors of the last product save, per pack row index (the save
  /// sends one request per pack, so each rejection belongs to one row). A key
  /// like `variants[1].pricePaise` is routed to row 1 as `pricePaise`.
  Map<int, Map<String, String>> productPackErrors = {};

  void _notePackFieldErrors(int index, Map<String, String> fields) {
    final re = RegExp(r'^variants\[(\d+)\]\.(.+)$');
    for (final e in fields.entries) {
      final m = re.firstMatch(e.key);
      final row = m == null ? index : int.parse(m.group(1)!);
      final key = m == null ? e.key : m.group(2)!;
      (productPackErrors[row] ??= <String, String>{})[key] = e.value;
    }
  }

  Future<String?> _apiSaveProductNow(Product p) async {
    String? firstError;
    productPackErrors = {};
    // The backend keeps ONE product per pack: `POST /admin/products` always
    // creates a brand-new product, and only `POST /admin/products/{id}/variants`
    // appends a pack to an existing one. Posting every pack through the create
    // endpoint therefore produced N duplicate products for an N-pack item —
    // so the first pack creates (or reuses) the product and every further pack
    // is added as a variant of it.
    String? anchorId;
    for (final v in p.variants) {
      if (v.backendId != null) {
        anchorId = v.backendId;
        break;
      }
    }
    for (var i = 0; i < p.variants.length; i++) {
      final v = p.variants[i];
      try {
        if (v.backendId != null) {
          final updated = await _patchPack(p, v);
          v.backendId = updated.id ?? v.backendId;
        } else if (anchorId != null) {
          final created = await Api.instance.admin.addVariant(
            anchorId,
            packSize: v.label,
            unit: unitCodeFor(v.unit, fallback: p.unit),
            mrpPaise: rupeesToPaise(v.mrp),
            pricePaise: rupeesToPaise(v.price),
            active: v.active && p.available,
            qtyOnHand: v.stock,
            lowThreshold: p.lowStock,
            variantOrder: i,
          );
          v.backendId = created.id;
        } else {
          final created = await Api.instance.admin.createProduct(
            categoryId: p.category,
            nameEn: p.name,
            nameGu: p.nameGu.isEmpty ? p.name : p.nameGu,
            description: p.desc,
            mrpPaise: rupeesToPaise(v.mrp),
            pricePaise: rupeesToPaise(v.price),
            unit: unitCodeFor(v.unit, fallback: p.unit),
            packSize: v.label,
            active: v.active && p.available,
            hotSale: p.hotSale,
            earnsCoins: p.earnsCoins,
            coinRedeemable: p.allowCoins,
            qtyOnHand: v.stock,
            lowThreshold: p.lowStock,
          );
          v.backendId = created.id;
          // Every later pack hangs off this product instead of creating its own.
          anchorId = created.id;
        }
      } on ApiException catch (e) {
        apiLastError = e.message;
        firstError ??= e.message;
        _notePackFieldErrors(i, e.fields);
      } catch (_) {
        apiLastError = 'Could not save the product.';
        firstError ??= 'Could not save the product.';
      }
    }
    await refreshAdminProducts();
    return firstError;
  }

  /// Saves an existing pack with `PATCH /admin/products/{id}` carrying only
  /// the keys that differ from the server's current row (read first with
  /// `GET /admin/products/{id}`). Stock is never in the PATCH (the backend
  /// rejects `qtyOnHand`): a changed on-hand figure goes through
  /// `POST /admin/products/{id}/stock` as a delta. Hot-sale window and any
  /// other field the form does not change are therefore never overwritten.
  Future<AdminProductDto> _patchPack(Product p, Variant v) async {
    final id = v.backendId!;
    AdminProductDto? cur;
    try {
      cur = await Api.instance.admin.getProduct(id);
    } on ApiException {
      cur = null; // patch every form field except stock
    }
    String norm(String? t) => (t ?? '').trim();
    final want = <String, Object?>{
      'categoryId': p.category,
      'nameEn': p.name,
      'nameGu': p.nameGu.isEmpty ? p.name : p.nameGu,
      'description': p.desc,
      'mrpPaise': rupeesToPaise(v.mrp),
      'pricePaise': rupeesToPaise(v.price),
      'unit': unitCodeFor(v.unit, fallback: p.unit),
      'packSize': v.label,
      'active': v.active && p.available,
      'hotSale': p.hotSale,
      'earnsCoins': p.earnsCoins,
      'coinRedeemable': p.allowCoins,
      'lowThreshold': p.lowStock,
    };
    final have = cur == null
        ? const <String, Object?>{}
        : <String, Object?>{
            'categoryId': cur.categoryId,
            'nameEn': cur.nameEn,
            'nameGu': cur.nameGu,
            'description': cur.description,
            'mrpPaise': cur.mrpPaise,
            'pricePaise': cur.pricePaise,
            'unit': cur.unit,
            'packSize': cur.packSize,
            'active': cur.active,
            'hotSale': cur.hotSale,
            'earnsCoins': cur.earnsCoins,
            'coinRedeemable': cur.coinRedeemable,
            'lowThreshold': cur.lowThreshold,
          };
    final patch = <String, Object?>{};
    want.forEach((k, w) {
      if (cur == null) {
        patch[k] = w;
        return;
      }
      final h = have[k];
      final same = norm('${w ?? ''}') == norm('${h ?? ''}');
      if (!same) patch[k] = w;
    });
    AdminProductDto result = cur ?? AdminProductDto(id: id);
    if (patch.isNotEmpty) {
      result = await Api.instance.admin.patchProduct(id, patch);
    }
    if (cur != null && v.stock != cur.qtyOnHand) {
      result = await Api.instance.admin.adjustStock(
          id, v.stock - cur.qtyOnHand,
          // The backend records only the exact value ADJUST as a correction;
          // any other text is stored as RESTOCK (wrong for a decrease).
          reason: 'ADJUST');
    }
    return result;
  }

  Future<void> _apiRestock(String productId, List<int> addPerPack) async {
    final p = productById(productId);
    if (p == null) return;
    for (var i = 0; i < addPerPack.length && i < p.variants.length; i++) {
      final add = addPerPack[i];
      if (add <= 0) continue;
      final v = p.variants[i];
      if (v.backendId == null) continue;
      try {
        await Api.instance.admin
            .adjustStock(v.backendId!, add, reason: 'Supplier purchase');
      } on ApiException catch (e) {
        apiLastError = e.message;
      } catch (_) {
        apiLastError = 'Could not update stock.';
      }
    }
    await refreshAdminProducts();
  }

  /// The server call of the last [saveCoupon]; resolves to the API error
  /// when the backend refused it (the form highlights `ApiException` fields).
  Future<ApiException?>? couponSync;

  Future<ApiException?> _apiSaveCoupon(Coupon c) async {
    try {
      final kind = couponKindToWire(c.type);
      final startAt = _isoDay(c.starts);
      final endAt = _isoDay(c.expires, endOfDay: true);
      // Empty list = every category, which is how the backend stores it.
      final ids = List<String>.of(c.categoryIds);
      final list = await Api.instance.admin.listCoupons();
      final match = list.where((d) => d.code == c.code).toList();
      if (match.isNotEmpty && match.first.id != null) {
        await Api.instance.admin.updateCoupon(
          match.first.id!,
          code: c.code,
          kind: kind,
          // Backend `value` is paise for FLAT, a percent for PERCENT.
          value: kind == 'FLAT' ? rupeesToPaise(c.value) : c.value.round(),
          minOrderPaise: rupeesToPaise(c.min),
          maxDiscountPaise:
              c.maxDiscount == null ? null : rupeesToPaise(c.maxDiscount!),
          categoryIds: ids,
          productIds: c.productIds,
          productGroupIds: c.productGroupIds,
          // PUT is a full replacement and the form has no per-customer limit:
          // carry the stored one over instead of silently resetting it to 0.
          perUserLimit: match.first.perUserLimit,
          totalLimit: c.maxUses >= 999999 ? 0 : c.maxUses,
          startAt: startAt,
          endAt: endAt,
          active: c.active,
          worksWithCoins: c.worksWithCoins,
          firstOrderOnly: c.firstOrderOnly,
        );
      } else {
        await Api.instance.admin.createCoupon(
          code: c.code,
          kind: kind,
          value: kind == 'FLAT' ? rupeesToPaise(c.value) : c.value.round(),
          minOrderPaise: rupeesToPaise(c.min),
          maxDiscountPaise:
              c.maxDiscount == null ? null : rupeesToPaise(c.maxDiscount!),
          categoryIds: ids,
          productIds: c.productIds,
          productGroupIds: c.productGroupIds,
          totalLimit: c.maxUses >= 999999 ? 0 : c.maxUses,
          startAt: startAt,
          endAt: endAt,
          active: c.active,
          worksWithCoins: c.worksWithCoins,
          firstOrderOnly: c.firstOrderOnly,
        );
      }
      coupons = couponsFromDtos(await Api.instance.admin.listCoupons());
      _changed();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      // The local row was never stored: show the server's truth again.
      try {
        coupons = couponsFromDtos(await Api.instance.admin.listCoupons());
        _changed();
      } catch (_) {}
      return e;
    } catch (_) {
      apiLastError = 'Could not save the coupon.';
      return const ApiException(0, 'Could not save the coupon.');
    }
  }

  Future<String?> _apiSaveRule(CoinRule r) async {
    try {
      final list = await Api.instance.admin.listCoinRules();
      final match = list.where((d) => d.id == r.id).toList();
      final mode = coinModeToWire(r.mode);
      if (match.isNotEmpty) {
        await Api.instance.admin.updateCoinRule(
          r.id,
          name: r.name,
          spendPaise: rupeesToPaise(r.spend),
          coins: r.coins,
          mode: mode,
          // PUT is a full replacement: keep the minimum-order value the
          // rule already has (the editor has no field for it yet).
          minOrderPaise: match.first.minOrderPaise,
          startAt: _isoDay(r.starts),
          endAt: _isoDay(r.expires, endOfDay: true),
          active: r.active,
        );
      } else {
        final created = await Api.instance.admin.createCoinRule(
          name: r.name,
          spendPaise: rupeesToPaise(r.spend),
          coins: r.coins,
          mode: mode,
          startAt: _isoDay(r.starts),
          endAt: _isoDay(r.expires, endOfDay: true),
          active: r.active,
        );
        r.id = created.id ?? r.id;
      }
      coinRules = coinRulesFromDtos(await Api.instance.admin.listCoinRules());
      _changed();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      await _reloadCoinRulesQuiet();
      return e.message;
    } catch (_) {
      apiLastError = 'Could not save the rule.';
      await _reloadCoinRulesQuiet();
      return 'Could not save the rule.';
    }
  }

  /// Shows the server's rules again after a refused save (rollback).
  Future<void> _reloadCoinRulesQuiet() async {
    try {
      coinRules = coinRulesFromDtos(await Api.instance.admin.listCoinRules());
    } catch (_) {}
    _changed();
  }

  Future<String?> _apiSaveCoinSettings(
      {required num coinValue, required int maxPercent, required int expiryMonths}) async {
    try {
      await Api.instance.admin.saveCoinSettings(
        paisePerCoin: rupeesToPaise(coinValue),
        maxRedeemPercent: maxPercent,
        expiryMonths: expiryMonths,
      );
      coinSettings =
          coinSettingsFromDto(await Api.instance.admin.getCoinSettings());
      _changed();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      return e.message;
    } catch (_) {
      apiLastError = 'Could not save coin settings.';
      return 'Could not save coin settings.';
    }
  }

  /// `POST`/`PUT /admin/hot-banners` — create or update the sale banner row.
  Future<void> _apiSaveHotSale({
    required bool live,
    required String title,
    required String starts,
    required String ends,
    String? startIso,
    String? endIso,
    bool exact = false,
  }) async {
    try {
      final startAt = exact ? startIso : _isoDay(starts);
      final endAt = exact ? endIso : _isoDay(ends, endOfDay: true);
      if (bannerId != null && bannerId!.isNotEmpty) {
        // `PUT /admin/hot-banners/{id}` is a full replacement: omitting
        // `subtitle` / `imageUrl` would wipe whatever the banner already has
        // (set elsewhere), so carry the stored values over.
        HotBannerDto? current;
        try {
          for (final b in await Api.instance.admin.listBanners()) {
            if (b.id == bannerId) current = b;
          }
        } catch (_) {}
        await Api.instance.admin.updateBanner(
          bannerId!,
          title: title,
          subtitle: current?.subtitle,
          imageUrl: current?.imageUrl,
          startAt: startAt,
          endAt: endAt,
          active: live,
        );
      } else {
        final created = await Api.instance.admin.createBanner(
          title: title,
          startAt: startAt,
          endAt: endAt,
          active: live,
        );
        bannerId = created.id;
      }
      final banners = await Api.instance.admin.listBanners();
      if (bannerId == null && banners.isNotEmpty) bannerId = banners.first.id;
      hotSale = hotSaleFromBanners(banners, products);
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      apiLastError = 'Could not save the sale banner.';
      _changed();
    }
  }

  /// `PUT /me` — persist the edited profile. Returns an error message or
  /// null on success.
  Future<String?> _apiUpdateProfile() async {
    try {
      final u = await Api.instance.auth.updateProfile(
        name: userName,
        mobile: userPhone,
      );
      if (u.name != null && u.name!.isNotEmpty) userName = u.name!;
      if (u.mobile != null && u.mobile!.isNotEmpty) userPhone = u.mobile!;
      apiLastError = null;
      _changed();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
      return e.message;
    } catch (_) {
      apiLastError = 'Could not save the profile.';
      _changed();
      return 'Could not save the profile.';
    }
  }

  // --- units of measure ----------------------------------------------------

  /// `GET /units` — read the store's unit list (public endpoint, no admin
  /// rights needed). Safe to call often: the result is cached until
  /// [reloadUnits] is used after the admin edits the list.
  Future<void> refreshUnits() async {
    if (!backendMode || unitsLoaded) return;
    try {
      units = await Api.instance.catalog.getUnits();
      unitsLoaded = true;
      _changed();
    } catch (_) {
      // Keep whatever we had — the form falls back to `pc`.
    }
  }

  /// Re-read the unit list after the admin added/edited one (the product
  /// picker must see it immediately).
  Future<void> reloadUnits() async {
    unitsLoaded = false;
    await refreshUnits();
    await refreshAdminUnits();
  }

  /// `GET /admin/units` - the admin list also shows units that are switched
  /// off (the public list has active ones only), so they can be switched on.
  Future<void> refreshAdminUnits() async {
    if (!backendMode) return;
    try {
      final rows = await Api.instance.admin.listUnits();
      rows.sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        return c != 0 ? c : a.code.compareTo(b.code);
      });
      adminUnits = rows;
      _changed();
    } catch (_) {
      // A non-admin session (403) keeps the public list.
    }
  }

  /// `POST /admin/units` — add a unit of measure. Returns an error or null.
  Future<String?> addUnit({
    required String code,
    required String nameEn,
    String nameGu = '',
    String soldBy = 'UNIT',
  }) async {
    // The server keeps the admin's spelling and matches codes ignoring case.
    final clean = code.trim();
    if (clean.isEmpty) return 'Give the unit a code';
    if (clean.length > 20) return 'Unit code can be at most 20 characters';
    if ((adminUnits.isNotEmpty ? adminUnits : units)
        .any((u) => u.code.toLowerCase() == clean.toLowerCase())) {
      return 'That unit code already exists';
    }
    if (nameEn.trim().isEmpty) return 'Give the unit a name';
    try {
      await Api.instance.admin.createUnit(
        code: clean,
        nameEn: nameEn.trim(),
        nameGu: nameGu.trim(),
        soldBy: soldBy,
        sortOrder: units.length,
      );
      await reloadUnits();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not add the unit.';
    }
  }

  /// `PUT /admin/units/{code}` — rename/reactivate. The code itself is the
  /// key, so it cannot change (products reference it).
  Future<String?> saveUnit(UnitDto unit, {String? oldCode}) async {
    if (unit.nameEn.trim().isEmpty) return 'Give the unit a name';
    final newCode = unit.code.trim();
    if (newCode.isEmpty) return 'Give the unit a code';
    if (newCode.length > 20) return 'Unit code can be at most 20 characters';
    try {
      // A different code renames the unit and moves its products with it.
      await Api.instance.admin.updateUnit(
        oldCode ?? newCode,
        newCode: newCode,
        nameEn: unit.nameEn.trim(),
        nameGu: unit.nameGu.trim(),
        soldBy: unit.soldBy,
        sortOrder: unit.sortOrder,
        active: unit.active,
      );
      await reloadUnits();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save the unit.';
    }
  }

  /// `DELETE /admin/units/{code}` — remove an unused unit. The backend
  /// refuses while a product still sells in it, and that message is surfaced
  /// verbatim (no silent failure).
  Future<String?> removeUnit(String code) async {
    try {
      await Api.instance.admin.deleteUnit(code);
      await reloadUnits();
      return null;
    } on ApiException catch (e) {
      if (e.code == 'UNIT_IN_USE') {
        final n = e.details?['products'];
        return '${n ?? 'Some'} product${n == 1 ? '' : 's'} still use this unit. '
            'Switch it off instead of deleting it.';
      }
      return e.message;
    } catch (_) {
      return 'Could not delete the unit.';
    }
  }

  /// Active unit codes, sorted — what the product editor offers.
  List<UnitDto> get activeUnits =>
      units.where((u) => u.active).toList(growable: false);

  /// The unit code to store for a pack.
  ///
  /// The backend rejects anything that is not an active unit, so a blank or
  /// unknown value becomes the product's own unit when it is valid, else the
  /// first active unit, else `pc`. Pack *labels* ("500 g") are never units.
  String unitCodeFor(String raw, {String? fallback}) {
    final wanted = raw.trim();
    final active = activeUnits;
    bool known(String code) =>
        code.isNotEmpty && active.any((u) => u.code == code);
    if (known(wanted)) return wanted;
    if (known(fallback ?? '')) return fallback!;
    if (active.isNotEmpty) return active.first.code;
    // Units never loaded (offline / first paint): `pc` is seeded by V9.
    return 'pc';
  }

  // --- admin editors: shop settings, staff, payment methods ---------------

  /// `PUT /admin/shop-settings` — save the store details shown across the app.
  Future<String?> saveShopSettings({
    required String shopName,
    required String address,
    required String phone,
    String gstin = '',
    String stateCode = '',
    String upiId = '',
    String invoicePrefix = '',
    String receiptFooter = '',
    String weighedPrefix = '',
    String weighedMode = 'WEIGHT_GRAMS',
    String details = '',
    String? promise,
    String? shortName,
    String? shopNameGu,
    String? addressGu,
    String? promiseGu,
    String? detailsGu,
  }) async {
    if (shopName.trim().isEmpty) return 'Give the shop a name';
    // Backend: `details` is capped at 500 characters — fail here with a
    // readable message rather than a 400 from the server.
    if (details.trim().length > 500) {
      return 'Shop details must be 500 characters or fewer';
    }
    final name = shopName.trim();
    // Offline demo only: with a backend the force-refresh below updates
    // every screen from the server's answer.
    if (!backendMode) seed.store = StoreInfo(
      name: name,
      nameGu: name,
      phone: phone.trim(),
      phoneHref: phone.replaceAll(RegExp(r'\D'), ''),
      address: address.trim(),
      promise: receiptFooter.isEmpty ? seed.store.promise : receiptFooter,
      logo: seed.store.logo,
      openHours: seed.store.openHours,
    );
    _changed();
    if (!backendMode) return null;
    try {
      await Api.instance.admin.saveShop(
        shopName: name,
        address: address.trim(),
        phone: phone.trim(),
        gstin: gstin.trim(),
        stateCode: stateCode.trim(),
        upiId: upiId.trim(),
        invoicePrefix: invoicePrefix.trim(),
        receiptFooter: receiptFooter.trim(),
        weighedPrefix: weighedPrefix.trim(),
        weighedMode: weighedMode,
        details: details.trim(),
        promise: promise?.trim(),
        shortName: shortName?.trim(),
        shopNameGu: shopNameGu?.trim(),
        addressGu: addressGu?.trim(),
        promiseGu: promiseGu?.trim(),
        detailsGu: detailsGu?.trim(),
      );
      shopSettings = await Api.instance.admin.getShop();
      // Show the change at once: hard-refresh the cached store profile.
      await StoreProfileHub.instance.refresh(force: true);
      _applyStoreProfile();
      _changed();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
      return e.message;
    } catch (_) {
      return 'Could not save the shop settings.';
    }
  }

  /// `GET /admin/staff` → refresh [adminStaff].
  Future<void> refreshStaff() async {
    if (!backendMode) return;
    try {
      adminStaff = await Api.instance.admin.listStaff();
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep the current roster.
    }
  }

  /// `POST /admin/staff` — invite a staff user. Returns an error or null.
  /// Set when the last [addStaff] got 409 `EMAIL_ALREADY_REGISTERED`: the
  /// role of the existing account (`details.role`), else null.
  String? staffConflictRole;

  Future<String?> addStaff({
    required String email,
    required String name,
    String mobile = '',
    bool confirmPromote = false,
  }) async {
    staffConflictRole = null;
    final clean = email.trim();
    final bad = Validators.email(clean, required: true) ??
        Validators.text(name, label: 'Name', required: true, max: 80) ??
        Validators.mobile(mobile.trim());
    if (bad != null) return bad;
    try {
      await Api.instance.admin.createStaff(
        email: clean,
        name: name.trim(),
        mobile: mobile.trim(),
        confirmPromote: confirmPromote,
      );
      await refreshStaff();
      return null;
    } on ApiException catch (e) {
      if (e.isConflict && e.code == 'EMAIL_ALREADY_REGISTERED') {
        staffConflictRole = e.details?['role']?.toString() ?? '';
      }
      apiLastError = e.message;
      _changed();
      return e.message;
    } catch (_) {
      return 'Could not add the staff member.';
    }
  }

  /// `PATCH /admin/staff/{id}` — enable/disable a staff account.
  ///
  /// Returns the error message, or null on success. The roster is re-read so
  /// `StaffViewDto.active` (the server's blocked flag) is what the screen shows.
  Future<String?> setStaffActive(String id, bool active) async {
    if (!backendMode) return null;
    try {
      await Api.instance.admin.setStaffActive(id, active);
      adminStaff = await Api.instance.admin.listStaff();
      _changed();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
      return e.message;
    } catch (_) {
      apiLastError = 'Could not update the staff member.';
      return 'Could not update the staff member.';
    }
  }

  /// Toggle one payment method and persist the whole matrix
  /// (`PUT /admin/payment-methods` takes the full array).
  ///
  /// The backend is the source of truth: it answers 422 `PAYMENT_NOT_CONFIGURED`
  /// when an enabled method has no credentials, and refuses to switch the last
  /// enabled method off. Either way the local toggle is **reverted** so the
  /// screen never shows a state the server rejected.
  Future<void> togglePaymentMethod(String code) async {
    final idx = paymentMethods.indexWhere((m) => m.code == code);
    if (idx < 0) return;
    final before = paymentMethods.map((m) => SettingDto(
          code: m.code,
          enabled: m.enabled,
          configured: m.configured,
        ))
        .toList();
    paymentMethods[idx].enabled = !paymentMethods[idx].enabled;
    _changed();
    if (!backendMode) return;
    try {
      paymentMethods = await Api.instance.admin
          .savePaymentMethods(List.of(paymentMethods));
      _changed();
    } on ApiException catch (e) {
      // Roll back — the server's answer is what checkout will honour.
      paymentMethods = before;
      apiLastError = e.message;
      _changed();
    } catch (_) {
      paymentMethods = before;
      apiLastError = 'Could not save payment methods.';
      _changed();
    }
  }

  // --- product photo + POS attributes -------------------------------------

  /// `POST /admin/products/{id}/image` — multipart upload; on success the
  /// product's art is switched to the served image URL (returned to the
  /// caller so an unsaved draft can preview it too).
  Future<({String? url, String? error})> uploadProductImage(
      String backendId, List<int> bytes, String filename) async {
    if (bytes.isEmpty) return (url: null, error: 'The selected file is empty');
    // Server limits: 5 MB per file; JPEG, PNG or WebP only.
    if (bytes.length > 5 * 1024 * 1024) {
      return (url: null, error: 'The photo is over 5 MB. Choose a smaller one.');
    }
    final ext = filename.toLowerCase().split('.').last;
    if (ext == 'heic' || ext == 'heif') {
      return (url: null, error: 'Use a JPEG, PNG or WebP photo (HEIC is not supported).');
    }
    try {
      // One request: `variants=all` makes the server put the picture on
      // every pack of the product (replacing any existing one).
      final dto = await Api.instance.admin
          .uploadProductImage(backendId, bytes, filename, variants: 'all');
      final url = dto.imageUrl;
      if (url != null && url.isNotEmpty) {
        for (final p in products) {
          if (p.variants.any((v) => v.backendId == backendId)) {
            p.art = url;
            break;
          }
        }
        _changed();
        // Re-read the list so the stored picture on every pack is shown.
        try {
          await refreshAdminProducts();
        } on ApiException {
          // The local row already has the new art; a late refresh is cosmetic.
        }
        return (url: url, error: null);
      }
      return (url: null, error: 'The server did not return an image URL.');
    } on ApiException catch (e) {
      return (url: null, error: uploadErrorMessage(e));
    } catch (_) {
      return (url: null, error: 'Could not upload the image.');
    }
  }

  /// Maps the upload errors (`400 details.fields.file`, codes
  /// `UNSUPPORTED_IMAGE` / `FILE_TOO_LARGE`) to a message for the admin.
  static String uploadErrorMessage(ApiException e) {
    final f = e.fields['file'] ?? ApiException.takeFields()['file'];
    final code = (e.code ?? '').toUpperCase();
    if (code == 'UNSUPPORTED_IMAGE') {
      return f ?? 'The file must be an image (JPEG, PNG or WebP).';
    }
    if (code == 'FILE_TOO_LARGE') {
      return f ?? 'The image is too large (max 5 MB).';
    }
    return f ?? e.message;
  }

  /// `GET /admin/products/{id}/pos` — POS/tax attributes for the editor.
  Future<PosAttributesDto?> loadPosAttributes(String backendId) async {
    try {
      return await Api.instance.admin.getPosAttributes(backendId);
    } catch (_) {
      return null;
    }
  }

  /// `PUT /admin/products/{id}/pos` — save POS/tax attributes.
  Future<String?> savePosAttributes(
    String backendId, {
    required String soldBy,
    String plu = '',
    int gstPercent = 0,
    String hsn = '',
    List<String> barcodes = const [],
  }) async {
    try {
      await Api.instance.admin.savePosAttributes(
        backendId,
        soldBy: soldBy,
        plu: plu.trim(),
        gstPercent: gstPercent,
        hsn: hsn.trim(),
        barcodes: barcodes
            .map((b) => b.trim())
            .where((b) => b.isNotEmpty)
            .toList(),
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save the POS details.';
    }
  }

  // --- POS (counter till) --------------------------------------------------

  /// Catalog from `GET /pos/products` (paise-priced till rows).
  List<PosProductDto> posProducts = [];

  /// Last server-priced ticket from `POST /pos/quote`.
  PosBillViewDto? posBill;

  /// Parked carts from `GET /pos/holds`.
  List<HoldViewDto> posHolds = [];

  /// Today's totals from `GET /pos/reports/day`.
  DayReportDto? posDayReport;

  /// Shop details for the till from `GET /pos/shop`.
  ShopSettingDto? posShop;

  /// Load (or search) the till catalog.
  Future<void> posLoadProducts({String? q}) async {
    if (!backendMode) return;
    try {
      final all = <PosProductDto>[];
      var pg = 0;
      // Page until the backend says there is no more (`hasMore` is exact;
      // `total` stops at 10,000). Older backends fall back to page*size.
      while (pg < 200) {
        final page = await Api.instance.pos.getProducts(q: q, page: pg, size: 50);
        all.addAll(page.items);
        pg++;
        if (page.items.isEmpty) break;
        final more = page.hasMore ?? (pg * 50 < page.total);
        if (!more) break;
      }
      posProducts = all;
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      apiLastError = 'Could not load POS products.';
      _changed();
    }
  }

  /// `GET /pos/barcode/{code}` → the scanned product (null when not found).
  ///
  /// Returns the product AND the quantity the code implies (1 for a pack
  /// barcode, grams for a weighed scale label). On a failure the backend's
  /// reason (e.g. "weighed item: enter the weight") is left in [apiLastError].
  Future<PosScanDto?> posScan(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;
    try {
      final s = await Api.instance.pos.scanBarcode(clean);
      return s.product.productId == null ? null : s;
    } on ApiException catch (e) {
      // 404 = unknown code (cashier searches by name); 400 = a readable
      // reason such as a bad check digit or "weighed item: enter the weight".
      apiLastError = e.statusCode == 404 ? null : e.message;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Machine code (`SHIFT_NOT_OPEN`, `DISCOUNT_NEEDS_APPROVAL`, `OUT_OF_STOCK`
  /// ...) of the last failed [posCharge], so the till can react to it.
  String? posLastErrorCode;

  /// `details.fields` of the last failed till action (sale, return, credit
  /// repayment), e.g. `payments[1].mode`, `refunds[0].mode`, `refundMode`.
  Map<String, String> posLastFieldErrors = const {};

  /// `details` object of the last failed till action (`OUT_OF_STOCK` items,
  /// `CREDIT_LIMIT_EXCEEDED` limit/balance/available, `RETURN_EXCEEDS_SOLD`
  /// returnable ...), so the screen can word the reason with real numbers.
  Map<String, dynamic> posLastErrorDetails = const {};

  // --- POS shifts (cash drawer) -------------------------------------------

  /// The caller's open shift (`GET /pos/shifts/current`), null when none.
  ShiftViewDto? posShift;

  /// True once [posLoadShift] has answered, so the UI can tell "no shift"
  /// from "not asked yet".
  bool posShiftLoaded = false;

  Future<void> posLoadShift() async {
    if (!backendMode) return;
    try {
      posShift = await Api.instance.pos.currentShift();
      posShiftLoaded = true;
      _changed();
    } catch (_) {
      // Keep whatever we had; billing will report SHIFT_NOT_OPEN if needed.
    }
  }

  /// `POST /pos/shifts/open` -> error message or null.
  Future<String?> posOpenShift(int openingFloatPaise) async {
    try {
      posShift = await Api.instance.pos.openShift(openingFloatPaise);
      posShiftLoaded = true;
      _changed();
      return null;
    } on ApiException catch (e) {
      if (e.code == 'SHIFT_ALREADY_OPEN') {
        await posLoadShift();
        return null;
      }
      return e.message;
    } catch (_) {
      return 'Could not open the shift.';
    }
  }

  /// `POST /pos/shifts/close` -> (closed shift, error, errorCode).
  Future<(ShiftViewDto?, String?, String?)> posCloseShift(
      int countedCashPaise, {String? note}) async {
    try {
      final s = await Api.instance.pos
          .closeShift(countedCashPaise, note: note);
      posShift = null;
      posShiftLoaded = true;
      unawaited(posLoadDayReport());
      _changed();
      return (s, null, null);
    } on ApiException catch (e) {
      return (null, e.message, e.code);
    } catch (_) {
      return (null, 'Could not close the shift.', null);
    }
  }

  /// Price the current ticket server-side (GST split, discounts, warnings).
  Future<void> posQuote(
    List<Map<String, dynamic>> items, {
    String? mobile,
    String? coupon,
    Map<String, dynamic>? manualDiscount,
    String? coinMode,
    int? coinPercent,
  }) async {
    if (items.isEmpty) {
      posBill = null;
      _changed();
      return;
    }
    try {
      posBill = await Api.instance.pos.quote(
        items: items,
        customerMobile: mobile,
        couponCode: coupon,
        coinMode: coinMode,
        percent: coinPercent,
        // Preview only: the quote needs no PIN, the sale enforces it.
        manualDiscount: manualDiscount == null
            ? null
            : {
                'amountPaise': manualDiscount['amountPaise'],
                if ('${manualDiscount['reason'] ?? ''}'.trim().isNotEmpty)
                  'reason': manualDiscount['reason'],
              },
      );
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      posBill = null;
      _changed();
    } catch (_) {
      apiLastError = 'Could not price the ticket.';
      _changed();
    }
  }

  /// `POST /pos/sales` — ring up the ticket. Returns the sale (with invoice
  /// number) or null on failure (see [apiLastError]).
  ///
  /// [payments] is the full list of lines — one for a simple sale, several
  /// for a split/hybrid one. They must add up to the bill exactly (the
  /// backend rejects anything else with a readable 400, which is surfaced
  /// through [apiLastError]). [cashTenderedPaise] only applies when one of
  /// the lines is cash.
  Future<SaleRecordDto?> posCharge({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? mobile,
    String? coupon,
    int? cashTenderedPaise,
    Map<String, dynamic>? manualDiscount,
    String? idempotencyKey,
    String? coinMode,
    int? coinPercent,
  }) async {
    if (items.isEmpty) return null;
    posLastErrorCode = null;
    posLastFieldErrors = const {};
    posLastErrorDetails = const {};
    // Normalise before sending so a mode the till derived from a
    // payment-method code (`ONLINE`, `DEBIT_CARD`, …) is stored as one of
    // the backend's four rather than bounced by `PaymentRules`.
    final lines = [
      for (final p in payments)
        {
          ...p,
          'mode': normalizePayMode('${p['mode'] ?? ''}'),
          'amountPaise': (p['amountPaise'] as num?)?.toInt() ?? 0,
        },
    ];
    try {
      final sale = await Api.instance.pos.createSale(
        items: items,
        payments: lines,
        customerMobile: mobile,
        couponCode: coupon,
        coinMode: coinMode,
        percent: coinPercent,
        cashTenderedPaise: cashTenderedPaise,
        manualDiscount: manualDiscount,
        idempotencyKey: idempotencyKey,
      );
      // The till's stock/quotas moved — refresh catalog + day totals.
      posBill = null;
      unawaited(posLoadProducts());
      unawaited(posLoadDayReport());
      if (posShift != null) unawaited(posLoadShift());
      _changed();
      return sale;
    } on ApiException catch (e) {
      apiLastError = e.message;
      posLastErrorCode = e.code;
      posLastFieldErrors = e.fields;
      posLastErrorDetails = e.details ?? const {};
      _changed();
      return null;
    } catch (_) {
      apiLastError = 'The sale could not be recorded.';
      _changed();
      return null;
    }
  }

  /// Printable receipt text for a completed sale.
  Future<ReceiptDto?> posReceipt(String saleId) async {
    try {
      return await Api.instance.pos.getReceipt(saleId);
    } catch (_) {
      return null;
    }
  }

  /// `GET /pos/sales/{id}/returns/{returnId}/receipt` - credit-note text.
  Future<ReceiptDto?> posReturnReceipt(String saleId, String returnId,
      {int width = 32}) async {
    try {
      return await Api.instance.pos.getReturnReceipt(saleId, returnId,
          width: width);
    } catch (_) {
      return null;
    }
  }

  /// `GET /pos/credit/payments/{id}/receipt` - repayment receipt text.
  Future<ReceiptDto?> posCreditReceipt(String paymentId,
      {int width = 32}) async {
    try {
      return await Api.instance.pos.getCreditPaymentReceipt(paymentId,
          width: width);
    } catch (_) {
      return null;
    }
  }

  /// `GET /pos/upi-link` → UPI deep link for the amount to charge.
  Future<String?> posUpiLink(int amountPaise) async {
    try {
      final link = await Api.instance.pos
          .getUpiLink(amountPaise: amountPaise, note: seed.store.name);
      return link.isEmpty ? null : link;
    } catch (_) {
      return null;
    }
  }

  // --- POS holds (parked carts) -------------------------------------------

  Future<void> posLoadHolds() async {
    if (!backendMode) return;
    try {
      posHolds = await Api.instance.pos.getHolds();
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Keep current holds.
    }
  }

  /// Parks the ticket. Returns the error message, or null when it was saved
  /// (the caller must keep the ticket on screen when this returns an error).
  Future<String?> posSaveHold(String label, PosCartDto cart) async {
    try {
      final hold = await Api.instance.pos
          .createHold(label: label, cart: cart.toJson());
      posHolds = [hold, ...posHolds.where((h) => h.id != hold.id)];
      _changed();
      return null;
    } on ApiException catch (e) {
      apiLastError = e.message;
      posLastErrorCode = e.code; // HOLD_LIMIT -> the till opens the holds list
      _changed();
      return e.message;
    } catch (_) {
      apiLastError = 'Could not park the cart.';
      _changed();
      return 'Could not park the cart.';
    }
  }

  /// Why the last [posResumeHold] / [posDeleteHold] failed (the server's own
  /// sentence, e.g. "Held basket not found"), null after a success.
  String? posHoldError;

  /// Resume a held cart → its items, or null when it can't be loaded (the
  /// reason is then in [posHoldError]).
  Future<PosCartDto?> posResumeHold(String id) async {
    posHoldError = null;
    try {
      final hold = await Api.instance.pos.getHold(id);
      return hold.cart;
    } on ApiException catch (e) {
      posHoldError = e.statusCode == 404
          ? 'That parked ticket is already gone (someone resumed or removed it).'
          : e.messageWithRef;
      if (e.statusCode == 404) {
        posHolds = posHolds.where((h) => h.id != id).toList();
        _changed();
      }
      return null;
    } catch (_) {
      posHoldError = 'Could not open the parked ticket.';
      return null;
    }
  }

  /// `DELETE /pos/holds/{id}`. Returns true when the hold is gone. A 404 means
  /// somebody (or an earlier tap) already removed it, which is the outcome the
  /// cashier wanted, so it counts as success; any other failure keeps the
  /// hold in the list and leaves the server's reason in [posHoldError].
  Future<bool> posDeleteHold(String id) async {
    posHoldError = null;
    final before = List<HoldViewDto>.of(posHolds);
    posHolds = posHolds.where((h) => h.id != id).toList();
    _changed();
    try {
      await Api.instance.pos.deleteHold(id);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return true;
      posHolds = before; // restore on failure
      posHoldError = e.statusCode == 403
          ? 'You are not allowed to remove this parked ticket.'
          : e.messageWithRef;
      _changed();
      return false;
    } catch (_) {
      posHolds = before;
      posHoldError = 'Could not reach the server to remove the parked ticket.';
      _changed();
      return false;
    }
  }

  // --- POS till report -----------------------------------------------------

  Future<void> posLoadDayReport({String? date}) async {
    if (!backendMode) return;
    try {
      posDayReport = await Api.instance.pos.getDayReport(date: date);
      _changed();
    } on ApiException catch (e) {
      apiLastError = e.message;
      _changed();
    } catch (_) {
      // Report is decorative; keep the last one.
    }
  }

  Future<void> posLoadShop() async {
    if (!backendMode) return;
    try {
      posShop = await Api.instance.pos.getShop();
      _changed();
    } catch (_) {
      // Till falls back to the store details.
    }
  }

  // --- POS returns + credit collection -------------------------------------

  String _errOf(Object e, String fallback) =>
      e is ApiException ? e.message : fallback;

  /// `GET /pos/sales` - recent sales for the return picker.
  Future<List<SaleRecordDto>> posRecentSales(
      {String? invoiceNo, String? mobile, String? date}) async {
    try {
      return await Api.instance.pos
          .listSales(invoiceNo: invoiceNo, mobile: mobile, date: date);
    } catch (_) {
      return const [];
    }
  }

  /// `GET /pos/sales/{id}` - a fresh copy (carries `returnedQty`).
  Future<SaleRecordDto?> posSale(String id) async {
    try {
      return await Api.instance.pos.getSale(id);
    } catch (_) {
      return null;
    }
  }

  /// `GET /pos/sales/{id}/returns`.
  Future<List<ReturnRecordDto>> posReturnsOf(String saleId) async {
    try {
      return await Api.instance.pos.getReturns(saleId);
    } catch (_) {
      return const [];
    }
  }

  /// `POST /pos/sales/{id}/returns` -> (credit note, error message).
  Future<(ReturnRecordDto?, String?)> posRefund(
    String saleId, {
    required List<Map<String, dynamic>> items,
    String? reason,
    List<Map<String, dynamic>> refunds = const [],
    String? refundMode,
    String? idempotencyKey,
  }) async {
    posLastFieldErrors = const {};
    posLastErrorCode = null;
    posLastErrorDetails = const {};
    try {
      final r = await Api.instance.pos.refund(saleId,
          items: items,
          reason: reason,
          refunds: refunds,
          refundMode: refundMode,
          idempotencyKey: idempotencyKey);
      unawaited(posLoadProducts());
      unawaited(posLoadDayReport());
      return (r, null);
    } catch (e) {
      if (e is ApiException) {
        posLastFieldErrors = e.fields;
        posLastErrorCode = e.code;
        posLastErrorDetails = e.details ?? const {};
      }
      return (null, _errOf(e, 'The return could not be recorded.'));
    }
  }

  /// `GET /pos/credit/account` + `/pos/credit/ledger` -> (account, ledger, error).
  Future<(CreditAccountDto?, List<CreditLedgerEntryDto>, String?)>
      posCreditLookup(String mobile) async {
    try {
      final acc = await Api.instance.pos.getCreditAccount(mobile);
      final led = await Api.instance.pos.getCreditLedger(mobile, size: 10);
      return (acc, led.items, null);
    } catch (e) {
      return (null, const <CreditLedgerEntryDto>[],
          _errOf(e, 'Could not look up that customer.'));
    }
  }

  /// `GET /pos/credit/account?mobile=` for the till's credit panel:
  /// (account, HTTP status, message). 404 means the shop has never seen the
  /// number (credit then still has to be enabled); 0 means no connection.
  Future<(CreditAccountDto?, int, String?)> posCreditAccountOf(
      String mobile) async {
    try {
      final acc = await Api.instance.pos.getCreditAccount(mobile);
      return (acc, 200, null);
    } on ApiException catch (e) {
      return (null, e.statusCode, e.message);
    } catch (_) {
      return (null, 0, 'Could not look up that customer.');
    }
  }

  /// One page of credit accounts for the pickers and the Credit screen
  /// (`GET /admin/credit/accounts`, ADMIN only): (rows, hasMore, error).
  Future<(List<DebtorDto>, bool, String?)> creditAccountsPage({
    required bool outstandingOnly,
    int page = 0,
  }) async {
    try {
      final p = await Api.instance.admin.getCreditAccounts(
          outstandingOnly: outstandingOnly, page: page, size: 50);
      final more = p.hasMore ?? ((page + 1) * 50 < p.total);
      return (p.items, more && p.items.isNotEmpty, null);
    } catch (e) {
      return (const <DebtorDto>[], false,
          _errOf(e, 'Could not load credit customers.'));
    }
  }

  /// `PUT /admin/credit/limit` for the till's one-click "Enable credit":
  /// (account, error). Creates the customer when the shop has never seen the
  /// number. ADMIN only (a cashier gets 403, reported as [forbidden]).
  Future<(CreditAccountDto?, String?, bool)> posEnableCredit(
      String mobile, int limitPaise) async {
    try {
      final acc =
          await Api.instance.admin.approveCreditLimit(mobile.trim(), limitPaise);
      return (acc, null, false);
    } on ApiException catch (e) {
      return (null, e.message, e.statusCode == 403);
    } catch (_) {
      return (null, 'Could not enable credit.', false);
    }
  }

  /// `POST /pos/credit/payments` -> (receipt, error).
  Future<(CreditReceiptDto?, String?)> posCollectCredit({
    required String mobile,
    required List<Map<String, dynamic>> payments,
    String? note,
    String? idempotencyKey,
  }) async {
    posLastFieldErrors = const {};
    try {
      final lines = [
        for (final p in payments)
          {...p, 'mode': normalizePayMode('${p['mode'] ?? ''}')},
      ];
      final r = await Api.instance.pos.collectCredit(
          mobile: mobile,
          payments: lines,
          note: note,
          idempotencyKey: idempotencyKey);
      unawaited(posLoadDayReport());
      return (r, null);
    } catch (e) {
      if (e is ApiException) posLastFieldErrors = e.fields;
      return (null, _errOf(e, 'The payment could not be recorded.'));
    }
  }

  // --- Admin credit (udhar) ------------------------------------------------

  /// Debtor list for the admin Credit screen.
  List<DebtorDto> adminDebtors = [];
  int adminDebtorsTotal = 0;
  CreditReportDto? adminCreditReport;

  /// More pages of the debtor list exist (`hasMore` of the last page).
  bool adminDebtorsHasMore = false;
  int _adminDebtorsPage = 0;
  bool _adminDebtorsDuesOnly = true;

  /// `GET /admin/credit/accounts` (+ `/admin/reports/credit`). Returns an
  /// error message or null. [outstandingOnly] defaults to what the screen
  /// last asked for, so a follow-up refresh after a limit change keeps the
  /// same list.
  Future<String?> adminLoadCredit({bool? outstandingOnly}) async {
    if (!backendMode) return null;
    _adminDebtorsDuesOnly = outstandingOnly ?? _adminDebtorsDuesOnly;
    try {
      final page = await Api.instance.admin.getCreditAccounts(
          outstandingOnly: _adminDebtorsDuesOnly, size: 50);
      adminDebtors = page.items;
      adminDebtorsTotal = page.total;
      adminDebtorsHasMore =
          (page.hasMore ?? (page.items.length < page.total)) &&
              page.items.isNotEmpty;
      _adminDebtorsPage = 0;
      _changed();
      try {
        adminCreditReport = await Api.instance.admin.getCreditReport();
        _changed();
      } catch (_) {
        // Summary is decorative; the list still works.
      }
      return null;
    } catch (e) {
      return _errOf(e, 'Could not load credit accounts.');
    }
  }

  /// Appends the next page of the debtor list. Returns an error or null.
  Future<String?> adminLoadMoreCredit() async {
    if (!backendMode || !adminDebtorsHasMore) return null;
    try {
      final page = await Api.instance.admin.getCreditAccounts(
          outstandingOnly: _adminDebtorsDuesOnly,
          page: _adminDebtorsPage + 1,
          size: 50);
      _adminDebtorsPage++;
      adminDebtors = [...adminDebtors, ...page.items];
      adminDebtorsTotal = page.total;
      adminDebtorsHasMore =
          (page.hasMore ?? (adminDebtors.length < page.total)) &&
              page.items.isNotEmpty;
      _changed();
      return null;
    } catch (e) {
      return _errOf(e, 'Could not load more customers.');
    }
  }

  Future<CreditReportDto?> adminCreditReportFor(String period) async {
    try {
      return await Api.instance.admin.getCreditReport(period: period);
    } catch (_) {
      return null;
    }
  }

  /// Account + ledger for one customer -> (account, ledger, error).
  Future<(CreditAccountDto?, List<CreditLedgerEntryDto>, String?)>
      adminCreditDetail(String customerId) async {
    try {
      final acc = await Api.instance.admin.getCreditAccount(customerId);
      final led = await Api.instance.admin.getCreditLedger(customerId);
      return (acc, led.items, null);
    } catch (e) {
      return (null, const <CreditLedgerEntryDto>[],
          _errOf(e, 'Could not load that account.'));
    }
  }

  /// `PUT /admin/credit/accounts/{id}/limit`; returns an error or null.
  Future<String?> adminSetCreditLimit(String customerId, int limitPaise) async {
    try {
      await Api.instance.admin.setCreditLimit(customerId, limitPaise);
      await adminLoadCredit();
      return null;
    } catch (e) {
      return _errOf(e, 'Could not change the limit.');
    }
  }

  /// `PUT /admin/credit/limit` (by mobile); returns an error or null.
  Future<String?> adminApproveCredit(String mobile, int limitPaise) async {
    try {
      await Api.instance.admin.approveCreditLimit(mobile.trim(), limitPaise);
      await adminLoadCredit();
      return null;
    } catch (e) {
      return _errOf(e, 'Could not approve credit.');
    }
  }

  /// `POST /admin/credit/accounts/{id}/adjust`; returns an error or null.
  Future<String?> adminAdjustCredit(
      String customerId, int amountPaise, String note) async {
    try {
      await Api.instance.admin.adjustCredit(customerId, amountPaise, note);
      await adminLoadCredit();
      return null;
    } catch (e) {
      return _errOf(e, 'Could not adjust the balance.');
    }
  }

  // --- Reviews -------------------------------------------------------------

  /// `GET /products/{packId}/reviews/mine`; null when signed out / offline.
  Future<MyReviewDto?> myReviewFor(String packId) async {
    if (!backendMode || packId.isEmpty) return null;
    try {
      return await Api.instance.catalog.getMyReview(packId);
    } catch (_) {
      return null;
    }
  }

  /// `yyyy-MM-dd` -> a UTC ISO instant (`...Z`, what the backend's `Instant`
  /// fields expect), or null when empty (means "evergreen"). The shop works in
  /// India time, so a start is 00:00 IST of that day and an end
  /// ([endOfDay]) is 23:59:59 IST - a coupon "valid till 30 Nov" then stays
  /// valid through that whole day instead of ending at 05:30 IST.
  String? _isoDay(String day, {bool endOfDay = false}) {
    final t = day.trim();
    final d = DateTime.tryParse(t);
    if (t.isEmpty || d == null) return null;
    final ist = DateTime.utc(d.year, d.month, d.day, endOfDay ? 23 : 0,
        endOfDay ? 59 : 0, endOfDay ? 59 : 0);
    final utc = ist.subtract(const Duration(hours: 5, minutes: 30));
    return utc.toIso8601String().replaceFirst(RegExp(r'\.\d+'), '');
  }

  void resetDemo() {
    resetAll();
    // A reset also forgets the persisted device basket, otherwise the next
    // bootstrap would quietly re-apply it and the reset would not stick.
    if (ApiConfig.isLive) {
      CartStore.clear();
      _pendingCart = const [];
      _pendingCoupon = null;
    }
    // Backend mode: "reset" means re-sync from the server (the demo seed is
    // replaced immediately by live data anyway).
    if (backendMode) {
      unawaited(isBackendAdmin ? bootstrapAdmin() : bootstrapCustomer());
    }
  }
}
