import 'package:flutter/material.dart' hide Stepper;

import '../nav/nav.dart';
import '../provider/state_scope.dart';
import '../state/app_state.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'controls.dart';
import 'product_card.dart' show toneBg;
import 'require_signin.dart';
import 'store_kit.dart';
import 'toast.dart';

int _cartIndex(AppState state, String productId, int variantIndex) =>
    state.cartItems.indexWhere(
        (it) => it.productId == productId && it.variantIndex == variantIndex);

/// Right-hand cart panel for desktop customer pages.
class StoreMiniCart extends StatelessWidget {
  const StoreMiniCart({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final lines = state.cartDetails();
    final count = state.cartCount();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: StoreKit.card(accent: AppColors.red, radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(count),
          if (lines.isEmpty)
            _empty()
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: lines.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 16, thickness: 1, color: Color(0x14000000)),
                itemBuilder: (ctx, i) => _line(state, lines[i], i),
              ),
            ),
            _footer(state),
          ],
        ],
      ),
    );
  }

  Widget _header(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(gradient: StoreKit.heroNavyRed),
      child: Row(
        children: [
          const AppIcon('cart', size: 20, color: AppColors.white, sw: 2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(gt('Your cart'),
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: StoreKit.goldWarm,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppColors.redTint, shape: BoxShape.circle),
            child: const Center(
                child: AppIcon('cart', size: 28, color: AppColors.red, sw: 1.8)),
          ),
          const SizedBox(height: 12),
          Text(gt('Your cart is empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _line(AppState state, CartLine line, int i) {
    final p = line.p;
    final gu = state.lang == 'gu';
    final name = gu && p.nameGu.isNotEmpty ? p.nameGu : p.name;
    final pack = line.v.label.trim().isNotEmpty ? line.v.label : line.v.unit;
    final tn = StoreKit.tone(i);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [toneBg(p.tone), tn.$2.withValues(alpha: .65)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: ProductArtView(p.art, size: 38)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              if (pack.isNotEmpty)
                Text(pack,
                    style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11,
                        color: AppColors.ink3)),
              const SizedBox(height: 4),
              Text(money(line.lineTotal),
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Stepper(
          compact: true,
          value: line.qty,
          ariaDec: gt('Decrease'),
          ariaInc: gt('Increase'),
          onDec: () => _change(state, line, -1),
          onInc: () => _change(state, line, 1),
        ),
      ],
    );
  }

  void _change(AppState state, CartLine line, int delta) {
    final idx = _cartIndex(state, line.productId, line.variantIndex);
    if (idx < 0) return;
    final err = state.setQty(idx, delta);
    if (err != null) showToast(err, 'error');
  }

  Widget _footer(AppState state) {
    final t = state.cartTotals();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        gradient: StoreKit.creamSoft,
        border: Border(top: BorderSide(color: Color(0x1A000000))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sumRow(gt('Subtotal'), money(t.subtotal), false),
          const SizedBox(height: 6),
          _sumRow(gt('Total'), money(t.total), true),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => go('/cart'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: StoreKit.redWarm,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x40D3202B),
                        offset: Offset(0, 6),
                        blurRadius: 12),
                  ],
                ),
                child: Center(
                  child: Text(gt('View cart & checkout'),
                      style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value, bool strong) {
    final s = TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: strong ? 15 : 12.5,
        fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
        color: strong ? AppColors.ink : AppColors.ink3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: s), Text(value, style: s)],
    );
  }
}

/// Compact ADD / - qty + control for product cards.
class StoreAddStepper extends StatelessWidget {
  final String productId;
  final int variantIndex;

  const StoreAddStepper(
      {super.key, required this.productId, required this.variantIndex});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final p = state.productById(productId);
    if (p == null) return const SizedBox.shrink();
    final vi = (variantIndex >= 0 && variantIndex < p.variants.length)
        ? variantIndex
        : p.defaultVariant;
    final soldOut = !p.available || state.variantStock(p, vi) <= 0;
    final idx = _cartIndex(state, productId, vi);
    final qty = idx >= 0 ? state.cartItems[idx].qty : 0;

    if (qty > 0) {
      return Container(
        height: 34,
        decoration: BoxDecoration(
          gradient: StoreKit.redWarm,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn('minus', () => _change(state, productId, vi, -1)),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 22),
              child: Text('$qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white)),
            ),
            _btn('plus', () => _change(state, productId, vi, 1)),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: soldOut
          ? null
          : () {
              if (!ensureSignedIn(state)) return;
              final err = state.addToCart(productId, vi, 1);
              if (err != null) {
                showToast(err, 'error');
              } else {
                showToast('Added to cart');
              }
            },
      child: Opacity(
        opacity: soldOut ? .4 : 1,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: StoreKit.redWarm,
            borderRadius: BorderRadius.circular(99),
            boxShadow: soldOut
                ? null
                : const [
                    BoxShadow(
                        color: Color(0x40D3202B),
                        offset: Offset(0, 4),
                        blurRadius: 8),
                  ],
          ),
          child: Text(gt('ADD'),
              style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                  color: AppColors.white)),
        ),
      ),
    );
  }

  Widget _btn(String icon, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 34,
          child: Center(
              child: AppIcon(icon, size: 14, color: AppColors.white, sw: 2.6)),
        ),
      );

  static void _change(AppState state, String pid, int vi, int delta) {
    final idx = _cartIndex(state, pid, vi);
    if (idx < 0) return;
    final err = state.setQty(idx, delta);
    if (err != null) showToast(err, 'error');
  }
}
