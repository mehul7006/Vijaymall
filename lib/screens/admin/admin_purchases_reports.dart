import 'package:flutter/material.dart';

import '../../data/api/purchase_dto.dart';
import '../../data/purchase_store.dart';
import '../../data/validators.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import '../../widgets/sheet.dart';
import 'admin_purchases_common.dart';

// ---------------------------------------------------------------------------
// Price history of one product (sheet)
// ---------------------------------------------------------------------------

Future<void> showPriceHistory(BuildContext context, String productId, String name) {
  return showAppSheet<void>(
    context: context,
    title: gt('Purchase price history'),
    sub: name,
    builder: (ctx) => _PriceHistory(productId: productId),
  );
}

class _PriceHistory extends StatefulWidget {
  final String productId;
  const _PriceHistory({required this.productId});
  @override
  State<_PriceHistory> createState() => _PriceHistoryState();
}

class _PriceHistoryState extends State<_PriceHistory> {
  List<PriceRowDto>? _rows;
  String? _error;
  String _rounding = 'PAISE';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final r = await PurchaseStore.instance.api
          .priceHistory(widget.productId, limit: 20, rounding: _rounding);
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) setState(() => _error = purchaseError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PurchaseStore.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PChoice<String>(
        options: const [
          ('PAISE', 'To the paisa'),
          ('RUPEE', 'To the rupee'),
          ('EXACT', 'Exact'),
        ],
        value: _rounding,
        onChanged: (v) {
          setState(() => _rounding = v);
          _load();
        },
      ),
      const SizedBox(height: 10),
      if (_error != null)
        ErrorRetry(message: _error!, onRetry: _load)
      else if (_rows == null)
        const SkeletonRows(rows: 4)
      else if (_rows!.isEmpty)
        Text(gt('This product has not been purchased yet.'), style: pSub)
      else
        for (final r in _rows!)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pop();
              go('/admin/purchases?id=${r.purchaseId}');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.supplierName, style: pHead),
                    Text(
                        '${pDate(r.invoiceDate)}${r.invoiceNo.isEmpty ? '' : ' · ${r.invoiceNo}'}'
                        ' · ${store.qty(widget.productId, r.qty + r.freeQty)}',
                        style: pSub),
                    Text(
                        '${gt('Invoice price')} ${pRs(r.unitCostPaise)}'
                        '${r.mrpPaise == null ? '' : ' · MRP ${pRs(r.mrpPaise!)}'}'
                        '${r.sellingPricePaise == null ? '' : ' · ${gt('Price')} ${pRs(r.sellingPricePaise!)}'}',
                        style: pSub),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                      pRsD(
                          _rounding == 'EXACT'
                              ? r.landedUnitCostPaise
                              : r.landedUnitCostRoundedPaise,
                          decimals: _rounding == 'EXACT' ? 4 : 2),
                      style: pHead),
                  Text(gt('landed / unit'), style: pSub),
                ]),
              ]),
            ),
          ),
      const SizedBox(height: 8),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Debit notes (all purchase returns)
// ---------------------------------------------------------------------------

class PurchaseReturnsView extends StatefulWidget {
  const PurchaseReturnsView({super.key});
  @override
  State<PurchaseReturnsView> createState() => _PurchaseReturnsViewState();
}

class _PurchaseReturnsViewState extends State<PurchaseReturnsView> {
  final List<PurchaseReturnDto> _rows = [];
  int _page = 0;
  bool _loading = true, _more = false, _hasMore = false;
  String? _error;
  final Set<String> _open = {};
  String? _supId, _supName, _from, _to;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _more = true;
      } else {
        _rows.clear();
        _loading = true;
        _error = null;
      }
    });
    try {
      final r = await PurchaseStore.instance.api.allReturns(
          supplierId: _supId,
          from: _from,
          to: _to,
          page: more ? _page + 1 : 0,
          size: 20);
      if (!mounted) return;
      setState(() {
        _rows.addAll(r.items);
        _page = r.page;
        _hasMore = r.hasMore;
        _loading = false;
        _more = false;
      });
      PurchaseStore.instance
          .ensurePacks(r.items.expand((e) => e.items).map((e) => e.productId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = purchaseError(e);
        _loading = false;
        _more = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PurchaseStore.instance;
    final filters = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PPickFilter(
          kind: 'supplier',
          selectedName: _supName,
          onPick: (id, n) {
            setState(() {
              _supId = id;
              _supName = n;
            });
            _load();
          },
          onClear: () {
            setState(() {
              _supId = null;
              _supName = null;
            });
            _load();
          }),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: AppButton(
                _from == null ? 'Dates: all' : '${pDate(_from)} - ${pDate(_to)}',
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
    ]);
    if (_loading) return Column(children: [filters, const SkeletonRows(rows: 4)]);
    if (_error != null) return Column(children: [filters, ErrorRetry(message: _error!, onRetry: _load)]);
    if (_rows.isEmpty) {
      return Column(children: [
        filters,
        EmptyState(
            icon: 'box',
            title: gt('No returns yet'),
            copy: gt('Goods sent back to a supplier appear here as debit notes.')),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      filters,
      for (final r in _rows)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: AppColors.line),
            boxShadow: AppColors.sh1,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open.contains(r.id) ? _open.remove(r.id) : _open.add(r.id)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.noteNo} · ${r.supplierName}', style: pHead),
                    Text(
                        '${pDate(r.createdAt)}${r.invoiceNo.isEmpty ? '' : ' · ${gt('Invoice')} ${r.invoiceNo}'} · ${r.reason}',
                        style: pSub),
                  ]),
                ),
                Text(pRs(r.totalPaise), style: pHead),
              ]),
            ),
            if (_open.contains(r.id)) ...[
              const SizedBox(height: 8),
              for (final l in r.items)
                PKv(l.name, '${store.qty(l.productId, -l.qty)} · ${pRs(l.totalPaise)}'),
              PKv('Taxable', pRs(r.taxablePaise)),
              PKv('CGST + SGST', pRs(r.cgstPaise + r.sgstPaise)),
              if (r.igstPaise > 0) PKv('IGST', pRs(r.igstPaise)),
              if (r.cessPaise > 0) PKv('Cess', pRs(r.cessPaise)),
              Align(
                alignment: Alignment.centerLeft,
                child: AppLink('Open purchase',
                    onTap: () => go('/admin/purchases?id=${r.purchaseId}')),
              ),
            ],
          ]),
        ),
      if (_hasMore)
        AppButton('Load more',
            variant: BtnVariant.secondary,
            block: true,
            loading: _more,
            onTap: _more ? null : () => _load(more: true)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// The four purchase reports
// ---------------------------------------------------------------------------

class PurchaseReportsView extends StatefulWidget {
  const PurchaseReportsView({super.key});
  @override
  State<PurchaseReportsView> createState() => _PurchaseReportsViewState();
}

class _PurchaseReportsViewState extends State<PurchaseReportsView> {
  String _tab = 'register';
  late String _from = '${todayYmd().substring(0, 8)}01';
  String _to = todayYmd();
  String _asOf = todayYmd();
  int? _rate;
  String? _supId, _supName, _prodId, _prodName;
  bool _loading = true, _more = false;
  String? _error;
  String? _rangeErr;
  // data
  final List<RegisterRowDto> _reg = [];
  int _regPage = 0;
  bool _regHasMore = false;
  String _regTotal = '0';
  InputGstDto? _gst;
  DiscountsDto? _disc;
  AgeingDto? _age;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _checkRange() {
    final a = DateTime.tryParse(_from), b = DateTime.tryParse(_to);
    if (a == null || b == null) return gt('Choose both dates');
    if (a.isAfter(b)) return gt('The start date is after the end date');
    if (b.difference(a).inDays >= 366) return gt('Choose a range of at most 366 days');
    return null;
  }

  Future<void> _load({bool more = false}) async {
    if (_tab != 'ageing') {
      final err = _checkRange();
      if (err != null) {
        setState(() => _rangeErr = err);
        return;
      }
    }
    setState(() {
      _rangeErr = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    final api = PurchaseStore.instance.api;
    try {
      switch (_tab) {
        case 'register':
          final r = await api.register(
              from: _from,
              to: _to,
              gstRate: _rate,
              supplierId: _supId,
              productId: _prodId,
              page: more ? _regPage + 1 : 0,
              size: 20);
          if (!mounted) return;
          setState(() {
            if (!more) _reg.clear();
            _reg.addAll(r.items);
            _regPage = r.page;
            _regHasMore = r.hasMore;
            _regTotal = r.totalLabel;
          });
          break;
        case 'gst':
          final r = await api.inputGst(from: _from, to: _to);
          if (!mounted) return;
          setState(() => _gst = r);
          break;
        case 'discounts':
          final r = await api.discounts(from: _from, to: _to);
          if (!mounted) return;
          setState(() => _disc = r);
          break;
        default:
          final r = await api.ageing(asOf: _asOf);
          if (!mounted) return;
          setState(() => _age = r);
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = purchaseError(e);
        _loading = false;
        _more = false;
      });
    }
  }

  bool _exporting = false;

  /// CSV of the report on screen. The register is fetched page by page for
  /// the whole range (50 per page) so the file is complete.
  Future<void> _export() async {
    setState(() => _exporting = true);
    final api = PurchaseStore.instance.api;
    try {
      switch (_tab) {
        case 'register':
          final rows = <RegisterRowDto>[];
          for (var page = 0; page < 200; page++) {
            final r = await api.register(
                from: _from,
                to: _to,
                gstRate: _rate,
                supplierId: _supId,
                productId: _prodId,
                page: page,
                size: 50);
            rows.addAll(r.items);
            if (!r.hasMore) break;
          }
          saveCsv(
              'purchase-register-$_from-to-$_to.csv',
              toCsv([
                'Invoice date', 'Invoice no', 'Supplier', 'GST mode', 'Product',
                'Qty', 'Free qty', 'Unit cost', 'Discount', 'Taxable', 'GST %',
                'CGST', 'SGST', 'IGST', 'Cess', 'Line total', 'Landed unit cost (paise)'
              ], [
                for (final r in rows)
                  [
                    r.invoiceDate, r.invoiceNo, r.supplierName, r.gstMode,
                    r.productName, '${r.qty}', '${r.freeQty}',
                    csvRs(r.unitCostPaise), csvRs(r.discountPaise),
                    csvRs(r.taxablePaise), '${r.gstPercent}',
                    csvRs(r.cgstPaise), csvRs(r.sgstPaise), csvRs(r.igstPaise),
                    csvRs(r.cessPaise), csvRs(r.lineTotalPaise),
                    r.landedUnitCostPaise.toStringAsFixed(4)
                  ]
              ]));
          break;
        case 'gst':
          final g = _gst ?? await api.inputGst(from: _from, to: _to);
          saveCsv(
              'input-gst-$_from-to-$_to.csv',
              toCsv([
                'GST mode', 'GST %', 'Taxable', 'CGST', 'SGST', 'IGST', 'Cess',
                'Creditable', 'Not creditable'
              ], [
                for (final l in g.lines)
                  [
                    l.gstMode, '${l.gstPercent}', csvRs(l.taxablePaise),
                    csvRs(l.cgstPaise), csvRs(l.sgstPaise), csvRs(l.igstPaise),
                    csvRs(l.cessPaise), csvRs(l.creditablePaise),
                    csvRs(l.nonCreditablePaise)
                  ],
                [
                  'Total', '', csvRs(g.taxablePaise), csvRs(g.cgstPaise),
                  csvRs(g.sgstPaise), csvRs(g.igstPaise), csvRs(g.cessPaise),
                  csvRs(g.creditablePaise), csvRs(g.nonCreditablePaise)
                ]
              ]));
          break;
        case 'discounts':
          final d = _disc ?? await api.discounts(from: _from, to: _to);
          saveCsv(
              'purchase-discounts-$_from-to-$_to.csv',
              toCsv([
                'Supplier', 'Purchases', 'Goods value', 'Line discount', 'Bill discount'
              ], [
                for (final s in d.bySupplier)
                  [
                    s.supplierName, '${s.purchaseCount}', csvRs(s.grossPaise),
                    csvRs(s.lineDiscountPaise), csvRs(s.docDiscountPaise)
                  ],
                [
                  'Total', '', csvRs(d.grossPaise), csvRs(d.lineDiscountPaise),
                  csvRs(d.docDiscountPaise)
                ]
              ]));
          break;
        default:
          final a = _age ?? await api.ageing(asOf: _asOf);
          saveCsv(
              'payables-ageing-$_asOf.csv',
              toCsv([
                'Supplier', '0-30 days', '31-60 days', '61+ days',
                'Supplier credit', 'Total due'
              ], [
                for (final s in a.bySupplier)
                  [
                    s.supplierName, csvRs(s.days0to30Paise),
                    csvRs(s.days31to60Paise), csvRs(s.days61PlusPaise),
                    csvRs(s.creditPaise), csvRs(s.totalDuePaise)
                  ],
                [
                  'Total', csvRs(a.days0to30Paise), csvRs(a.days31to60Paise),
                  csvRs(a.days61PlusPaise), csvRs(a.creditPaise),
                  csvRs(a.totalDuePaise)
                ]
              ]));
      }
    } catch (e) {
      if (mounted) showToast(purchaseError(e), 'error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pick(bool from) async {
    final r = await pickYmd(context, from ? _from : _to, last: DateTime.now());
    if (r == null) return;
    setState(() => from ? _from = r : _to = r);
    _load();
  }

  Widget _range() {
    if (_tab == 'ageing') {
      return Row(children: [
        Text(gt('As of'), style: pHead),
        const SizedBox(width: 10),
        Expanded(
            child: AppButton(pDate(_asOf), variant: BtnVariant.secondary, onTap: () async {
          final r = await pickYmd(context, _asOf, last: DateTime.now());
          if (r != null) {
            setState(() => _asOf = r);
            _load();
          }
        })),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: AppButton('${gt('From')} ${pDate(_from)}',
                variant: BtnVariant.secondary, onTap: () => _pick(true))),
        const SizedBox(width: 8),
        Expanded(
            child: AppButton('${gt('To')} ${pDate(_to)}',
                variant: BtnVariant.secondary, onTap: () => _pick(false))),
      ]),
      if (_rangeErr != null) PNote(_rangeErr!, error: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ChipRail(children: [
        for (final t in const [
          ('register', 'Purchase register'),
          ('gst', 'Input GST'),
          ('discounts', 'Discounts'),
          ('ageing', 'Payables ageing'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip(t.$2, selected: _tab == t.$1, onTap: () {
              setState(() => _tab = t.$1);
              _load();
            }),
          ),
      ]),
      const SizedBox(height: 10),
      _range(),
      if (_tab == 'register') ...[
        const SizedBox(height: 10),
        ChipRail(children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip('All GST rates', small: true, selected: _rate == null, onTap: () {
              setState(() => _rate = null);
              _load();
            }),
          ),
          for (final s in Validators.gstSlabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip('$s%', small: true, selected: _rate == s, onTap: () {
                setState(() => _rate = s);
                _load();
              }),
            ),
        ]),
        const SizedBox(height: 10),
        PPickFilter(
            kind: 'supplier',
            selectedName: _supName,
            onPick: (id, n) {
              setState(() {
                _supId = id;
                _supName = n;
              });
              _load();
            },
            onClear: () {
              setState(() {
                _supId = null;
                _supName = null;
              });
              _load();
            }),
        const SizedBox(height: 8),
        PPickFilter(
            kind: 'product',
            selectedName: _prodName,
            onPick: (id, n) {
              setState(() {
                _prodId = id;
                _prodName = n;
              });
              _load();
            },
            onClear: () {
              setState(() {
                _prodId = null;
                _prodName = null;
              });
              _load();
            }),
      ],
      const SizedBox(height: 10),
      AppButton('Download CSV',
          icon: 'download',
          variant: BtnVariant.secondary,
          block: true,
          loading: _exporting,
          onTap: _loading || _exporting ? null : _export),
      const SizedBox(height: 12),
      if (_loading)
        const SkeletonRows(rows: 4)
      else if (_error != null)
        ErrorRetry(message: _error!, onRetry: _load)
      else
        _body(),
    ]);
  }

  Widget _body() {
    switch (_tab) {
      case 'register':
        return _register();
      case 'gst':
        return _inputGst();
      case 'discounts':
        return _discounts();
      default:
        return _ageing();
    }
  }

  Widget _register() {
    if (_reg.isEmpty) {
      return EmptyState(
          icon: 'chart',
          title: gt('No purchases in this period'),
          copy: gt('Change the dates or the GST rate.'));
    }
    final pageTotal = _reg.fold<int>(0, (a, r) => a + r.lineTotalPaise);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$_regTotal ${gt('lines')} · ${gt('shown')} ${_reg.length} · ${gt('total of shown')} ${pRs(pageTotal)}',
          style: pHead),
      const SizedBox(height: 8),
      for (final r in _reg)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => go('/admin/purchases?id=${r.purchaseId}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.productName, style: pHead)),
                Text(pRs(r.lineTotalPaise), style: pHead),
              ]),
              Text(
                  '${r.supplierName} · ${pDate(r.invoiceDate)}${r.invoiceNo.isEmpty ? '' : ' · ${r.invoiceNo}'}',
                  style: pSub),
              Text(
                  '${r.qty}${r.freeQty > 0 ? ' + ${r.freeQty} ${gt('free')}' : ''} x ${pRs(r.unitCostPaise)}'
                  ' · ${gt('Taxable')} ${pRs(r.taxablePaise)} · GST ${r.gstPercent}%'
                  '${r.discountPaise > 0 ? ' · ${gt('discount')} ${pRs(r.discountPaise)}' : ''}',
                  style: pSub),
              Text(
                  '${r.igstPaise > 0 ? 'IGST ${pRs(r.igstPaise)}' : 'CGST ${pRs(r.cgstPaise)} + SGST ${pRs(r.sgstPaise)}'}'
                  '${r.cessPaise > 0 ? ' + ${gt('cess')} ${pRs(r.cessPaise)}' : ''}'
                  ' · ${gt('landed')} ${pRsD(r.landedUnitCostPaise, decimals: 4)}',
                  style: pSub),
            ]),
          ),
        ),
      if (_regHasMore)
        AppButton('Load more',
            variant: BtnVariant.secondary,
            block: true,
            loading: _more,
            onTap: _more ? null : () => _load(more: true)),
    ]);
  }

  Widget _inputGst() {
    final g = _gst;
    if (g == null) return const SizedBox.shrink();
    Widget cell(String t, double w, {bool head = false, bool left = false, bool bold = false}) => SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
            child: Text(t,
                textAlign: left ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: head ? 11 : 12,
                    fontWeight: head || bold ? FontWeight.w800 : FontWeight.w600,
                    color: head ? AppColors.ink3 : AppColors.ink)),
          ),
        );
    const w = [104.0, 82.0, 72.0, 72.0, 72.0, 62.0, 84.0, 84.0];
    Widget row(List<String> c, {bool head = false, bool bold = false}) => Container(
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.line, width: head || bold ? 1.2 : .6))),
          child: Row(children: [
            for (var i = 0; i < 8; i++) cell(c[i], w[i], head: head, bold: bold, left: i == 0),
          ]),
        );
    return CardPanel(
      title: '${pDate(g.from)} - ${pDate(g.to)}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(children: [
            row([gt('GST'), gt('Taxable'), 'CGST', 'SGST', 'IGST', gt('Cess'), gt('Credit'), gt('No credit')],
                head: true),
            for (final l in g.lines)
              row([
                l.gstMode == 'COMPOSITION'
                    ? '${l.gstPercent}% ${gt('Comp.')}'
                    : l.gstMode == 'NONE'
                        ? '${l.gstPercent}% ${gt('No GST')}'
                        : '${l.gstPercent}%',
                pRs(l.taxablePaise),
                pRs(l.cgstPaise),
                pRs(l.sgstPaise),
                pRs(l.igstPaise),
                pRs(l.cessPaise),
                pRs(l.creditablePaise),
                pRs(l.nonCreditablePaise),
              ]),
            row([
              gt('Total'),
              pRs(g.taxablePaise),
              pRs(g.cgstPaise),
              pRs(g.sgstPaise),
              pRs(g.igstPaise),
              pRs(g.cessPaise),
              pRs(g.creditablePaise),
              pRs(g.nonCreditablePaise),
            ], bold: true),
          ]),
        ),
        const PHint('Credit = tax you can claim back (Regular purchases). No credit = tax on Composition purchases (Comp.), part of the cost. Returns are already subtracted.'),
      ]),
    );
  }

  Widget _discounts() {
    final d = _disc;
    if (d == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CardPanel(
        title: '${pDate(d.from)} - ${pDate(d.to)}',
        child: Column(children: [
          PKv('Goods value before discounts', pRs(d.grossPaise)),
          PKv('Line discounts', pRs(d.lineDiscountPaise)),
          PKv('Bill discounts', pRs(d.docDiscountPaise)),
          PKv('Total discount', pRs(d.lineDiscountPaise + d.docDiscountPaise), bold: true),
        ]),
      ),
      const SizedBox(height: 12),
      if (d.bySupplier.isEmpty)
        Text(gt('No discounts in this period.'), style: pSub)
      else
        CardPanel(
          title: gt('By supplier'),
          child: Column(children: [
            for (final s in d.bySupplier)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.supplierName, style: pHead),
                      Text('${s.purchaseCount} ${gt('purchases')} · ${gt('goods')} ${pRs(s.grossPaise)}',
                          style: pSub),
                    ]),
                  ),
                  Text(pRs(s.lineDiscountPaise + s.docDiscountPaise), style: pHead),
                ]),
              ),
          ]),
        ),
    ]);
  }

  Widget _ageing() {
    final a = _age;
    if (a == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CardPanel(
        title: '${gt('As of')} ${pDate(a.asOf)}',
        child: Column(children: [
          PKv('0 to 30 days', pRs(a.days0to30Paise)),
          PKv('31 to 60 days', pRs(a.days31to60Paise)),
          PKv('61 days and more', pRs(a.days61PlusPaise)),
          if (a.creditPaise != 0) PKv('Supplier credit', pRs(a.creditPaise)),
          PKv('Total due', pRs(a.totalDuePaise), bold: true),
        ]),
      ),
      const SizedBox(height: 12),
      if (a.bySupplier.isEmpty)
        Text(gt('Nothing is owed.'), style: pSub)
      else
        for (final s in a.bySupplier)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => go('/admin/purchases?supplier=${s.supplierId}'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.supplierName, style: pHead)),
                  Text(pRs(s.totalDuePaise), style: pHead),
                ]),
                Text(
                    '0-30: ${pRs(s.days0to30Paise)} · 31-60: ${pRs(s.days31to60Paise)} · 61+: ${pRs(s.days61PlusPaise)}'
                    '${s.creditPaise != 0 ? ' · ${gt('credit')} ${pRs(s.creditPaise)}' : ''}',
                    style: pSub),
              ]),
            ),
          ),
    ]);
  }
}
