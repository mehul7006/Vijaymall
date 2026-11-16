import 'admin_api.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'auth_api.dart';
import 'cart_api.dart';
import 'catalog_api.dart';
import 'credit_api.dart';
import 'flash_api.dart';
import 'ops_api.dart';
import 'orders_api.dart';
import 'pos_api.dart';
import 'push_api.dart';
import 'session_store.dart';
import 'wallet_api.dart';

/// App-wide API facade. Construct once (see `Api.configure`) and read it via
/// `Api.instance`. Bundles the endpoint groups and the shared wire<->UI
/// mappings (statuses, fulfilment, coin modes, money in paise).
class Api {
  Api._(this.client) {
    auth = AuthApi(client);
    admin = AdminApi(client);
    catalog = CatalogApi(client);
    orders = OrdersApi(client);
    wallet = WalletApi(client);
    credit = CreditApi(client);
    pos = PosApi(client);
    cart = CartApi(client);
    ops = OpsApi(client);
    flash = FlashApi(client);
    push = PushApi(client);
  }

  static Api? _instance;

  /// Configure (or re-configure, e.g. with a new base URL) the singleton.
  static Api configure({String? baseUrl, ApiClient? client}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      ApiConfig.setBaseUrl(baseUrl);
    }
    _instance = Api._(client ?? ApiClient());
    return _instance!;
  }

  static Api get instance {
    return _instance ??= Api._(ApiClient());
  }

  static bool get isConfigured => _instance != null;

  final ApiClient client;
  late final AuthApi auth;
  late final AdminApi admin;
  late final CatalogApi catalog;
  late final OrdersApi orders;
  late final WalletApi wallet;
  late final CreditApi credit;
  late final PosApi pos;
  late final CartApi cart;
  late final OpsApi ops;
  late final FlashApi flash;
  late final PushApi push;

  SessionStore get session => SessionStore.instance;
}

// ---------------------------------------------------------------------------
// Status / enum mappings (frontend Title Case <-> backend SCREAMING_SNAKE)
// ---------------------------------------------------------------------------

const Map<String, String> _statusToWire = {
  'Placed': 'PLACED',
  'Confirmed': 'CONFIRMED',
  'Packed': 'PACKED',
  'Ready for Pickup': 'READY_FOR_PICKUP',
  'Out for Delivery': 'OUT_FOR_DELIVERY',
  'Delivered': 'DELIVERED',
  'Picked Up': 'PICKED_UP',
  'Cancelled': 'CANCELLED',
};

const Map<String, String> _statusFromWire = {
  'PAYMENT_PENDING': 'Placed',
  'PLACED': 'Placed',
  'CONFIRMED': 'Confirmed',
  'PACKED': 'Packed',
  'READY_FOR_PICKUP': 'Ready for Pickup',
  'OUT_FOR_DELIVERY': 'Out for Delivery',
  'DELIVERED': 'Delivered',
  'PICKED_UP': 'Picked Up',
  'CANCELLED': 'Cancelled',
};

/// Frontend 'Placed' -> wire 'PLACED'.
String statusToWire(String status) =>
    _statusToWire[status] ?? status.toUpperCase().replaceAll(' ', '_');

/// Wire 'READY_FOR_PICKUP' -> frontend 'Ready for Pickup'.
String statusFromWire(String? wire) {
  if (wire == null || wire.isEmpty) return '';
  return _statusFromWire[wire.toUpperCase()] ?? wire;
}

const Map<String, String> _fulfilToWire = {
  'delivery': 'DELIVERY',
  'pickup': 'PICKUP',
};

const Map<String, String> _fulfilFromWire = {
  'DELIVERY': 'delivery',
  'PICKUP': 'pickup',
};

String fulfilToWire(String mode) =>
    _fulfilToWire[mode] ?? mode.toUpperCase();

String fulfilFromWire(String? wire) {
  if (wire == null || wire.isEmpty) return 'delivery';
  return _fulfilFromWire[wire.toUpperCase()] ?? wire.toLowerCase();
}

/// Frontend coin rule mode 'pro-rata'|'slab' -> wire 'PRO_RATA'|'SLAB'.
String coinModeToWire(String mode) {
  final m = mode.toLowerCase();
  if (m == 'slab') return 'SLAB';
  if (m == 'pro-rata' || m == 'prorata' || m == 'pro_rata') return 'PRO_RATA';
  return m.toUpperCase();
}

/// Wire 'PRO_RATA'|'SLAB' -> frontend 'pro-rata'|'slab'.
String coinModeFromWire(String? wire) {
  final m = (wire ?? '').toUpperCase();
  if (m == 'SLAB') return 'slab';
  return 'pro-rata';
}

/// Coupon kind: frontend 'flat'|'percent' -> wire 'FLAT'|'PERCENT'.
String couponKindToWire(String type) =>
    type.toLowerCase() == 'percent' ? 'PERCENT' : 'FLAT';

/// Wire kind -> frontend 'flat'|'percent'.
String couponKindFromWire(String? kind) =>
    (kind ?? '').toUpperCase() == 'PERCENT' ? 'percent' : 'flat';

// ---------------------------------------------------------------------------
// Money: backend paise <-> frontend rupees
// ---------------------------------------------------------------------------

int rupeesToPaise(num rupees) => (rupees * 100).round();
num paiseToRupees(num paise) => paise % 100 == 0 ? (paise ~/ 100) : paise / 100;
