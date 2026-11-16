import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/purchase_dto.dart';
import '../../data/purchase_store.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import 'admin_purchases_common.dart';
import 'admin_purchases_detail.dart';
import 'admin_purchases_form.dart';
import 'admin_purchases_reports.dart';
import 'admin_purchases_suppliers.dart';

/// `#/admin/purchases` - suppliers, purchases with GST, payments, returns,
/// payables and purchase reports (`70-purchases.md`, playbook P2). ADMIN only.
///
/// Routes (query): none = hub (`tab=purchases|suppliers|returns|reports`),
/// `new=1[&supplier=<id>]` = new purchase, `id=<purchase>` = detail,
/// `supplier=<id>` = supplier account and statement.
class AdminPurchasesScreen extends StatelessWidget {
  final Map<String, String> query;
  const AdminPurchasesScreen({super.key, this.query = const {}});

  @override
  Widget build(BuildContext context) {
    if (query['new'] == '1') {
      return AdminPurchaseFormScreen(
          key: ValueKey('new-${query['supplier']}'), supplierId: query['supplier']);
    }
    final id = query['id'];
    if (id != null && id.isNotEmpty) {
      return PurchaseDetailScreen(key: ValueKey(id), id: id);
    }
    final sup = query['supplier'];
    if (sup != null && sup.isNotEmpty) {
      return SupplierAccountScreen(key: ValueKey(sup), id: sup);
    }
    return _PurchasesHub(initialTab: query['tab'] ?? 'purchases');
  }
}

class _PurchasesHub extends StatefulWidget {
  final String initialTab;
  const _PurchasesHub({required this.initialTab});
  @override
  State<_PurchasesHub> createState() => _PurchasesHubState();
}

class _PurchasesHubState extends State<_PurchasesHub> {
  late String _tab = const ['purchases', 'suppliers', 'returns', 'reports']
          .contains(widget.initialTab)
      ? widget.initialTab
      : 'purchases';

  @override
  Widget build(BuildContext context) {
    return PurchasePage(
      title: gt('Purchases'),
      sub: gt('Suppliers, purchase bills with GST, payments and returns'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ChipRail(children: [
          for (final t in const [
            ('purchases', 'Purchases'),
            ('suppliers', 'Suppliers'),
            ('returns', 'Returns'),
            ('reports', 'Reports'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(t.$2,
                  selected: _tab == t.$1, onTap: () => setState(() => _tab = t.$1)),
            ),
        ]),
        const SizedBox(height: 12),
        if (_tab == 'purchases')
          const _PurchaseList()
        else if (_tab == 'suppliers')
          const SupplierListView()
        else if (_tab == 'returns')
          const PurchaseReturnsView()
        else
          const PurchaseReportsView(),
        const SizedBox(height: 12),
        AppLink('Stock count (physical count of the shelf)',
            onTap: () => go('/admin/stock-ops')),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase list + payables header
// ---------------------------------------------------------------------------

class _PurchaseList extends StatefulWidget {
  const _PurchaseList();
  @override
  State<_PurchaseList> createState() => _PurchaseListState();
}

class _PurchaseListState extends State<_PurchaseList> {
  final _store = PurchaseStore.instance;
  final _q = TextEditingController();
  Timer? _debounce;
  String _status = ''; // '', PENDING, PARTIAL, PAID, OVERDUE
  String? _from, _to;
  final List<PurchaseDto> _rows = [];
  int _page = 0;
  bool _loading = true, _more = false, _hasMore = false, _allSup = false;
  String? _error;
  String _total = '0';
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _store.loadPayables();
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool more = false}) async {
    final gen = more ? _gen : ++_gen;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _rows.clear();
        _page = 0;
        _loading = true;
        _error = null;
      }
    });
    try {
      final r = await _store.api.list(
        paymentStatus: _status == '' || _status == 'OVERDUE' ? null : _status,
        overdue: _status == 'OVERDUE',
        supplier: _q.text,
        from: _from,
        to: _to,
        page: more ? _page + 1 : 0,
        size: 20,
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _rows.addAll(r.items);
        _page = r.page;
        _hasMore = r.hasMore;
        _total = r.totalLabel;
        _loading = false;
        _more = false;
      });
      _store.ensurePacks(r.items.expand((p) => p.items).map((l) => l.productId));
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = purchaseError(e);
        _loading = false;
        _more = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final a = await pickYmd(context, _from, last: DateTime.now());
    if (a == null || !mounted) return;
    final b = await pickYmd(context, _to ?? a, last: DateTime.now());
    if (b == null) return;
    setState(() {
      _from = a.compareTo(b) <= 0 ? a : b;
      _to = a.compareTo(b) <= 0 ? b : a;
    });
    _load();
  }

  Widget _payables() {
    final p = _store.payables;
    if (p == null) return const SizedBox.shrink();
    final top = _allSup ? p.bySupplier : p.bySupplier.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CardPanel(
        title: gt('Payables'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: _stat(gt('You owe'), pRs(p.totalDuePaise),
                    p.totalDuePaise > 0 ? AppColors.red : AppColors.ink)),
            Expanded(
                child: _stat(
                    gt('Overdue'),
                    '${pRs(p.overduePaise)}${p.overdueCount > 0 ? ' (${p.overdueCount})' : ''}',
                    p.overduePaise > 0 ? AppColors.red : AppColors.ink)),
          ]),
          if (p.totalReturnedPaise > 0)
            Text('${gt('Debit notes so far')} ${pRs(p.totalReturnedPaise)}', style: pSub),
          if (top.isNotEmpty) ...[
            const Divider(height: 18, color: AppColors.line),
            for (final s in top)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => go('/admin/purchases?supplier=${s.supplierId}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${s.name}${s.overdueCount > 0 ? ' · ${s.overdueCount} ${gt('overdue')}' : ''}',
                            style: pBody)),
                    Text(
                        s.totalDuePaise < 0
                            ? '${gt('Credit')} ${pRs(-s.totalDuePaise)}'
                            : pRs(s.totalDuePaise),
                        style: pHead.copyWith(
                            color: s.totalDuePaise < 0 ? AppColors.green : AppColors.ink)),
                  ]),
                ),
              ),
            if (p.bySupplier.length > 4)
              AppLink(_allSup ? 'Show fewer' : 'Show all suppliers',
                  onTap: () => setState(() => _allSup = !_allSup)),
          ],
        ]),
      ),
    );
  }

  Widget _stat(String k, String v, Color c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: pSub),
        Text(v, style: pHead.copyWith(fontSize: 17, color: c)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppButton('New purchase', icon: 'plus', block: true,
          onTap: () => go('/admin/purchases?new=1')),
      const SizedBox(height: 12),
      _payables(),
      ChipRail(children: [
        for (final t in const [
          ('', 'All'),
          ('PENDING', 'Pending'),
          ('PARTIAL', 'Part paid'),
          ('PAID', 'Paid'),
          ('OVERDUE', 'Overdue'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip(t.$2, selected: _status == t.$1, onTap: () {
              setState(() => _status = t.$1);
              _load();
            }),
          ),
      ]),
      const SizedBox(height: 10),
      AppField(
        label: 'Find supplier',
        controller: _q,
        placeholder: 'Type a supplier name',
        onChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), _load);
        },
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: AppButton(
                _from == null ? 'Invoice dates: all' : '${pDate(_from)} - ${pDate(_to)}',
                variant: BtnVariant.secondary,
                onTap: _pickRange)),
        if (_from != null) ...[
          const SizedBox(width: 8),
          AppButton('Clear', variant: BtnVariant.secondary, onTap: () {
            setState(() {
              _from = null;
              _to = null;
            });
            _load();
          }),
        ],
      ]),
      const SizedBox(height: 12),
      if (_loading)
        const SkeletonRows(rows: 4)
      else if (_error != null)
        ErrorRetry(message: _error!, onRetry: _load)
      else if (_rows.isEmpty)
        EmptyState(
            icon: 'box',
            title: gt('No purchases found'),
            copy: gt('Record a supplier delivery with New purchase.'))
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('$_total ${gt('purchases')}', style: pSub),
        ),
        for (final p in _rows) _row(p),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppButton('Load more',
                variant: BtnVariant.secondary,
                block: true,
                loading: _more,
                onTap: _more ? null : () => _load(more: true)),
          ),
      ],
    ]);
  }

  Widget _row(PurchaseDto p) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => go('/admin/purchases?id=${p.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.sh1,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.supplierName, style: pHead),
                Text(
                    '${p.invoiceNo.isEmpty ? '-' : p.invoiceNo} · ${pDate(p.invoiceDate)}'
                    '${p.dueDate != null && p.duePaise > 0 ? ' · ${gt('due')} ${pDate(p.dueDate)}' : ''}',
                    style: pSub),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(pRs(p.totalCostPaise), style: pHead),
              if (p.duePaise != 0)
                Text(
                    p.duePaise > 0
                        ? '${gt('Due')} ${pRs(p.duePaise)}'
                        : '${gt('Credit')} ${pRs(-p.duePaise)}',
                    style: pSub.copyWith(
                        color: p.duePaise > 0 ? AppColors.red : AppColors.green,
                        fontWeight: FontWeight.w800)),
            ]),
          ]),
          const SizedBox(height: 6),
          payBadges(p.paymentStatus, p.overdue, p.duePaise),
          const SizedBox(height: 6),
          for (final l in p.items.take(4))
            Text('${l.name} · ${_store.qty(l.productId, l.received)}', style: pSub),
          if (p.items.length > 4)
            Text('+${p.items.length - 4} ${gt('more items')}', style: pSub),
          if (p.note.isNotEmpty) Text(p.note, style: pSub),
        ]),
      ),
    );
  }
}
