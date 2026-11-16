import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/flash_dto.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/flash_widgets.dart' show flashWhen;
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_flash_common.dart';
import 'admin_flash_form.dart';
import 'admin_flash_report.dart';

/// `#/admin/flash-sales` - staff flash-sale module (`40-flash-sales.md`).
///
/// Routes (query): none = list, `id=<sale>` = detail, `new=1` = create form,
/// `edit=<sale>` = edit form, `report=<sale>` = one sale's report,
/// `report=all` = report across a date range.
class AdminFlashSalesScreen extends StatelessWidget {
  final Map<String, String> query;
  const AdminFlashSalesScreen({super.key, this.query = const {}});

  @override
  Widget build(BuildContext context) {
    if (query['new'] == '1') return const AdminFlashFormScreen();
    final edit = query['edit'];
    if (edit != null && edit.isNotEmpty) {
      return AdminFlashFormScreen(editId: edit);
    }
    final rep = query['report'];
    if (rep != null && rep.isNotEmpty) {
      return AdminFlashReportScreen(saleId: rep == 'all' ? null : rep);
    }
    final id = query['id'];
    if (id != null && id.isNotEmpty) {
      return _FlashDetail(key: ValueKey(id), id: id);
    }
    return const _FlashList();
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class _FlashList extends StatefulWidget {
  const _FlashList();

  @override
  State<_FlashList> createState() => _FlashListState();
}

class _FlashListState extends State<_FlashList> {
  String _status = '';
  final List<FlashSaleRow> _rows = [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _more = false;
  String? _error;

  /// Bumped on every fresh (page 0) request so a slow answer for an earlier
  /// chip can never overwrite the list of the chip chosen after it.
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final gen = more ? _gen : ++_gen;
    final status = _status;
    if (more) {
      setState(() => _more = true);
    } else {
      setState(() {
        // Switching chips: drop the previous chip's rows at once.
        _rows.clear();
        _page = 0;
        _more = false;
        _loading = true;
        _error = null;
      });
    }
    try {
      final p = more ? _page + 1 : 0;
      final r = await Api.instance.flash
          .list(status: status, page: p, size: 20);
      if (!mounted || gen != _gen) return;
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(r.items);
        _page = r.page;
        _total = r.total;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = flashError(e);
        _loading = false;
        _more = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlashAdminPage(
      title: gt('Flash sales'),
      sub: gt('Timed offers with a stock cap and a per-customer limit'),
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppButton('New flash sale',
                    icon: 'plus',
                    onTap: () => go('/admin/flash-sales?new=1')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton('Report',
                    icon: 'chart',
                    variant: BtnVariant.secondary,
                    onTap: () => go('/admin/flash-sales?report=all')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FlashStatusChips(
            value: _status,
            onChanged: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SkeletonRows(rows: 4)
          else if (_error != null)
            ErrorRetry(message: _error!, onRetry: _load)
          else if (_rows.isEmpty)
            EmptyState(
              icon: 'bolt',
              title: gt('No flash sales here'),
              copy: gt('Create one to run a timed offer on selected products.'),
              actionLabel: _status.isEmpty ? null : gt('Show all'),
              onAction: _status.isEmpty
                  ? null
                  : () {
                      setState(() => _status = '');
                      _load();
                    },
            )
          else ...[
            ResultSummary('$_total ${gt(_total == 1 ? 'sale' : 'sales')}'),
            const SizedBox(height: 8),
            for (final r in _rows) _row(r),
            if (_rows.length < _total)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppButton('Load more',
                    variant: BtnVariant.soft,
                    block: true,
                    loading: _more,
                    onTap: _more ? null : () => _load(more: true)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(FlashSaleRow r) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => go('/admin/flash-sales?id=${r.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.sh1,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Center(
                  child: AppIcon('bolt', size: 19, color: AppColors.red)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      )),
                  const SizedBox(height: 3),
                  Text(fmtWindow(r.startsAt, r.endsAt),
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      )),
                  const SizedBox(height: 2),
                  Text(
                      '${r.itemCount} ${gt(r.itemCount == 1 ? 'product' : 'products')} · ${channelLabel(r.channel)}',
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink2,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            flashStatusPill(r.status),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

class _FlashDetail extends StatefulWidget {
  final String id;
  const _FlashDetail({super.key, required this.id});

  @override
  State<_FlashDetail> createState() => _FlashDetailState();
}

class _FlashDetailState extends State<_FlashDetail> {
  FlashSaleView? _sale;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Sold counts change silently while a sale runs (no per-purchase event).
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_sale?.isActive == true && !_busy) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _error = null);
    try {
      final s = await Api.instance.flash.get(widget.id);
      if (!mounted) return;
      setState(() {
        _sale = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || quiet) return;
      setState(() {
        _error = flashError(e);
        _loading = false;
      });
    }
  }

  /// Runs a state-changing call, adopts the returned sale, shows the server's
  /// message on failure.
  Future<void> _run(Future<FlashSaleView> Function() call, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await call();
      if (!mounted) return;
      setState(() => _sale = s);
      showToast(done);
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(e.messageWithRef, 'error');
      if (e.code == 'FLASH_OVERLAP') _overlapSheet(e);
      _load(quiet: true);
    } catch (e) {
      if (mounted) showToast(flashError(e), 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _overlapSheet(ApiException e) {
    final id = e.details?['saleId']?.toString();
    final name = e.details?['saleName']?.toString() ?? '';
    if (id == null || id.isEmpty) return;
    showFlashOverlapSheet(context, message: e.message, saleId: id, saleName: name);
  }

  Future<void> _startNow(FlashSaleView s) async {
    final ok = await flashConfirm(context,
        title: 'Start this sale now?',
        body:
            'The sale price applies to customers immediately. It keeps its planned end time.',
        confirmLabel: 'Start now');
    if (ok) await _run(() => Api.instance.flash.startNow(s.id), gt('Sale started'));
  }

  Future<void> _endNow(FlashSaleView s) async {
    final ok = await flashConfirm(context,
        title: 'End this sale now?',
        body:
            'New quotes and orders use the normal price at once. Orders already placed keep the sale price they were charged.',
        confirmLabel: 'End sale now',
        danger: true);
    if (ok) await _run(() => Api.instance.flash.endNow(s.id), gt('Sale ended'));
  }

  Future<void> _cancel(FlashSaleView s) async {
    final ok = await flashConfirm(context,
        title: 'Cancel this sale?',
        body:
            'This cannot be undone. The sale price stops at once and the sale moves to Cancelled. Use Duplicate to reuse its setup later.',
        confirmLabel: 'Cancel sale',
        danger: true);
    if (ok) await _run(() => Api.instance.flash.cancel(s.id), gt('Sale cancelled'));
  }

  Future<void> _deleteSale(FlashSaleView s) async {
    final ok = await flashConfirm(context,
        title: 'Delete this sale?',
        body:
            'The sale and its products are removed for good. Only a sale that has not started can be deleted.',
        confirmLabel: 'Delete sale',
        danger: true);
    if (!ok || _busy) return;
    setState(() => _busy = true);
    try {
      await Api.instance.flash.deleteSale(s.id);
    } on ApiException catch (e) {
      // 404 on a repeat means it is already gone.
      if (e.statusCode != 404) {
        if (mounted) {
          setState(() => _busy = false);
          showToast(e.messageWithRef, 'error');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(flashError(e), 'error');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(gt('Sale deleted'));
    go('/admin/flash-sales');
  }

  Future<void> _duplicate(FlashSaleView s) async {
    final created = await showFlashDuplicateSheet(context, s);
    if (created != null && mounted) {
      showToast(gt('Sale copied'));
      go('/admin/flash-sales?id=${created.id}');
    }
  }

  Future<void> _removeItem(FlashSaleView s, FlashItemView it) async {
    final ok = await flashConfirm(context,
        title: 'Remove this product?',
        body: 'It will no longer be part of this sale.',
        confirmLabel: 'Remove',
        danger: true);
    if (ok) {
      await _run(
          () => Api.instance.flash.deleteItem(s.id, it.id), gt('Product removed'));
    }
  }

  Future<void> _editItem(FlashSaleView s, FlashItemView it) async {
    final updated = await showFlashItemSheet(context, sale: s, item: it);
    if (updated != null && mounted) {
      setState(() => _sale = updated);
      showToast(gt('Product updated'));
    }
  }

  Future<void> _addItem(FlashSaleView s) async {
    final updated = await showFlashItemSheet(context, sale: s);
    if (updated != null && mounted) {
      setState(() => _sale = updated);
      showToast(gt('Product added'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _sale;
    return FlashAdminPage(
      title: s?.name ?? gt('Flash sale'),
      sub: s == null ? '' : '${gt('Window')}: ${fmtWindow(s.startsAt, s.endsAt)}',
      backToList: true,
      onRefresh: _load,
      child: _loading
          ? const SkeletonRows(rows: 4)
          : s == null
              ? ErrorRetry(message: _error ?? gt('Not found'), onRetry: _load)
              : _body(s),
    );
  }

  Widget _body(FlashSaleView s) {
    final disc = switch (s.discountKind) {
      'PERCENT' => '${s.discountValue}% ${gt('off')}',
      'FIXED_PRICE' => '${gt('Fixed price')} ${fmtPaise(s.discountValue)}',
      _ => gt('Set per product'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardPanel(
          title: gt('Sale'),
          trailing: flashStatusPill(s.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlashKv('Starts', flashWhen(s.startsAt)),
              FlashKv('Ends', flashWhen(s.endsAt)),
              FlashKv('Where', channelLabel(s.channel)),
              FlashKv('Discount', disc),
              FlashKv(
                  'Per customer',
                  s.perCustomerLimit > 0
                      ? '${gt('Max')} ${s.perCustomerLimit}'
                      : gt('No limit')),
              if (s.bannerText.isNotEmpty) FlashKv('Banner', s.bannerText),
              if (s.description.isNotEmpty) FlashKv('Details', s.description),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (s.isScheduled)
                    AppButton('Start now',
                        icon: 'bolt',
                        size: BtnSize.sm,
                        loading: _busy,
                        onTap: _busy ? null : () => _startNow(s)),
                  if (s.isActive)
                    AppButton('End now',
                        size: BtnSize.sm,
                        variant: BtnVariant.dangerSoft,
                        disabled: _busy,
                        onTap: _busy ? null : () => _endNow(s)),
                  if (!s.isClosed)
                    AppButton('Edit',
                        icon: 'edit',
                        size: BtnSize.sm,
                        variant: BtnVariant.secondary,
                        onTap: () => go('/admin/flash-sales?edit=${s.id}')),
                  AppButton('Duplicate',
                      icon: 'refresh',
                      size: BtnSize.sm,
                      variant: BtnVariant.secondary,
                      onTap: _busy ? null : () => _duplicate(s)),
                  AppButton('Report',
                      icon: 'chart',
                      size: BtnSize.sm,
                      variant: BtnVariant.secondary,
                      onTap: () => go('/admin/flash-sales?report=${s.id}')),
                  if (s.isScheduled)
                    AppButton('Delete',
                        icon: 'trash',
                        size: BtnSize.sm,
                        variant: BtnVariant.dangerSoft,
                        disabled: _busy,
                        onTap: _busy ? null : () => _deleteSale(s)),
                  if (!s.isClosed)
                    AppButton('Cancel sale',
                        size: BtnSize.sm,
                        variant: BtnVariant.dangerSoft,
                        disabled: _busy,
                        onTap: _busy ? null : () => _cancel(s)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: '${gt('Products')} (${s.items.length})',
          actionLabel: s.isClosed ? null : gt('Add product'),
          onAction: s.isClosed ? null : () => _addItem(s),
          child: s.items.isEmpty
              ? Hint(gt('This sale has no products yet. It will not show to customers.'))
              : Column(children: [
                  for (var i = 0; i < s.items.length; i++)
                    _itemRow(s, s.items[i], divider: i < s.items.length - 1),
                ]),
        ),
      ],
    );
  }

  Widget _itemRow(FlashSaleView s, FlashItemView it, {required bool divider}) {
    final noOffer = it.salePricePaise == null;
    final capped = it.maxQty != null;
    final frac = capped && it.maxQty! > 0 ? it.soldQty / it.maxQty! : 0.0;
    final disc = it.effectiveKind == 'PERCENT'
        ? '${it.effectiveValue}%'
        : it.effectiveKind == 'FIXED_PRICE'
            ? fmtPaise(it.effectiveValue)
            : '-';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: divider ? AppColors.line : Colors.transparent)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(it.nameEn,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    )),
              ),
              if (!s.isClosed) ...[
                IconBtn('edit',
                    size: 36, iconSize: 15, onTap: () => _editItem(s, it)),
                if (it.untouched) ...[
                  const SizedBox(width: 6),
                  IconBtn('trash',
                      size: 36,
                      iconSize: 15,
                      onTap: _busy ? null : () => _removeItem(s, it)),
                ],
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (noOffer)
            Text(
                gt('No offer right now: this discount no longer gives a lower price than the list price.'),
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                ))
          else
            Row(
              children: [
                Text(fmtPaise(it.salePricePaise!),
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red,
                    )),
                const SizedBox(width: 6),
                Text(fmtPaise(it.listPricePaise),
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12,
                      color: AppColors.ink3,
                      decoration: TextDecoration.lineThrough,
                    )),
                const SizedBox(width: 8),
                if (it.discountPercent != null)
                  Text('${it.discountPercent}% ${gt('off')}',
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      )),
              ],
            ),
          const SizedBox(height: 6),
          Text(
              '${gt('Discount')}: $disc${it.hasOwnDiscount ? '' : ' (${gt('sale default')})'}'
              ' · ${gt('Per customer')}: ${it.effectivePerCustomerLimit > 0 ? it.effectivePerCustomerLimit : gt('no limit')}',
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink2,
              )),
          const SizedBox(height: 6),
          if (capped) ...[
            MeterBar(frac,
                color: it.unitsLeft == 0 ? AppColors.red : AppColors.navy2),
            const SizedBox(height: 4),
            Text(
                '${it.soldQty} / ${it.maxQty} ${gt('sold')} · ${it.unitsLeft ?? 0} ${gt('left')}',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                )),
          ] else
            Text('${it.soldQty} ${gt('sold')} · ${gt('No stock cap')}',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                )),
        ],
      ),
    );
  }
}

/// 409 `FLASH_OVERLAP`: tell which sale holds the product and offer to open it.
void showFlashOverlapSheet(BuildContext context,
    {required String message, required String saleId, required String saleName}) {
  showAppSheet<void>(
    context: context,
    title: 'Product already in another sale',
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Text(message,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.ink2,
              )),
        ),
        AppButton(saleName.isEmpty ? 'Open that sale' : '${gt('Open')} "$saleName"',
            block: true, onTap: () {
          Navigator.of(ctx).pop();
          go('/admin/flash-sales?id=$saleId');
        }),
        const SizedBox(height: 8),
        AppButton('Close',
            variant: BtnVariant.secondary,
            block: true,
            onTap: () => Navigator.of(ctx).pop()),
        const SizedBox(height: 8),
      ],
    ),
  );
}
