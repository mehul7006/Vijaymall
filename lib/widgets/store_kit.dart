import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Shared "warm premium" look for the customer side: brand red, gold, navy and
/// warm cream. Colour and decoration only: it never changes data or flows.
class StoreKit {
  StoreKit._();

  /// Six category colours, used round-robin by position so neighbours differ.
  /// (soft top, deeper bottom, ink for text/icons on top of it)
  static const List<(Color, Color, Color)> tones = [
    (Color(0xFFFFE3E5), Color(0xFFFFB9BF), Color(0xFFB3121C)), // rose
    (Color(0xFFFFF0C2), Color(0xFFFFD66B), Color(0xFF7A4B00)), // gold
    (Color(0xFFE0E6FF), Color(0xFFB4C1F7), Color(0xFF1F2A6B)), // navy blue
    (Color(0xFFD9F5E6), Color(0xFFA6E3C3), Color(0xFF0B6B44)), // mint
    (Color(0xFFFFE6D2), Color(0xFFFFC49A), Color(0xFF9A4208)), // peach
    (Color(0xFFEBE0FA), Color(0xFFD0B9F2), Color(0xFF4F2A91)), // lilac
  ];

  static (Color, Color, Color) tone(int i) => tones[i % tones.length];

  /// Hero banners.
  static const LinearGradient heroNavyRed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF121A47), Color(0xFF2B3A9A), Color(0xFFB3121C)],
    stops: [0.0, 0.55, 1.0],
  );
  static const LinearGradient goldWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD66B), Color(0xFFF5B301), Color(0xFFE8890C)],
  );
  static const LinearGradient redWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEE4A52), Color(0xFFD3202B), Color(0xFF8E1B1B)],
  );
  static const LinearGradient creamSoft = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFBF2), Color(0xFFFFF3DC)],
  );

  /// White card with a warm hairline border and a soft coloured shadow.
  static BoxDecoration card({
    Color accent = AppColors.red,
    double radius = 18,
    bool tinted = false,
  }) =>
      BoxDecoration(
        gradient: tinted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: .08), AppColors.white],
                stops: const [0.0, 0.7],
              )
            : null,
        color: tinted ? null : AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: .10),
              offset: const Offset(0, 8),
              blurRadius: 22),
        ],
      );
}

/// Section heading with a gold-red accent bar and an optional "See all".
class StoreSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? icon;

  const StoreSectionTitle(this.title,
      {super.key, this.subtitle, this.actionLabel, this.onAction, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 5,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gold, AppColors.red],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          AppIcon(icon!, size: 20, color: AppColors.red),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                      color: AppColors.ink)),
              if (subtitle != null)
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 12,
                        color: AppColors.ink3)),
            ],
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red)),
            ),
          ),
      ],
    );
  }
}

/// Round category tile: a coloured gradient disc with the category photo (or
/// icon) and the name under it. [image] is any widget (for example the first
/// product photo of that category from the backend); [icon] is the fallback.
class StoreCategoryTile extends StatelessWidget {
  final int index;
  final String label;
  final String? sub;
  final String icon;
  final Widget? image;
  final bool selected;
  final VoidCallback? onTap;
  final double size;

  const StoreCategoryTile({
    super.key,
    required this.index,
    required this.label,
    required this.icon,
    this.sub,
    this.image,
    this.selected = false,
    this.onTap,
    this.size = 84,
  });

  @override
  Widget build(BuildContext context) {
    final t = StoreKit.tone(index);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size + 14,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [t.$1, t.$2],
                ),
                border: Border.all(
                    color: selected ? t.$3 : AppColors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: t.$3.withValues(alpha: selected ? .35 : .18),
                      offset: const Offset(0, 8),
                      blurRadius: 16),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: image ??
                    AppIcon(icon, size: size * .42, color: t.$3, sw: 1.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? t.$3 : AppColors.ink)),
            if (sub != null)
              Text(sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 10.5,
                      color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }
}

/// Small stock badge: In stock (green), Low stock (gold), Out of stock (red).
/// Pass the numbers the backend sent; this only picks colour and wording.
class StoreStockBadge extends StatelessWidget {
  final String label;
  final StoreStockLevel level;
  const StoreStockBadge(this.label, this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (level) {
      StoreStockLevel.ok => (AppColors.greenTint, AppColors.green),
      StoreStockLevel.low => (AppColors.goldTint, AppColors.goldInk),
      StoreStockLevel.out => (AppColors.redTint, AppColors.red3),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: .25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1.2)),
      ]),
    );
  }
}

enum StoreStockLevel { ok, low, out }
