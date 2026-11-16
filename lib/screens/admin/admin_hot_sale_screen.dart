import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto.dart';
import '../../data/ist.dart';
import '../../provider/state_scope.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/flash_widgets.dart' show flashWhen;
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_flash_common.dart' show pickIstDateTime, flashConfirm;

/// `#/admin/hot-sale` - ONE sale (banner + live switch + window) and the
/// products featured in it.
///
/// The backend decides which products show in `GET /hot-sale` from each
/// product's own `hotSale` / `hotStart` / `hotEnd` (ProductRepository.conditions);
/// the banner window only decides whether the banner row is shown. So the
/// sale window is written to every item (`PATCH /admin/products/{id}`); an item
/// whose window equals the sale window "uses the sale window", any other
/// window is a custom override.
class AdminHotSaleScreen extends StatelessWidget {
  const AdminHotSaleScreen({super.key});

  @override
  Widget build(BuildContext context) => const _HotSaleBody();
}

class _HotSaleBody extends StatefulWidget {
  const _HotSaleBody();

  @override
  State<_HotSaleBody> createState() => _HotSaleBodyState();
}

enum _Mode { inherit, stale, custom }

class _HotSaleBodyState extends State<_HotSaleBody> {
  bool _loading = true;
  String? _loadError;
  bool _busy = false;
  String _progress = '';

  // The sale (edited values) and what is saved on the server.
  bool _live = true;
  String _title = '';
  DateTime? _start;
  DateTime? _end;
  DateTime? _savedStart;
  DateTime? _savedEnd;

  List<AdminProductDto> _all = const [];
  // Items that matched the previous sale window and were not re-applied yet.
  final Set<String> _stale = {};

  List<AdminProductDto> get _items =>
      _all.where((p) => p.hotSale).toList();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final admin = Api.instance.admin;
      final state = StateScope.read(context);
      final banners = await admin.listBanners();
      HotBannerDto? b;
      for (final x in banners) {
        if (x.id == state.bannerId) b = x;
      }
      b ??= banners.isEmpty ? null : banners.first;
      final rows = <AdminProductDto>[];
      for (var page = 0; page < 40; page++) {
        final r = await admin.listProducts(hotSale: true, page: page, size: 50);
        rows.addAll(r.items);
        if (r.hasMore == false || r.items.length < 50) break;
      }
      if (!mounted) return;
      setState(() {
        _live = b?.active ?? true;
        _title = b?.title ?? '';
        _start = parseIst(b?.startAt);
        _end = parseIst(b?.endAt);
        _savedStart = _start;
        _savedEnd = _end;
        _all = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is ApiException ? e.message : 'Could not load the hot sale';
      });
    }
  }

  // ---- window helpers ----------------------------------------------------

  static bool _same(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.difference(b).inSeconds.abs() < 60;
  }

  DateTime? _istOf(String? iso) => parseIst(iso);

  bool _matches(AdminProductDto p, DateTime? s, DateTime? e) =>
      _same(_istOf(p.hotStart), s) && _same(_istOf(p.hotEnd), e);

  _Mode _modeOf(AdminProductDto p) {
    if (_matches(p, _savedStart, _savedEnd)) return _Mode.inherit;
    if (_stale.contains(p.id)) return _Mode.stale;
    final noWindow = p.hotStart == null && p.hotEnd == null;
    if (noWindow) return _Mode.stale;
    return _Mode.custom;
  }

  static String? _iso(DateTime? ist) => ist == null
      ? null
      : ist
          .subtract(istOffset)
          .toIso8601String()
          .replaceFirst(RegExp(r'\.\d+'), '');

  String _err(Object e) =>
      e is ApiException ? e.messageWithRef : gt('Could not reach the server. Please try again.');

  // ---- server writes -----------------------------------------------------

  Future<AdminProductDto> _patch(AdminProductDto p, Map<String, Object?> f) async {
    final u = await Api.instance.admin.patchProduct(p.id!, f);
    final i = _all.indexWhere((x) => x.id == p.id);
    _all = i >= 0 ? ([..._all]..[i] = u) : [..._all, u];
    return u;
  }

  /// PATCH many rows, at most ~37 calls a minute, with live progress.
  /// Returns the number done; stops at the first failure.
  Future<int> _bulk(
      List<AdminProductDto> rows, Map<String, Object?> fields, String verb) async {
    var done = 0;
    setState(() => _busy = true);
    try {
      // One `PATCH /admin/products/hot-sale` per chunk of up to 200 ids (all
      // or nothing per chunk) instead of one call per item.
      final hot = fields['hotSale'] as bool? ?? true;
      final start = fields['hotStart'] as String?;
      final end = fields['hotEnd'] as String?;
      for (var i = 0; i < rows.length; i += 200) {
        if (!mounted) return done;
        final chunk = rows.sublist(i, i + 200 > rows.length ? rows.length : i + 200);
        setState(() => _progress = '$verb ${done + chunk.length} / ${rows.length}');
        try {
          await Api.instance.admin.bulkHotSale(
            [for (final p in chunk) p.id!],
            hotSale: hot,
            hotStart: start,
            hotEnd: end,
          );
        } on ApiException catch (e) {
          if (e.statusCode == 429) {
            final wait = e.retryAfterHeader ?? 20;
            setState(() => _progress = '${gt('Waiting')} ${wait}s...');
            await Future<void>.delayed(Duration(seconds: wait));
            try {
              await Api.instance.admin.bulkHotSale(
                [for (final p in chunk) p.id!],
                hotSale: hot,
                hotStart: start,
                hotEnd: end,
              );
            } catch (e2) {
              showToast(_err(e2), 'error');
              break;
            }
          } else {
            showToast(_err(e), 'error');
            break;
          }
        }
        for (final p in chunk) {
          p.hotSale = hot;
          p.hotStart = start;
          p.hotEnd = end;
          _stale.remove(p.id);
        }
        done += chunk.length;
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = '';
        });
      }
    }
    // Keep the shared catalog (and the customer hot-sale strip) in step.
    if (mounted) await StateScope.read(context).refreshAdminProducts();
    return done;
  }

  Future<void> _saveSale() async {
    final state = StateScope.read(context);
    final inheriting = _items.where((p) => _modeOf(p) == _Mode.inherit).toList();
    final changed = !_same(_start, _savedStart) || !_same(_end, _savedEnd);
    setState(() => _busy = true);
    final err = await state.saveHotSaleWindow(
        live: _live, title: _title, startIst: _start, endIst: _end);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(gt('Hot sale updated'));
    if (!changed) {
      setState(() {
        _savedStart = _start;
        _savedEnd = _end;
      });
      return;
    }
    // Items that used the old window are now behind the sale.
    _stale.addAll(inheriting.map((p) => p.id!));
    setState(() {
      _savedStart = _start;
      _savedEnd = _end;
    });
    if (inheriting.isNotEmpty) await _offerApply(inheriting.length);
  }

  Future<void> _offerApply(int n) async {
    final skip = _items.where((p) => _modeOf(p) == _Mode.custom).length;
    final ok = await flashConfirm(
      context,
      title: gt('Apply to all items?'),
      body:
          '${gt('Apply the new sale window to all items that use the sale window')} ($n).'
          '${skip > 0 ? ' $skip ${gt('item(s) with a custom window are skipped.')}' : ''}',
      confirmLabel: 'Apply to all items',
    );
    if (ok) await _applyToAll();
  }

  Future<void> _applyToAll() async {
    final rows =
        _items.where((p) => _modeOf(p) != _Mode.custom).toList();
    if (rows.isEmpty) {
      showToast(gt('Nothing to apply'));
      return;
    }
    final n = await _bulk(rows,
        {'hotStart': _iso(_savedStart), 'hotEnd': _iso(_savedEnd)}, gt('Applying'));
    if (mounted) {
      setState(() {});
      showToast('$n / ${rows.length} ${gt('items updated')}',
          n == rows.length ? 'success' : 'error');
    }
  }

  Future<void> _remove(AdminProductDto p) async {
    final ok = await flashConfirm(
      context,
      title: gt('Remove from hot sale?'),
      body: '${p.nameEn ?? ''} ${gt('will stop being a hot sale item and its own window is cleared.')}',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _patch(p, {'hotSale': false, 'hotStart': null, 'hotEnd': null});
      _stale.remove(p.id);
      if (mounted) await StateScope.read(context).refreshAdminProducts();
      if (mounted) showToast(gt('Removed from hot sale'));
    } catch (e) {
      if (mounted) showToast(_err(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAll() async {
    final rows = _items;
    if (rows.isEmpty) return;
    final ok = await flashConfirm(
      context,
      title: gt('Remove all items?'),
      body:
          '${rows.length} ${gt('items will stop being hot sale items and their own windows are cleared.')}',
      confirmLabel: 'Remove all',
      danger: true,
    );
    if (!ok) return;
    final n = await _bulk(rows,
        {'hotSale': false, 'hotStart': null, 'hotEnd': null}, gt('Removing'));
    if (mounted) {
      setState(() {});
      showToast('$n / ${rows.length} ${gt('removed')}',
          n == rows.length ? 'success' : 'error');
    }
  }

  Future<void> _resetToSale(AdminProductDto p) async {
    setState(() => _busy = true);
    try {
      await _patch(p, {'hotStart': _iso(_savedStart), 'hotEnd': _iso(_savedEnd)});
      _stale.remove(p.id);
      if (mounted) await StateScope.read(context).refreshAdminProducts();
    } catch (e) {
      if (mounted) showToast(_err(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _override(AdminProductDto p) async {
    DateTime? s = _istOf(p.hotStart) ?? _savedStart;
    DateTime? e = _istOf(p.hotEnd) ?? _savedEnd;
    await showAppSheet(
      context: context,
      title: gt('Custom window'),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.nameEn ?? ''}${(p.packSize ?? '').isEmpty ? '' : ' · ${p.packSize}'}',
                style: _h),
            const SizedBox(height: 10),
            FieldRow(
              minWidth: 420,
              children: [
                SelectField(
                  label: gt('Starts'),
                  value: s == null ? '' : flashWhen(s),
                  placeholder: gt('Not set'),
                  onTap: () async {
                    final d = await pickIstDateTime(ctx, s ?? istNow());
                    if (d != null) setSheet(() => s = d);
                  },
                ),
                SelectField(
                  label: gt('Ends'),
                  value: e == null ? '' : flashWhen(e),
                  placeholder: gt('Not set'),
                  onTap: () async {
                    final d = await pickIstDateTime(
                        ctx, e ?? (s ?? istNow()).add(const Duration(days: 1)));
                    if (d != null) setSheet(() => e = d);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppButton('Save custom window', block: true, onTap: () async {
              if (s != null && e != null && e!.isBefore(s!)) {
                showToast(gt('The end must be after the start'), 'error');
                return;
              }
              Navigator.of(ctx).pop();
              setState(() => _busy = true);
              try {
                await _patch(p, {'hotStart': _iso(s), 'hotEnd': _iso(e)});
                _stale.remove(p.id);
                if (mounted) await StateScope.read(context).refreshAdminProducts();
              } catch (er) {
                if (mounted) showToast(_err(er), 'error');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            }),
            const SizedBox(height: 8),
          ],
        );
      }),
    );
  }

  Future<void> _add(AdminProductDto p) async {
    setState(() => _busy = true);
    try {
      await _patch(p, {
        'hotSale': true,
        'hotStart': _iso(_savedStart),
        'hotEnd': _iso(_savedEnd),
      });
      if (mounted) await StateScope.read(context).refreshAdminProducts();
    } catch (e) {
      if (mounted) showToast(_err(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- UI ----------------------------------------------------------------

  static const _h = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
  static const _sub = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink3,
  );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final custom = items.where((p) => _modeOf(p) == _Mode.custom).length;
    final dirty =
        !_same(_start, _savedStart) || !_same(_end, _savedEnd);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Hot sale'),
                  sub: _live ? gt('Live · one sale, many items') : gt('Paused · one sale, many items'),
                  bell: false,
                ),
                ScreenScroll(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _loading
                          ? const SkeletonRows(rows: 4)
                          : _loadError != null
                              ? Column(children: [
                                  Hint(_loadError!),
                                  const SizedBox(height: 10),
                                  AppButton('Try again', onTap: _reload),
                                ])
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    KpiGrid([
                                      KpiCard(
                                        icon: 'flame',
                                        tint: _live ? AppColors.green : AppColors.ink3,
                                        bg: _live ? AppColors.greenTint : AppColors.bg,
                                        label: gt('Status'),
                                        value: _live ? gt('Live') : gt('Paused'),
                                      ),
                                      KpiCard(
                                        icon: 'star',
                                        tint: AppColors.goldInk,
                                        bg: AppColors.goldTint,
                                        label: gt('Featured products'),
                                        value: '${items.length}',
                                      ),
                                    ]),
                                    const SizedBox(height: 12),
                                    _saleCard(dirty),
                                    const SizedBox(height: 12),
                                    _itemsCard(items, custom),
                                  ],
                                ),
                    ),
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

  Widget _saleCard(bool dirty) {
    return CardPanel(
      title: gt('The sale'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(gt('Live'), style: _h)),
            AppSwitch(value: _live, onChanged: (v) => setState(() => _live = v)),
          ]),
          const SizedBox(height: 14),
          AppField(
            label: gt('Title'),
            placeholder: gt('Up to 30% off on Dry Fruit'),
            value: _title,
            onChanged: (v) => setState(() => _title = v),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _dateField(gt('Starts'), _start, (d) => _start = d)),
            const SizedBox(width: 10),
            Expanded(child: _dateField(gt('Ends'), _end, (d) => _end = d)),
          ]),
          const SizedBox(height: 6),
          Text(gt('India time. Items use this window unless you override them.'),
              style: _sub),
          const SizedBox(height: 14),
          AppButton('Save hot sale',
              block: true,
              loading: _busy && _progress.isEmpty,
              onTap: _busy ? null : _saveSale),
          if (dirty) ...[
            const SizedBox(height: 6),
            Text(gt('Window changed - save to apply'), style: _sub),
          ],
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? v, void Function(DateTime?) set) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectField(
          label: label,
          value: v == null ? '' : flashWhen(v),
          placeholder: gt('Not set'),
          onTap: () async {
            final d = await pickIstDateTime(context, v ?? istNow());
            if (d != null) setState(() => set(d));
          },
        ),
        if (v != null)
          GestureDetector(
            onTap: () => setState(() => set(null)),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(gt('Clear'),
                  style: _sub.copyWith(color: AppColors.red)),
            ),
          ),
      ],
    );
  }

  Widget _itemsCard(List<AdminProductDto> items, int custom) {
    final stale = items.where((p) => _modeOf(p) == _Mode.stale).length;
    return CardPanel(
      title: gt('Featured products'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_busy && _progress.isNotEmpty) ...[
            Text(_progress, style: _h.copyWith(color: AppColors.navy)),
            const SizedBox(height: 8),
          ],
          if (items.isEmpty) Hint(gt('No products are featured yet.')),
          for (var i = 0; i < items.length; i++)
            _row(items[i], divider: i < items.length - 1),
          if (items.isNotEmpty) const SizedBox(height: 12),
          if (stale > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppButton('Apply sale window to $stale item(s)',
                  block: true,
                  variant: BtnVariant.secondary,
                  onTap: _busy ? null : _applyToAll),
            ),
          SelectField(
            label: gt('Add a product'),
            value: '',
            placeholder: gt('Choose a product'),
            onTap: _busy ? null : _pick,
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppButton('Remove all',
                block: true,
                variant: BtnVariant.danger,
                onTap: _busy ? null : _removeAll),
          ],
        ],
      ),
    );
  }

  Widget _row(AdminProductDto p, {required bool divider}) {
    final mode = _modeOf(p);
    final s = _istOf(p.hotStart), e = _istOf(p.hotEnd);
    final win = (s == null && e == null)
        ? gt('No window (always on)')
        : '${s == null ? gt('Open') : flashWhen(s)}  ->  ${e == null ? gt('Open') : flashWhen(e)}';
    Widget chip;
    switch (mode) {
      case _Mode.inherit:
        chip = Pill.active(gt('Uses sale window'));
      case _Mode.stale:
        chip = Pill.low(gt('Not on sale window yet'));
      case _Mode.custom:
        chip = const Pill(
            label: 'Custom window', bg: AppColors.goldTint, fg: AppColors.goldInk);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: divider ? AppColors.line : Colors.transparent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                '${p.nameEn ?? ''}${(p.packSize ?? '').isEmpty ? '' : ' · ${p.packSize}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _h,
              ),
            ),
            const SizedBox(width: 8),
            chip,
          ]),
          const SizedBox(height: 3),
          Text('$win · ${p.qtyOnHand} ${gt('in stock')}', style: _sub),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            AppChip(gt('Override'),
                small: true, selected: false, onTap: _busy ? null : () => _override(p)),
            if (mode != _Mode.inherit)
              AppChip(gt('Reset to sale'),
                  small: true, selected: false, onTap: _busy ? null : () => _resetToSale(p)),
            AppChip(gt('Remove'),
                small: true, selected: false, onTap: _busy ? null : () => _remove(p)),
          ]),
        ],
      ),
    );
  }

  void _pick() {
    // Candidates come from the server: not hot yet, active, filtered by the
    // search text (`GET /admin/products?hotSale=false&active=true&q=`).
    var q = '';
    var seq = 0;
    var typed = 0;
    var loading = true;
    String? failed;
    List<AdminProductDto> shown = const [];
    void safe(StateSetter set, VoidCallback f) {
      try {
        set(f);
      } catch (_) {} // the sheet was closed meanwhile
    }

    Future<void> load(StateSetter setSheet) async {
      final mine = ++seq;
      safe(setSheet, () => loading = true);
      try {
        final r = await Api.instance.admin.listProducts(
            hotSale: false, active: true, q: q.trim(), page: 0, size: 30);
        if (mine != seq) return;
        safe(setSheet, () {
          shown = r.items;
          loading = false;
          failed = null;
        });
      } catch (e) {
        if (mine != seq) return;
        safe(setSheet, () {
          loading = false;
          failed = _err(e);
        });
      }
    }

    var started = false;
    showAppSheet(
      context: context,
      title: gt('Add a product'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          if (!started) {
            started = true;
            Future.microtask(() => load(setSheet));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppField(
                placeholder: gt('Search products by name'),
                value: q,
                onChanged: (v) {
                  q = v;
                  final t = ++typed;
                  Future<void>.delayed(const Duration(milliseconds: 350), () {
                    if (t == typed) load(setSheet);
                  });
                },
              ),
              const SizedBox(height: 4),
              Text(gt('Added items use the sale window.'), style: _sub),
              const SizedBox(height: 10),
              for (final p in shown)
                SheetOption(
                  title:
                      '${p.nameEn ?? ''}${(p.packSize ?? '').isEmpty ? '' : ' · ${p.packSize}'}',
                  sub: '${p.qtyOnHand} ${gt('in stock')}',
                  selected: false,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _add(p);
                  },
                ),
              if (failed != null)
                Hint(failed!)
              else if (!loading && shown.isEmpty)
                Hint(q.trim().isEmpty
                    ? gt('Every product is already featured.')
                    : gt('No products match that search.')),
            ],
          );
        },
      ),
    );
  }
}
