import 'package:flutter/material.dart';

import '../nav/nav.dart';
import '../provider/state_scope.dart';
import '../screens/customer/sheets/addresses_sheet.dart';
import '../state/app_state.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'hover_label.dart';
import 'popover.dart';
import 'toast.dart';

/// Which kind of person the signed-in session is, for the top bar and the
/// profile menu.
enum BarRole { guest, customer, staff, admin }

BarRole barRoleOf(AppState s) {
  if (s.adminPagesAllowed && (s.backendMode || s.adminSignedIn)) {
    return BarRole.admin;
  }
  if (s.isAdminAllowed) return BarRole.staff;
  if (s.signedIn || s.backendMode) return BarRole.customer;
  return BarRole.guest;
}

String roleChipLabel(BarRole r) {
  switch (r) {
    case BarRole.admin:
      return 'ADMIN';
    case BarRole.staff:
      return 'STAFF';
    case BarRole.customer:
      return 'CUSTOMER';
    case BarRole.guest:
      return 'GUEST';
  }
}

/// Up to two initials from the display name (falls back to the e-mail, then V).
String initialsOf(AppState s) {
  final name = s.userName.trim();
  final src = name.isNotEmpty ? name : (s.userEmail ?? '').trim();
  final parts =
      src.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'V';
  String first(String p) => String.fromCharCode(p.runes.first).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return first(parts[0]) + first(parts[1]);
}

/// E-mail when there is one, else the mobile number.
String contactLine(AppState s) {
  final e = (s.userEmail ?? '').trim();
  if (e.isNotEmpty) return e;
  return s.userPhone.trim();
}

/// Small pill with the role name ("ADMIN" / "STAFF" / "CUSTOMER").
class RoleChip extends StatelessWidget {
  final BarRole role;

  /// Draw for a coloured top bar (translucent white / gold) instead of a
  /// light surface.
  final bool onBar;

  const RoleChip(this.role, {super.key, this.onBar = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (onBar) {
      bg = role == BarRole.admin ? AppColors.gold2 : AppColors.white;
      fg = role == BarRole.admin ? AppColors.navyDeep : AppColors.staffBar;
    } else {
      switch (role) {
        case BarRole.admin:
          bg = AppColors.navy;
          fg = AppColors.white;
          break;
        case BarRole.staff:
          bg = AppColors.staffBar;
          fg = AppColors.white;
          break;
        default:
          bg = AppColors.navyTint;
          fg = AppColors.navy;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        gt(roleChipLabel(role)),
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 9.5,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
          color: fg,
        ),
      ),
    );
  }
}

/// Round avatar with initials (or a user glyph for a guest).
class InitialsAvatar extends StatelessWidget {
  final AppState state;
  final double size;
  final bool onBar;

  const InitialsAvatar({
    super.key,
    required this.state,
    this.size = 40,
    this.onBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final guest = barRoleOf(state) == BarRole.guest;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: onBar ? null : AppColors.avatarGradient,
        color: onBar ? Colors.white.withValues(alpha: .18) : null,
        border: onBar
            ? Border.all(color: Colors.white.withValues(alpha: .55), width: 1.5)
            : null,
      ),
      child: guest
          ? AppIcon('user',
              size: size * .48,
              color: onBar ? AppColors.white : AppColors.goldInk)
          : Text(
              initialsOf(state),
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: size * .34,
                fontWeight: FontWeight.w800,
                color: onBar ? AppColors.white : AppColors.goldInk,
              ),
            ),
    );
  }
}

/// The avatar button on the right of the top bar; opens the profile menu.
class ProfileAvatarButton extends StatelessWidget {
  final bool onBar;
  final bool adminRoute;
  final double size;

  const ProfileAvatarButton({
    super.key,
    required this.adminRoute,
    this.onBar = false,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return Builder(
      builder: (anchor) => HoverLabel(
        message: gt('Profile'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showProfileMenu(anchor, adminRoute: adminRoute),
            child: SizedBox(
              width: size,
              height: size,
              child: InitialsAvatar(state: state, size: size, onBar: onBar),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the profile menu: a dropdown on wide windows, a bottom sheet on
/// phones.
void showProfileMenu(BuildContext anchor, {required bool adminRoute}) {
  showTopBarPanel(
    anchor: anchor,
    tag: 'profile-menu',
    width: 320,
    maxHeightFactor: .8,
    builder: (ctx) => _ProfileMenuBody(adminRoute: adminRoute),
  );
}

class _ProfileMenuBody extends StatelessWidget {
  final bool adminRoute;

  const _ProfileMenuBody({required this.adminRoute});

  void _open(BuildContext ctx, String route) {
    Navigator.of(ctx).maybePop();
    go(route);
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final role = barRoleOf(s);
    final guest = role == BarRole.guest;
    final staffSide = role == BarRole.admin || role == BarRole.staff;
    final inAdmin = adminRoute && staffSide;
    final gu = s.lang == 'gu';
    final name = s.userName.trim().isNotEmpty
        ? s.userName.trim()
        : (guest ? gt('Guest') : gt('My account'));
    final contact = contactLine(s);

    final items = <Widget>[];
    if (guest) {
      items.add(_MenuItem(
        icon: 'user',
        label: gt('Sign in'),
        onTap: () => _open(context, '/signin'),
      ));
    } else if (inAdmin) {
      items.addAll([
        _MenuItem(
          icon: 'user',
          label: gt('My profile'),
          onTap: () => _open(context, '/admin/profile'),
        ),
        if (role == BarRole.admin)
          _MenuItem(
            icon: 'home',
            label: gt('Admin home'),
            onTap: () => _open(context, '/admin'),
          )
        else
          _MenuItem(
            icon: 'cart',
            label: gt('Orders'),
            onTap: () => _open(context, '/admin/orders'),
          ),
        if (role == BarRole.admin)
          _MenuItem(
            icon: 'store',
            label: gt('Shop settings'),
            onTap: () => _open(context, '/admin/shop-settings'),
          ),
        _MenuItem(
          icon: 'store',
          label: gt('Open the store'),
          onTap: () => _open(context, '/home'),
        ),
      ]);
    } else {
      items.addAll([
        _MenuItem(
          icon: 'user',
          label: gt('My profile'),
          onTap: () => _open(context, '/profile'),
        ),
        _MenuItem(
          icon: 'box',
          label: gt('My orders'),
          onTap: () => _open(context, '/orders'),
        ),
        _MenuItem(
          icon: 'wallet',
          label: gt('Wallet & coins'),
          onTap: () => _open(context, '/wallet'),
        ),
        _MenuItem(
          icon: 'pin',
          label: gt('Addresses'),
          onTap: () {
            Navigator.of(context).maybePop();
            final c = rootSheetContext;
            if (c != null) showAddressSheet(c);
          },
        ),
        if (staffSide)
          _MenuItem(
            icon: 'chart',
            label: gt('Admin panel'),
            onTap: () => _open(context, '/admin'),
          ),
      ]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            children: [
              InitialsAvatar(state: s, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (contact.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          contact,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    RoleChip(role),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...items,
                _LanguageRow(state: s, gu: gu),
                if (!guest) ...[
                  const Divider(height: 12, thickness: 1, color: AppColors.line),
                  _MenuItem(
                    icon: 'logout',
                    label: gt('Sign out'),
                    danger: true,
                    onTap: () {
                      Navigator.of(context).maybePop();
                      final st = StateScope.read(context);
                      if (inAdmin) {
                        st.adminSignOut();
                        go('/signin');
                      } else {
                        st.signOut();
                        go('/welcome');
                      }
                      showToast(gt('Signed out'));
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatefulWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.danger ? AppColors.red : AppColors.ink;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover
                ? (widget.danger ? AppColors.redTint : AppColors.bg)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: widget.danger ? AppColors.redTint : AppColors.navyTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: AppIcon(widget.icon,
                      size: 15,
                      color: widget.danger ? AppColors.red : AppColors.navy,
                      sw: 1.8),
                ),
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
                    fontWeight: FontWeight.w700,
                    color: fg,
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

class _LanguageRow extends StatelessWidget {
  final AppState state;
  final bool gu;

  const _LanguageRow({required this.state, required this.gu});

  @override
  Widget build(BuildContext context) {
    Widget seg(String code, String label) {
      final on = state.lang == code;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (state.lang != code) state.setLang(code);
        },
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.navy : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? AppColors.navy : AppColors.line),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? AppColors.white : AppColors.ink2,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.navyTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'અ',
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gt('Language'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          seg('en', 'English'),
          const SizedBox(width: 6),
          seg('gu', 'ગુજરાતી'),
        ],
      ),
    );
  }
}
