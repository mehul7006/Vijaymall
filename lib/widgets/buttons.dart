import 'package:flutter/material.dart';

import '../nav/nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import '../state/gu_strings.dart';

enum BtnVariant { primary, secondary, soft, ghost, danger, dangerSoft, gold, navy }

enum BtnSize { lg, md, sm, xs }

/// The prototype's `Btn({variant, size})` — gradient primary, glass secondary,
/// tinted soft/danger variants, gold & navy gradients for coin/navy CTAs.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnVariant variant;
  final BtnSize size;
  final String? icon;
  final bool block;
  final bool disabled;
  final bool loading;

  const AppButton(
    this.label, {
    super.key,
    this.onTap,
    this.variant = BtnVariant.primary,
    this.size = BtnSize.md,
    this.icon,
    this.block = false,
    this.disabled = false,
    this.loading = false,
  });

  double get _height {
    switch (size) {
      case BtnSize.lg:
        return 54;
      case BtnSize.md:
        return 48;
      case BtnSize.sm:
        return 38;
      case BtnSize.xs:
        return 30;
    }
  }

  double get _fontSize {
    switch (size) {
      case BtnSize.lg:
        return 16;
      case BtnSize.md:
        return 15;
      case BtnSize.sm:
        return 13;
      case BtnSize.xs:
        return 11;
    }
  }

  double get _iconSize {
    switch (size) {
      case BtnSize.lg:
        return 18;
      case BtnSize.md:
        return 17;
      case BtnSize.sm:
        return 14;
      case BtnSize.xs:
        return 12;
    }
  }

  bool get _isOff => disabled || loading || onTap == null;

  @override
  Widget build(BuildContext context) {
    final radius = size == BtnSize.xs ? 10.0 : size == BtnSize.sm ? 12.0 : 16.0;
    final onSurface = _textColor;
    final child = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: onSurface,
            ),
          )
        else if (icon != null)
          AppIcon(icon!, size: _iconSize, color: onSurface, sw: 2),
        if (icon != null || loading) SizedBox(width: size == BtnSize.xs ? 5 : 8),
        Flexible(
          child: Text(
            gt(label),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: _fontSize,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: size == BtnSize.xs ? .1 : -.01,
              color: onSurface,
            ),
          ),
        ),
      ],
    );

    final glossy = variant == BtnVariant.primary ||
        variant == BtnVariant.gold ||
        variant == BtnVariant.navy ||
        variant == BtnVariant.danger;
    return Opacity(
      opacity: _isOff ? .55 : 1,
      child: _PressScale(
        enabled: !_isOff,
        onTap: _isOff ? null : onTap,
        child: Container(
          height: _height,
          padding: EdgeInsets.symmetric(
            horizontal: size == BtnSize.xs
                ? 11
                : size == BtnSize.sm
                    ? 15
                    : 20,
          ),
          decoration: _decoration(radius),
          foregroundDecoration: glossy
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: .22),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.55],
                  ),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .22)),
                )
              : null,
          child: child,
        ),
      ),
    );
  }

  Color get _textColor {
    switch (variant) {
      case BtnVariant.primary:
      case BtnVariant.gold:
      case BtnVariant.navy:
      case BtnVariant.danger:
        return AppColors.white;
      case BtnVariant.secondary:
        return AppColors.ink;
      case BtnVariant.soft:
        final p = SectionPalette.forRoute(Nav.instance.route);
        return p.accent == AppColors.red ? AppColors.red : p.accent;
      case BtnVariant.dangerSoft:
        return AppColors.red;
      case BtnVariant.ghost:
        return AppColors.ink2;
    }
  }

  BoxDecoration _decoration(double radius) {
    switch (variant) {
      case BtnVariant.primary:
        final pal = SectionPalette.forRoute(Nav.instance.route);
        if (pal.accent == AppColors.red) {
          return BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: _isOff ? null : AppColors.shRed,
          );
        }
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pal.accent, pal.mid],
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: _isOff
              ? null
              : [
                  BoxShadow(
                      color: pal.accent.withValues(alpha: .35),
                      offset: const Offset(0, 10),
                      blurRadius: 24)
                ],
        );
      case BtnVariant.gold:
        return BoxDecoration(
          gradient: AppColors.coinGradient,
          borderRadius: BorderRadius.circular(radius),
        );
      case BtnVariant.navy:
        return BoxDecoration(
          gradient: AppColors.navyGradient,
          borderRadius: BorderRadius.circular(radius),
        );
      case BtnVariant.danger:
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE4424B), Color(0xFFB3121C)],
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: _isOff ? null : AppColors.shRed,
        );
      case BtnVariant.secondary:
        return BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.sh1,
        );
      case BtnVariant.soft:
        return BoxDecoration(
          color: SectionPalette.forRoute(Nav.instance.route).tint,
          borderRadius: BorderRadius.circular(radius),
        );
      case BtnVariant.dangerSoft:
        return BoxDecoration(
          color: AppColors.redTint,
          borderRadius: BorderRadius.circular(radius),
        );
      case BtnVariant.ghost:
        return BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(radius),
        );
    }
  }
}

/// Tap target that gently shrinks while pressed.
class _PressScale extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onTap;
  final Widget child;
  const _PressScale(
      {required this.enabled, required this.onTap, required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? .97 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

/// Inline text link (`<button class="link">`).
class AppLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final FontWeight weight;

  /// Optional minimum tap-target height (0 = just the text).
  final double minHeight;

  const AppLink(
    this.label, {
    super.key,
    this.onTap,
    this.color = AppColors.red,
    this.size = 13,
    this.weight = FontWeight.w800,
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget text = Text(
      gt(label),
      style: TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: size,
        fontWeight: weight,
        color: color,
        decoration: TextDecoration.underline,
        decorationColor: color.withOpacity(.35),
      ),
    );
    if (minHeight > 0) {
      text = ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Center(widthFactor: 1, child: text),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: text,
    );
  }
}

/// Circular glass icon button (`.icon-btn`, 46×46, radius 17).
class IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;
  final String? badge;

  const IconBtn(
    this.icon, {
    super.key,
    this.onTap,
    this.size = 46,
    this.iconSize = 21,
    this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    // Center(widthFactor/heightFactor: 1) loosens any tight constraint from a
    // stretching parent, so the tile always stays a size x size square.
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(size == 46 ? 17 : size / 2),
          border: Border.all(color: AppColors.glassEdge),
          boxShadow: AppColors.sh1,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: AppIcon(
                icon,
                size: iconSize,
                color: color ?? AppColors.ink,
                sw: 1.8,
              ),
            ),
            if (badge != null)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.white, width: 1.5),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      height: 1.1,
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
