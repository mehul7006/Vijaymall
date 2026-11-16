import 'dart:convert' show utf8;

import '../../data/ist.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart' show Api;
import '../../data/purchase_file_view.dart' show downloadBytes;

import '../../data/api/dto.dart';
import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';

/// `#/admin/stock-report` — day-wise stock movement report.
///
/// Mirrors the prototype's `views['admin-stock-report']` + `sheets['stock-item']`:
/// day chips, stock-in/sold/on-shelf stats, per-item movement table, show-all
/// toggle, and a per-item receipt/sold/shelf drill-down sheet.
class AdminStockReportScreen extends StatefulWidget {
  const AdminStockReportScreen({super.key});

  @override
  State<AdminStockReportScreen> createState() => _AdminStockReportScreenState();
}

class _AdminStockReportScreenState extends State<AdminStockReportScreen> {
  /// Selected report day (YYYY-MM-DD). Defaults to today.
  String _day = localDayKey(istNow());

  /// When true, include products with no movement on the selected day.
  bool _showAll = false;

  /// Older movements fetched on demand (the app keeps only the newest 400).
  final List<StockMovementDto> _older = [];
  bool _loadingOlder = false, _noMoreOlder = false;
  static const _cap = 400;

  /// Every movement in hand: the app's newest 400 plus [_older].
  List<StockMovementDto> _allServerMoves(AppState state) =>
      [...state.adminStockMoves, ..._older];

  /// The oldest loaded movement is newer than the start of the selected day
  /// while the app's list hit its cap: the day may be incomplete.
  bool _maybeIncomplete(AppState state) {
    if (_noMoreOlder || state.adminStockMoves.length < _cap) return false;
    DateTime? oldest;
    for (final m in _allServerMoves(state)) {
      final at = m.atDateTime;
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
    }
    if (oldest == null) return false;
    return localDayKey(oldest).compareTo(_day) > 0 ||
        localDayKey(oldest) == _day;
  }

  /// Pages further back (`GET /admin/stock-movements`, 50 per page) until the
  /// selected day is covered, the history ends, or 20 pages were read.
  Future<void> _loadOlder(AppState state) async {
    setState(() => _loadingOlder = true);
    try {
      var page = _allServerMoves(state).length ~/ 50;
      for (var n = 0; n < 20; n++) {
        final r = await Api.instance.admin.stockMovements(page: page++, size: 50);
        _older.addAll(r.items);
        if (r.items.isEmpty || r.hasMore == false) {
          _noMoreOlder = true;
          break;
        }
        DateTime? oldest;
        for (final m in r.items) {
          final at = m.atDateTime;
          if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
        }
        if (oldest != null && localDayKey(oldest).compareTo(_day) < 0) break;
      }
    } on ApiException catch (e) {
      showToast(e.message, 'error');
    } catch (_) {
      showToast(gt('Could not load older movements'), 'error');
    }
    if (mounted) setState(() => _loadingOlder = false);
  }

  String _csv(String v) =>
      '"${v.replaceAll('"', '""')}"';

  void _exportCsv(_StockDayData data) {
    final b = StringBuffer('Item,In,Sold,Net,On shelf\r\n');
    for (final r in data.rows) {
      b.write('${_csv(r.name)},${r.inQty},${r.soldQty},${r.inQty - r.soldQty},${r.shelf}\r\n');
    }
    final ok = downloadBytes(
        utf8.encode(b.toString()), 'stock-movement-$_day.csv', 'text/csv');
    showToast(ok
        ? gt('Stock movement report downloaded')
        : gt('Download is only available in the browser'), ok ? 'success' : 'error');
  }

  /// Day metadata for a YYYY-MM-DD key.
  _StockDayMeta _meta(String key) {
    final parts = key.split('-').map(int.parse).toList();
    final date = parts.length == 3
        ? DateTime(parts[0], parts[1], parts[2])
        : istNow();
    final yesterday = istNow().subtract(const Duration(days: 1));
    final todayKey = localDayKey(istNow());
    final yesterdayKey = localDayKey(yesterday);
    return _StockDayMeta(
      key: key,
      title: key == todayKey
          ? 'Today'
          : key == yesterdayKey
              ? 'Yesterday'
              : _weekdays[date.weekday - 1],
      full:
          '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}',
      short: _weekdaysShort[date.weekday - 1],
      dayNum: date.day,
      isToday: key == todayKey,
    );
  }

  /// Last 7 days (including today), newest first.
  List<_StockDayMeta> _dayOptions() {
    final out = <_StockDayMeta>[];
    for (var i = 0; i < 7; i++) {
      final d = istNow().subtract(Duration(days: i));
      out.add(_meta(localDayKey(d)));
    }
    return out;
  }

  /// Server-driven movements (admin session) mapped into local [StockMove]
  /// rows, or the local demo ledger when the backend has none.
  List<StockMove> _effectiveMoves(AppState state) {
    if (state.adminStockMoves.isEmpty) return state.stockMoves;
    final out = <StockMove>[];
    for (final sm in _allServerMoves(state)) {
      final at = sm.atDateTime;
      if (at == null) continue;
      final packId = sm.productId ?? '';
      final ref = state.packIndex[packId];
      out.add(StockMove(
        id: sm.id ?? '',
        productId: ref?.product.id ?? packId,
        productName: sm.name ?? ref?.product.name ?? packId,
        variantIndex: ref?.variantIndex ?? 0,
        variantLabel: sm.packLabel ?? '',
        qty: sm.delta, // signed: >0 stock in, <0 sold
        at: at,
        note: _movementNote(sm),
      ));
    }
    return out;
  }

  /// Reason plus the order/counter-bill number behind the movement — the same
  /// `VSM-1001` the customer sees. Manual adjustments carry no ref, so they
  /// read exactly as before.
  String _movementNote(StockMovementDto sm) {
    final reason = (sm.reason ?? '').trim();
    final ref = (sm.ref ?? '').trim();
    if (ref.isEmpty) return reason;
    return reason.isEmpty ? ref : '$reason · $ref';
  }

  /// Computes per-item stock movement for the selected day.
  _StockDayData _stockData(AppState state) {
    final items = <String, _StockItem>{};
    final serverMode = state.adminStockMoves.isNotEmpty;

    _StockItem ensureItem(String id, Product? p, String fallbackName) {
      if (!items.containsKey(id)) {
        items[id] = _StockItem(
          id: id,
          product: p,
          name: p?.name ?? fallbackName,
          art: p?.art ?? 'box',
          tone: p?.tone ?? 'gold',
          inQty: 0,
          soldQty: 0,
          shelf: p?.stock ?? 0,
        );
      }
      return items[id]!;
    }

    _StockPack ensurePack(_StockItem item, String? label, int? variantIndex,
        Product? p) {
      final key = label ??
          (p != null &&
                  variantIndex != null &&
                  variantIndex >= 0 &&
                  variantIndex < p.variants.length
              ? p.variants[variantIndex].label
              : 'Pack-0');
      if (!item.packs.containsKey(key)) {
        final pv = p != null &&
                variantIndex != null &&
                variantIndex >= 0 &&
                variantIndex < p.variants.length
            ? p.variants[variantIndex]
            : null;
        item.packs[key] = _StockPack(
          label: key,
          inQty: 0,
          soldQty: 0,
          shelf: pv?.stock,
        );
      }
      return item.packs[key]!;
    }

    // Stock in: supplier receipts / opening stock logged that day.
    final allMoves = _effectiveMoves(state);
    for (final m in allMoves) {
      if (m.qty <= 0 || localDayKey(m.at) != _day) continue;
      final p = state.productById(m.productId);
      final item = ensureItem(m.productId, p, m.productName);
      item.inQty += m.qty;
      ensurePack(item, m.variantLabel, m.variantIndex, p).inQty += m.qty;
    }

    // Sold: server mode uses negative stock deltas (includes POS sales);
    // otherwise non-cancelled local orders placed that day.
    if (serverMode) {
      for (final m in allMoves) {
        if (m.qty >= 0 || localDayKey(m.at) != _day) continue;
        final p = state.productById(m.productId);
        final item = ensureItem(m.productId, p, m.productName);
        item.soldQty += -m.qty;
        ensurePack(item, m.variantLabel, m.variantIndex, p).soldQty += -m.qty;
      }
    } else {
      for (final o in state.orders) {
        if (o.status == 'Cancelled' || localDayKey(o.placedAt) != _day) continue;
        for (final it in o.items) {
          final p = state.productById(it.productId);
          final vi = p != null
              ? state.orderItemVariantIndex(p, it)
              : it.variantIndex;
          final item = ensureItem(it.productId, p, it.name);
          item.soldQty += it.qty;
          ensurePack(item, it.unit, vi, p).soldQty += it.qty;
        }
      }
    }

    if (_showAll) {
      for (final p in state.products) {
        ensureItem(p.id, p, p.name);
      }
    }

    final rows = items.values.toList();
    final moved = rows
        .where((item) => item.inQty > 0 || item.soldQty > 0)
        .toList()
      ..sort((a, b) {
        final cmp =
            (b.inQty + b.soldQty).compareTo(a.inQty + a.soldQty);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
    final idle = rows
        .where((item) => item.inQty == 0 && item.soldQty == 0)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final allRows = moved..addAll(idle);
    return _StockDayData(
      rows: allRows,
      inTotal: moved.fold<int>(0, (sum, i) => sum + i.inQty),
      soldTotal: moved.fold<int>(0, (sum, i) => sum + i.soldQty),
      shelfTotal:
          state.products.fold<int>(0, (sum, p) => sum + p.stock),
      movedCount: moved.length,
    );
  }

  void _pickDay() {
    final parts = _day.split('-').map(int.parse).toList();
    final initial = parts.length == 3
        ? DateTime(parts[0], parts[1], parts[2])
        : istNow();
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(istNow().year - 1),
      lastDate: istNow(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.navy,
          ),
        ),
        child: child!,
      ),
    ).then((picked) {
      if (picked != null && mounted) {
        setState(() => _day = localDayKey(picked));
      }
    });
  }

  void _openItemSheet(AppState state, String id, String day) {
    final p = state.productById(id);
    if (p == null) return;

    final serverMode = state.adminStockMoves.isNotEmpty;
    final moves = _effectiveMoves(state)
        .where((m) =>
            m.productId == id && m.qty > 0 && localDayKey(m.at) == day)
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));

    final sales = <Map<String, dynamic>>[];
    if (serverMode) {
      // Sold lines come from negative stock deltas (reason/cashier on the row).
      for (final m in _effectiveMoves(state)) {
        if (m.productId != id || m.qty >= 0 || localDayKey(m.at) != day) {
          continue;
        }
        sales.add({
          'qty': -m.qty,
          'label': m.variantLabel,
          'variantIndex': m.variantIndex,
          'note': m.note.isNotEmpty ? m.note : 'Sold',
        });
      }
    } else {
      for (final o in state.orders) {
        if (o.status == 'Cancelled' || localDayKey(o.placedAt) != day) continue;
        for (final it in o.items) {
          if (it.productId != id) continue;
          sales.add({
            'order': o,
            'qty': it.qty,
            'label': it.unit,
            'variantIndex': it.variantIndex,
          });
        }
      }
      sales.sort((a, b) {
        final oa = a['order'] as Order;
        final ob = b['order'] as Order;
        return ob.placedAt.compareTo(oa.placedAt);
      });
    }

    final inQty = moves.fold<int>(0, (sum, m) => sum + m.qty);
    final soldQty = sales.fold<int>(0, (sum, s) => sum + s['qty'] as int);

    final packs = <_StockPack>[];
    for (var i = 0; i < p.variants.length; i++) {
      final v = p.variants[i];
      final packMoves = moves.where((m) =>
          m.variantIndex == i || m.variantLabel == v.label);
      final packSales = sales.where((s) {
        final vi = state.orderItemVariantIndex(p,
            OrderItem(
              productId: id,
              variantIndex: s['variantIndex'] as int,
              name: '',
              nameGu: '',
              unit: s['label'] as String,
              price: 0,
              qty: 0,
              earnsCoins: false,
              allowCoins: false,
              art: '',
              tone: '',
            ));
        return vi == i || (s['label'] as String) == v.label;
      });
      packs.add(_StockPack(
        label: v.label,
        inQty: packMoves.fold<int>(0, (sum, m) => sum + m.qty),
        soldQty: packSales.fold<int>(0, (sum, s) => sum + s['qty'] as int),
        shelf: state.variantStock(p, i),
      ));
    }

    showAppSheet<void>(
      context: context,
      title: p.name,
      sub: '${_meta(day).full} · stock check',
      builder: (ctx) => _StockItemSheet(
        product: p,
        day: day,
        meta: _meta(day),
        moves: moves,
        sales: sales,
        inQty: inQty,
        soldQty: soldQty,
        packs: packs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final data = _stockData(state);
    final meta = _meta(_day);
    final dayOpts = _dayOptions();
    if (!dayOpts.any((d) => d.key == _day)) dayOpts.insert(0, meta);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Stock movement'),
                  sub: gt('Purchases vs sold · item wise'),
                  bell: false,
                  onBack: () => go('/admin/reports'),
                ),
                ScreenScroll(
                  bottom: 32,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Report tabs ----
                      _ReportTabs(
                        active: 'stock',
                        onSales: () => go('/admin/reports'),
                        onStock: () => setState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // ---- Stock card ----
                      CardPanel(
                        title: gt('Stock movement'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header + day picker
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meta.title,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.uiFont,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        meta.full,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.uiFont,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _AppFieldLike(
                                  label: gt('Choose date'),
                                  value: meta.full,
                                  onTap: _pickDay,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Day chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final d in dayOpts)
                                  _DayChip(
                                    meta: d,
                                    active: d.key == _day,
                                    onTap: () {
                                      setState(() => _day = d.key);
                                    },
                                  ),
                              ],
                            ),
                            if (_day != localDayKey(istNow()) || _showAll) ...[
                              const SizedBox(height: 8),
                              AppLink(
                                gt('Reset to today'),
                                onTap: () => setState(() {
                                  _day = localDayKey(istNow());
                                  _showAll = false;
                                }),
                              ),
                            ],
                            const SizedBox(height: 14),

                            // Stats
                            KpiGrid([
                              KpiCard(
                                icon: 'plus',
                                tint: AppColors.green,
                                bg: AppColors.greenTint,
                                label: gt('Stock in'),
                                value: '+${data.inTotal}',
                                deltaHint: gt('units received'),
                              ),
                              KpiCard(
                                icon: 'cart',
                                tint: AppColors.red,
                                bg: AppColors.redTint,
                                label: gt('Sold'),
                                value:
                                    '${data.soldTotal > 0 ? '−' : ''}${data.soldTotal}',
                                deltaHint: gt('units in orders'),
                              ),
                              KpiCard(
                                icon: 'chart',
                                tint: AppColors.goldInk,
                                bg: AppColors.goldTint,
                                label: gt('Net movement'),
                                value:
                                    '${data.inTotal - data.soldTotal > 0 ? '+' : ''}${data.inTotal - data.soldTotal}',
                                deltaHint: gt('in minus sold'),
                              ),
                              KpiCard(
                                icon: 'box',
                                tint: AppColors.navy,
                                bg: AppColors.navyTint,
                                label: gt('On shelf'),
                                value: '${data.shelfTotal}',
                                deltaHint: gt('all packs now'),
                              ),
                            ]),
                            const SizedBox(height: 14),

                            // Table
                            TableCard(
                              header: const TableHeadRow(
                                [
                                  TableCol('Item', 2),
                                  TableCol('In', 1, align: TextAlign.right),
                                  TableCol('Sold', 1, align: TextAlign.right),
                                  TableCol('Shelf', 1, align: TextAlign.right),
                                ],
                                leading: 44,
                              ),
                              rows: [
                                if (data.movedCount > 0 || _showAll)
                                  ...List.generate(
                                    data.rows.length,
                                    (i) => _StockRow(
                                      item: data.rows[i],
                                      state: state,
                                      onTap: () => _openItemSheet(
                                          state, data.rows[i].id, _day),
                                      divider: i < data.rows.length - 1,
                                    ),
                                  )
                                else
                                  _EmptyMovement(meta: meta),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Show-all toggle + hint
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () =>
                                        setState(() => _showAll = !_showAll),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: _showAll
                                                  ? AppColors.navy
                                                  : AppColors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: _showAll
                                                    ? AppColors.navy
                                                    : AppColors.line,
                                              ),
                                            ),
                                            child: Center(
                                              child: _showAll
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 12,
                                                      color: AppColors.white,
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(gt('Show all items'),
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.uiFont,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(gt('Include items with no movement'),
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.uiFont,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.ink3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Hint(
                              'Tap an item to review each receipt and sold order pack by pack. Sold uses non-cancelled orders placed that day; direct pack edits are not counted as purchases.',
                            ),
                            const SizedBox(height: 8),
                            if (_maybeIncomplete(state)) ...[
                              Text(
                                  gt('Only the newest movements are loaded, so this day may be incomplete. Load older movements to cover it.'),
                                  style: const TextStyle(
                                      fontFamily: AppTheme.uiFont,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.goldInk)),
                              const SizedBox(height: 8),
                              AppButton('Load older movements',
                                  variant: BtnVariant.secondary,
                                  block: true,
                                  loading: _loadingOlder,
                                  onTap: _loadingOlder
                                      ? null
                                      : () => _loadOlder(state)),
                              const SizedBox(height: 8),
                            ],
                            AppButton(
                              'Export stock movement report (CSV)',
                              variant: BtnVariant.secondary,
                              block: true,
                              onTap: () => _exportCsv(data),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Hint(
                        'Every receipt and order line stays visible inside an item, so a wrong entry can be traced to its source.',
                        color: AppColors.ink3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'reports'),
          ],
        ),
      ),
    );
  }
}

/// Day metadata.
class _StockDayMeta {
  final String key;
  final String title;
  final String full;
  final String short;
  final int dayNum;
  final bool isToday;

  const _StockDayMeta({
    required this.key,
    required this.title,
    required this.full,
    required this.short,
    required this.dayNum,
    required this.isToday,
  });
}

final List<String> _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

final List<String> _weekdaysShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];

final List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// Computed movement data for one day.
class _StockDayData {
  final List<_StockItem> rows;
  final int inTotal;
  final int soldTotal;
  final int shelfTotal;
  final int movedCount;

  const _StockDayData({
    required this.rows,
    required this.inTotal,
    required this.soldTotal,
    required this.shelfTotal,
    required this.movedCount,
  });
}

/// One product's movement on a day.
class _StockItem {
  final String id;
  final Product? product;
  final String name;
  final String art;
  final String tone;
  int inQty;
  int soldQty;
  int shelf;
  final Map<String, _StockPack> packs = {};

  _StockItem({
    required this.id,
    required this.product,
    required this.name,
    required this.art,
    required this.tone,
    required this.inQty,
    required this.soldQty,
    required this.shelf,
  });
}

/// One pack/variant within an item.
class _StockPack {
  final String label;
  int inQty;
  int soldQty;
  final int? shelf;

  _StockPack({
    required this.label,
    required this.inQty,
    required this.soldQty,
    this.shelf,
  });
}

/// Report tab row (Sales / Stock movement).
class _ReportTabs extends StatelessWidget {
  final String active;
  final VoidCallback onSales;
  final VoidCallback onStock;

  const _ReportTabs({
    required this.active,
    required this.onSales,
    required this.onStock,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(
          tabKey: 'sales',
          label: gt('Sales'),
          icon: 'chart',
          active: active == 'sales',
          onTap: onSales,
        ),
        const SizedBox(width: 10),
        _Tab(
          tabKey: 'stock',
          label: gt('Stock movement'),
          icon: 'box',
          active: active == 'stock',
          onTap: onStock,
        ),
      ],
    );
  }
}

class _Tab extends StatefulWidget {
  final String tabKey;
  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.tabKey,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        selected: active,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.navy
                  : (_hover ? AppColors.navyTint : AppColors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: active ? AppColors.navy : AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(widget.icon,
                    size: 15,
                    color: active ? AppColors.white : AppColors.ink2,
                    sw: 1.8),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: active ? AppColors.white : AppColors.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable "Choose date" field-like button.
class _AppFieldLike extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _AppFieldLike({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $value',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 15, color: AppColors.navy2),
              const SizedBox(width: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day selector chip (weekday + date number).
class _DayChip extends StatelessWidget {
  final _StockDayMeta meta;
  final bool active;
  final VoidCallback onTap;

  const _DayChip({
    required this.meta,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: meta.full,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.navy : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.navy : AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                meta.isToday ? gt('Today') : meta.short,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.white : AppColors.ink3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${meta.dayNum}',
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One stock row - tappable to open the per-item sheet.
class _StockRow extends StatelessWidget {
  final _StockItem item;
  final AppState state;
  final VoidCallback onTap;
  final bool divider;

  const _StockRow({
    required this.item,
    required this.state,
    required this.onTap,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final packText = item.packs.values
        .where((p) => p.inQty > 0 || p.soldQty > 0)
        .map((p) {
          final flow = <String>[];
          if (p.inQty > 0) flow.add('+${p.inQty}');
          if (p.soldQty > 0) flow.add('−${p.soldQty}');
          return '${p.label} ${flow.join(' ')}';
        })
        .join(' · ');
    final sub = packText.isNotEmpty
        ? packText
        : (item.product != null
            ? '${item.product!.variants.length} pack${item.product!.variants.length == 1 ? '' : 's'} · no movement'
            : 'No movement');

    return TableRowShell(
      last: !divider,
      onTap: onTap,
      semanticLabel: item.name,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.line),
            ),
            child: Center(child: ProductArtView(item.art, size: 26)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _NumCell(
              value: item.inQty > 0 ? '+${item.inQty}' : '—',
              color: AppColors.green,
            ),
          ),
          Expanded(
            child: _NumCell(
              value: item.soldQty > 0 ? '−${item.soldQty}' : '—',
              color: AppColors.red,
            ),
          ),
          Expanded(
            child: _NumCell(
              value: item.shelf > 0 ? '${item.shelf}' : '—',
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumCell extends StatelessWidget {
  final String value;
  final Color color;

  const _NumCell({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}

/// Empty state when there's no movement on the selected day.
class _EmptyMovement extends StatelessWidget {
  final _StockDayMeta meta;

  const _EmptyMovement({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.line),
            ),
            child: Center(
              child: AppIcon('box', size: 28, color: AppColors.ink3),
            ),
          ),
          const SizedBox(height: 14),
          Text(gt('No movement on this day'),
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(gt('No purchases or sales were recorded. Pick another date or show all shelf items.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink3,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-item stock drill-down sheet (matches `sheets['stock-item']`).
class _StockItemSheet extends StatelessWidget {
  final Product product;
  final String day;
  final _StockDayMeta meta;
  final List<StockMove> moves;
  final List<Map<String, dynamic>> sales;
  final int inQty;
  final int soldQty;
  final List<_StockPack> packs;

  const _StockItemSheet({
    required this.product,
    required this.day,
    required this.meta,
    required this.moves,
    required this.sales,
    required this.inQty,
    required this.soldQty,
    required this.packs,
  });

  @override
  Widget build(BuildContext context) {
    final moveWord = moves.length == 1 ? 'receipt' : 'receipts';
    final saleWord = sales.length == 1 ? 'order line' : 'order lines';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats strip
          Row(
            children: [
              Expanded(
                child: _SheetStat(
                  tint: AppColors.green,
                  bg: AppColors.greenTint,
                  label: gt('Stock in'),
                  value: '+$inQty',
                  sub: gt('units received'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SheetStat(
                  tint: AppColors.red,
                  bg: AppColors.redTint,
                  label: gt('Sold'),
                  value: '${soldQty > 0 ? '−' : ''}$soldQty',
                  sub: gt('units in orders'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SheetStat(
                  tint: AppColors.navy,
                  bg: AppColors.navyTint,
                  label: gt('On shelf'),
                  value: '${product.stock}',
                  sub: gt('all packs now'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stock in section
          _SectionHead('Stock in', '${moves.length} $moveWord'),
          _card(
            child: moves.isEmpty
                ? _EmptyLine(
                    title: gt('No stock received on this day.'),
                    copy: '')
                : Column(
                    children: List.generate(
                      moves.length,
                      (i) => _MoveRow(
                        m: moves[i],
                        product: product,
                        divider: i < moves.length - 1,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // Sold section
          _SectionHead('Sold', '${sales.length} $saleWord'),
          _card(
            child: sales.isEmpty
                ? _EmptyLine(
                    title: gt('No orders for this item on this day.'),
                    copy: '')
                : Column(
                    children: List.generate(
                      sales.length,
                      (i) => _SaleRow(
                        sale: sales[i],
                        product: product,
                        divider: i < sales.length - 1,
                        onTap: () {
                          final o = sales[i]['order'] as Order?;
                          if (o == null) return; // server row: no order link
                          Navigator.of(context).maybePop();
                          go('/admin/order/${o.number}');
                        },
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // On shelf now section
          _SectionHead('On shelf now', '${packs.length} packs'),
          _card(
            child: Column(
              children: List.generate(
                packs.length,
                (i) => _PackRow(
                  pack: packs[i],
                  divider: i < packs.length - 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          const Hint(
            'Sales count every non-cancelled order placed on this day. Stock in only includes supplier receipts, new packs and product opening stock.',
          ),
          const SizedBox(height: 14),
          AppButton(
            'Done',
            variant: BtnVariant.soft,
            block: true,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

Widget _SectionHead(String title, String hint) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        Text(
          hint,
          style: const TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink3,
          ),
        ),
      ],
    ),
  );
}

Widget _card({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
      boxShadow: AppColors.sh1,
    ),
    child: child,
  );
}

class _SheetStat extends StatelessWidget {
  final Color tint;
  final Color bg;
  final String label;
  final String value;
  final String sub;

  const _SheetStat({
    required this.tint,
    required this.bg,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.sh1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: AppIcon(
                label == 'Stock in' ? 'plus'
                    : label == 'Sold' ? 'cart'
                    : 'box',
                size: 12,
                color: tint,
                sw: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// One stock-in receipt line.
class _MoveRow extends StatelessWidget {
  final StockMove m;
  final Product product;
  final bool divider;

  const _MoveRow({
    required this.m,
    required this.product,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final label = m.variantLabel.isNotEmpty
        ? m.variantLabel
        : (m.variantIndex >= 0 &&
                m.variantIndex < product.variants.length
            ? product.variants[m.variantIndex].label
            : 'Pack');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.greenTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: AppIcon('plus', size: 16, color: AppColors.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${m.qty} × $label',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_timeLabel(m.at)} · ${m.note.isNotEmpty ? m.note : 'Stock received'}',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One sold order line.
class _SaleRow extends StatelessWidget {
  final Map<String, dynamic> sale;
  final Product product;
  final bool divider;
  final VoidCallback onTap;

  const _SaleRow({
    required this.sale,
    required this.product,
    required this.divider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final o = sale['order'] as Order?;
    final label = sale['label'] as String?;
    final note = sale['note'] as String?;
    final pv = product.variants.isNotEmpty
        ? product.variants[
            ((sale['variantIndex'] as int?)?.clamp(
                    0, product.variants.length - 1)) ??
                0]
        : null;
    final packLabel = (label != null && label.isNotEmpty)
        ? label
        : (pv?.label ?? 'Pack');
    final sub = o != null
        ? '${o.number} · ${o.customer} · ${_timeLabel(o.placedAt)} · ${_statusLabel(o.status)}'
        : (note ?? 'Sold');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: AppIcon('cart', size: 15, color: AppColors.red),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '−${sale['qty']} × $packLabel',
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const AppIcon('right', size: 14, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

/// One pack row in "On shelf now".
class _PackRow extends StatelessWidget {
  final _StockPack pack;
  final bool divider;

  const _PackRow({required this.pack, required this.divider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: divider ? AppColors.line : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.label,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'In +${pack.inQty} · Sold −${pack.soldQty}',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${pack.shelf ?? 0}',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 1),
              Text(gt('on shelf'),
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String title;
  final String copy;

  const _EmptyLine({required this.title, required this.copy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (copy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              copy,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _timeLabel(DateTime d) {
  return '${pad2(d.hour)}:${pad2(d.minute)}';
}

String _statusLabel(String status) {
  return switch (status) {
    'Placed' => 'New',
    'Confirmed' => 'Confirmed',
    'Packed' => 'Packed',
    'Ready for Pickup' => 'Ready',
    'Out for Delivery' => 'Out for delivery',
    'Delivered' => 'Delivered',
    'Picked Up' => 'Picked up',
    'Cancelled' => 'Cancelled',
    _ => status,
  };
}

String pad2(int n) => n.toString().padLeft(2, '0');
