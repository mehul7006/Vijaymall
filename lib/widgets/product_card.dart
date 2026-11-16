import 'package:flutter/material.dart';

import '../data/models.dart';
import '../nav/nav.dart';
import '../provider/state_scope.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../state/gu_strings.dart';
import 'app_icon.dart';
import 'flash_widgets.dart';
import 'skeleton.dart';
import 'store_kit.dart';
import 'store_mini_cart.dart' show StoreAddStepper;
import 'toast.dart';

/// `tone-{tone}` background colours from styles.css.
Color toneBg(String tone) => switch (tone) {
      'mint' => const Color(0xFFDFF4EA),
      'peach' => const Color(0xFFFFE9DC),
      'gold' => const Color(0xFFFFF1C8),
      'rose' => const Color(0xFFFBE3EA),
      'sky' => const Color(0xFFE3F1FA),
      'lilac' => const Color(0xFFECE7F8),
      'sand' => const Color(0xFFF6EDDD),
      _ => AppColors.bg,
    };

/// `productCard(p)` — used on Home, Shop and hot rails.
class ProductCard extends StatelessWidget {
  final Product p;
  final double width;

  const ProductCard(this.p, {super.key, this.width = 172});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.read(context);
    final gu = state.lang == 'gu';
    final vi = p.defaultVariant < p.variants.length ? p.defaultVariant : 0;
    final v = state.variantOf(p, vi);
    final stock = state.variantStock(p, vi);
    final soldOut = !p.available || stock <= 0;
    final off = discountPct(v);
    final saved = state.isSaved(p.id);

    final ci = state.categories.indexWhere((c) => c.id == p.category);
    final t = StoreKit.tone(ci < 0 ? 0 : ci);
    final level = soldOut
        ? StoreStockLevel.out
        : (stock <= p.lowStock || stock <= 5
            ? StoreStockLevel.low
            : StoreStockLevel.ok);
    final stockLabel = soldOut
        ? gt('Sold out')
        : (level == StoreStockLevel.low
            ? (gu ? 'માત્ર $stock બાકી' : 'Only $stock left')
            : gt('In stock'));

    return Pressable(
      scale: .975,
      onTap: () => go('/product/${p.id}'),
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: StoreKit.card(accent: t.$3, radius: 20, tinted: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Stack(
                children: [
                  Container(
                    height: (width * .62).clamp(116.0, 190.0).toDouble(),
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [t.$1, t.$2],
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Center(child: ProductArtView(p.art, size: (width * .56).clamp(100.0, 170.0).toDouble())),
                  ),
                  if (v.flash != null)
                    Positioned(top: 8, left: 8, child: FlashBadge(v.flash!))
                  else if (off > 0)
                    Positioned(
                      top: 8,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
                        decoration: BoxDecoration(
                          gradient: StoreKit.redWarm,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(99)),
                          border: Border.all(
                              color: AppColors.gold, width: 1),
                        ),
                        child: Text(
                          gu ? '$off% છૂટ' : '$off% off',
                          style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  if (soldOut)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x99FFFFFF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final nowSaved = state.toggleWishlist(p.id);
                        showToast(nowSaved
                            ? 'Saved for later'
                            : 'Removed from saved items');
                      },
                      // 44x44 hit area around the 30px visual.
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: saved
                                ? AppColors.redTint
                                : const Color(0xF2FFFFFF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: t.$3.withValues(alpha: .18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Center(
                            child: AnimatedScale(
                              scale: saved ? 1.15 : 1,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              child: AppIcon(
                                'heart',
                                size: 15,
                                color: saved ? AppColors.red : AppColors.ink2,
                                sw: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gu ? (p.nameGu.isNotEmpty ? p.nameGu : p.name) : p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const AppIcon('star', size: 10, color: AppColors.gold),
                      const SizedBox(width: 3),
                      Text(
                        '${p.rating}',
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '· ${v.label}',
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 10.5,
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  StoreStockBadge(stockLabel, level),
                  if (v.flash != null && !soldOut) ...[
                    const SizedBox(height: 5),
                    FlashOfferCountdown(v.flash!,
                        prefix: '${gt('Ends in')} ',
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.red,
                        )),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Text(
                              money(v.price),
                              style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                            if (v.strike > v.price) ...[
                              const SizedBox(width: 5),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 1),
                                child: Text(
                                  money(v.strike),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink3,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      StoreAddStepper(productId: p.id, variantIndex: vi),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
