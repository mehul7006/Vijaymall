import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../nav/nav.dart';
import '../provider/state_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'admin_alerts.dart';
import 'app_icon.dart';
import 'desktop_shell.dart';

/// Fake device status bar — `.statusbar` (h44, 12/800, 9:41 + indicators).
class StatusBar extends StatelessWidget {
  final bool light;

  const StatusBar({super.key, this.light = false});

  static const String _signal =
      '<svg width="16" height="11" viewBox="0 0 16 11" fill="none">'
      '<rect x="0" y="7" width="3" height="4" rx="1" fill="currentColor"/>'
      '<rect x="4.3" y="5" width="3" height="6" rx="1" fill="currentColor"/>'
      '<rect x="8.6" y="2.5" width="3" height="8.5" rx="1" fill="currentColor"/>'
      '<rect x="12.9" y="0" width="3" height="11" rx="1" fill="currentColor"/>'
      '</svg>';
  static const String _wifi =
      '<svg width="15" height="11" viewBox="0 0 15 11" fill="none">'
      '<path d="M1 3.4A9.6 9.6 0 0 1 14 3.4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>'
      '<path d="M3.6 6.2a6 6 0 0 1 7.8 0" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>'
      '<path d="M6.2 8.9a2.3 2.3 0 0 1 2.6 0" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>'
      '</svg>';
  static const String _battery =
      '<svg width="23" height="11" viewBox="0 0 23 11" fill="none">'
      '<rect x="0.6" y="0.6" width="19" height="9.8" rx="3" stroke="currentColor" stroke-width="1.2" opacity=".5"/>'
      '<rect x="2.2" y="2.2" width="14" height="6.6" rx="1.8" fill="currentColor"/>'
      '<path d="M21.4 4v3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" opacity=".5"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    // Desktop site chrome has no fake device status bar.
    if (DesktopShell.useSiteChrome(MediaQuery.sizeOf(context).width)) {
      return const SizedBox.shrink();
    }
    final fg = light ? AppColors.white : AppColors.ink;
    Widget ind(String svg) => SvgPicture.string(
          svg.replaceAll('currentColor', colorHex(fg)),
          width: 20,
          height: 11,
        );
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '9:41',
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            Row(
              children: [
                ind(_signal),
                const SizedBox(width: 6),
                ind(_wifi),
                const SizedBox(width: 6),
                ind(_battery),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `.appbar` — back button + title/sub + right slot.
class ScreenBar extends StatelessWidget {
  final String title;
  final String? sub;
  final VoidCallback? onBack;
  final Widget? right;
  final bool showBack;

  const ScreenBar({
    super.key,
    required this.title,
    this.sub,
    this.onBack,
    this.right,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack ?? () => Nav.instance.pop(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.glassEdge),
                  boxShadow: AppColors.sh1,
                ),
                child: const Center(
                  child: AppIcon('back', size: 21, color: AppColors.ink),
                ),
              ),
            ),
          if (showBack) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 24,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.035,
                    color: AppColors.ink,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: 10), right!],
        ],
      ),
    );
  }
}

/// `.screen-scroll` — padded scrolling body.
class ScreenScroll extends StatelessWidget {
  final Widget child;
  final double bottom;
  final EdgeInsets padding;

  /// Optional pull-to-refresh handler (adds a RefreshIndicator).
  final Future<void> Function()? onRefresh;

  const ScreenScroll({
    super.key,
    required this.child,
    this.bottom = 112,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Without the floating nav bar the large mobile inset is unnecessary.
    var bottomInset = bottom;
    if (DesktopShell.isWide(MediaQuery.sizeOf(context).width) &&
        bottomInset > 56) {
      bottomInset = 40;
    }
    final scroll = SingleChildScrollView(
      physics: onRefresh != null
          ? const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics())
          : const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        padding.left,
        padding.top,
        padding.right,
        bottomInset + padding.bottom,
      ),
      child: child,
    );
    return Expanded(
      child: onRefresh == null
          ? scroll
          : RefreshIndicator(
              color: AppColors.red,
              onRefresh: onRefresh!,
              child: scroll,
            ),
    );
  }
}

/// Wide-window (>= 900) page body: [left] scrolls, [right] stays beside it
/// (its own scroll, so a summary card is always in view). Takes the place of
/// a `ScreenScroll` inside the page's column; the 16 px gutters match the
/// title bar and `ScreenBar`.
class WideSplit extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double rightWidth;

  const WideSplit({
    super.key,
    required this.left,
    required this.right,
    this.rightWidth = 380,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: left,
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: rightWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two equal columns of cards for wide windows; on phones the caller keeps a
/// single column. Each side is a plain list, spaced by [gap].
class TwoColumns extends StatelessWidget {
  final List<Widget> a;
  final List<Widget> b;
  final double gap;

  const TwoColumns({super.key, required this.a, required this.b, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    Widget col(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              items[i],
            ],
          ],
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(a)),
        const SizedBox(width: 20),
        Expanded(child: col(b)),
      ],
    );
  }
}

/// `.actionbar` — fixed bottom CTA strip with white fade / solid variant.
class ActionBar extends StatelessWidget {
  final Widget child;
  final bool solid;

  const ActionBar({super.key, required this.child, this.solid = false});

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + safeBottom),
      decoration: BoxDecoration(
        color: solid ? AppColors.white : null,
        gradient: solid
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00FFFFFF), Color(0xF2FFFFFF), Color(0xFFFFFFFF)],
                stops: [0.0, .35, 1.0],
              ),
        border: solid ? Border.all(color: AppColors.line) : null,
        boxShadow: solid ? AppColors.sh1 : null,
      ),
      child: child,
    );
  }
}

class _TabSpec {
  final String key;
  final String icon;
  final String en;
  final String gu;
  final String route;

  const _TabSpec(this.key, this.icon, this.en, this.gu, this.route);
}

const List<_TabSpec> _customerTabs = [
  _TabSpec('home', 'home', 'Home', 'હોમ', '/home'),
  _TabSpec('shop', 'grid', 'Shop', 'દુકાન', '/shop'),
  _TabSpec('cart', 'cart', 'Cart', 'કાર્ટ', '/cart'),
  _TabSpec('wallet', 'wallet', 'Coins', 'કોઈન્સ', '/wallet'),
  _TabSpec('profile', 'user', 'Profile', 'પ્રોફાઇલ', '/profile'),
];

const List<_TabSpec> _adminTabs = [
  _TabSpec('dashboard', 'home', 'Dashboard', 'ડેશબોર્ડ', '/admin'),
  _TabSpec('orders', 'cart', 'Orders', 'ઓર્ડર', '/admin/orders'),
  _TabSpec('inventory', 'box', 'Stock', 'સ્ટોક', '/admin/inventory'),
  _TabSpec('coins', 'coin', 'Rewards', 'ઇનામ', '/admin/coins'),
  _TabSpec('more', 'settings', 'More', 'વધુ', '/admin/more'),
];

/// CASHIER sees only what the server lets them call: /admin/orders/** and /pos/**.
const List<_TabSpec> _cashierTabs = [
  _TabSpec('orders', 'cart', 'Orders', 'ઓર્ડર', '/admin/orders'),
  _TabSpec('pos', 'bolt', 'POS till', 'પીઓએસ', '/admin/pos'),
];

class _NavBar extends StatelessWidget {
  final List<_TabSpec> tabs;
  final String active;
  final int? Function(String key) badgeFor;
  final Color activeBg;
  final Color activeFg;

  const _NavBar({
    required this.tabs,
    required this.active,
    required this.badgeFor,
    this.activeBg = AppColors.redTint,
    this.activeFg = AppColors.red,
  });

  @override
  Widget build(BuildContext context) {
    // On desktop the header/sidebar carry navigation — no floating pill nav.
    if (DesktopShell.isWide(MediaQuery.sizeOf(context).width)) {
      return const SizedBox.shrink();
    }
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final inset = MediaQuery.of(context).size.width <= 360 ? 9.0 : 11.0;
    return Positioned(
      left: inset,
      right: inset,
      bottom: inset + safeBottom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 72,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Row(
              children: tabs.map((t) {
                final selected = t.key == active;
                final badge = badgeFor(t.key);
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => go(t.route),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 58,
                      decoration: BoxDecoration(
                        color: selected ? activeBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  t.icon,
                                  size: 21,
                                  color: selected ? activeFg : AppColors.ink3,
                                  sw: 1.8,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _trLabel(context, t),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 9,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: selected ? activeFg : AppColors.ink3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (badge != null && badge > 0)
                            Positioned(
                              top: 2,
                              left: 0,
                              right: 0,
                              // Anchored to the icon (tab centre + 12px), so
                              // 4-tab and 5-tab bars both put it on the
                              // icon's corner instead of a fixed x offset.
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Transform.translate(
                                  offset: const Offset(20, 0),
                                  child: Container(
                                constraints: const BoxConstraints(minWidth: 17),
                                height: 17,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.red,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: AppColors.white, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: _PopText(
                                  '$badge',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

String _trLabel(BuildContext context, _TabSpec t) {
  final state = StateScope.of(context);
  return state.lang == 'gu' ? t.gu : t.en;
}

/// Customer bottom nav — home/shop/cart/wallet/profile, cart badge only.
class CustomerNav extends StatelessWidget {
  final String active;

  const CustomerNav({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return _NavBar(
      tabs: _customerTabs,
      active: active,
      badgeFor: (key) => key == 'cart' ? state.cartCount() : null,
    );
  }
}

/// `.admin-head` — navy gradient page header (logo tile, gold subtitle,
/// radial gold glow, 32px bottom radius) with bell + owner actions.
class AdminHead extends StatelessWidget {
  final String title;
  final String sub;

  /// Bell opens the store alerts sheet; `false` hides it (`adminHead(o.bell)`).
  final bool bell;
  final List<Widget> actions;
  final VoidCallback? onBell;

  /// Optional back arrow on the far left (mobile only — desktop sidebar covers nav).
  final VoidCallback? onBack;

  const AdminHead({
    super.key,
    required this.title,
    required this.sub,
    this.bell = true,
    this.actions = const [],
    this.onBell,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final pending = StateScope.of(context).newOrderCount();
    // On the site chrome the headline, bell and owner avatar live in the main
    // top bar (beside the "Vijay Super Mall" logo), so the page banner only
    // has to carry the subtitle and the screen's own actions.
    final siteChrome = DesktopShell.useSiteChrome(MediaQuery.sizeOf(context).width);
    final pal = SectionPalette.forRoute(Nav.instance.route);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [pal.deep, pal.mid, pal.accent],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // `.admin-head::after` — soft gold glow, top-right.
          Positioned(
            right: -76,
            top: -86,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    pal.glow.withValues(alpha: .38),
                    pal.glow.withValues(alpha: 0)
                  ],
                  stops: [0.0, 0.68],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(siteChrome ? 20 : 16, 14, 16, siteChrome ? 16 : 20),
            child: Row(
              children: [
                if (onBack != null) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: .15)),
                      ),
                      child: const Center(
                        child: AppIcon('back', size: 18, color: AppColors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!siteChrome) ...[
                  Container(
                    width: 46,
                    height: 46,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: .15)),
                    ),
                    child: const Center(
                      child: LogoMark(size: 31, color: AppColors.gold2),
                    ),
                  ),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!siteChrome)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.035,
                            color: AppColors.white,
                          ),
                        ),
                      if (!siteChrome) const SizedBox(height: 3),
                      Text(
                        siteChrome ? '$title · $sub' : sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: siteChrome ? 12.5 : 9.5,
                          height: siteChrome ? 1.2 : 1.25,
                          fontWeight: FontWeight.w700,
                          color: siteChrome
                              ? Colors.white.withValues(alpha: .92)
                              : AppColors.gold2.withValues(alpha: .95),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (bell && !siteChrome)
                  _AdminCircleBtn(
                    icon: 'bell',
                    badge: pending,
                    onTap: onBell ?? () => showAdminAlerts(context),
                  ),
                for (final a in actions) ...[const SizedBox(width: 7), a],
                if (!siteChrome) ...[
                  const SizedBox(width: 7),
                  // Owner avatar → More.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => go('/admin/more'),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: .15)),
                      ),
                      child: const Text(
                        'VH',
                        style: TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.admin-circle-btn` — 40px glass icon button in the admin header.
class _AdminCircleBtn extends StatefulWidget {
  final String icon;
  final int badge;
  final VoidCallback onTap;

  const _AdminCircleBtn({
    required this.icon,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_AdminCircleBtn> createState() => _AdminCircleBtnState();
}

class _AdminCircleBtnState extends State<_AdminCircleBtn> {
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
          width: 40,
          height: 40,
          clipBehavior: Clip.none,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hover ? .16 : .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .15)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: AppIcon(widget.icon, size: 18, color: AppColors.white),
              ),
              if (widget.badge > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.navy, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.badge}',
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
      ),
    );
  }
}

/// Admin bottom nav — dashboard/orders/inventory/coins/more, Placed badge.
class AdminNav extends StatelessWidget {
  final String active;

  const AdminNav({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return _NavBar(
      tabs: state.adminPagesAllowed ? _adminTabs : _cashierTabs,
      active: active,
      badgeFor: (key) => key == 'orders' ? state.newOrderCount() : null,
      activeBg: AppColors.navyTint,
      activeFg: AppColors.navy,
    );
  }
}

/// Badge count text that pops (scale + fade) whenever the value changes.
class _PopText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _PopText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}
