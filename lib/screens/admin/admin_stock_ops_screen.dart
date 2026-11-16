import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';

import '../../state/gu_strings.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/validators.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto.dart';
import '../../data/api/purchase_dto.dart';
import '../../data/purchase_store.dart';
import '../../nav/nav.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';

String _rs(int paise) {
  final a = paise.abs();
  final p = a % 100;
  return '${paise < 0 ? '-' : ''}${money(a ~/ 100)}${p == 0 ? '' : '.${p.toString().padLeft(2, '0')}'}';
}

const _h = TextStyle(
  fontFamily: AppTheme.uiFont,
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  color: AppColors.ink,
);
const _sub = TextStyle(
  fontFamily: AppTheme.uiFont,
  fontSize: 11.5,
  color: AppColors.ink3,
);

/// One line being typed: a product plus a quantity (and a unit cost for a
/// delivery).
class _Line {
  _Line(this.productId, this.name, {String qty = '', String cost = ''})
      : qty = TextEditingController(text: qty),
        cost = TextEditingController(text: cost);

  final String productId;
  final String name;
  final TextEditingController qty;
  final TextEditingController cost;

  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

/// `#/admin/stock-ops` - stock-in entry points, physical stock counts
/// (`POST /admin/stock-takes`) and the deliveries list (`GET /admin/purchases`).
/// Receiving a delivery now lives in the purchases module
/// (`#/admin/purchases?new=1`); suppliers come from `/admin/suppliers`.
/// ADMIN only on the server.
class AdminStockOpsScreen extends StatefulWidget {
  const AdminStockOpsScreen({super.key});

  @override
  State<AdminStockOpsScreen> createState() => _AdminStockOpsScreenState();
}

class _AdminStockOpsScreenState extends State<AdminStockOpsScreen> {
  String _tab = 'receive';

  final _find = TextEditingController();
  final List<_Line> _lines = [];
  List<AdminProductDto> _hits = const [];
  bool _busy = false;
  final _note = TextEditingController();

  Map<String, dynamic>? _takeResult;

  // Deliveries list (GET /admin/purchases, paged, server-side supplier search).
  final _histQ = TextEditingController();
  Timer? _histDebounce;
  final List<PurchaseDto> _history = [];
  int _histPage = 0;
  bool _historyLoading = false, _histMore = false, _histHasMore = false;
  String _histTotal = '0';
  int _histGen = 0;

  @override
  void dispose() {
    _histDebounce?.cancel();
    _histQ.dispose();
    _note.dispose();
    _find.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String _err(Object e, String fallback) =>
      e is ApiException ? e.message : fallback;

  Future<void> _search() async {
    final q = _find.text.trim();
    if (q.isEmpty) {
      setState(() => _hits = const []);
      return;
    }
    try {
      final page = await Api.instance.admin.listProducts(q: q, size: 20);
      if (mounted) setState(() => _hits = page.items);
    } catch (e) {
      if (mounted) showToast(_err(e, 'Search failed'), 'error');
    }
  }

  void _addLine(AdminProductDto p) {
    if (p.id == null || _lines.any((l) => l.productId == p.id)) return;
    unawaited(PurchaseStore.instance.ensurePacks([p.id!]).then((_) {
      if (mounted) setState(() {});
    }));
    final label = [
      p.nameEn ?? 'Item',
      if ((p.packSize ?? '').isNotEmpty) p.packSize!,
    ].join(' · ');
    setState(() {
      _takeKey = null;
      _lines.add(_Line(p.id!, label));
      _hits = const [];
      _find.clear();
    });
  }

  int? _int(String s) => int.tryParse(s.trim());

  /// One optional `Idempotency-Key` per stock count: kept while the same
  /// count is retried after a timeout, dropped once the server answered.
  String? _takeKey;

  /// Per-line error text under the counted-quantity input (product id).
  final Map<String, String> _lineErr = {};

  Future<void> _stockTake() async {
    if (_lines.isEmpty) {
      showToast('Add at least one product', 'error');
      return;
    }
    if (_lines.length > 500) {
      showToast(gt('A stock count can have 500 products at most.'), 'error');
      return;
    }
    final items = <Map<String, dynamic>>[];
    final errs = <String, String>{};
    for (final l in _lines) {
      final m = Validators.whole(l.qty.text,
          label: 'Counted quantity', required: true, min: 0, max: 100000000);
      if (m != null) {
        errs[l.productId] = gt(m);
        continue;
      }
      items.add({'productId': l.productId, 'countedQty': _int(l.qty.text)});
    }
    setState(() {
      _lineErr
        ..clear()
        ..addAll(errs);
    });
    if (errs.isNotEmpty) {
      showToast(gt('Enter a counted quantity (0 or more) for every product.'),
          'error');
      return;
    }
    setState(() => _busy = true);
    try {
      _takeKey ??= newIdempotencyKey();
      final r = await Api.instance.admin.createStockTake(
          note: _note.text.trim(), items: items, idempotencyKey: _takeKey);
      _takeKey = null;
      unawaited(PurchaseStore.instance
          .ensurePacks((r['changes'] as List? ?? []).whereType<Map>().map((c) => '${c['productId']}'))
          .then((_) {
        if (mounted) setState(() {});
      }));
      if (!mounted) return;
      setState(() {
        _takeResult = r;
        for (final l in _lines) {
          l.dispose();
        }
        _lines.clear();
      });
    } catch (e) {
      if (e is ApiException && e.statusCode >= 400 && e.statusCode < 500) {
        // The server answered: the next attempt is a different request.
        _takeKey = null;
        // `items[N].countedQty` / `items[N].productId` -> show under line N.
        final bad = <String, String>{};
        e.fields.forEach((k, v) {
          final m = RegExp(r'items\[(\d+)\]').firstMatch(k);
          final i = m == null ? null : int.tryParse(m.group(1)!);
          if (i != null && i < _lines.length) bad[_lines[i].productId] = v;
        });
        if (bad.isNotEmpty && mounted) setState(() => _lineErr.addAll(bad));
      }
      if (mounted) {
        final msg = e is ApiException
            ? (e.code == 'IDEMPOTENCY_KEY_REUSED'
                ? gt('This count was already saved with different figures. Check the list and save again.')
                : (e.fields['items'] ?? e.message))
            : 'Could not save the stock count';
        showToast(msg, 'error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadHistory({bool more = false}) async {
    final gen = more ? _histGen : ++_histGen;
    setState(() {
      if (more) {
        _histMore = true;
      } else {
        _history.clear();
        _histPage = 0;
        _historyLoading = true;
      }
    });
    try {
      final store = PurchaseStore.instance;
      final r = await store.api.list(
          supplier: _histQ.text, page: more ? _histPage + 1 : 0, size: 20);
      if (!mounted || gen != _histGen) return;
      setState(() {
        _history.addAll(r.items);
        _histPage = r.page;
        _histHasMore = r.hasMore;
        _histTotal = r.totalLabel;
        _historyLoading = false;
        _histMore = false;
      });
      unawaited(store
          .ensurePacks(r.items.expand((p) => p.items).map((l) => l.productId))
          .then((_) {
        if (mounted) setState(() {});
      }));
    } catch (e) {
      if (!mounted || gen != _histGen) return;
      setState(() {
        _historyLoading = false;
        _histMore = false;
      });
      showToast(_err(e, 'Could not load deliveries'), 'error');
    }
  }

  Widget _picker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: AppField(
              label: 'Find product',
              controller: _find,
              placeholder: 'Type a name, press Enter',
              onEditingComplete: _search,
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: AppButton('Find', onTap: _search),
          ),
        ]),
        if (_hits.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in _hits.take(20))
              AppChip(
                '${p.nameEn ?? 'Item'}'
                '${(p.packSize ?? '').isEmpty ? '' : ' · ${p.packSize}'}'
                ' · ${p.qtyOnHand} in stock',
                small: true,
                selected: false,
                onTap: () => _addLine(p),
              ),
          ]),
        ],
      ],
    );
  }

  Widget _lineEditors({required bool withCost}) {
    if (_lines.isEmpty) {
      return const Hint('Search for a product and tap it to add a line. '
          'Weighed items are counted in grams.');
    }
    return Column(children: [
      for (final l in _lines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(l.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: _h),
              ),
              const SizedBox(width: 6),
              IconBtn('trash',
                  size: 34,
                  iconSize: 14,
                  onTap: () => setState(() {
                        _takeKey = null;
                        _lineErr.remove(l.productId);
                        _lines.remove(l);
                        l.dispose();
                      })),
            ]),
            const SizedBox(height: 6),
            FieldRow(children: [
              AppField(
                label: withCost ? 'Qty received' : 'Counted qty',
                controller: l.qty,
                numeric: true,
                error: _lineErr[l.productId],
                onChanged: (_) {
                  _takeKey = null; // a changed count is a new request
                  if (_lineErr.containsKey(l.productId)) {
                    setState(() => _lineErr.remove(l.productId));
                  }
                },
              ),
              if (withCost)
                AppField(
                  label: 'Cost / unit (Rs)',
                  controller: l.cost,
                  numeric: true,
                ),
            ]),
          ]),
        ),
    ]);
  }

  Widget _receiveTab() => Column(children: [
        CardPanel(
          title: 'Receive a delivery',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Hint('Deliveries are recorded as purchase bills with GST, '
                  'free units, discount, freight, batch and expiry, and can be '
                  'paid now or later.'),
              const SizedBox(height: 12),
              AppButton('New purchase',
                  icon: 'plus',
                  block: true,
                  onTap: () => go('/admin/purchases?new=1')),
              const SizedBox(height: 8),
              AppButton('Suppliers',
                  block: true,
                  variant: BtnVariant.secondary,
                  onTap: () => go('/admin/purchases?tab=suppliers')),
              const SizedBox(height: 8),
              AppButton('Purchases and payables',
                  block: true,
                  variant: BtnVariant.secondary,
                  onTap: () => go('/admin/purchases')),
            ],
          ),
        ),
      ]);

  Widget _countTab() {
    final r = _takeResult;
    return Column(children: [
      CardPanel(
        title: 'Stock count',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Hint('Enter what is on the shelf. Stock is set to these '
                'figures and the difference is saved as shrinkage. Count '
                'outside trading hours: sales during a count skew the result.'),
            const SizedBox(height: 10),
            AppField(label: 'Note (optional)', controller: _note),
            const SizedBox(height: 12),
            _picker(),
            const SizedBox(height: 10),
            _lineEditors(withCost: false),
            const SizedBox(height: 12),
            AppButton('Save count',
                block: true, loading: _busy, onTap: _busy ? null : _stockTake),
          ],
        ),
      ),
      if (r != null) ...[
        const SizedBox(height: 12),
        CardPanel(
          title: 'Variance report',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((r['changes'] as List? ?? []).isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(gt('Every counted product matched the system. Nothing was changed.'),
                      style: _h),
                ),
              for (final c in (r['changes'] as List? ?? []).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${c['name']} · ${PurchaseStore.instance.qty('${c['productId']}', ((c['before'] as num?) ?? 0).toInt(), plus: false)} → ${PurchaseStore.instance.qty('${c['productId']}', ((c['counted'] as num?) ?? 0).toInt(), plus: false)}',
                        style: _sub.copyWith(color: AppColors.ink2),
                      ),
                    ),
                    Text(
                      PurchaseStore.instance.qty('${c['productId']}', ((c['delta'] as num?) ?? 0).toInt()),
                      style: _h.copyWith(
                          color: ((c['delta'] as num?) ?? 0) < 0
                              ? AppColors.red
                              : AppColors.ink),
                    ),
                  ]),
                ),
              Text('${r['unchanged'] ?? 0} ${gt('product(s) matched the system')}',
                  style: _sub),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _historyTab() {
    final store = PurchaseStore.instance;
    return CardPanel(
      title: 'Deliveries',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: AppField(
                label: 'Find supplier',
                controller: _histQ,
                placeholder: 'Type a supplier name',
                onChanged: (_) {
                  _histDebounce?.cancel();
                  _histDebounce =
                      Timer(const Duration(milliseconds: 350), _loadHistory);
                },
              ),
            ),
            const SizedBox(width: 8),
            AppButton('Clear',
                variant: BtnVariant.secondary,
                onTap: () {
                  _histQ.clear();
                  _loadHistory();
                }),
          ]),
          const SizedBox(height: 10),
          if (!_historyLoading && _history.isNotEmpty)
            Text('$_histTotal ${gt('deliveries')}', style: _h),
          const SizedBox(height: 6),
          if (_historyLoading)
            const SkeletonRows(rows: 4)
          else if (_history.isEmpty)
            const Hint('No deliveries recorded yet.')
          else
            Column(children: [
              for (final d in _history)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => go('/admin/purchases?id=${d.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.supplierName, style: _h),
                                Text(
                                  '${d.invoiceNo.isEmpty ? '-' : d.invoiceNo} · '
                                  '${d.items.length} ${gt('item(s)')} · '
                                  '${d.invoiceDate}',
                                  style: _sub,
                                ),
                                for (final it in d.items)
                                  Text(
                                    '${it.name} · ${store.qty(it.productId, it.received)}',
                                    style: _sub,
                                  ),
                                if (d.note.isNotEmpty)
                                  Text(d.note, style: _sub),
                              ],
                            ),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_rs(d.totalCostPaise), style: _h),
                                if (d.duePaise > 0)
                                  Text('${gt('Due')} ${_rs(d.duePaise)}',
                                      style: _sub.copyWith(color: AppColors.red)),
                              ]),
                        ]),
                  ),
                ),
              if (_histHasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppButton('Load more',
                      variant: BtnVariant.secondary,
                      block: true,
                      loading: _histMore,
                      onTap: _histMore ? null : () => _loadHistory(more: true)),
                ),
            ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const AdminHead(
                  title: 'Stock in & count',
                  sub: 'Supplier deliveries and physical stock counts',
                  bell: false,
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Segmented(
                        options: const [
                          SegmentOption('receive', 'Receive'),
                          SegmentOption('count', 'Count'),
                          SegmentOption('history', 'Deliveries'),
                        ],
                        value: _tab,
                        onChanged: (v) {
                          setState(() {
                            _tab = v;
                            _hits = const [];
                            _find.clear();
                            _histQ.clear();
                          });
                          if (v == 'history') _loadHistory();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_tab == 'receive')
                        _receiveTab()
                      else if (_tab == 'count')
                        _countTab()
                      else
                        _historyTab(),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }
}
