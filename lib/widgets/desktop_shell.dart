import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../nav/nav.dart';
import 'rich_backdrop.dart';
import '../provider/state_scope.dart';
import '../screens/customer/sheets/addresses_sheet.dart';
import '../screens/customer/sheets/notifications_sheet.dart';
import '../data/seed_data.dart' as seed;
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../data/store_profile_cache.dart';
import 'admin_alerts.dart';
import 'hover_label.dart';
import 'popover.dart';
import 'profile_menu.dart';
import 'app_icon.dart';
import '../state/gu_strings.dart';

/// Wide-screen (≥900px) chrome — the app renders as a real website instead of
/// a phone card: a fixed site header, an admin sidebar on admin routes and a
/// centered content column. Below 900px `main.dart` keeps the phone layout.
class DesktopShell extends StatelessWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  /// Width at which the phone frame is replaced by the site chrome.
  static const double breakpoint = 900;

  static bool isWide(double width) => width >= breakpoint;

  /// Web always renders as a real website (full display, no phone card);
  /// native builds switch to the site chrome at [breakpoint].
  static bool useSiteChrome(double width) => kIsWeb || width >= breakpoint;

  static const List<String> _authRoutes = ['/splash', '/welcome', '/signin'];

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    // MaterialApp injects its debug `_errorTextStyle` (red text with a yellow
    // double underline — "consider putting your text in a Material") as the
    // root DefaultTextStyle. This shell sits in `MaterialApp.builder`, i.e.
    // ABOVE the Navigator where each screen's Scaffold normally provides the
    // Material text style — so header/sidebar texts that set their own
    // colour/font but not `decoration` were leaking the yellow underline.
    // A proper base DefaultTextStyle (decoration cleared) fixes that.
    final baseStyle = (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
        .copyWith(decoration: TextDecoration.none);
    return DefaultTextStyle(
      style: baseStyle,
      child: ListenableBuilder(
      listenable: Nav.instance,
      builder: (context, _) {
        final path = Nav.instance.route.split('?').first;
        if (_authRoutes.contains(path)) {
          return _AuthFrame(route: path, child: child);
        }
        final adminRoute = path == '/admin' || path.startsWith('/admin/');
        // Admin chrome is only drawn for a session that may open the panel;
        // anyone else (signed out, or a regular customer) is bounced to
        // sign-in instead of seeing the store's admin navigation.
        //
        // The bounce waits for `sessionSettled`: `GET /me` has not answered
        // on the first frame after a refresh, so an admin would otherwise be
        // misread as a visitor and thrown out of their own panel on reload.
        final isAdmin = adminRoute && state.isAdminAllowed;
        if (adminRoute && !isAdmin && state.sessionSettled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Nav.instance.route.split('?').first == path) go('/signin');
          });
        }
        // A popover belongs to the page it was opened on.
        if (path != _shellLastPath) {
          _shellLastPath = path;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            closeActivePopover();
          });
        }
        final winW = MediaQuery.sizeOf(context).width;
        final showSidebar = isAdmin && DesktopShell.isWide(winW);
        final maxContent = isAdmin ? 1400.0 : 1600.0;
        return RichBackdrop(
          child: Column(
            children: [
              _SiteHeader(isAdmin: isAdmin, route: path, state: state),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showSidebar)
                      _AdminSidebar(route: Nav.instance.route, state: state),
                    Expanded(
                      // Same container as the title bar: customer pages are
                      // centred in 1200 px, admin pages start right beside the
                      // sidebar (no stray centering).
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth < maxContent
                              ? c.maxWidth
                              : maxContent;
                          return Align(
                            alignment: isAdmin
                                ? Alignment.topLeft
                                : Alignment.topCenter,
                            child: SizedBox(
                              width: w,
                              height: c.maxHeight,
                              child: child,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }
}

String _shellLastPath = '';

/// Auth screens render full-bleed on the web — splash stays a centered
/// column, while welcome/sign-in fill the whole display with their own
/// two-column web layout (no phone frame, no side padding).
class _AuthFrame extends StatelessWidget {
  final String route;
  final Widget child;

  const _AuthFrame({required this.route, required this.child});

  @override
  Widget build(BuildContext context) {
    if (route == '/splash') {
      return ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: SizedBox(
            width: 520,
            height: double.infinity,
            child: child,
          ),
        ),
      );
    }
    return ColoredBox(color: AppColors.bg, child: child);
  }
}

/// `.site-header` — the one top bar for every screen width and every role.
///
///  * customer: white bar — menu, store logo + name (never clipped: it is the
///    flexible part), links, "deliver to", notification bell, cart and the
///    profile avatar;
///  * admin: deep-navy bar with an "ADMIN" chip; staff (cashier): teal bar
///    with a "STAFF" chip, so the role is obvious at a glance.
///
/// Customer content is held to the same 16 px gutters and the same 1200 px
/// container as the page below it, so the brand lines up with the page's left
/// edge; admin bars run full width above the sidebar.
class _SiteHeader extends StatelessWidget {
  final bool isAdmin;
  final String route;
  final AppState state;

  const _SiteHeader({
    required this.isAdmin,
    required this.route,
    required this.state,
  });

  bool _active(String target) {
    if (target == '/admin') return route == '/admin';
    return route == target || route.startsWith('$target/');
  }

  /// Headline shown beside the main logo on admin routes.
  static String _adminTitleFor(String route) {
    if (route == '/admin') return 'Dashboard';
    if (route.startsWith('/admin/order/')) return 'Order';
    if (route.startsWith('/admin/orders')) return 'Orders';
    if (route.startsWith('/admin/inventory')) return 'Inventory';
    if (route.startsWith('/admin/hot-sale')) return 'Hot sale';
    if (route.startsWith('/admin/flash-sales')) return 'Flash sales';
    if (route.startsWith('/admin/gst-master')) return 'GST and HSN master';
    if (route.startsWith('/admin/purchases')) return 'Purchases & suppliers';
    if (route.startsWith('/admin/bank')) return 'Bank and settlements';
    if (route.startsWith('/admin/push')) return 'Push notifications';
    if (route.startsWith('/admin/coupons')) return 'Coupons';
    if (route.startsWith('/admin/coin-rules')) return 'Coin rules';
    if (route.startsWith('/admin/reports/stock')) return 'Stock movement';
    if (route.startsWith('/admin/reports')) return 'Reports';
    if (route.startsWith('/admin/profile')) return 'My profile';
    if (route.startsWith('/admin/more')) return 'More';
    return 'Owner console';
  }

  @override
  Widget build(BuildContext context) {
    final gu = state.lang == 'gu';
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final compact = width < 600;
    final inlineLinks = width >= 1180;
    final roomy = width >= 1320;
    final showSearch = width >= 1500;
    final role = barRoleOf(state);
    final staffBar = isAdmin && role == BarRole.staff;
    final barRole = isAdmin
        ? (role == BarRole.staff ? BarRole.staff : BarRole.admin)
        : role;
    final dark = isAdmin;
    final h = compact ? 64.0 : 76.0;
    final gap = compact ? 6.0 : 10.0;
    final address = state.addresses.isEmpty
        ? null
        : state.addresses.firstWhere(
            (a) => a.id == state.flow.selectedAddressId,
            orElse: () => state.addresses.first,
          );

    final brand = _Brand(
      isAdmin: isAdmin,
      compact: compact,
      gu: gu,
      role: barRole,
      onTap: () => go(isAdmin ? '/admin' : '/home'),
    );

    // ---- right-hand actions (identical order on every width) ----
    final actions = <Widget>[
      if (wide) _LangToggle(state: state, dark: dark),
      Builder(
        builder: (anchor) => _HeaderBadge(
          icon: 'bell',
          count: isAdmin ? state.newOrderCount() : state.inboxUnread,
          tooltip: isAdmin
              ? gt('New orders')
              : (gu ? 'સૂચનાઓ' : 'Notifications'),
          dark: dark,
          size: compact ? 40 : 42,
          onTap: () => isAdmin
              ? showAdminAlertsFromBar(anchor)
              : showNotificationsFromBar(anchor),
        ),
      ),
      if (!isAdmin)
        _HeaderBadge(
          icon: 'cart',
          count: state.cartCount(),
          tooltip: gu ? 'કાર્ટ' : 'Cart',
          size: compact ? 40 : 42,
          onTap: () => go('/cart'),
        ),
      ProfileAvatarButton(
        adminRoute: isAdmin,
        onBar: dark,
        size: compact ? 40 : 42,
      ),
    ];
    Widget actionRow() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              actions[i],
            ],
          ],
        );

    // ---- left / middle part ----
    final List<Widget> lead;
    if (isAdmin) {
      if (wide) {
        lead = [
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340), child: brand),
          const SizedBox(width: 16),
          Container(
              width: 1,
              height: 28,
              color: Colors.white.withValues(alpha: .28)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              gt(_adminTitleFor(route)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 20,
                height: 1.1,
                letterSpacing: -.02,
                color: AppColors.white,
              ),
            ),
          ),
          SizedBox(width: gap),
        ];
      } else {
        lead = [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: brand)),
          SizedBox(width: gap),
        ];
      }
    } else if (inlineLinks) {
      lead = [
        _HeaderMenuBtn(onTap: () => showStoreDrawer(context)),
        const SizedBox(width: 12),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260), child: brand),
        const SizedBox(width: 20),
        _NavLink(
            label: gu ? 'હોમ' : 'Home',
            target: '/home',
            active: _active('/home')),
        _NavLink(
            label: gu ? 'દુકાન' : 'Shop',
            target: '/shop',
            active: _active('/shop')),
        _NavLink(
            label: gu ? 'ઓર્ડર' : 'Orders',
            target: '/orders',
            active: _active('/orders')),
        _NavLink(
            label: gu ? 'કોઈન્સ' : 'Coins',
            target: '/wallet',
            active: _active('/wallet')),
        Expanded(
          child: LayoutBuilder(builder: (context, room) {
            // Not enough room left after links + actions: drop the pill
            // rather than overflow the bar.
            if (room.maxWidth < 150) return const SizedBox.shrink();
            return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSearch) ...[
                    const _HeaderSearch(),
                    const SizedBox(width: 14),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 270),
                      child: _DeliverPill(
                        label: address == null
                            ? (gu ? 'સરનામું ઉમેરો' : 'Add an address')
                            : '${address.label} · ${address.full.split(',').first.trim()}',
                        caption: gu ? 'ડિલિવરી સરનામું' : 'Deliver to',
                        showText: roomy,
                        onTap: () {
                          final ctx = rootSheetContext;
                          if (ctx != null) showAddressSheet(ctx);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          }),
        ),
      ];
    } else {
      lead = [
        if (!compact) ...[
          _HeaderMenuBtn(onTap: () => showStoreDrawer(context)),
          const SizedBox(width: 12),
        ],
        Expanded(child: Align(alignment: Alignment.centerLeft, child: brand)),
        SizedBox(width: gap),
      ];
    }

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [...lead, actionRow()],
      ),
    );
    if (!isAdmin) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: content,
        ),
      );
    }

    final pal = SectionPalette.forRoute(route);
    return Container(
      height: h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isAdmin ? null : AppColors.white,
        gradient: isAdmin
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: staffBar
                    ? const [
                        Color(0xFF063F3B),
                        AppColors.staffBar,
                        Color(0xFF14958B)
                      ]
                    : const [
                        Color(0xFF1F2A6B),
                        Color(0xFF2B3A9A),
                        Color(0xFF3447B5)
                      ],
                stops: const [0.0, 0.55, 1.0],
              )
            : null,
        border: isAdmin
            ? Border(
                bottom: BorderSide(
                    color: (staffBar ? AppColors.gold2 : pal.glow)
                        .withValues(alpha: .85),
                    width: 2.5))
            : const Border(bottom: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF121A47).withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: isAdmin
          ? Stack(children: [
              // soft light from the top-left, no lines
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.9, -1.6),
                        radius: 1.1,
                        colors: [
                          Colors.white.withValues(alpha: .10),
                          Colors.white.withValues(alpha: 0)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              content,
            ])
          : content,
    );
  }
}

/// Store logo + name (from the store profile) and, on staff bars, the role
/// chip. The name is the flexible part: it ellipsises instead of clipping the
/// buttons next to it.
class _Brand extends StatelessWidget {
  final bool isAdmin;
  final bool compact;
  final bool gu;
  final BarRole role;
  final VoidCallback onTap;

  const _Brand({
    required this.isAdmin,
    required this.compact,
    required this.gu,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hub = StoreProfileHub.instance;
    final logo = compact ? 34.0 : 40.0;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final p = hub.profile;
        final name = (p != null && p.shopName.trim().isNotEmpty)
            ? p.shopName.trim()
            : seed.store.name;
        final sub = isAdmin
            ? (role == BarRole.staff
                ? (gu ? 'સ્ટાફ કન્સોલ' : 'Staff console')
                : (gu ? 'ઓનર કન્સોલ' : 'Owner console'))
            : (gu
                ? '${seed.storeLocality()} · મફત ડિલિવરી'
                : '${seed.storeLocality()} · Free delivery');
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: logo,
                  height: logo,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(logo * .24),
                    border: isAdmin
                        ? Border.all(color: Colors.white.withValues(alpha: .4))
                        : null,
                  ),
                  child: LogoMark(size: logo, color: AppColors.white),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontSize: compact ? 16 : 19,
                          height: 1.1,
                          color: isAdmin ? AppColors.white : AppColors.ink,
                        ),
                      ),
                      if (!compact)
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 10,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: isAdmin
                                ? AppColors.white.withValues(alpha: .86)
                                : AppColors.ink3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  RoleChip(role, onBar: true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Menu button that slides the storefront drawer in — the customer-side twin
/// of the admin sidebar.
class _HeaderMenuBtn extends StatefulWidget {
  final VoidCallback onTap;

  const _HeaderMenuBtn({required this.onTap});

  @override
  State<_HeaderMenuBtn> createState() => _HeaderMenuBtnState();
}

class _HeaderMenuBtnState extends State<_HeaderMenuBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _hover ? AppColors.navyTint : AppColors.bg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.line),
          ),
          child: const Center(
            child: AppIcon('filter', size: 19, color: AppColors.ink, sw: 1.7),
          ),
        ),
      ),
    );
  }
}

/// `.deliver-to` pill — pin + selected address, opens the address sheet.
class _DeliverPill extends StatefulWidget {
  final String label;
  final String caption;
  final bool showText;
  final VoidCallback onTap;

  const _DeliverPill({
    required this.label,
    required this.caption,
    required this.showText,
    required this.onTap,
  });

  @override
  State<_DeliverPill> createState() => _DeliverPillState();
}

class _DeliverPillState extends State<_DeliverPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover ? AppColors.redTint : AppColors.bg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: _hover ? AppColors.red.withValues(alpha: .3) : AppColors.line),
          ),
          child: Row(
            // Shrinks with its `Flexible` wrapper in the site header instead
            // of pushing the header Row past the window width.
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon('pin', size: 16, color: AppColors.red),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 8.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Narrow windows keep just the caption so the pill never
                    // pushes the header Row past the window width.
                    if (widget.showText)
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const AppIcon('down', size: 11, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Storefront drawer — the customer twin of the admin sidebar: navy panel,
/// brand block, menu links and the store-status footer.
void showStoreDrawer(BuildContext context) {
  final overlay = rootNavKey.currentState?.overlay;
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _StoreDrawer(onClose: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _StoreDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const _StoreDrawer({required this.onClose});

  @override
  State<_StoreDrawer> createState() => _StoreDrawerState();
}

class _StoreDrawerState extends State<_StoreDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final route = Nav.instance.route;

    bool active(String target) =>
        route == target || route.startsWith('$target/');

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // scrim
          GestureDetector(
            onTap: _close,
            child: FadeTransition(
              opacity: _curve,
              child: Container(
                color: const Color(0x9914162B),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SlideTransition(
              position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
                  .animate(_curve),
              child: Container(
                width: 292,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1F2A6B),
                      Color(0xFF2B3A9A),
                      Color(0xFF3447B5)
                    ],
                    stops: [0.0, .6, 1.0],
                  ),
                  border: Border(
                      right: BorderSide(color: Color(0x55F5B301), width: 2)),
                ),
                foregroundDecoration: const BoxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // brand block
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 12, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .15),
                              ),
                            ),
                            child: const Center(
                              child:
                                  LogoMark(size: 24, color: AppColors.gold2),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  seed.store.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.displayFont,
                                    fontSize: 16,
                                    height: 1.1,
                                    color: AppColors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  gu ? 'સ્ટોર ફ્રન્ટ' : 'Store front',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 10,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _close,
                            child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const AppIcon('back',
                                  size: 15, color: AppColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        color: Colors.white12, height: 1, thickness: 1),
                    const SizedBox(height: 10),

                    _DrawerSectionLabel(gu ? 'મેનુ' : 'MENU'),
                    _DrawerLink(
                      icon: 'home',
                      label: gu ? 'હોમ' : 'Home',
                      target: '/home',
                      active: active('/home'),
                      onClose: _close,
                    ),
                    _DrawerLink(
                      icon: 'box',
                      label: gu ? 'દુકાન' : 'Shop',
                      target: '/shop',
                      active: active('/shop'),
                      onClose: _close,
                    ),
                    _DrawerLink(
                      icon: 'cart',
                      label: gu ? 'કાર્ટ' : 'Cart',
                      target: '/cart',
                      active: active('/cart'),
                      badge: state.cartCount(),
                      onClose: _close,
                    ),
                    _DrawerLink(
                      icon: 'cart',
                      label: gu ? 'મારા ઓર્ડર' : 'My orders',
                      target: '/orders',
                      active: active('/orders'),
                      onClose: _close,
                    ),

                    const SizedBox(height: 10),
                    _DrawerSectionLabel(gu ? 'વૉલેટ અને ખાતું' : 'WALLET & ACCOUNT'),
                    _DrawerLink(
                      icon: 'coin',
                      label: gu ? 'કોઈન્સ' : 'Coins',
                      target: '/wallet',
                      active: active('/wallet'),
                      badge: state.coinBalance() > 0 ? state.coinBalance() : null,
                      onClose: _close,
                    ),
                    _DrawerLink(
                      icon: 'user',
                      label: gu ? 'પ્રોફાઇલ' : 'Profile',
                      target: '/profile',
                      active: active('/profile'),
                      onClose: _close,
                    ),

                    const Spacer(),

                    // footer
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .14),
                        border: const Border(
                          top: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                gu
                                    ? 'દુકાન ખુલ્લી · 9–9'
                                    : 'Store open · 9–9',
                                style: const TextStyle(
                                  fontFamily: AppTheme.uiFont,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _close();
                              go('/welcome');
                            },
                            child: Text(
                              gu
                                  ? '${seed.store.nameGu} · ${seed.storeLocality()}'
                                  : '${seed.store.name} · ${seed.storeLocality()}',
                              style: TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 10,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: .55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  final String text;

  const _DrawerSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: .45),
        ),
      ),
    );
  }
}

class _DrawerLink extends StatefulWidget {
  final String icon;
  final String label;
  final String target;
  final bool active;
  final int? badge;
  final VoidCallback onClose;

  const _DrawerLink({
    required this.icon,
    required this.label,
    required this.target,
    required this.active,
    this.badge,
    required this.onClose,
  });

  @override
  State<_DrawerLink> createState() => _DrawerLinkState();
}

class _DrawerLinkState extends State<_DrawerLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active || _hover
        ? AppColors.white
        : Colors.white.withValues(alpha: .82);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            go(widget.target);
            widget.onClose();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.active
                  ? Colors.white.withValues(alpha: .13)
                  : _hover
                      ? Colors.white.withValues(alpha: .07)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: widget.active
                  ? Border.all(color: Colors.white.withValues(alpha: .12))
                  : null,
            ),
            child: Row(
              children: [
                AppIcon(
                  widget.icon,
                  size: 19,
                  color: widget.active ? AppColors.gold2 : color,
                  sw: 1.7,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13.5,
                      fontWeight: widget.active ? FontWeight.w800 : FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (widget.badge != null && widget.badge! > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.active
                          ? AppColors.gold2
                          : Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.badge}',
                      style: TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: widget.active ? AppColors.navy : AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _NavLink extends StatefulWidget {
  final String label;
  final String target;
  final bool active;

  const _NavLink({
    required this.label,
    required this.target,
    required this.active,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? AppColors.red
        : _hover
            ? AppColors.ink
            : AppColors.ink2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => go(widget.target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.active
                ? AppColors.redTint
                : _hover
                    ? AppColors.bg
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13,
              fontWeight: widget.active ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Header search box — submits into `#/shop?q=…` like the prototype search.
class _HeaderSearch extends StatefulWidget {
  const _HeaderSearch();

  @override
  State<_HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<_HeaderSearch> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Nav.instance.addListener(_syncWithRoute);
    _syncWithRoute();
  }

  /// The box mirrors the shelf's applied search: on `/shop?q=…` it shows the
  /// term, anywhere else (or after the shelf cleared it) it is empty, so the
  /// header can never show text the page is not filtering by.
  void _syncWithRoute() {
    final uri = Uri.tryParse(Nav.instance.route);
    final onShop = uri != null && uri.path == '/shop';
    final want = onShop ? (uri.queryParameters['q'] ?? '') : '';
    if (_controller.text != want) _controller.text = want;
  }

  @override
  void dispose() {
    Nav.instance.removeListener(_syncWithRoute);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            final q = v.trim();
            if (q.isEmpty) return;
            go('/shop?q=${Uri.encodeQueryComponent(q)}');
          },
          style: const TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: gt('Search the mall…'),
            hintStyle: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink3,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: AppIcon('search', size: 17, color: AppColors.ink3),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: AppColors.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.navy2, width: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  final AppState state;
  final bool dark;

  const _LangToggle({required this.state, this.dark = false});

  @override
  Widget build(BuildContext context) {
    Widget seg(String code, String label, bool selected) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (state.lang != code) state.setLang(code);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? (selected ? AppColors.white : Colors.transparent)
                  : (selected ? AppColors.navy : AppColors.white),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: dark
                    ? (selected ? AppColors.white : Colors.transparent)
                    : (selected ? AppColors.navy : AppColors.line),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: dark
                    ? (selected ? AppColors.navy : AppColors.white)
                    : (selected ? AppColors.white : AppColors.ink2),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 116,
      height: 40,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: .14) : AppColors.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: dark ? Colors.white.withValues(alpha: .3) : AppColors.line),
      ),
      child: Row(
        children: [
          seg('en', 'EN', state.lang == 'en'),
          seg('gu', 'ગુજ', state.lang == 'gu'),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatefulWidget {
  final String icon;
  final int count;
  final String tooltip;
  final VoidCallback onTap;

  /// Drawn on a coloured (admin / staff) bar.
  final bool dark;
  final double size;

  const _HeaderBadge({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onTap,
    this.dark = false,
    this.size = 42,
  });

  @override
  State<_HeaderBadge> createState() => _HeaderBadgeState();
}

class _HeaderBadgeState extends State<_HeaderBadge> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return HoverLabel(
      message: widget.tooltip,
      child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.dark
                      ? Colors.white.withValues(alpha: _hover ? .26 : .14)
                      : (_hover ? AppColors.navyTint : AppColors.bg),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: widget.dark
                          ? Colors.white.withValues(alpha: .3)
                          : AppColors.line),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: AppIcon(
                        widget.icon,
                        size: 19,
                        color: widget.dark ? AppColors.white : AppColors.ink,
                        sw: 1.7,
                      ),
                    ),
                    if (widget.count > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${widget.count}',
                            style: const TextStyle(
                              fontFamily: AppTheme.uiFont,
                              fontSize: 8.5,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _SideItem {
  final String icon;
  final String label;
  final String labelGu;
  final String target;

  const _SideItem(this.icon, this.label, this.labelGu, this.target);
}

class _SideGroup {
  final String key;
  final String label;
  final String labelGu;
  final List<_SideItem> items;

  const _SideGroup(this.key, this.label, this.labelGu, this.items);
}

/// CASHIER: only /admin/orders/** and /pos/** are open to this role.
const List<_SideGroup> _cashierGroups = [
  _SideGroup('work', 'Counter', 'કાઉન્ટર', [
    _SideItem('cart', 'Orders', 'ઓર્ડર', '/admin/orders'),
    _SideItem('bolt', 'POS till', 'પીઓએસ', '/admin/pos'),
    _SideItem('flame', 'Flash sales', 'ફ્લેશ સેલ', '/admin/flash-sales'),
  ]),
];

/// ADMIN: every page, grouped the way the owner thinks about the shop.
const List<_SideGroup> _adminGroups = [
  _SideGroup('overview', 'Overview', 'ઝલક', [
    _SideItem('home', 'Dashboard', 'ડેશબોર્ડ', '/admin'),
  ]),
  _SideGroup('sales', 'Sales', 'વેચાણ', [
    _SideItem('cart', 'Orders', 'ઓર્ડર', '/admin/orders'),
    _SideItem('bolt', 'POS till', 'પીઓએસ', '/admin/pos'),
    _SideItem('flame', 'Hot sale', 'હૉટ સેલ', '/admin/hot-sale'),
    _SideItem('bolt', 'Flash sales', 'ફ્લેશ સેલ', '/admin/flash-sales'),
    _SideItem('ticket', 'Coupons', 'કૂપન', '/admin/coupons'),
    _SideItem('coin', 'Coin rules', 'કોઈન નિયમ', '/admin/coins'),
  ]),
  _SideGroup('stock', 'Catalog and stock', 'કેટલોગ અને સ્ટોક', [
    _SideItem('box', 'Inventory', 'ઇન્વેન્ટરી', '/admin/inventory'),
    _SideItem('grid', 'Categories', 'કેટેગરી', '/admin/categories'),
    _SideItem('grid', 'Units', 'એકમ', '/admin/units'),
    _SideItem('box', 'Stock in and count', 'સ્ટોક ઇન અને ગણતરી',
        '/admin/stock-ops'),
    _SideItem('ticket', 'Barcode labels', 'બારકોડ લેબલ', '/admin/labels'),
    _SideItem('box', 'GST and HSN master', 'GST અને HSN માસ્ટર', '/admin/gst-master'),
    _SideItem('box', 'Stock lots and expiry', 'સ્ટોક લૉટ અને એક્સપાયરી',
        '/admin/stock-lots'),
    _SideItem('refresh', 'Stock movement', 'સ્ટોક હિલચાલ',
        '/admin/stock-report'),
    _SideItem('box', 'Low stock', 'ઓછો સ્ટોક', '/admin/counter?tab=low'),
  ]),
  _SideGroup('money', 'Purchasing and money', 'ખરીદી અને નાણાં', [
    _SideItem('box', 'Purchases and suppliers', 'ખરીદી અને સપ્લાયર',
        '/admin/purchases'),
    _SideItem('card', 'Bank and settlements', 'બેંક અને સેટલમેન્ટ',
        '/admin/bank'),
    _SideItem('card', 'Payment methods', 'ચુકવણી પદ્ધતિ', '/admin/payments'),
    _SideItem('coin', 'Credit (udhar)', 'ઉધાર', '/admin/credit'),
    _SideItem('coin', 'Refunds', 'રિફંડ', '/admin/system?tab=refunds'),
  ]),
  _SideGroup('people', 'People', 'લોકો', [
    _SideItem('users', 'Customers', 'ગ્રાહકો', '/admin/customers'),
    _SideItem('users', 'Staff', 'સ્ટાફ', '/admin/staff'),
    _SideItem('bell', 'Push notifications', 'પુશ નોટિફિકેશન', '/admin/push'),
  ]),
  _SideGroup('reports', 'Reports and counter', 'રિપોર્ટ અને કાઉન્ટર', [
    _SideItem('chart', 'Reports', 'રિપોર્ટ', '/admin/reports'),
    _SideItem('clock', 'Cash drawer shifts', 'કેશ ડ્રોઅર શિફ્ટ',
        '/admin/counter?tab=shifts'),
    _SideItem('filter', 'Audit log', 'ઑડિટ લૉગ', '/admin/counter?tab=audit'),
    _SideItem('card', 'Payment problems', 'ચુકવણી સમસ્યા',
        '/admin/counter?tab=anomalies'),
    _SideItem('settings', 'Till sync and PIN', 'ટિલ સિંક અને પિન',
        '/admin/counter?tab=sync'),
  ]),
  _SideGroup('settings', 'Settings', 'સેટિંગ્સ', [
    _SideItem('store', 'Shop settings', 'દુકાન સેટિંગ્સ',
        '/admin/shop-settings'),
    _SideItem('store', 'Shop profile and hours', 'દુકાન પ્રોફાઇલ',
        '/admin/system?tab=profile'),
    _SideItem('filter', 'Configuration', 'કન્ફિગરેશન',
        '/admin/system?tab=config'),
    _SideItem('box', 'Caches and logs', 'કેશ અને લૉગ',
        '/admin/system?tab=caches'),
    _SideItem('user', 'My profile', 'મારી પ્રોફાઇલ', '/admin/profile'),
  ]),
];

/// Fixed left navigation for admin routes (desktop only): grouped, collapsible
/// sections, one highlighted row for the page that is open.
class _AdminSidebar extends StatefulWidget {
  final String route;
  final AppState state;

  const _AdminSidebar({required this.route, required this.state});

  @override
  State<_AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<_AdminSidebar> {
  /// Groups the user has toggled; absent = default (open when it holds the
  /// current page or is the Sales group).
  final Map<String, bool> _open = {};
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _defaultTab = {
    '/admin/counter': 'shifts',
    '/admin/system': 'refunds',
  };

  /// The nav target the current route belongs to, or null.
  String? _activeTarget(List<_SideGroup> groups) {
    var path = widget.route.split('?').first;
    final q = Uri.tryParse(widget.route)?.queryParameters ?? const {};
    if (path.startsWith('/admin/order/')) path = '/admin/orders';
    if (path == '/admin/product' || path.startsWith('/admin/product/')) {
      path = '/admin/inventory';
    }
    if (path == '/admin/shift') path = '/admin/pos';
    String? best;
    var bestLen = -1;
    for (final g in groups) {
      for (final it in g.items) {
        final tp = it.target.split('?').first;
        final tq = Uri.tryParse(it.target)?.queryParameters ?? const {};
        final hit = tp == '/admin'
            ? path == '/admin'
            : (path == tp || path.startsWith('$tp/'));
        if (!hit) continue;
        if (tq.containsKey('tab') &&
            (q['tab'] ?? _defaultTab[tp]) != tq['tab']) {
          continue;
        }
        final len = tp.length + (tq.containsKey('tab') ? 1 : 0);
        if (len > bestLen) {
          bestLen = len;
          best = it.target;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final gu = state.lang == 'gu';
    final groups = state.adminPagesAllowed ? _adminGroups : _cashierGroups;
    final active = _activeTarget(groups);
    final pending = state.newOrderCount();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 256,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [AppColors.navy, AppColors.navyDeep],
        ),
        border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: .12))),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22121A47), offset: Offset(4, 0), blurRadius: 18)
        ],
      ),
      child: Stack(children: [
        Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              thickness: 4,
              radius: const Radius.circular(4),
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                children: [
                  for (final g in groups) ..._group(g, active, gu, pending),
                ],
              ),
            ),
          ),
          _footer(state, gu),
        ],
      ),
      ]),
    );
  }

  List<Widget> _group(_SideGroup g, String? active, bool gu, int pending) {
    final holdsActive = g.items.any((i) => i.target == active);
    final single = g.items.length == 1 || g.key == 'work';
    final open = single || (_open[g.key] ?? (holdsActive || g.key == 'sales'));
    return [
      if (!single)
        _GroupHead(
          color: SectionPalette.forRoute(g.items.first.target).glow,
          label: gu ? g.labelGu : g.label,
          open: open,
          holdsActive: holdsActive && !open,
          onTap: () => setState(() => _open[g.key] = !open),
        )
      else
        const SizedBox(height: 2),
      if (open)
        for (final it in g.items)
          _SideLink(
            item: it,
            label: gu ? it.labelGu : it.label,
            selected: it.target == active,
            badge: it.target == '/admin/orders' ? pending : 0,
          ),
      const SizedBox(height: 10),
    ];
  }

  Widget _footer(AppState state, bool gu) {
    final name = state.userName.trim();
    final admin = state.adminPagesAllowed;
    final initials = name.isEmpty
        ? (admin ? 'A' : 'C')
        : name
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .take(2)
            .map((s) => s[0].toUpperCase())
            .join();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0x26000000),
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: Text(initials,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? (admin ? 'Owner' : 'Cashier') : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white)),
                Text(
                    admin
                        ? (gu ? 'ઓનર કન્સોલ' : 'Owner console')
                        : (gu ? 'કાઉન્ટર સ્ટાફ' : 'Counter staff'),
                    style: TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: SectionPalette.forRoute(widget.route).glow)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHead extends StatelessWidget {
  final Color color;
  final String label;
  final bool open;
  final bool holdsActive;
  final VoidCallback onTap;

  const _GroupHead({
    required this.color,
    required this.label,
    required this.open,
    required this.holdsActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: .6), blurRadius: 6)
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .9,
                    color: Colors.white.withValues(alpha: .78),
                  ),
                ),
              ),
              if (holdsActive)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
              Icon(
                open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: Colors.white.withValues(alpha: .6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideLink extends StatefulWidget {
  final _SideItem item;
  final String label;
  final bool selected;
  final int badge;

  const _SideLink({
    required this.item,
    required this.label,
    required this.selected,
    required this.badge,
  });

  @override
  State<_SideLink> createState() => _SideLinkState();
}

class _SideLinkState extends State<_SideLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final pal = SectionPalette.forRoute(widget.item.target);
    final fg = selected
        ? AppColors.white
        : Colors.white.withValues(alpha: _hover ? .98 : .82);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => go(widget.item.target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.only(left: 6, right: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: .20)
                : _hover
                    ? Colors.white.withValues(alpha: .09)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: .32)
                    : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: selected ? pal.glow : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.white
                      : Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: AppIcon(
                    widget.item.icon,
                    size: 15,
                    color: selected ? pal.deep : Colors.white,
                    sw: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (widget.badge > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.badge}',
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
