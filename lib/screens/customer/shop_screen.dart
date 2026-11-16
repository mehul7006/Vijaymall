import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/panels.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_layout.dart';
import '../../widgets/store_mini_cart.dart';
import '../../state/gu_strings.dart';
import '../../widgets/toast.dart';
import 'sheets/filters_sheet.dart';

/// `#/shop` — search results / category / hot sale shelf (§3.5).
class ShopScreen extends StatelessWidget {
  final String query;
  final String category;
  final bool hot;

  const ShopScreen({
    super.key,
    this.query = '',
    this.category = '',
    this.hot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _ShopBody(query: query, category: category, hot: hot),
      ),
    );
  }
}

class _ShopBody extends StatefulWidget {
  final String query;
  final String category;
  final bool hot;

  const _ShopBody({
    required this.query,
    required this.category,
    required this.hot,
  });

  @override
  State<_ShopBody> createState() => _ShopBodyState();
}

class _ShopBodyState extends State<_ShopBody> {
  String _sort = 'popular';
  bool _stock = false;
  bool _coins = false;
  late final TextEditingController _search;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.query);
    // A fresh visit of the shelf always starts unfiltered (sort / toggles are
    // kept in AppState only while this screen is alive).
    final flow = StateScope.read(context).flow;
    flow.shopSort = 'popular';
    flow.shopStock = false;
    flow.shopCoins = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      final flow = StateScope.read(context).flow;
      _sort = flow.shopSort;
      _stock = flow.shopStock;
      _coins = flow.shopCoins;
    }
  }

  @override
  void didUpdateWidget(covariant _ShopBody old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      _search.text = widget.query;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _filterCount =>
      (_stock ? 1 : 0) + (_coins ? 1 : 0) + (_sort != 'popular' ? 1 : 0);

  /// Anything narrowing the shelf: sheet filters, search text, category, hot.
  bool get _anyActive =>
      _filterCount > 0 ||
      _search.text.trim().isNotEmpty ||
      widget.query.isNotEmpty ||
      widget.category.isNotEmpty ||
      widget.hot;

  void _applyFilters(String sort, bool stock, bool coins) {
    final state = StateScope.read(context);
    state.flow.shopSort = sort;
    state.flow.shopStock = stock;
    state.flow.shopCoins = coins;
    setState(() {
      _sort = sort;
      _stock = stock;
      _coins = coins;
    });
  }

  /// Sheet-only reset (sort + toggles); search / category stay.
  void _resetFilters() {
    _applyFilters('popular', false, false);
    showToast('Filters cleared');
  }

  /// Full reset: sheet filters, typed + applied search, category and hot
  /// (the URL goes back to a bare `/shop`).
  void _clearEverything() {
    _applyFilters('popular', false, false);
    _search.clear();
    if (widget.query.isNotEmpty ||
        widget.category.isNotEmpty ||
        widget.hot) {
      go('/shop');
    }
    showToast('Filters cleared');
  }

  /// Filter pipeline: copy → cat → hot → query → stock → coins → sort.
  List<Product> _results(AppState state) {
    var list = List<Product>.of(state.products);
    if (widget.category.isNotEmpty) {
      list = list.where((p) => p.category == widget.category).toList();
    }
    if (widget.hot) {
      list = list
          .where((p) => state.hotSale.featured.contains(p.id))
          .toList();
    }
    final q = widget.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              '${p.name} ${p.nameGu} ${p.category}'.toLowerCase().contains(q))
          .toList();
    }
    if (_stock) {
      list = list.where((p) => p.available && p.stock > 0).toList();
    }
    if (_coins) {
      list = list.where((p) => p.allowCoins || p.earnsCoins).toList();
    }

    num priceOf(Product p) {
      final vi = p.defaultVariant < p.variants.length ? p.defaultVariant : 0;
      return state.variantOf(p, vi).price;
    }

    if (_sort == 'price-low') {
      list.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
    } else if (_sort == 'price-high') {
      list.sort((a, b) => priceOf(b).compareTo(priceOf(a)));
    } else if (_sort == 'rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      list.sort((a, b) => b.reviews.compareTo(a.reviews));
    }
    return list;
  }

  void _submitSearch(String value) {
    final params = <String, String>{};
    final q = value.trim();
    if (q.isNotEmpty) params['q'] = q;
    if (widget.category.isNotEmpty) params['cat'] = widget.category;
    if (widget.hot) params['hot'] = '1';
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    go(qs.isEmpty ? '/shop' : '/shop?$qs');
  }

  void _clearSearch() {
    _search.clear();
    setState(() {});
    if (widget.query.isEmpty) return;
    go(widget.category.isNotEmpty ? '/shop?cat=${widget.category}' : '/shop');
  }

  /// First real product photo of the category from the backend list, if any.
  Widget? _catPhoto(AppState state, Category c, double size) {
    for (final p in state.products) {
      if (p.category != c.id) continue;
      final a = p.art.trim();
      if (a.startsWith('http://') ||
          a.startsWith('https://') ||
          a.startsWith('/')) {
        return SizedBox(
          width: size,
          height: size,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: ProductArtView(p.art, size: size),
          ),
        );
      }
    }
    return null;
  }

  /// Product grid / loading / empty states (shared by phone and wide layouts).
  Widget _resultsBlock(AppState state, bool gu, List<Product> results,
      double bw, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
              // results
              if (results.isEmpty && storefrontLoading(state))
                LoadingOrElse(
                  skeleton: const ProductGridSkeleton(count: 6),
                  fallback: ErrorState(
                    onRetry: () => refreshStorefront(state),
                  ),
                )
              else if (results.isEmpty)
                EmptyState(
                  icon: 'search',
                  title: gu ? 'કોઈ વસ્તુ મળી નથી' : 'No products found',
                  copy: gu
                      ? 'બીજી કેટેગરી અજમાવો અથવા ફિલ્ટર સાફ કરો.'
                      : 'Try another category or clear your filters.',
                  actionLabel: gu ? 'ફિલ્ટર સાફ કરો' : 'Clear filters',
                  onAction: _clearEverything,
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final int cols;
                    if (wide) {
                      cols = StoreBreakpoints.gridCols(c.maxWidth,
                          minCard: 168);
                    } else if (StoreBreakpoints.mid(bw)) {
                      cols = 3;
                    } else {
                      cols = c.maxWidth >= 560 ? 3 : 2;
                    }
                    final w = ((c.maxWidth - 12 * (cols - 1)) / cols)
                        .clamp(120.0, wide ? 400.0 : 240.0)
                        .toDouble();
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final p in results) ProductCard(p, width: w),
                      ],
                    );
                  },
                ),
      ],
    );
  }

  Widget _sideTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(t,
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
                color: AppColors.ink)),
      );

  Widget _sideRow(String label, String icon, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              gradient: on ? StoreKit.redWarm : null,
              color: on ? null : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: on
                      ? AppColors.gold
                      : AppColors.red.withValues(alpha: .14),
                  width: on ? 1.3 : 1),
            ),
            child: Row(children: [
              AppIcon(icon,
                  size: 14, color: on ? AppColors.white : AppColors.red, sw: 2),
              const SizedBox(width: 9),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: on ? AppColors.white : AppColors.ink2)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Left filter rail for wide screens (same sort / in-stock / coins state as
  /// the filters sheet, plus category navigation).
  Widget _filterRail(AppState state, bool gu, List<Category> cats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: StoreKit.card(accent: AppColors.gold, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sideTitle(gu ? 'કેટેગરી' : 'Category'),
          _sideRow(gu ? 'બધું' : 'All', 'store',
              widget.category.isEmpty && !widget.hot, () => go('/shop')),
          for (final c in cats)
            _sideRow(gu ? c.nameGu : c.name, c.icon, widget.category == c.id,
                () => go('/shop?cat=${c.id}')),
          _sideTitle(gt('Sort by')),
          _sideRow(gt('Popular'), 'star', _sort == 'popular',
              () => _applyFilters('popular', _stock, _coins)),
          _sideRow(gt('Top rated'), 'star', _sort == 'rating',
              () => _applyFilters('rating', _stock, _coins)),
          _sideRow(gt('Price low to high'), 'filter', _sort == 'price-low',
              () => _applyFilters('price-low', _stock, _coins)),
          _sideRow(gt('Price high to low'), 'filter', _sort == 'price-high',
              () => _applyFilters('price-high', _stock, _coins)),
          _sideTitle(gt('Filters')),
          _sideRow(gt('In stock'), 'check', _stock,
              () => _applyFilters(_sort, !_stock, _coins)),
          _sideRow(gt('Coins'), 'coin', _coins,
              () => _applyFilters(_sort, _stock, !_coins)),
          if (_anyActive) ...[
            const SizedBox(height: 6),
            AppLink(
              gu ? 'ફિલ્ટર સાફ કરો' : 'Clear filters',
              onTap: _clearEverything,
              minHeight: 32,
            ),
          ],
        ],
      ),
    );
  }

  // BUILD -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final bw = MediaQuery.sizeOf(context).width;
    final wide = StoreBreakpoints.wide(bw);
    final results = _results(state);
    final total = state.products.length;

    // title precedence: q → hot → cat → all
    var title = gu ? 'બધી વસ્તુઓ' : 'All products';
    if (widget.category.isNotEmpty) {
      title = widget.category;
      for (final c in state.categories) {
        if (c.id == widget.category) {
          title = gu ? c.nameGu : c.name;
          break;
        }
      }
    }
    if (widget.hot) title = gu ? 'હોટ સેલ' : 'Hot sale';
    if (widget.query.isNotEmpty) {
      title = gu ? 'શોધ પરિણામ' : 'Search results';
    }

    final qPart = widget.query.isEmpty
        ? ''
        : (gu ? ' “${widget.query}” માટે' : ' for “${widget.query}”');
    final n = results.length;
    final sub = gu
        ? '$n વસ્તુઓ$qPart · મફત ડિલિવરી'
        : '$n product${n == 1 ? '' : 's'}$qPart · free delivery';

    final cats = state.categories
        .where((c) => state.products.any((p) => p.category == c.id))
        .toList();

    var sortSuffix = '';
    if (_sort == 'rating') sortSuffix = ' · Top rated';
    if (_sort == 'price-low') sortSuffix = ' · Price low to high';
    if (_sort == 'price-high') sortSuffix = ' · Price high to low';

    return Column(
      children: [
        const StatusBar(),

        // inline app bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
              IconBtn('back', onTap: () => go('/home')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gu
                          ? AppTheme.guj(
                              size: 22,
                              w: FontWeight.w800,
                              color: AppColors.ink,
                            )
                          : const TextStyle(
                              fontFamily: AppTheme.uiFont,
                              fontSize: 24,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.035,
                              color: AppColors.ink,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily:
                            gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!wide)
              IconBtn(
                'filter',
                badge: _filterCount > 0 ? '$_filterCount' : null,
                onTap: () => showFiltersSheet(
                  context,
                  stock: _stock,
                  coins: _coins,
                  sort: _sort,
                  onApply: _applyFilters,
                  onClear: _resetFilters,
                ),
              ),
            ],
          ),
        ),

        ScreenScroll(
          bottom: 112,
          padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
          onRefresh: () => refreshStorefront(StateScope.read(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // search field
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
                  border: Border.all(color: AppColors.line),
                  boxShadow: AppColors.sh1,
                ),
                child: Row(
                  children: [
                    const AppIcon('search', size: 17, color: AppColors.ink3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: _submitSearch,
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: gu ? 'આ શેલ્ફમાં શોધો…' : 'Search this shelf…',
                          hintStyle: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                    ),
                    if (_search.text.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _clearSearch,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child:
                              AppIcon('close', size: 15, color: AppColors.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // category tiles
              StoreSectionTitle(gu ? 'કેટેગરી' : 'Shop by category'),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StoreCategoryTile(
                      index: 0,
                      size: 72,
                      label: gu ? 'બધું' : 'All',
                      icon: 'store',
                      selected: widget.category.isEmpty && !widget.hot,
                      onTap: () => go('/shop'),
                    ),
                    for (var i = 0; i < cats.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: StoreCategoryTile(
                          index: i + 1,
                          size: 72,
                          label: gu ? cats[i].nameGu : cats[i].name,
                          icon: cats[i].icon,
                          image: _catPhoto(state, cats[i], 72),
                          selected: widget.category == cats[i].id,
                          onTap: () => go('/shop?cat=${cats[i].id}'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 250, child: _filterRail(state, gu, cats)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
              // count line
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  gu
                                      ? 'દર્શાવે છે $n માંથી $total વસ્તુઓ$sortSuffix'
                                      : 'Showing $n of $total items$sortSuffix',
                                  style: TextStyle(
                                    fontFamily:
                                        gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink3,
                                  ),
                                ),
                              ),
                              if (_anyActive) ...[
                                const SizedBox(width: 8),
                                AppLink(
                                  gu ? 'ફિલ્ટર સાફ કરો' : 'Clear filters',
                                  onTap: _clearEverything,
                                  minHeight: 32,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          _resultsBlock(state, gu, results, bw, wide),
                        ],
                      ),
                    ),
                    if (bw >= 1300) ...[
                      const SizedBox(width: 20),
                      const SizedBox(width: 330, child: StoreMiniCart()),
                    ],
                  ],
                )
              else ...[
              // sort / filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ShopChip(gt('Popular'), 'star', _sort == 'popular',
                        () => _applyFilters('popular', _stock, _coins)),
                    const SizedBox(width: 8),
                    _ShopChip(gt('Top rated'), 'star', _sort == 'rating',
                        () => _applyFilters('rating', _stock, _coins)),
                    const SizedBox(width: 8),
                    _ShopChip(gt('Price low to high'), 'filter',
                        _sort == 'price-low',
                        () => _applyFilters('price-low', _stock, _coins)),
                    const SizedBox(width: 8),
                    _ShopChip(gt('Price high to low'), 'filter',
                        _sort == 'price-high',
                        () => _applyFilters('price-high', _stock, _coins)),
                    const SizedBox(width: 8),
                    _ShopChip(gt('In stock'), 'check', _stock,
                        () => _applyFilters(_sort, !_stock, _coins)),
                    const SizedBox(width: 8),
                    _ShopChip(gt('Coins'), 'coin', _coins,
                        () => _applyFilters(_sort, _stock, !_coins)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // count line
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gu
                          ? 'દર્શાવે છે $n માંથી $total વસ્તુઓ$sortSuffix'
                          : 'Showing $n of $total items$sortSuffix',
                      style: TextStyle(
                        fontFamily:
                            gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                  if (_anyActive) ...[
                    const SizedBox(width: 8),
                    AppLink(
                      gu ? 'ફિલ્ટર સાફ કરો' : 'Clear filters',
                      onTap: _clearEverything,
                      minHeight: 32,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              _resultsBlock(state, gu, results, bw, wide),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Sort / filter chip: gradient when active.
class _ShopChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool on;
  final VoidCallback onTap;

  const _ShopChip(this.label, this.icon, this.on, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          gradient: on ? StoreKit.redWarm : null,
          color: on ? null : AppColors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: on ? AppColors.gold : AppColors.red.withValues(alpha: .18),
              width: on ? 1.4 : 1),
          boxShadow: on
              ? [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: .28),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(icon,
              size: 13, color: on ? AppColors.white : AppColors.red, sw: 2),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: on ? AppColors.white : AppColors.ink2)),
        ]),
      ),
    );
  }
}
