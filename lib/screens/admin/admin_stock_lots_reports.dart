import 'package:flutter/material.dart';

import '../../data/api/lots_api.dart';
import '../../data/api/lots_dto.dart';
import '../../data/ist.dart';
import '../../data/lots_store.dart';
import '../../provider/state_scope.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import 'admin_stock_lots_common.dart';

Widget _chips(List<(String, String)> tabs, String value,
        ValueChanged<String> onChanged) =>
    ChipRail(children: [
      for (final t in tabs)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppChip(gt(t.$2),
              selected: value == t.$1, onTap: () => onChanged(t.$1)),
        ),
    ]);

Widget _statBox(String label, String value, {Color? color}) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: LotsKv(label, value, color: color),
    );

// ===========================================================================
// Expiring
// ===========================================================================

class LotsExpiringTab extends StatefulWidget {
  final VoidCallback onStockHealth;
  const LotsExpiringTab({super.key, required this.onStockHealth});

  @override
  State<LotsExpiringTab> createState() => _LotsExpiringTabState();
}

class _LotsExpiringTabState extends State<LotsExpiringTab> {
  ExpiringResult? _res;
  bool _loading = true;
  String? _error;
  String? _daysError;
  int? _days; // null = shop default
  final _daysCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _daysCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await LotsApi.instance.expiring(days: _days);
      if (!mounted) return;
      setState(() {
        _res = r;
        _loading = false;
        if (_days == null) _daysCtl.text = '${r.days}';
      });
      LotsStore.instance.refreshExpiring();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = lotsError(e);
      });
    }
  }

  void _apply() {
    final t = _daysCtl.text.trim();
    final n = int.tryParse(t);
    if (n == null) {
      setState(() => _daysError = gt('Enter a whole number of days'));
      return;
    }
    if (n < 0 || n > 365) {
      setState(() => _daysError = gt('Days must be 0 to 365'));
      return;
    }
    setState(() {
      _daysError = null;
      _days = n;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final r = _res;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardPanel(
          title: gt('Expiring soon'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChipRail(children: [
                for (final d in const [0, 7, 30, 60, 90])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(d == 0 ? gt('Expired / today') : '$d ${gt('days')}',
                        selected: _days == d, onTap: () {
                      _daysCtl.text = '$d';
                      setState(() {
                        _days = d;
                        _daysError = null;
                      });
                      _load();
                    }),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppField(
                      label: 'Days ahead (0 to 365)',
                      controller: _daysCtl,
                      numeric: true,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      error: _daysError,
                      onEditingComplete: _apply,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 27),
                    child: AppButton('Show',
                        variant: BtnVariant.secondary, onTap: _apply),
                  ),
                ],
              ),
              if (r != null)
                LotsNote(
                    '${gt('Lots with stock expiring up to')} ${lDate(r.until)} (${r.days} ${gt('days')}), ${gt('expired ones included')}.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_loading && r == null)
          const SkeletonRows(rows: 3)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (r != null && r.lots.isEmpty)
          CardPanel(
            child: EmptyState(
                icon: 'box',
                title: gt('Nothing close to expiry'),
                copy: gt('No lot with stock expires in this window.')),
          )
        else if (r != null) ...[
          if (r.truncated)
            LotsNote(gt('Showing the first 200. Narrow the window to see the rest.'),
                warn: true),
          for (final l in r.lots)
            LotCard(
              lot: l,
              unit: lotUnitFor(state, l.productId),
              showName: true,
              onChanged: _load,
              onStockHealth: widget.onStockHealth,
            ),
        ],
      ],
    );
  }
}

// ===========================================================================
// Valuation
// ===========================================================================

class LotsValuationTab extends StatefulWidget {
  const LotsValuationTab({super.key});

  @override
  State<LotsValuationTab> createState() => _LotsValuationTabState();
}

class _LotsValuationTabState extends State<LotsValuationTab> {
  String _group = 'product';
  Valuation? _val;
  final _rows = <ValuationRow>[];
  bool _loading = true, _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = more ? (_val?.info.page ?? 0) + 1 : 0;
      final v = await LotsApi.instance
          .valuation(groupBy: _group, page: page, size: 20);
      if (!mounted) return;
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(v.rows);
        _val = v;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _more = false;
        _error = lotsError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _val;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chips(const [('product', 'By product'), ('category', 'By category')],
            _group, (g) {
          setState(() => _group = g);
          _load();
        }),
        const SizedBox(height: 12),
        if (_loading && v == null)
          const SkeletonRows(rows: 4)
        else if (_error != null && v == null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (v != null) ...[
          if (v.total.costUnknownQty > 0)
            LotsNote(
                '${v.total.costUnknownQty} ${gt('units in')} ${v.total.costUnknownProducts} ${gt('products have no known cost; the value is understated. Receive a purchase or correct the cost to fix it.')}',
                warn: true),
          Row(
            children: [
              Expanded(
                  child: _statBox(
                      v.total.costUnknownQty > 0
                          ? 'Stock value (at least)'
                          : 'Stock value',
                      lRs(v.total.valuePaise))),
              const SizedBox(width: 10),
              Expanded(child: _statBox('Units in stock', '${v.total.qty}')),
            ],
          ),
          const SizedBox(height: 12),
          if (_rows.isEmpty)
            CardPanel(
                child: EmptyState(
                    icon: 'box',
                    title: gt('No stock'),
                    copy: gt('Nothing is on the shelf.')))
          else
            CardPanel(
              title: _group == 'category'
                  ? gt('Value by category')
                  : gt('Value by product'),
              child: Column(
                children: [
                  for (final r in _rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name, style: lHead),
                                Text(
                                    '${r.qty} ${gt('units')}${r.costUnknownQty > 0 ? ' · ${r.costUnknownQty} ${gt('with unknown cost')}' : ''}',
                                    style: TextStyle(
                                        fontFamily: AppTheme.uiFont,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: r.costUnknownQty > 0
                                            ? AppColors.red
                                            : AppColors.ink3)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(lRs(r.valuePaise), style: lHead),
                        ],
                      ),
                    ),
                  if (v.info.hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppButton('Load more',
                          variant: BtnVariant.secondary,
                          block: true,
                          loading: _more,
                          onTap: () => _load(more: true)),
                    ),
                  LotsNote('${gt('Showing')} ${_rows.length} ${gt('of')} ${v.info.totalText}'),
                ],
              ),
            ),
          if (_error != null) LotsNote(_error!, error: true),
        ],
      ],
    );
  }
}

// ===========================================================================
// Margin
// ===========================================================================

class LotsMarginTab extends StatefulWidget {
  const LotsMarginTab({super.key});

  @override
  State<LotsMarginTab> createState() => _LotsMarginTabState();
}

class _LotsMarginTabState extends State<LotsMarginTab> {
  String _group = 'product';
  late DateTime _to = istNow();
  late DateTime _from = DateTime.utc(istNow().year, istNow().month, 1);
  final _rows = <MarginRow>[];
  MarginPage? _page;
  bool _loading = true, _more = false;
  String? _error, _rangeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _checkRange() {
    if (_from.isAfter(_to)) return gt('The start date must not be after the end date');
    if (_to.difference(_from).inDays > 365) {
      return gt('The range can be one year at most');
    }
    return null;
  }

  Future<void> _load({bool more = false}) async {
    final bad = _checkRange();
    if (bad != null) {
      setState(() => _rangeError = bad);
      return;
    }
    setState(() {
      _rangeError = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = more ? (_page?.info.page ?? 0) + 1 : 0;
      final r = await LotsApi.instance.margin(
          groupBy: _group,
          from: lYmd(_from),
          to: lYmd(_to),
          page: page,
          size: 20);
      if (!mounted) return;
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(r.items);
        _page = r;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = lotsError(e);
      setState(() {
        _loading = false;
        _more = false;
        if (_page != null) {
          _rangeError = msg;
        } else {
          _error = msg;
        }
      });
    }
  }

  Future<void> _pick(bool from) async {
    final cur = from ? _from : _to;
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(cur.year, cur.month, cur.day),
      firstDate: DateTime(istNow().year - 3),
      lastDate: DateTime(istNow().year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.navy)),
        child: child!,
      ),
    );
    if (d == null || !mounted) return;
    setState(() {
      final v = DateTime.utc(d.year, d.month, d.day);
      if (from) {
        _from = v;
      } else {
        _to = v;
      }
    });
    _load();
  }

  String _pct(double? p) => p == null
      ? '-'
      : '${p == p.roundToDouble() ? p.round() : p.toStringAsFixed(2)}%';

  @override
  Widget build(BuildContext context) {
    final uncosted = _rows.fold<int>(0, (a, r) => a + r.uncostedLines);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chips(const [
          ('product', 'By product'),
          ('category', 'By category'),
          ('day', 'By day'),
        ], _group, (g) {
          setState(() => _group = g);
          _load();
        }),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: SelectField(
                    label: 'From',
                    value: lDate(lYmd(_from)),
                    onTap: () => _pick(true))),
            const SizedBox(width: 10),
            Expanded(
                child: SelectField(
                    label: 'To',
                    value: lDate(lYmd(_to)),
                    onTap: () => _pick(false))),
          ],
        ),
        if (_rangeError != null) LotsNote(_rangeError!, error: true),
        const SizedBox(height: 12),
        LotsNote(
            gt('Revenue is before tax and net of returns. While stock with unknown cost exists, the margin is an upper bound (see Stock value).'),
            warn: true),
        if (_loading && _page == null)
          const SkeletonRows(rows: 4)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (_page != null) ...[
          if (uncosted > 0)
            LotsNote(
                '$uncosted ${gt('lines have no cost data and are excluded.')}',
                warn: true),
          if (_rows.isEmpty)
            CardPanel(
                child: EmptyState(
                    icon: 'box',
                    title: gt('No sales'),
                    copy: gt('Nothing was sold in these dates.')))
          else
            for (final r in _rows)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_group == 'day' ? lDate(r.key) : r.name, style: lHead),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 22,
                      runSpacing: 10,
                      children: [
                        LotsKv('Revenue', lRs(r.revenuePaise)),
                        LotsKv('Cost', lRs(r.costPaise)),
                        LotsKv('Margin', lRs(r.marginPaise),
                            color: r.marginPaise < 0 ? AppColors.red : null),
                        LotsKv('Margin %', _pct(r.marginPercent)),
                      ],
                    ),
                    if (r.uncostedLines > 0)
                      LotsNote(
                          '${r.uncostedLines} ${gt('lines have no cost data and are excluded.')}',
                          error: true),
                  ],
                ),
              ),
          if (_page!.info.hasMore)
            AppButton('Load more',
                variant: BtnVariant.secondary,
                block: true,
                loading: _more,
                onTap: () => _load(more: true)),
        ],
      ],
    );
  }
}

// ===========================================================================
// Stock health (lot check)
// ===========================================================================

class LotsHealthTab extends StatefulWidget {
  const LotsHealthTab({super.key});

  @override
  State<LotsHealthTab> createState() => _LotsHealthTabState();
}

class _LotsHealthTabState extends State<LotsHealthTab> {
  LotCheck? _res;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await LotsApi.instance.lotCheck();
      if (!mounted) return;
      setState(() {
        _res = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = lotsError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    if (_loading && r == null) return const SkeletonRows(rows: 3);
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    if (r == null) return const SizedBox.shrink();
    final state = StateScope.of(context);
    if (r.drifts.isEmpty) {
      return CardPanel(
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 44, color: AppColors.green),
            const SizedBox(height: 8),
            Text(gt('Stock health is OK'), style: lHead),
            const SizedBox(height: 4),
            Text(gt('Every variant has lots that add up to its stock on hand.'),
                textAlign: TextAlign.center, style: lSub),
            const SizedBox(height: 12),
            AppButton('Check again',
                variant: BtnVariant.secondary, size: BtnSize.sm, onTap: _load),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LotsNote(
            gt('These variants have lots that do not add up to their stock on hand. The app cannot fix this: contact support with the product ids. A stock count or a positive correction is the normal way to bring them back in line.'),
            warn: true),
        if (r.truncated)
          LotsNote(gt('Showing the first 200 variants; more exist.'), warn: true),
        for (final d in r.drifts)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: AppColors.red),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: lHead),
                const SizedBox(height: 2),
                SelectableText(d.productId, style: lSub),
                const SizedBox(height: 8),
                Wrap(spacing: 22, children: [
                  LotsKv('On hand', lotUnitFor(state, d.productId).qty(d.onHand)),
                  LotsKv('In lots', lotUnitFor(state, d.productId).qty(d.inLots),
                      color: AppColors.red),
                ]),
              ],
            ),
          ),
        AppButton('Check again',
            variant: BtnVariant.secondary, block: true, onTap: _load),
      ],
    );
  }
}
