import 'package:flutter/material.dart';

import '../nav/nav.dart';
import '../provider/state_scope.dart';
import '../screens/admin/admin_coin_rules_screen.dart';
import '../screens/admin/admin_counter_desk_screen.dart';
import '../screens/admin/admin_shift_screen.dart';
import '../screens/admin/admin_bank_screen.dart';
import '../screens/admin/admin_purchases_screen.dart';
import '../screens/admin/admin_stock_lots_screen.dart';
import '../screens/admin/admin_labels_screen.dart';
import '../screens/admin/admin_gst_master_screen.dart';
import '../screens/admin/admin_coupons_screen.dart';
import '../screens/admin/admin_credit_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_flash_sales_screen.dart';
import '../screens/admin/admin_hot_sale_screen.dart';
import '../screens/admin/admin_inventory_screen.dart';
import '../screens/admin/admin_more_screen.dart';
import '../screens/admin/admin_profile_screen.dart';
import '../screens/admin/admin_system_screen.dart';
import '../screens/admin/admin_order_detail_screen.dart';
import '../screens/admin/admin_orders_screen.dart';
import '../screens/admin/admin_payment_methods_screen.dart';
import '../screens/admin/admin_pos_screen.dart';
import '../screens/admin/admin_push_screen.dart';
import '../screens/admin/admin_product_edit_screen.dart';
import '../screens/admin/admin_reports_screen.dart';
import '../screens/admin/admin_shop_settings_screen.dart';
import '../screens/admin/admin_staff_screen.dart';
import '../screens/admin/admin_customers_screen.dart';
import '../screens/admin/admin_stock_ops_screen.dart';
import '../screens/admin/admin_stock_report_screen.dart';
import '../screens/admin/admin_categories_screen.dart';
import '../screens/admin/admin_units_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/checkout_screen.dart';
import '../screens/customer/home_screen.dart';
import '../screens/customer/missing_screen.dart';
import '../screens/customer/orders_screen.dart';
import '../screens/customer/placed_screen.dart';
import '../screens/customer/product_screen.dart';
import '../screens/customer/profile_screen.dart';
import '../screens/customer/shop_screen.dart';
import '../screens/customer/setup_screen.dart';
import '../screens/customer/signin_screen.dart';
import '../screens/customer/splash_screen.dart';
import '../screens/customer/track_screen.dart';
import '../screens/customer/wallet_screen.dart';
import '../screens/customer/welcome_screen.dart';
import '../theme/app_colors.dart';
import '../state/gu_strings.dart';

/// Maps the prototype's hash routes to screen widgets.
///
/// `#/home`, `#/shop?cat=dry&q=amul&hot=1`, `#/product/almonds`,
/// `#/placed/VSM-1044`, `#/admin/order/VSM-1031`, `#/admin/product/new`, …
Widget buildScreen(String route) {
  final qIndex = route.indexOf('?');
  final path = qIndex >= 0 ? route.substring(0, qIndex) : route;
  final query = qIndex >= 0
      ? Uri.splitQueryString(route.substring(qIndex + 1))
      : const <String, String>{};
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();

  if (segs.isEmpty) return const SplashScreen();

  switch (segs.first) {
    // ---- customer ----
    case 'splash':
      return const SplashScreen();
    case 'welcome':
      return const WelcomeScreen();
    case 'signin':
      return const SigninScreen();
    // First-time login: collect the profile the new account is still missing
    // and announce the store's first-order offer.
    case 'setup':
      return const SetupScreen();
    case 'home':
      return const HomeScreen();
    case 'shop':
      return ShopScreen(
        query: query['q'] ?? '',
        category: query['cat'] ?? '',
        hot: query['hot'] == '1',
      );
    case 'product':
      if (segs.length < 2) {
        return MissingScreen(
          title: gt('Product'),
          copy: gt('This product is no longer in the catalogue.'),
          backRoute: '/shop',
        );
      }
      return ProductScreen(productId: segs[1]);
    case 'cart':
      return const CartScreen();
    // Account pages: a signed-out visitor is sent to sign-in (and brought
    // back here afterwards) instead of seeing an empty customer area.
    case 'checkout':
      return _CustomerGuard(route: route, child: const CheckoutScreen());
    case 'placed':
      return _CustomerGuard(
          route: route,
          child: PlacedScreen(number: segs.length > 1 ? segs[1] : ''));
    case 'track':
      return _CustomerGuard(
          route: route,
          child: TrackScreen(number: segs.length > 1 ? segs[1] : ''));
    case 'orders':
      return _CustomerGuard(route: route, child: const OrdersScreen());
    case 'wallet':
      return _CustomerGuard(route: route, child: const WalletScreen());
    case 'profile':
      return _CustomerGuard(route: route, child: const ProfileScreen());

    // ---- admin ----
    case 'admin':
      return _AdminGuard(
        page: segs.length > 1 ? segs[1] : '',
        child: _adminScreen(segs, query),
      );
  }

  return MissingScreen(
    copy: gt('That page could not be found.'),
    backRoute: '/home',
  );
}

/// Keeps the account pages (profile, wallet, orders, checkout, tracking) out
/// of reach of a signed-out visitor. Browsing (home, shop, product, cart) is
/// open to guests; adding to the cart needs a sign-in (`ensureSignedIn`). A visitor without a session is sent to `#/signin` and the
/// page they wanted is remembered in [Nav.returnTo].
class _CustomerGuard extends StatelessWidget {
  const _CustomerGuard({required this.child, required this.route});

  final Widget child;
  final String route;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    // Same test as the top bar's guest role (`barRoleOf`).
    if (state.signedIn || state.backendMode) return child;
    // A stored session may still be resolving (`GET /me`): don't bounce yet.
    if (!state.sessionSettled) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.red),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Nav.instance.route != route) return;
      Nav.instance.returnTo = route;
      Nav.instance.replace('/signin');
    });
    return const Center(
      child: CircularProgressIndicator(color: AppColors.red),
    );
  }
}

/// Builds the admin subtree for `#/admin`, `#/admin/orders`,…
Widget _adminScreen(List<String> segs, Map<String, String> query) {
  if (segs.length == 1) return const AdminDashboardScreen();
  switch (segs[1]) {
    case 'orders':
      return AdminOrdersScreen(day: query['day'], view: query['view']);
    case 'order':
      return AdminOrderDetailScreen(number: segs.length > 2 ? segs[2] : '');
    case 'inventory':
      return AdminInventoryScreen(filter: query['filter']);
    case 'product':
      return AdminProductEditScreen(
        productId: segs.length > 2 ? segs[2] : 'new',
      );
    case 'hot-sale':
      return const AdminHotSaleScreen();
    case 'flash-sales':
      return AdminFlashSalesScreen(query: query);
    case 'push':
      return AdminPushScreen(query: query);
    case 'coupons':
      return AdminCouponsScreen(
        isNew: query['new'] == '1',
        editCode: query['edit'],
      );
    case 'coins':
      return const AdminCoinRulesScreen();
    case 'reports':
      return const AdminReportsScreen();
    case 'stock-report':
      return const AdminStockReportScreen();
    case 'counter':
      return AdminCounterDeskScreen(tab: query['tab'] ?? 'shifts');
    case 'more':
      return const AdminMoreScreen();
    case 'profile':
      return const AdminProfileScreen();
    case 'shop-settings':
      return const AdminShopSettingsScreen();
    case 'staff':
      return const AdminStaffScreen();
    case 'customers':
      return const AdminCustomersScreen();
    case 'payments':
      return const AdminPaymentMethodsScreen();
    case 'system':
      return AdminSystemScreen(tab: query['tab'] ?? 'refunds');
    case 'units':
      return const AdminUnitsScreen();
    case 'categories':
      return const AdminCategoriesScreen();
    case 'pos':
      return const AdminPosScreen();
    case 'shift':
      return const AdminShiftScreen();
    case 'bank':
      return AdminBankScreen(query: query);
    case 'purchases':
      return AdminPurchasesScreen(query: query);
    case 'stock-lots':
      return AdminStockLotsScreen(query: query);
    case 'labels':
      return AdminLabelsScreen(query: query);
    case 'gst-master':
      return const AdminGstMasterScreen();
    case 'credit':
      return const AdminCreditScreen();
    case 'stock-ops':
      return const AdminStockOpsScreen();
  }
  return const AdminDashboardScreen();
}

/// Keeps `#/admin/*` out of reach of anyone who is not store staff.
///
/// A live build (`ApiConfig.isLive`) opens the panel exactly as far as the
/// backend's `SecurityConfig` does:
///  * **ADMIN** — every `#/admin/*` page;
///  * **CASHIER** (counter staff) — only the Orders pages
///    (`#/admin/orders`, `#/admin/order/:no`), because those are the only
///    `/admin/**` routes the backend lets a counter role call; anything else
///    would just answer 403.
/// A regular customer is bounced to sign-in; the offline prototype keeps
/// using its local `adminSignedIn` flag.
class _AdminGuard extends StatelessWidget {
  const _AdminGuard({required this.child, required this.page});

  final Widget child;

  /// Route segment after `admin` (`''` for the panel root).
  final String page;

  // Pages a CASHIER may open: the order desk (/admin/orders/**) and the
  // till (/pos/**); every other /admin/** is ADMIN-only on the server.
  static const _ordersPages = {'orders', 'order', 'pos', 'shift', 'flash-sales', 'profile', 'labels'};

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final staffOnOrders =
        state.isAdminAllowed && _ordersPages.contains(page);
    if (state.adminPagesAllowed || staffOnOrders) return child;
    // A persisted session is still being resolved (`GET /me` is in flight).
    // Claiming "admins only" before we know who the visitor is would bounce a
    // valid admin out of `#/admin/*` on every refresh — wait for the answer.
    if (!state.sessionSettled) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.red),
      );
    }
    // Signed in as counter staff, but on a page their role cannot reach:
    // keep them inside the panel, pointed at the Orders screens they do own,
    // instead of throwing their valid session out to sign-in.
    if (state.isAdminAllowed) {
      return MissingScreen(
        title: gt('Staff access'),
        heading: 'Orders are yours',
        copy: gt('Counter staff can work the Orders screens. Ask the store '
            'admin for access to this page.'),
        backRoute: '/admin/orders',
        buttonLabel: 'Go to orders',
        buttonRoute: '/admin/orders',
      );
    }
    return MissingScreen(
      title: gt('Admin sign-in required'),
      heading: 'Store admins only',
      copy: gt('Sign in with a store-admin account to open the panel.'),
      backRoute: '/signin',
      buttonLabel: 'Go to sign in',
      buttonRoute: '/signin',
    );
  }
}
