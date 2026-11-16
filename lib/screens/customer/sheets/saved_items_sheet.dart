import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../nav/nav.dart';
import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/sheet.dart';
import '../../../state/gu_strings.dart';

/// §3.14 `Saved items` — the wishlist as tappable inventory rows.
void showSavedItemsSheet(BuildContext context) {
  final st = StateScope.read(context);
  final saved =
      st.wishlist.map(st.productById).whereType<Product>().length;

  showAppSheet<void>(
    context: context,
    title: gt('Saved items'),
    sub: '$saved product${saved == 1 ? '' : 's'}',
    builder: (ctx) => const _SavedItemsBody(),
    footer: Builder(
      builder: (c) => AppButton(
        'Done',
        variant: BtnVariant.secondary,
        block: true,
        onTap: () => Navigator.of(c).maybePop(),
      ),
    ),
  );
}

class _SavedItemsBody extends StatelessWidget {
  const _SavedItemsBody();

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    final gu = st.lang == 'gu';
    final saved =
        st.wishlist.map(st.productById).whereType<Product>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (saved.isEmpty)
          EmptyState(
            icon: 'heart',
            title: gt('Nothing saved yet'),
            copy: gt('Tap the heart on any product to save it for later.'),
            actionLabel: gt('Browse products'),
            onAction: () {
              Navigator.of(context).maybePop();
              go('/shop');
            },
          )
        else
          for (final p in saved) _SavedRow(product: p, gu: gu),
      ],
    );
  }
}

/// `.inventory-row` — thumb + name + `{unit} · {price}` + chevron.
class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.product, required this.gu});

  final Product product;
  final bool gu;

  @override
  Widget build(BuildContext context) {
    final st = StateScope.read(context);
    final vi =
        product.defaultVariant < product.variants.length ? product.defaultVariant : 0;
    final v = st.variantOf(product, vi);
    final name =
        gu ? (product.nameGu.isNotEmpty ? product.nameGu : product.name) : product.name;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).maybePop();
        go('/product/${product.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(17),
          boxShadow: AppColors.sh1,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: toneBg(product.tone),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: ProductArtView(product.art, size: 38),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(gu, size: 14, w: FontWeight.w800, height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${v.unit} · ${money(v.price)}',
                    style: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12,
                      color: AppColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const AppIcon('right', size: 15, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

/// Bilingual text style — Gujarati falls back to the Hind Vadodara family.
TextStyle _ts(
  bool gu, {
  double size = 11.5,
  FontWeight w = FontWeight.w600,
  Color color = AppColors.ink,
  double? height,
}) {
  if (gu) return AppTheme.guj(size: size, w: w, color: color);
  return TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
  );
}
