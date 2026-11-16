import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'store_kit.dart';

/// Customer-only building blocks for the profile / wallet / setup pages.
/// Colour and layout only; every value is passed in by the screen.

TextStyle _shopTs(bool gu, double size, FontWeight w, Color c,
    {double? height}) {
  if (gu) return AppTheme.guj(size: size, w: w, color: c);
  return TextStyle(
      fontFamily: AppTheme.uiFont,
      fontSize: size,
      fontWeight: w,
      color: c,
      height: height);
}

/// Menu row: coloured icon badge, title, subtitle and a chevron / trailing.
class ShopperMenuCard extends StatelessWidget {
  final String icon;
  final String title;
  final String? sub;
  final VoidCallback? onTap;
  final int toneIndex;
  final Widget? trailing;
  final bool danger;
  final bool gu;

  const ShopperMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.gu,
    this.sub,
    this.onTap,
    this.toneIndex = 0,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = danger ? StoreKit.tone(0) : StoreKit.tone(toneIndex);
    final accent = danger ? AppColors.red : t.$3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor:
            onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: StoreKit.card(accent: accent, radius: 18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.$1, t.$2],
                  ),
                ),
                child: Center(
                    child: AppIcon(icon, size: 22, color: accent, sw: 1.9)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _shopTs(gu, 14.5, FontWeight.w800,
                            danger ? AppColors.red : AppColors.ink)),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _shopTs(
                              gu, 12, FontWeight.w600, AppColors.ink2,
                              height: 1.35)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: t.$1.withValues(alpha: .7),
                        shape: BoxShape.circle),
                    child: Center(
                        child: AppIcon('right',
                            size: 14, color: accent, sw: 2.2)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Group heading for a block of menu cards.
class ShopperGroupTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const ShopperGroupTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        children: [
          Expanded(child: StoreSectionTitle(title)),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                gradient: StoreKit.goldWarm,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(trailing!,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldInk)),
            ),
        ],
      ),
    );
  }
}

/// Coloured shortcut tile (orders / coins / addresses ...).
class ShopperShortcutTile extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final int toneIndex;
  final bool gu;
  final VoidCallback? onTap;

  const ShopperShortcutTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.gu,
    this.toneIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = StoreKit.tone(toneIndex);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.$1, t.$2],
          ),
          boxShadow: [
            BoxShadow(
                color: t.$3.withValues(alpha: .18),
                offset: const Offset(0, 6),
                blurRadius: 14),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 20, color: t.$3, sw: 1.9),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: _shopTs(false, 20, FontWeight.w800, t.$3,
                      height: 1.1)),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _shopTs(gu, 11.5, FontWeight.w700, t.$3)),
          ],
        ),
      ),
    );
  }
}
