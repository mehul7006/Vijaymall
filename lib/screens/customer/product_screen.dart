import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/flash_widgets.dart';
import '../../widgets/panels.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_layout.dart';
import '../../widgets/product_card.dart';
import '../../widgets/toast.dart';
import '../../widgets/require_signin.dart';
import 'missing_screen.dart';
import 'sheets/reviews_sheet.dart';
import '../../state/gu_strings.dart';

/// `#/product/{id}` — product detail page (§3.6).
class ProductScreen extends StatelessWidget {
  final String productId;

  const ProductScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    if (state.productById(productId) == null) {
      return MissingScreen(
        title: gt('Product'),
        copy: gt('This product is no longer in the catalogue.'),
        backRoute: '/shop',
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _ProductBody(productId: productId),
      ),
    );
  }
}

class _ProductBody extends StatefulWidget {
  final String productId;

  const _ProductBody({required this.productId});

  @override
  State<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends State<_ProductBody> {
  /// Mirrors the prototype's `ui.pdProduct` / `ui.pdVariant` / `ui.pdQty`.
  String _pid = '';
  int _vi = 0;
  int _qty = 1;

  /// On product change: default pack if in stock, else the first in-stock
  /// pack, else default; qty clamped to `[1, max(1, packStock)]`.
  void _sync(AppState state, Product p) {
    final def = (p.defaultVariant >= 0 && p.defaultVariant < p.variants.length)
        ? p.defaultVariant
        : 0;
    if (_pid != p.id) {
      _pid = p.id;
      var firstInStock = -1;
      for (var i = 0; i < p.variants.length; i++) {
        if (state.variantStock(p, i) > 0) {
          firstInStock = i;
          break;
        }
      }
      _vi = state.variantStock(p, def) > 0
          ? def
          : (firstInStock >= 0 ? firstInStock : def);
      _qty = 1;
    }
    if (_vi < 0 || _vi >= p.variants.length) _vi = def;
    final packStock = state.variantStock(p, _vi);
    final cap = packStock > 1 ? packStock : 1;
    if (_qty > cap) _qty = cap;
    if (_qty < 1) _qty = 1;
  }

  /// `share-product` — no share sheet on this platform, so copy the deep link.
  Future<void> _share(Product p) async {
    await Clipboard.setData(ClipboardData(text: '#/product/${p.id}'));
    showToast(gt('Product link copied'));
  }

  /// `add-pd` — reads qty, resets to 1, then addToCart (§3.6).
  void _add(AppState state, Product p, bool gu) {
    if (!ensureSignedIn(state)) return;
    final qty = _qty;
    setState(() => _qty = 1);
    final err = state.addToCart(p.id, _vi, qty);
    final name = gu ? (p.nameGu.isNotEmpty ? p.nameGu : p.name) : p.name;
    if (err != null) {
      showToast(err, 'error');
    } else {
      showToast('${gu ? 'કાર્ટમાં ઉમેર્યું' : 'Added to cart'} · $name');
    }
  }

  /// `.size` pack button — selected / sold-out states (§3.6).
  Widget _packBtn(AppState state, Product p, int i, bool gu) {
    final v = state.variantOf(p, i);
    final soldOut = state.variantStock(p, i) <= 0;
    final selected = i == _vi;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: soldOut
          ? null
          : () {
              setState(() => _vi = i);
            },
      child: Opacity(
        opacity: soldOut ? .55 : 1,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? StoreKit.redWarm : null,
            color: selected ? null : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.gold : AppColors.line,
                width: selected ? 1.5 : 1),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x40D3202B),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                v.label,
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.white : AppColors.ink2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                soldOut ? (gu ? 'ખતમ' : 'Sold out') : money(v.price),
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 10.5,
                  fontWeight: soldOut ? FontWeight.w800 : FontWeight.w600,
                  color: soldOut
                      ? AppColors.red
                      : (selected ? AppColors.white : AppColors.ink2)
                          .withValues(alpha: .6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(String icon, VoidCallback? onTap, String label) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .35 : 1,
          child: SizedBox(
            width: 34,
            height: 38,
            child: Center(
              child: AppIcon(icon, size: 16, color: AppColors.ink, sw: 2),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final p = state.productById(widget.productId);
    if (p == null) return const SizedBox.shrink();

    _sync(state, p);
    final v = state.variantOf(p, _vi);
    final packStock = state.variantStock(p, _vi);
    final off = discountPct(v);
    final out = !p.available || packStock <= 0;
    final low = !out && packStock <= p.lowStock;
    final inCart = state.cartItems
        .where((it) => it.productId == p.id)
        .fold<int>(0, (n, it) => n + it.qty);
    final cap = packStock > 1 ? packStock : 1;
    final ci = state.categories.indexWhere((c) => c.id == p.category);
    final tn = StoreKit.tone(ci < 0 ? 0 : ci);
    final name = gu ? (p.nameGu.isNotEmpty ? p.nameGu : p.name) : p.name;

    final Widget pill;
    if (out) {
      pill = Pill.out(p.available
          ? (gu ? 'પેક ખતમ' : 'Pack out of stock')
          : (gu ? 'સ્ટોકમાં નથી' : 'Out of stock'));
    } else if (low) {
      pill = Pill.low('Only $packStock left');
    } else {
      pill = Pill.active('In stock');
    }

    final noteBase = p.allowCoins
        ? (gu
            ? 'આ વસ્તુ પર કોઈન્સ વાપરો — ચેકઆઉટ પર 1 કોઈન = ₹1.'
            : 'Use your coins on this item — 1 coin = ₹1 at checkout.')
        : (gu
            ? 'આ વસ્તુ પર કોઈન્સ વાપરી શકાય નહીં.'
            : 'Coins can’t be redeemed on this item, but it still counts toward delivery.');
    final note = p.earnsCoins
        ? '$noteBase ${gu ? 'ડિલિવરી પછી કોઈન્સ પણ મળે.' : 'It also earns coins after delivery.'}'
        : noteBase;


    Widget hero(double h, double art, BorderRadius radius) =>               Container(
                height: h,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [tn.$1, tn.$2],
                  ),
                  borderRadius: radius,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: const Alignment(0, 0.06),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: .88, end: 1),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutBack,
                          builder: (context, v, c) =>
                              Transform.scale(scale: v, child: c),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x66FFFFFF),
                              boxShadow: [
                                BoxShadow(
                                    color: tn.$3.withValues(alpha: .2),
                                    blurRadius: 30,
                                    offset: const Offset(0, 14)),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ProductArtView(p.art, size: art),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconBtn(
                            'back',
                            iconSize: 21,
                            onTap: () => go('/shop'),
                          ),
                          Row(
                            children: [
                              IconBtn(
                                'heart',
                                iconSize: 19,
                                onTap: () {
                                  final nowSaved =
                                      state.toggleWishlist(p.id);
                                  showToast(nowSaved
                                      ? 'Saved for later'
                                      : 'Removed from saved items');
                                },
                              ),
                              const SizedBox(width: 8),
                              IconBtn(
                                'share',
                                iconSize: 18,
                                onTap: () => _share(p),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
    final Widget titleRow =                       Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: _ts(
                                    gu,
                                    size: 24,
                                    w: FontWeight.w800,
                                    height: 1.14,
                                    letterSpacing: -0.035,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.nameGu,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.gujaratiFont,
                                    fontSize: 11,
                                    color: AppColors.ink3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => showReviewsSheet(context, p),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const AppIcon('star',
                                          size: 13, color: AppColors.gold),
                                      const SizedBox(width: 4),
                                      Text(
                                        p.reviews > 0
                                            ? p.rating.toStringAsFixed(1)
                                            : '–',
                                        style: _ts(
                                          gu,
                                          size: 10.5,
                                          w: FontWeight.w800,
                                          color: AppColors.ink2,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        p.reviews > 0
                                            ? '· ${p.reviews} ${gu ? 'સમીક્ષાઓ' : 'reviews'}'
                                            : (gu
                                                ? '· સમીક્ષાઓ લખો'
                                                : '· Write a review'),
                                        style: _ts(
                                          gu,
                                          size: 10.5,
                                          color: AppColors.ink2,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const AppIcon('right',
                                          size: 11, color: AppColors.ink3),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          pill,
                        ],
                      );
    final Widget priceBox =                       Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: StoreKit.card(
                            accent: AppColors.gold, radius: 16, tinted: true),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(v.price),
                              style: _ts(
                                gu,
                                size: 31,
                                w: FontWeight.w900,
                                color: AppColors.red,
                                height: 1,
                                letterSpacing: -0.045,
                              ),
                            ),
                            if (v.strike > v.price) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  money(v.strike),
                                  style: _ts(
                                    gu,
                                    size: 13,
                                    color: AppColors.ink3,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: StoreKit.redWarm,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.gold),
                                ),
                                child: Text(
                                  '$off% off',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
    final List<Widget> flashW = [
                      if (v.flash != null)
                        FlashOfferPanel(
                            offer: v.flash!,
                            qty: _qty,
                            normalPrice: v.listPrice ?? v.price),
    ];
    final Widget tagsW =                       Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            TagPill.green(
                                gu ? 'મફત ડિલિવરી' : 'Free delivery', 'truck'),
                            if (p.earnsCoins)
                              TagPill.gold(
                                  gu ? 'કોઈન્સ મળે' : 'Earns coins', 'coin'),
                            if (p.allowCoins)
                              TagPill.navy(
                                  gu ? 'કોઈન્સ ચાલે' : 'Coins accepted',
                                  'wallet')
                            else
                              _Tag(
                                  gu ? 'કોઈન્સ લાગુ નહીં' : 'No coin redemption'),
                            _Tag(p.unit),
                          ],
                        ),
                      );
    final List<Widget> packW = [
                      const SizedBox(height: 19),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: StoreSectionTitle(
                            gu ? 'પેક પસંદ કરો' : 'Choose a pack'),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < p.variants.length; i++)
                            _packBtn(state, p, i, gu),
                        ],
                      ),
    ];
    final List<Widget> aboutW = [
                      const SizedBox(height: 19),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: StoreSectionTitle(
                            gu ? 'આ વસ્તુ વિશે' : 'About this item'),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: StoreKit.card(
                            accent: tn.$3, radius: 16, tinted: true),
                        child: Text(
                          gu
                              ? (p.descGu.isNotEmpty ? p.descGu : p.desc)
                              : p.desc,
                          style: _ts(
                            gu,
                            size: 12.5,
                            height: 1.7,
                            color: AppColors.ink2,
                          ),
                        ),
                      ),
    ];
    final Widget coinW =                       Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                          decoration: StoreKit.card(
                                  accent: AppColors.gold, radius: 16)
                              .copyWith(color: AppColors.goldTint),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: AppIcon('coin',
                                    size: 17,
                                    color: AppColors.goldInk,
                                    sw: 2),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  note,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.uiFont,
                                    fontSize: 10,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.goldInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
    final Widget promiseW =                       Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: IntrinsicHeight(
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PromiseTile(
                              icon: 'truck',
                              label: gu ? 'મફત હોમ ડિલિવરી' : 'Free home delivery',
                            ),
                            const SizedBox(width: 7),
                            _PromiseTile(
                              icon: 'store',
                              label: gu ? 'સ્ટોરમાં પેક' : 'Packed in store',
                            ),
                            const SizedBox(width: 7),
                            _PromiseTile(
                              icon: 'refresh',
                              label: gu ? 'સહેલું રિપ્લેસમેન્ટ' : 'Easy replacements',
                            ),
                          ],
                        ),
                        ),
                      );
    final List<Widget> inCartW = [
                      if (inCart > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Text(
                                '$inCart ${gu ? 'તમારી કાર્ટમાં' : 'in your cart'} · ',
                                style: _ts(
                                  gu,
                                  size: 11,
                                  height: 1.5,
                                  color: AppColors.ink3,
                                ),
                              ),
                              AppLink(
                                gu ? 'કાર્ટ જુઓ' : 'View cart',
                                size: 11.5,
                                onTap: () => go('/cart'),
                              ),
                            ],
                          ),
                        ),
    ];
    final Widget buyRow =           Row(
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.sh1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stepBtn(
                      'minus',
                      _qty > 1
                          ? () => setState(() {
                                _qty--;
                              })
                          : null,
                      'Decrease',
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 22,
                      child: Text(
                        '$_qty',
                        textAlign: TextAlign.center,
                        style: _ts(gu, size: 14, w: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _stepBtn(
                      'plus',
                      _qty < cap
                          ? () => setState(() {
                                _qty++;
                              })
                          : null,
                      'Increase',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: out ? null : () => _add(state, p, gu),
                  child: Opacity(
                    opacity: out ? .5 : 1,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: StoreKit.redWarm,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gold, width: 1.2),
                        boxShadow: out
                            ? null
                            : const [
                                BoxShadow(
                                    color: Color(0x55D3202B),
                                    blurRadius: 16,
                                    offset: Offset(0, 6)),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon('cart',
                              size: 18, color: AppColors.white, sw: 2.2),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              out
                                  ? (p.available
                                      ? (gu ? 'પેક ખતમ' : 'Pack sold out')
                                      : (gu ? 'સ્ટોક ખતમ' : 'Out of stock'))
                                  : '${gu ? 'ઉમેરો' : 'Add'} · ${money(flashLineTotal(v, _qty))}',
                              overflow: TextOverflow.ellipsis,
                              style: _ts(gu,
                                  size: 15,
                                  w: FontWeight.w800,
                                  color: AppColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      final related = state.products
          .where((x) => x.id != p.id && x.category == p.category)
          .toList();
      return Column(
        children: [
          const StatusBar(),
          ScreenScroll(
            bottom: 40,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: hero(660, 440, BorderRadius.circular(28)),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      flex: 10,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
                        decoration: StoreKit.card(
                            accent: AppColors.red, radius: 24, tinted: true),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            titleRow,
                            priceBox,
                            ...flashW,
                            tagsW,
                            ...packW,
                            const SizedBox(height: 19),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: StoreSectionTitle(
                                  gu ? 'જથ્થો' : 'Quantity'),
                            ),
                            buyRow,
                            ...inCartW,
                            promiseW,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: aboutW,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 19),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: StoreSectionTitle(
                                gu ? 'કોઈન્સ' : 'Coins'),
                          ),
                          coinW,
                        ],
                      ),
                    ),
                  ],
                ),
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  StoreShelf(
                    title: gu ? 'સમાન વસ્તુઓ' : 'More from this category',
                    itemCount: related.length,
                    itemWidth: 220,
                    height: 340,
                    itemBuilder: (ctx, i) =>
                        ProductCard(related[i], width: 220),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }


    return Column(
      children: [
        const StatusBar(),
        ScreenScroll(
          bottom: 132,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hero(
                  300,
                  212,
                  const BorderRadius.vertical(
                      bottom: Radius.circular(32))),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
                  decoration: const BoxDecoration(
                    color: Color(0xDCFFFFFF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleRow,
                      priceBox,
                      ...flashW,
                      tagsW,
                      ...packW,
                      ...aboutW,
                      coinW,
                      promiseW,
                      ...inCartW,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ActionBar(
          solid: true,
          child: buyRow,
        ),
      ],
    );
  }
}

/// `.tag` without an icon (unit / no-coin-redemption chips).
class _Tag extends StatelessWidget {
  final String label;

  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.ink2,
        ),
      ),
    );
  }
}

/// `.pd-promise div` — icon over label tile.
class _PromiseTile extends StatelessWidget {
  final String icon;
  final String label;

  const _PromiseTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
        decoration: StoreKit.card(accent: AppColors.navy, radius: 14),
        child: Column(
          children: [
            AppIcon(icon, size: 16, color: AppColors.navy, sw: 1.9),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Localized text style — `gu` picks the Gujarati family, else the UI font.
TextStyle _ts(
  bool gu, {
  required double size,
  FontWeight w = FontWeight.w600,
  Color color = AppColors.ink,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
}
