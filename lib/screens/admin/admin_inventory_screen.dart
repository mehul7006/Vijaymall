import 'package:flutter/material.dart';

import '../../data/gst_cache.dart';
import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_alerts.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';

/// `#/admin/inventory` — searchable catalogue with category chips + add FAB.
///
/// Deep link `?filter=low|out|active|inactive` preselects a stock chip. All
/// filters are local to one visit of the screen, so they start clean on every
/// normal navigation.
class AdminInventoryScreen extends StatelessWidget {
  final String? filter;

  const AdminInventoryScreen({super.key, this.filter});

  @override
  Widget build(BuildContext context) => _InventoryBody(filter: filter);
}

class _InventoryBody extends StatefulWidget {
  final String? filter;

  const _InventoryBody({this.filter});

  @override
  State<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<_InventoryBody> {
  String _query = '';
  String _cat = 'all';

  /// 'all' | 'active' | 'low' | 'out' | 'inactive'
  late String _stock = const {'active', 'low', 'out', 'inactive'}
          .contains(widget.filter)
      ? widget.filter!
      : 'all';

  @override
  void initState() {
    super.initState();
    // GST slab per pack for the list (one read of the till catalogue).
    GstCache.load().then((changed) {
      if (changed && mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _InventoryBody old) {
    super.didUpdateWidget(old);
    // Same screen re-entered through another deep link (`?filter=low` after
    // `?filter=out`, or a bare sidebar tap): start from that link's preset.
    if (old.filter != widget.filter) {
      _query = '';
      _cat = 'all';
      _stock = const {'active', 'low', 'out', 'inactive'}
              .contains(widget.filter)
          ? widget.filter!
          : 'all';
    }
  }

  bool _stockMatch(AppState st, Product p) {
    switch (_stock) {
      case 'active':
        return p.available;
      case 'low':
        return st.isLowStock(p);
      case 'out':
        return p.available && p.stock <= 0;
      case 'inactive':
        return !p.available;
    }
    return true;
  }

  /// Attention first: out of stock, then low stock, then healthy, inactive
  /// last; by name inside each group.
  int _rank(AppState st, Product p) {
    if (!p.available) return 3;
    if (p.stock <= 0) return 0;
    return st.isLowStock(p) ? 1 : 2;
  }

  void _clearAll() => setState(() {
        _cat = 'all';
        _query = '';
        _stock = 'all';
      });

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final q = _query.trim().toLowerCase();
    final list = state.products.where((p) {
      if (!_stockMatch(state, p)) return false;
      if (_cat != 'all' && p.category != _cat) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.nameGu.toLowerCase().contains(q) ||
          _catName(state, p.category).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final r = _rank(state, a).compareTo(_rank(state, b));
        return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final all = state.products;
    final nActive = all.where((p) => p.available).length;
    final nLow = all.where(state.isLowStock).length;
    final nOut = all.where((p) => p.available && p.stock <= 0).length;
    final nInactive = all.length - nActive;
    final filtersOn = _stock != 'all' || _cat != 'all' || q.isNotEmpty;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: 'Inventory',
                  sub: '${state.products.length} products · ${state.lowStockProducts().length} low stock',
                  bell: true,
                  onBell: () => showAdminAlerts(context),
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppLink(gt('Stock lots, expiry and value'),
                            onTap: () => go('/admin/stock-lots')),
                      ),
                      const SizedBox(height: 6),
                      CardPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppField(
                              label: 'Search inventory',
                              placeholder: 'Product name or category',
                              value: _query,
                              onChanged: (v) => setState(() => _query = v),
                            ),
                            const SizedBox(height: 14),
                            ChipRail(
                              children: [
                                for (final c in [
                                  ('all', '${gt('All')} (${all.length})'),
                                  ('active', '${gt('Active')} ($nActive)'),
                                  ('low', '${gt('Low stock')} ($nLow)'),
                                  ('out', '${gt('Out of stock')} ($nOut)'),
                                  ('inactive', '${gt('Inactive')} ($nInactive)'),
                                ]) ...[
                                  if (c.$1 != 'all') const SizedBox(width: 8),
                                  AppChip(
                                    c.$2,
                                    selected: _stock == c.$1,
                                    onTap: () => setState(() => _stock = c.$1),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            ChipRail(
                              children: [
                                AppChip(
                                  'All',
                                  selected: _cat == 'all',
                                  onTap: () => setState(() => _cat = 'all'),
                                ),
                                for (final c in state.categories) ...[
                                  const SizedBox(width: 8),
                                  AppChip(
                                    c.name,
                                    selected: _cat == c.id,
                                    onTap: () =>
                                        setState(() => _cat = c.id),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ResultSummary(
                        '${list.length} of ${state.products.length} products',
                        trailing: filtersOn
                            ? AppLink(gt('Clear filters'), onTap: _clearAll)
                            : null,
                      ),
                      list.isEmpty
                          ? CardPanel(
                              child: EmptyState(
                                icon: 'box',
                                title: 'No products found',
                                copy: 'Try another category or search term.',
                                actionLabel: filtersOn
                                    ? gt('Clear filters')
                                    : 'Add product',
                                onAction: filtersOn
                                    ? _clearAll
                                    : () => go('/admin/product/new'),
                              ),
                            )
                          : _InventoryList(state, list),
                    ],
                  ),
                ),
              ],
            ),

            // Floating "Add product" button above the bottom nav.
            Positioned(
              right: 18,
              bottom: (MediaQuery.sizeOf(context).width >= 900 ? 28 : 98) + safeBottom,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => go('/admin/product/new'),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: AppColors.shRed,
                  ),
                  child: const Center(
                    child: AppIcon(
                      'plus',
                      size: 24,
                      color: AppColors.white,
                      sw: 2.2,
                    ),
                  ),
                ),
              ),
            ),
            const AdminNav(active: 'inventory'),
          ],
        ),
      ),
    );
  }
}

String _catName(AppState state, String id) {
  for (final c in state.categories) {
    if (c.id == id) return c.name;
  }
  return id;
}

/// Category name plus the GST slab when known ("Dairy · GST 5%").
String _catWithGst(AppState state, Product p) {
  final g = GstCache.labelFor(p);
  final c = _catName(state, p.category);
  return g.isEmpty ? c : '$c · $g';
}

/// Backend id of the pack the "Print labels" shortcut opens (the default
/// pack, else the first saved one); null for a pack not saved yet.
String? _labelVariantId(Product p) {
  if (p.variants.isEmpty) return null;
  final d = p.defaultVariant >= 0 && p.defaultVariant < p.variants.length
      ? p.variants[p.defaultVariant].backendId
      : null;
  if (d != null) return d;
  for (final v in p.variants) {
    if (v.backendId != null) return v.backendId;
  }
  return null;
}

/// `inventoryRow(p)` — avatar, name, category, `{n} in stock` / Out of stock.
class _ProductRow extends StatelessWidget {
  final AppState state;
  final Product product;
  final bool divider;

  const _ProductRow(this.state, this.product, {this.divider = true});

  Future<void> _confirmDelete(BuildContext context) =>
      _confirmDeleteProduct(context, state, product);

  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = p.stock <= 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => go('/admin/product/${p.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: divider ? AppColors.line : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.line),
              ),
              child: Center(
                child: ProductArtView(p.art, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _catWithGst(state, p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!p.available && !out)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Pill.out('Inactive'),
              ),
            if (out)
              Pill.out('Out of stock')
            else
              Text(
                '${p.stock} in stock',
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: p.stock <= p.lowStock
                      ? AppColors.red
                      : AppColors.green,
                ),
              ),
            const SizedBox(width: 6),
            if (_labelVariantId(p) != null) ...[
              IconBtn(
                'ticket',
                size: 34,
                iconSize: 15,
                onTap: () => go('/admin/labels?variant=${_labelVariantId(p)}'),
              ),
              const SizedBox(width: 4),
            ],
            IconBtn(
              'trash',
              size: 34,
              iconSize: 15,
              onTap: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inventory list: data table on wide layouts, row cards on phones.
class _InventoryList extends StatelessWidget {
  final AppState state;
  final List<Product> list;

  const _InventoryList(this.state, this.list);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return CardPanel(
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++)
                _ProductRow(state, list[i], divider: i < list.length - 1),
            ],
          ),
        );
      }
      const cols = [
        TableCol('Product', 6),
        TableCol('Category', 3),
        TableCol('Stock', 3),
        TableCol('Status', 3),
      ];
      const cell = TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink2,
      );
      return Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.sh1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const TableHeadRow(cols, leading: 50, trailing: 118),
            for (var i = 0; i < list.length; i++)
              _tableRow(context, list[i], i == list.length - 1, cell),
          ],
        ),
      );
    });
  }

  Widget _tableRow(BuildContext context, Product p, bool last, TextStyle cell) {
    final out = p.stock <= 0;
    final low = !out && p.stock <= p.lowStock;
    return TableRowShell(
      last: last,
      onTap: () => go('/admin/product/${p.id}'),
      semanticLabel: 'Edit ${p.name}',
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.line),
            ),
            child: Center(child: ProductArtView(p.art, size: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cell.copyWith(
                    fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          Expanded(
            flex: 3,
            child: Text(_catWithGst(state, p),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: cell),
          ),
          Expanded(
            flex: 3,
            child: Text(out ? '0' : '${p.stock}',
                style: cell.copyWith(
                    fontWeight: FontWeight.w800,
                    color: out || low ? AppColors.red : AppColors.green)),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: out
                  ? Pill.out('Out of stock')
                  : !p.available
                      ? Pill.out('Inactive')
                      : low
                          ? Pill.low('Low stock')
                          : Pill.active('In stock'),
            ),
          ),
          SizedBox(
            width: 118,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_labelVariantId(p) != null) ...[
                  IconBtn('ticket',
                      size: 34,
                      iconSize: 15,
                      onTap: () =>
                          go('/admin/labels?variant=${_labelVariantId(p)}')),
                  const SizedBox(width: 4),
                ],
                IconBtn('edit',
                    size: 34,
                    iconSize: 15,
                    onTap: () => go('/admin/product/${p.id}')),
                const SizedBox(width: 4),
                IconBtn('trash',
                    size: 34,
                    iconSize: 15,
                    onTap: () => _confirmDeleteProduct(context, state, p)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
Future<void> _confirmDeleteProduct(
    BuildContext context, AppState state, Product product) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete product?'),
      content: Text(
          'Remove "${product.name}" and all its ${product.variants.length} '
          'pack(s) from inventory? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true) return;
  final r = await state.deleteProduct(product.id);
  showToast(r.error ?? r.note ?? 'Product deleted',
      r.error != null ? 'error' : 'success');
}