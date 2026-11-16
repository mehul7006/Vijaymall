import 'package:flutter/material.dart';

import '../../data/api/api_service.dart';
import '../../data/api/flash_dto.dart';
import '../../data/ist.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/fields.dart';
import '../../widgets/flash_widgets.dart' show flashWhen;
import '../../widgets/panels.dart';
import 'admin_flash_common.dart';

String _pct(double v) =>
    '${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(2)}%';

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `#/admin/flash-sales?report=<id>` (one sale) or `?report=all` (period).
class AdminFlashReportScreen extends StatefulWidget {
  final String? saleId;
  const AdminFlashReportScreen({super.key, this.saleId});

  @override
  State<AdminFlashReportScreen> createState() => _AdminFlashReportScreenState();
}

class _AdminFlashReportScreenState extends State<AdminFlashReportScreen> {
  FlashSaleReport? _sale;
  FlashPeriodReport? _period;
  bool _loading = true;
  String? _error;
  late DateTime _to = istNow();
  late DateTime _from = istNow().subtract(const Duration(days: 29));
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rangeError = null;
    });
    try {
      if (widget.saleId != null) {
        final r = await Api.instance.flash.report(widget.saleId!);
        if (!mounted) return;
        setState(() {
          _sale = r;
          _loading = false;
        });
      } else {
        final r = await Api.instance.flash
            .periodReport(from: _dateKey(_from), to: _dateKey(_to));
        if (!mounted) return;
        setState(() {
          _period = r;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = flashError(e);
      setState(() {
        _loading = false;
        // A bad range (400 on `to`) keeps the previous report on screen.
        if (widget.saleId == null && _period != null) {
          _rangeError = msg;
        } else {
          _error = msg;
        }
      });
    }
  }

  Future<void> _pickDate(bool from) async {
    final cur = from ? _from : _to;
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(cur.year, cur.month, cur.day),
      firstDate: DateTime(istNow().year - 2),
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

  @override
  Widget build(BuildContext context) {
    final one = widget.saleId != null;
    return FlashAdminPage(
      title: gt(one ? 'Sale report' : 'Flash sales report'),
      sub: one ? (_sale?.name ?? '') : gt('Sales that started in the chosen dates'),
      backToList: true,
      onRefresh: _load,
      child: _loading && _sale == null && _period == null
          ? const SkeletonRows(rows: 5)
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : one
                  ? _saleBody(_sale!)
                  : _periodBody(_period!),
    );
  }

  // ---- shared ---------------------------------------------------------------

  Widget _kpis(List<(String, String, String, Color, Color)> items) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final k in items)
            SizedBox(
              width: w,
              child: KpiCard(
                icon: k.$1,
                label: gt(k.$2),
                value: k.$3,
                tint: k.$4,
                bg: k.$5,
              ),
            ),
        ],
      );
    });
  }

  List<(String, String, String, Color, Color)> _commonKpis({
    required int units,
    required int revenue,
    required int discount,
    required double avg,
    required int orders,
    required int bills,
    required int customers,
  }) =>
      [
        ('bolt', 'Units sold', '$units', AppColors.red, AppColors.redTint),
        ('coin', 'Revenue', fmtPaise(revenue), AppColors.green, AppColors.greenTint),
        ('ticket', 'Discount given', fmtPaise(discount), AppColors.orange,
            AppColors.orangeTint),
        ('chart', 'Avg discount', _pct(avg), AppColors.navy, AppColors.navyTint),
        ('cart', 'Online orders', '$orders', AppColors.navy, AppColors.navyTint),
        ('store', 'Counter bills', '$bills', AppColors.goldInk, AppColors.goldTint),
        ('users', 'Customers', '$customers', AppColors.green, AppColors.greenTint),
      ];

  Widget _itemRows(List<FlashItemReport> rows, {bool meter = true}) {
    if (rows.isEmpty) return Hint(gt('Nothing sold yet.'));
    final top = rows.fold<int>(0, (m, r) => r.units > m ? r.units : m);
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.nameEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        )),
                  ),
                  Text('${r.units} ${gt('sold')}',
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.red,
                      )),
                ],
              ),
              const SizedBox(height: 5),
              if (meter)
                MeterBar(r.sellThroughPercent != null
                    ? r.sellThroughPercent! / 100
                    : (top == 0 ? 0 : r.units / top)),
              const SizedBox(height: 4),
              Text(
                  '${fmtPaise(r.revenuePaise)} ${gt('revenue')} · ${fmtPaise(r.discountPaise)} ${gt('discount')}'
                  '${r.maxQty != null ? ' · ${r.units}/${r.maxQty} (${_pct(r.sellThroughPercent ?? 0)})' : ''}',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  )),
            ],
          ),
        ),
    ]);
  }

  // ---- one sale -------------------------------------------------------------

  Widget _saleBody(FlashSaleReport r) {
    final kpis = _commonKpis(
      units: r.unitsSold,
      revenue: r.revenuePaise,
      discount: r.discountPaise,
      avg: r.avgDiscountPercent,
      orders: r.orders,
      bills: r.bills,
      customers: r.customers,
    );
    if (r.sellThroughPercent != null) {
      kpis.add(('box', 'Sell-through', _pct(r.sellThroughPercent!),
          AppColors.navy, AppColors.navyTint));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('${flashWhen(r.startsAt)} -> ${flashWhen(r.endsAt)}',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                )),
          ),
          flashStatusPill(r.status),
        ]),
        const SizedBox(height: 12),
        _kpis(kpis),
        const SizedBox(height: 12),
        CardPanel(title: gt('Sold per product'), child: _itemRows(r.byItem)),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('By channel'),
          child: Column(children: [
            for (final c in r.byChannel)
              FlashKv(
                  c.channel == 'POS' ? 'Counter' : 'Online',
                  '${c.units} ${gt('units')} · ${fmtPaise(c.revenuePaise)} · ${fmtPaise(c.discountPaise)} ${gt('discount')}'),
          ]),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('By hour (India time)'),
          child: r.byHour.isEmpty
              ? Hint(gt('Nothing sold yet.'))
              : Column(children: [
                  for (final h in r.byHour)
                    FlashKv(h.hour,
                        '${h.units} ${gt('units')} · ${fmtPaise(h.revenuePaise)}'),
                ]),
        ),
      ],
    );
  }

  // ---- period ---------------------------------------------------------------

  Widget _periodBody(FlashPeriodReport r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: SelectField(
              label: 'From',
              value: _dateKey(_from),
              onTap: () => _pickDate(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectField(
              label: 'To',
              value: _dateKey(_to),
              onTap: () => _pickDate(false),
            ),
          ),
        ]),
        if (_rangeError != null) FlashNote(_rangeError!, error: true),
        const SizedBox(height: 12),
        _kpis([
          ('bolt', 'Sales', '${r.sales}', AppColors.red, AppColors.redTint),
          ..._commonKpis(
            units: r.unitsSold,
            revenue: r.revenuePaise,
            discount: r.discountPaise,
            avg: r.avgDiscountPercent,
            orders: r.orders,
            bills: r.bills,
            customers: r.customers,
          ),
        ]),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Sales in this period'),
          child: r.bySale.isEmpty
              ? Hint(gt('No flash sale started in these dates.'))
              : Column(children: [
                  for (final s in r.bySale)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => go('/admin/flash-sales?report=${s.saleId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.uiFont,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      )),
                                  Text(
                                      '${s.unitsSold} ${gt('units')} · ${fmtPaise(s.revenuePaise)} · ${s.customers} ${gt('customers')}',
                                      style: const TextStyle(
                                        fontFamily: AppTheme.uiFont,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink3,
                                      )),
                                ],
                              ),
                            ),
                            flashStatusPill(s.status),
                          ],
                        ),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 12),
        CardPanel(
            title: gt('Best products'), child: _itemRows(r.bestItems, meter: true)),
      ],
    );
  }
}
