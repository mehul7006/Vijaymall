import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto.dart' show StaffViewDto;
import '../../data/ist.dart';
import '../../nav/nav.dart';
import '../../state/app_state.dart' show money;
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import 'admin_period_range.dart';

/// `#/admin/counter?tab=` - the back-office side of the counter (doc 30):
/// cash-drawer shifts, loss-prevention report, low stock, audit log, payment
/// problems, returned goods awaiting review, offline-sync status and the
/// manager approval PIN. Mostly read-only; ADMIN only on the backend.
class AdminCounterDeskScreen extends StatefulWidget {
  const AdminCounterDeskScreen({super.key, this.tab = 'shifts'});

  final String tab;

  @override
  State<AdminCounterDeskScreen> createState() => _AdminCounterDeskScreenState();
}

const _tabs = {
  'shifts': 'Shifts',
  'controls': 'Counter controls',
  'low': 'Low stock',
  'audit': 'Audit log',
  'anomalies': 'Payment problems',
  'offline': 'Offline bills',
  'defective': 'Returned goods',
  'sync': 'Sync & PIN',
};

TextStyle _t(double size, FontWeight w, Color c) => TextStyle(
    fontFamily: AppTheme.uiFont, fontSize: size, fontWeight: w, color: c);

/// Backend error codes this screen can meet, mapped to translatable copy.
const _codeText = {
  'ALREADY_REVIEWED': 'This exception was already reviewed.',
  'DEFECTIVE_ALREADY_REVIEWED': 'This batch was already reviewed.',
  'DEFECTIVE_NOT_HELD':
      'This batch is not waiting for a final decision (already decided or still under review).',
  'DEFECTIVE_SELF_REVIEW':
      'You took this return yourself. Another person or the admin must confirm it as defective.',
};

String _err(Object e) {
  if (e is ApiException) {
    final mapped = _codeText[e.code];
    if (mapped != null) return gt(mapped);
    if (e.fields.isNotEmpty) return e.fields.values.map(gt).join(' ');
    return gt(e.message);
  }
  return gt('Something went wrong. Please try again.');
}

String _rs(num? paise) => money((paise ?? 0) / 100);

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String _at(dynamic iso) {
  final d = parseIst(iso?.toString());
  if (d == null) return '-';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}

List<Map<String, dynamic>> _items(Map<String, dynamic> page) =>
    (page['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

class _AdminCounterDeskScreenState extends State<AdminCounterDeskScreen> {
  late String _tab = _tabs.containsKey(widget.tab) ? widget.tab : 'shifts';

  @override
  void didUpdateWidget(covariant AdminCounterDeskScreen old) {
    super.didUpdateWidget(old);
    // Deep link to another tab while the desk is already open.
    if (old.tab != widget.tab) {
      _tab = _tabs.containsKey(widget.tab) ? widget.tab : 'shifts';
    }
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
                AdminHead(
                  title: gt('Counter desk'),
                  sub: gt('Shifts, controls, stock, audit and payment checks'),
                  bell: false,
                  onBack: () => go('/admin/more'),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final e in _tabs.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(gt(e.value)),
                            selected: _tab == e.key,
                            onSelected: (_) => setState(() => _tab = e.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ScreenScroll(
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: switch (_tab) {
                        'controls' => const _ControlsTab(),
                        'low' => const _LowTab(),
                        'audit' => const _AuditTab(),
                        'anomalies' => const _AnomaliesTab(),
                        'offline' => const _OfflineTab(),
                        'defective' => const _DefectiveTab(),
                        'sync' => const _SyncTab(),
                        _ => const _ShiftsTab(),
                      },
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
}

// ---------------------------------------------------------------------------
// Shared loader: one future, loading / error / empty / data states.
// ---------------------------------------------------------------------------

class _Loader<T> extends StatefulWidget {
  const _Loader({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyTitle = 'Nothing here',
    this.emptyCopy = 'No records yet.',
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  final bool Function(T)? isEmpty;
  final String emptyTitle;
  final String emptyCopy;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.load();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const SkeletonRows(rows: 5);
    if (_error != null) {
      return ErrorRetry(message: _error!, onRetry: _run);
    }
    final d = _data as T;
    if (widget.isEmpty?.call(d) ?? false) {
      return EmptyState(title: widget.emptyTitle, copy: widget.emptyCopy);
    }
    return widget.builder(context, d, _run);
  }
}

Widget _row(List<Widget> cells, {bool last = false}) => TableRowShell(
      last: last,
      child: Row(children: cells),
    );

Widget _cell(String text, int flex,
        {TextAlign align = TextAlign.left, Color? color, bool bold = false}) =>
    Expanded(
      flex: flex,
      child: Text(text,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _t(12.5, bold ? FontWeight.w800 : FontWeight.w600,
              color ?? AppColors.ink)),
    );

Widget _stats(List<(String, String, String)> tiles) => IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        StatTile(icon: tiles[i].$1, value: tiles[i].$2, label: tiles[i].$3),
      ],
    ]));

Widget _pager(int page, bool hasMore, void Function(int) go) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppButton('Previous',
              variant: BtnVariant.secondary,
              size: BtnSize.sm,
              onTap: page > 0 ? () => go(page - 1) : null),
          const SizedBox(width: 10),
          Text('${gt('Page')} ${page + 1}', style: _t(12.5, FontWeight.w700, AppColors.ink2)),
          const SizedBox(width: 10),
          AppButton('Next',
              variant: BtnVariant.secondary,
              size: BtnSize.sm,
              onTap: hasMore ? () => go(page + 1) : null),
        ],
      ),
    );

/// "1,234" or "10,000+" when the server capped the total (`totalExact` false).
String _total(Map<String, dynamic> d) {
  final n = _i(d['total']);
  return d['totalExact'] == false ? '${money(n)}+' : '$n';
}

/// Cashier roster for the filter chips (`GET /admin/staff`); empty on error.
Future<List<StaffViewDto>> _staff() async {
  try {
    return await Api.instance.admin.listStaff();
  } catch (_) {
    return const [];
  }
}

String _staffName(StaffViewDto s) =>
    (s.name ?? '').trim().isNotEmpty ? s.name!.trim() : (s.email ?? '-');

/// Chips "All cashiers" + one per cashier; [onPick] gets the id or null.
Widget _cashierChips(
        List<StaffViewDto> staff, String? picked, ValueChanged<String?> onPick) =>
    staff.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChipRail(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppChip(gt('All cashiers'),
                    small: true,
                    selected: picked == null,
                    onTap: () => onPick(null)),
              ),
              for (final st in staff)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(_staffName(st),
                      small: true,
                      selected: picked == st.id,
                      onTap: () => onPick(st.id)),
                ),
            ]),
          );

// ---------------------------------------------------------------------------
// Shifts (GET /admin/pos/shifts)
// ---------------------------------------------------------------------------

class _ShiftsTab extends StatefulWidget {
  const _ShiftsTab();
  @override
  State<_ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<_ShiftsTab> {
  int _page = 0;
  String? _cashier;
  List<StaffViewDto> _team = const [];

  @override
  void initState() {
    super.initState();
    _staff().then((v) {
      if (mounted) setState(() => _team = v);
    });
  }

  String _who(dynamic id) {
    for (final st in _team) {
      if (st.id == id) return _staffName(st);
    }
    return '';
  }

  String _opened(Map<String, dynamic> r) {
    final who = _who(r['cashierId']);
    final note = (r['note'] ?? '').toString();
    return '${_at(r['openedAt'])}'
        '${who.isEmpty ? '' : '\n$who'}'
        '${r['open'] == true ? '\n${gt('OPEN')}' : r['closedAt'] != null ? '\n${gt('Closed')} ${_at(r['closedAt'])}' : ''}'
        '${note.isEmpty ? '' : '\n$note'}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _cashierChips(
          _team,
          _cashier,
          (v) => setState(() {
                _cashier = v;
                _page = 0;
              })),
      _Loader<Map<String, dynamic>>(
        key: ValueKey('$_cashier|$_page'),
        load: () =>
            Api.instance.admin.listPosShifts(cashierId: _cashier, page: _page),
        isEmpty: (d) => _items(d).isEmpty && _page == 0,
        emptyTitle: 'No shifts yet',
        emptyCopy: 'Cash-drawer shifts opened at the till appear here.',
        builder: (ctx, d, _) {
          final rows = _items(d);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ResultSummary('${_total(d)} ${gt('shifts')}'),
            const SizedBox(height: 8),
            CardPanel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                const TableHeadRow([
                  TableCol('Opened', 4),
                  TableCol('Float', 2, align: TextAlign.right),
                  TableCol('Expected', 2, align: TextAlign.right),
                  TableCol('Counted', 2, align: TextAlign.right),
                  TableCol('Variance', 2, align: TextAlign.right),
                ]),
                for (var i = 0; i < rows.length; i++)
                  _row([
                    _cell(_opened(rows[i]), 4),
                    _cell(_rs(rows[i]['openingFloatPaise'] as num?), 2,
                        align: TextAlign.right),
                    _cell(
                        rows[i]['expectedCashPaise'] == null
                            ? '-'
                            : _rs(rows[i]['expectedCashPaise'] as num?),
                        2,
                        align: TextAlign.right),
                    _cell(
                        rows[i]['countedCashPaise'] == null
                            ? '-'
                            : _rs(rows[i]['countedCashPaise'] as num?),
                        2,
                        align: TextAlign.right),
                    _cell(
                        rows[i]['variancePaise'] == null
                            ? '-'
                            : _rs(rows[i]['variancePaise'] as num?),
                        2,
                        align: TextAlign.right,
                        bold: true,
                        color: _i(rows[i]['variancePaise']) < 0
                            ? AppColors.red
                            : AppColors.ink),
                  ], last: i == rows.length - 1),
              ]),
            ),
            _pager(_page, d['hasMore'] == true,
                (p) => setState(() => _page = p)),
          ]);
        },
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Counter controls (GET /admin/reports/counter-controls)
// ---------------------------------------------------------------------------

class _ControlsTab extends StatefulWidget {
  const _ControlsTab();
  @override
  State<_ControlsTab> createState() => _ControlsTabState();
}

class _ControlsTabState extends State<_ControlsTab> {
  PeriodSel _sel = const PeriodSel('week');
  Map<String, String> _srvErr = const {};

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PeriodRangePicker(
        value: _sel,
        serverErrors: _srvErr,
        chipLabels: const {
          'week': '7 days',
          'month': '30 days',
          'quarter': '90 days'
        },
        onChanged: (v) => setState(() {
          _sel = v;
          _srvErr = const {};
        }),
      ),
      const SizedBox(height: 10),
      _Loader<Map<String, dynamic>>(
        key: ValueKey(_sel),
        load: () async {
          try {
            return await Api.instance.admin.counterControls(
                period: _sel.apiPeriod, from: _sel.apiFrom, to: _sel.apiTo);
          } on ApiException catch (e) {
            if (e.fields.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _srvErr = e.fields);
              });
            }
            rethrow;
          }
        },
        isEmpty: (d) => (d['cashiers'] as List? ?? []).isEmpty,
        emptyTitle: 'No counter activity',
        emptyCopy: 'No sales, returns or closed shifts in this period.',
        builder: (ctx, d, _) {
          final rows = (d['cashiers'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          var sales = 0, disc = 0, refunds = 0, variance = 0;
          for (final r in rows) {
            sales += _i(r['salesPaise']);
            disc += _i(r['manualDiscountPaise']);
            refunds += _i(r['refundsPaise']);
            variance += _i(r['shiftVariancePaise']);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResultSummary('${d['from']} ${gt('to')} ${d['to']}'),
                const SizedBox(height: 8),
                _stats([
                  ('chart', _rs(sales), 'Sales'),
                  ('ticket', _rs(disc), 'Manual discounts'),
                ]),
                const SizedBox(height: 8),
                _stats([
                  ('coin', _rs(refunds), 'Refunds'),
                  ('clock', _rs(variance), 'Drawer variance'),
                ]),
                const SizedBox(height: 12),
                CardPanel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    const TableHeadRow([
                      TableCol('Cashier', 3),
                      TableCol('Sales', 2, align: TextAlign.right),
                      TableCol('Discounts', 2, align: TextAlign.right),
                      TableCol('Returns', 2, align: TextAlign.right),
                      TableCol('Drawer', 2, align: TextAlign.right),
                    ]),
                    for (var i = 0; i < rows.length; i++)
                      _row([
                        _cell('${rows[i]['name'] ?? '?'}\n${_i(rows[i]['bills'])} ${gt('bills')}',
                            3),
                        _cell(_rs(rows[i]['salesPaise'] as num?), 2,
                            align: TextAlign.right),
                        _cell(
                            '${_i(rows[i]['manualDiscounts'])} x ${_rs(rows[i]['manualDiscountPaise'] as num?)}\n${rows[i]['discountPercentOfSales'] ?? 0}%',
                            2,
                            align: TextAlign.right),
                        _cell(
                            '${_i(rows[i]['returns'])} x ${_rs(rows[i]['refundsPaise'] as num?)}\n${rows[i]['refundPercentOfSales'] ?? 0}%',
                            2,
                            align: TextAlign.right),
                        _cell(
                            '${_rs(rows[i]['shiftVariancePaise'] as num?)}\n${_i(rows[i]['shiftsClosed'])} ${gt('shifts')}',
                            2,
                            align: TextAlign.right,
                            bold: true,
                            color: _i(rows[i]['shiftVariancePaise']) < 0
                                ? AppColors.red
                                : AppColors.ink),
                      ], last: i == rows.length - 1),
                  ]),
                ),
              ]);
        },
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Low stock (GET /admin/stock/low)
// ---------------------------------------------------------------------------

class _LowTab extends StatefulWidget {
  const _LowTab();
  @override
  State<_LowTab> createState() => _LowTabState();
}

class _LowTabState extends State<_LowTab> {
  /// `GET /admin/stock/low?limit=` (1..200, no paging).
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChipRail(children: [
        for (final n in const [50, 100, 200])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip('${gt('Show')} $n',
                small: true,
                selected: _limit == n,
                onTap: () => setState(() => _limit = n)),
          ),
      ]),
      const SizedBox(height: 10),
      _Loader<List<Map<String, dynamic>>>(
        key: ValueKey(_limit),
        load: () => Api.instance.admin.lowStock(limit: _limit),
        isEmpty: (d) => d.isEmpty,
        emptyTitle: 'Nothing to reorder',
        emptyCopy: 'No active product is at or below its stock alert level.',
        builder: (ctx, rows, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResultSummary(
                  '${rows.length} ${gt('products at or below their alert level, emptiest first')}'),
              if (rows.length >= _limit)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      _limit >= 200
                          ? gt('Only the 200 emptiest products can be listed. Restock these first, then reopen the list.')
                          : gt('There may be more. Choose a larger number above.'),
                      style: _t(12, FontWeight.w700, AppColors.goldInk)),
                ),
              const SizedBox(height: 8),
              CardPanel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  const TableHeadRow([
                    TableCol('Product', 6),
                    TableCol('On hand', 2, align: TextAlign.right),
                  ]),
                  for (var i = 0; i < rows.length; i++)
                    _row([
                      _cell('${rows[i]['name'] ?? '-'}', 6),
                      _cell('${_i(rows[i]['qty'])}', 2,
                          align: TextAlign.right,
                          bold: true,
                          color: _i(rows[i]['qty']) <= 0
                              ? AppColors.red
                              : AppColors.ink),
                    ], last: i == rows.length - 1),
                ]),
              ),
            ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Audit log (GET /admin/audit-log)
// ---------------------------------------------------------------------------

class _AuditTab extends StatefulWidget {
  const _AuditTab();
  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  final _action = TextEditingController();
  final _entity = TextEditingController();
  final _entityId = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  String? _actorId;
  List<StaffViewDto> _team = const [];

  /// The filters currently applied (set by Filter, not on every keystroke).
  Map<String, String> _applied = const {};
  Map<String, String> _errors = const {};
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _staff().then((v) {
      if (mounted) setState(() => _team = v);
    });
  }

  @override
  void dispose() {
    _action.dispose();
    _entity.dispose();
    _entityId.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _apply() {
    // from/to: both given -> at most 93 days; either alone is fine.
    final e = validateDayRange(_from.text, _to.text,
        maxDays: 93, fromRequired: false);
    final bothGiven = _from.text.trim().isNotEmpty && _to.text.trim().isNotEmpty;
    if (!bothGiven) e.remove('range');
    setState(() => _errors = e);
    if (e.isNotEmpty) return;
    setState(() {
      _applied = {
        if ((_actorId ?? '').isNotEmpty) 'actorId': _actorId!,
        if (_action.text.trim().isNotEmpty) 'action': _action.text.trim(),
        if (_entity.text.trim().isNotEmpty) 'entity': _entity.text.trim(),
        if (_entityId.text.trim().isNotEmpty) 'entityId': _entityId.text.trim(),
        if (_from.text.trim().isNotEmpty) 'from': _from.text.trim(),
        if (_to.text.trim().isNotEmpty) 'to': _to.text.trim(),
      };
      _page = 0;
    });
  }

  void _clear() {
    for (final c in [_action, _entity, _entityId, _from, _to]) {
      c.clear();
    }
    setState(() {
      _actorId = null;
      _applied = const {};
      _errors = const {};
      _page = 0;
    });
  }

  String? _e(String k) => _errors[k] == null ? null : gt(_errors[k]!);

  @override
  Widget build(BuildContext context) {
    final any = _applied.isNotEmpty ||
        [_action, _entity, _entityId, _from, _to]
            .any((c) => c.text.trim().isNotEmpty) ||
        _actorId != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _cashierChips(_team, _actorId, (v) => setState(() => _actorId = v)),
      FieldRow(children: [
        AppField(
          label: 'Action',
          controller: _action,
          uppercase: true,
          placeholder: 'e.g. SALE, RETURN, STOCK_TAKE',
          onEditingComplete: _apply,
        ),
        AppField(
          label: 'Record kind',
          controller: _entity,
          placeholder: 'e.g. pos_sale, purchase',
          onEditingComplete: _apply,
        ),
      ]),
      const SizedBox(height: 10),
      AppField(
        label: 'Record id (optional)',
        controller: _entityId,
        placeholder: 'Paste the id of a bill, shift, purchase...',
        onEditingComplete: _apply,
      ),
      const SizedBox(height: 10),
      FieldRow(children: [
        AppField(
          label: 'From (yyyy-MM-dd)',
          controller: _from,
          maxLength: 10,
          error: _e('from'),
          onEditingComplete: _apply,
        ),
        AppField(
          label: 'To (yyyy-MM-dd)',
          controller: _to,
          maxLength: 10,
          error: _e('to'),
          onEditingComplete: _apply,
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(gt('With both dates the range is limited to 93 days.'),
            style: _t(11, FontWeight.w600, AppColors.ink3)),
      ),
      const SizedBox(height: 8),
      Row(children: [
        AppButton('Filter', onTap: _apply),
        if (any) ...[
          const SizedBox(width: 8),
          AppButton('Clear', variant: BtnVariant.secondary, onTap: _clear),
        ],
      ]),
      const SizedBox(height: 10),
      _Loader<Map<String, dynamic>>(
        key: ValueKey('${_applied.entries.map((e) => '${e.key}=${e.value}').join('&')}|$_page'),
        load: () => Api.instance.admin.auditLog(
            actorId: _applied['actorId'],
            action: _applied['action'],
            entity: _applied['entity'],
            entityId: _applied['entityId'],
            from: _applied['from'],
            to: _applied['to'],
            page: _page),
        isEmpty: (d) => _items(d).isEmpty && _page == 0,
        emptyTitle: 'No audit entries',
        emptyCopy: 'Nothing matches that filter.',
        builder: (ctx, d, _) {
          final rows = _items(d);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResultSummary('${_total(d)} ${gt('entries, newest first')}'),
                const SizedBox(height: 8),
                CardPanel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    const TableHeadRow([
                      TableCol('When', 3),
                      TableCol('Who', 2),
                      TableCol('Action', 2),
                      TableCol('Change', 4),
                    ]),
                    for (var i = 0; i < rows.length; i++)
                      _row([
                        _cell(_at(rows[i]['at']), 3),
                        _cell('${rows[i]['actorName'] ?? gt('System')}', 2),
                        _cell('${rows[i]['action'] ?? ''}\n${rows[i]['entity'] ?? ''}',
                            2,
                            bold: true),
                        _cell('${rows[i]['change'] ?? ''}', 4),
                      ], last: i == rows.length - 1),
                  ]),
                ),
                _pager(_page, d['hasMore'] == true,
                    (p) => setState(() => _page = p)),
              ]);
        },
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Payment anomalies (GET /admin/payments/anomalies)
// ---------------------------------------------------------------------------

class _AnomaliesTab extends StatefulWidget {
  const _AnomaliesTab();
  @override
  State<_AnomaliesTab> createState() => _AnomaliesTabState();
}

class _AnomaliesTabState extends State<_AnomaliesTab> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return _Loader<Map<String, dynamic>>(
      key: ValueKey(_page),
      load: () => Api.instance.admin.paymentAnomalies(page: _page),
      isEmpty: (d) => _items(d).isEmpty && _page == 0,
      emptyTitle: 'No payment problems',
      emptyCopy: 'Wrong-amount and duplicate online payments are listed here.',
      builder: (ctx, d, _) {
        final rows = _items(d);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ResultSummary('${_total(d)} ${gt('payment problems')}'),
          const SizedBox(height: 8),
          CardPanel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              const TableHeadRow([
                TableCol('When', 3),
                TableCol('Kind', 2),
                TableCol('Expected', 2, align: TextAlign.right),
                TableCol('Received', 2, align: TextAlign.right),
              ]),
              for (var i = 0; i < rows.length; i++)
                _row([
                  _cell('${_at(rows[i]['createdAt'])}\n${rows[i]['providerRef'] ?? ''}',
                      3),
                  _cell('${rows[i]['kind'] ?? ''}', 2, bold: true),
                  _cell(_rs(rows[i]['expectedPaise'] as num?), 2,
                      align: TextAlign.right),
                  _cell(_rs(rows[i]['receivedPaise'] as num?), 2,
                      align: TextAlign.right, color: AppColors.red, bold: true),
                ], last: i == rows.length - 1),
            ]),
          ),
          _pager(_page, d['hasMore'] == true, (p) => setState(() => _page = p)),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Returned goods to check (GET /pos/stock/defective, POST .../review)
// ---------------------------------------------------------------------------

class _DefectiveTab extends StatefulWidget {
  const _DefectiveTab();
  @override
  State<_DefectiveTab> createState() => _DefectiveTabState();
}

class _DefectiveTabState extends State<_DefectiveTab> {
  String _status = 'PENDING_REVIEW';
  int _page = 0;
  int _nonce = 0;
  String? _busy;
  String? _productId;
  String _productName = '';

  Future<void> _review(String id, String decision) async {
    final note = await _askNote(
        context,
        decision == 'RESTOCK'
            ? 'Put these goods back on sale?'
            : 'Confirm these goods as defective?',
        'Note (optional)',
        200);
    if (note == null || !mounted) return;
    setState(() => _busy = id);
    try {
      await Api.instance.pos.reviewDefective(id, decision, note: note);
      showToast(gt(decision == 'RESTOCK' ? 'Put back on sale' : 'Marked defective'));
      _nonce++;
    } on ApiException catch (e) {
      showToast(_err(e), 'error');
      if (e.statusCode == 409) _nonce++;
    } catch (_) {
      showToast(gt('Could not save the review'), 'error');
    }
    if (mounted) setState(() => _busy = null);
  }

  /// Admin's final decision on a confirmed-defective (HELD) batch.
  Future<void> _resolve(String id, String action) async {
    final note = await _askNote(
        context,
        action == 'WRITE_OFF'
            ? 'Write off these goods?'
            : 'Return these goods to the supplier?',
        'Note (optional)',
        200);
    if (note == null || !mounted) return;
    setState(() => _busy = id);
    try {
      await Api.instance.admin.resolveDefective(id, action, note: note);
      showToast(gt(action == 'WRITE_OFF'
          ? 'Written off'
          : 'Marked as returned to supplier'));
      _nonce++;
    } on ApiException catch (e) {
      showToast(_err(e), 'error');
      if (e.statusCode == 409) _nonce++;
    } catch (_) {
      showToast(gt('Could not save the decision'), 'error');
    }
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Loader<List<Map<String, dynamic>>>(
        key: ValueKey('sum|$_nonce'),
        load: () => Api.instance.admin.defectiveSummary(),
        builder: (ctx, rows, _) {
          if (rows.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardPanel(
              title: gt('Open by product'),
              child: Column(children: [
                for (final r in rows.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                          child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _productId = '${r['productId']}';
                          _productName = '${r['productName'] ?? ''}';
                          _page = 0;
                        }),
                        child: Text('${r['productName'] ?? '-'}',
                            style: _t(13, FontWeight.w700, AppColors.ink)),
                      )),
                      Text(
                          '${gt('Defective')} ${_i(r['heldQty'])} - '
                          '${gt('To check')} ${_i(r['pendingReviewQty'])}',
                          style: _t(12, FontWeight.w700, AppColors.ink2)),
                    ]),
                  ),
              ]),
            ),
          );
        },
      ),
      if (_productId != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
                child: Text('${gt('Product')}: $_productName',
                    style: _t(12.5, FontWeight.w800, AppColors.ink2))),
            AppButton('Clear',
                variant: BtnVariant.secondary,
                size: BtnSize.sm,
                onTap: () => setState(() {
                      _productId = null;
                      _page = 0;
                    })),
          ]),
        ),
      ChipRail(children: [
        for (final s in const [
          'ALL',
          'PENDING_REVIEW',
          'HELD',
          'RESTOCKED',
          'WRITTEN_OFF',
          'RETURNED_TO_SUPPLIER'
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip(gt(_statusLabel(s)),
                small: true,
                selected: _status == s,
                onTap: () => setState(() {
                      _status = s;
                      _page = 0;
                    })),
          ),
      ]),
      const SizedBox(height: 10),
      _Loader<Map<String, dynamic>>(
        key: ValueKey('$_status|$_page|$_nonce|$_productId'),
        load: () => Api.instance.admin.defectiveReport(
            status: _status == 'ALL' ? null : _status,
            productId: _productId,
            page: _page),
        isEmpty: (d) => _items(d).isEmpty && _page == 0,
        emptyTitle: gt('Nothing waiting'),
        emptyCopy: gt('No returned goods with this status.'),
        builder: (ctx, d, _) {
          final rows = _items(d);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CardPanel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r['productName'] ?? '-'} x ${_i(r['qty'])}',
                                style: _t(14, FontWeight.w800, AppColors.ink)),
                            const SizedBox(height: 3),
                            Text(
                                '${gt(_sourceLabel('${r['source'] ?? ''}'))} - ${_at(r['createdAt'])}'
                                ' - ${gt(_statusLabel('${r['status'] ?? ''}'))}'
                                '${(r['note'] ?? '').toString().isEmpty ? '' : '\n${gt('Reason')}: ${r['note']}'}'
                                '${(r['reviewNote'] ?? '').toString().isEmpty ? '' : '\n${gt('Review note')}: ${r['reviewNote']}'}'
                                '${(r['resolveNote'] ?? '').toString().isEmpty ? '' : '\n${gt('Decision note')}: ${r['resolveNote']}'}',
                                style: _t(12, FontWeight.w600, AppColors.ink3)),
                            if (r['status'] == 'HELD') ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: AppButton('Write off',
                                      variant: BtnVariant.danger,
                                      size: BtnSize.sm,
                                      block: true,
                                      onTap: _busy != null
                                          ? null
                                          : () => _resolve(
                                              '${r['id']}', 'WRITE_OFF')),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppButton('Return to supplier',
                                      variant: BtnVariant.secondary,
                                      size: BtnSize.sm,
                                      block: true,
                                      onTap: _busy != null
                                          ? null
                                          : () => _resolve('${r['id']}',
                                              'RETURN_TO_SUPPLIER')),
                                ),
                              ]),
                            ],
                            if (r['status'] == 'PENDING_REVIEW') ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: AppButton('Defective',
                                      variant: BtnVariant.danger,
                                      size: BtnSize.sm,
                                      block: true,
                                      onTap: _busy != null
                                          ? null
                                          : () => _review('${r['id']}',
                                              'CONFIRM_DEFECTIVE')),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppButton('Fine, put on sale',
                                      variant: BtnVariant.secondary,
                                      size: BtnSize.sm,
                                      block: true,
                                      onTap: _busy != null
                                          ? null
                                          : () => _review('${r['id']}', 'RESTOCK')),
                                ),
                              ]),
                            ],
                          ]),
                    ),
                  ),
                _pager(_page, d['hasMore'] == true,
                    (p) => setState(() => _page = p)),
              ]);
        },
      ),
    ]);
  }
}

String _statusLabel(String s) => switch (s) {
      'ALL' => 'All',
      'PENDING_REVIEW' => 'Pending review',
      'HELD' => 'Confirmed defective',
      'RESTOCKED' => 'Restocked',
      'WRITTEN_OFF' => 'Written off',
      'RETURNED_TO_SUPPLIER' => 'Returned to supplier',
      _ => s,
    };

String _sourceLabel(String s) => switch (s) {
      'ORDER_RETURN' => 'Online order return',
      'POS_RETURN' => 'Counter return',
      _ => s,
    };

/// Small dialog asking for an optional note; null = cancelled.
Future<String?> _askNote(
    BuildContext context, String title, String hint, int max) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(gt(title), style: _t(16, FontWeight.w800, AppColors.ink)),
      content: TextField(
        controller: c,
        maxLength: max,
        decoration: InputDecoration(hintText: gt(hint)),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(gt('Cancel'))),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: Text(gt('Confirm'))),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Offline bill exceptions (GET /admin/pos/offline-exceptions, POST .../review)
// ---------------------------------------------------------------------------

class _OfflineTab extends StatefulWidget {
  const _OfflineTab();
  @override
  State<_OfflineTab> createState() => _OfflineTabState();
}

class _OfflineTabState extends State<_OfflineTab> {
  String _status = 'OPEN';
  int _page = 0;
  int _nonce = 0;
  String? _busy;

  static String _kind(String k) => switch (k) {
        'OVERSOLD' => 'Oversold (shelf had less)',
        'DISCOUNT' => 'Discount not checked',
        'PRICE_CHANGED' => 'Price differs from catalog',
        'GST_CHANGED' => 'GST rate differs',
        'PRODUCT_INACTIVE' => 'Product was inactive',
        _ => k,
      };

  /// expected / actual are paise for prices and discounts, percent for GST,
  /// units for stock.
  static String _val(String kind, dynamic v) {
    if (v == null || '$v'.isEmpty) return '-';
    final n = num.tryParse('$v');
    if (n == null) return '$v';
    return switch (kind) {
      'PRICE_CHANGED' || 'DISCOUNT' => _rs(n),
      'GST_CHANGED' => '$n%',
      _ => '$n',
    };
  }

  Future<void> _review(String id) async {
    final note = await _askNote(
        context, 'Mark this exception as reviewed?', 'Note (optional)', 500);
    if (note == null || !mounted) return;
    setState(() => _busy = id);
    try {
      await Api.instance.admin.reviewOfflineException(id, note: note);
      showToast(gt('Marked as reviewed'));
      _nonce++;
    } on ApiException catch (e) {
      showToast(_err(e), 'error');
      if (e.statusCode == 409) _nonce++;
    } catch (_) {
      showToast(gt('Could not save the review'), 'error');
    }
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChipRail(children: [
        for (final s in const ['OPEN', 'REVIEWED'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip(gt(s == 'OPEN' ? 'To review' : 'Reviewed'),
                small: true,
                selected: _status == s,
                onTap: () => setState(() {
                      _status = s;
                      _page = 0;
                    })),
          ),
      ]),
      const SizedBox(height: 10),
      _Loader<Map<String, dynamic>>(
        key: ValueKey('$_status|$_page|$_nonce'),
        load: () =>
            Api.instance.admin.offlineExceptions(status: _status, page: _page),
        isEmpty: (d) => _items(d).isEmpty && _page == 0,
        emptyTitle: gt('Nothing to review'),
        emptyCopy: gt(
            'Offline bills whose price, GST, discount or stock differed from the server are listed here.'),
        builder: (ctx, d, _) {
          final rows = _items(d);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ResultSummary('${_total(d)} ${gt('exceptions')}'),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CardPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(gt(_kind('${r['kind'] ?? ''}')),
                                style: _t(14, FontWeight.w800, AppColors.red)),
                          ),
                          Text('${r['invoiceNo'] ?? ''}',
                              style: _t(12.5, FontWeight.w800, AppColors.ink)),
                        ]),
                        const SizedBox(height: 3),
                        if ((r['productName'] ?? '').toString().isNotEmpty)
                          Text('${r['productName']}',
                              style: _t(13, FontWeight.w700, AppColors.ink)),
                        Text(
                            '${gt('Expected')}: ${_val('${r['kind']}', r['expected'])}'
                            '  ${gt('Till had')}: ${_val('${r['kind']}', r['actual'])}',
                            style: _t(12.5, FontWeight.w700, AppColors.ink2)),
                        if ((r['detail'] ?? '').toString().isNotEmpty)
                          Text('${r['detail']}',
                              style: _t(12, FontWeight.w600, AppColors.ink3)),
                        Text(
                            '${gt('Cashier')}: ${r['cashierName'] ?? '-'} - '
                            '${gt('Sold')} ${_at(r['soldAt'])}',
                            style: _t(12, FontWeight.w600, AppColors.ink3)),
                        if (r['reviewedAt'] != null)
                          Text(
                              '${gt('Reviewed')} ${_at(r['reviewedAt'])}'
                              '${(r['reviewNote'] ?? '').toString().isEmpty ? '' : ' - ${r['reviewNote']}'}',
                              style: _t(12, FontWeight.w600, AppColors.ink2)),
                        if (r['reviewedAt'] == null) ...[
                          const SizedBox(height: 10),
                          AppButton('Review',
                              size: BtnSize.sm,
                              block: true,
                              loading: _busy == '${r['id']}',
                              onTap: _busy != null
                                  ? null
                                  : () => _review('${r['id']}')),
                        ],
                      ]),
                ),
              ),
            _pager(
                _page,
                d['hasMore'] == true || (_page + 1) * 20 < _i(d['total']),
                (p) => setState(() => _page = p)),
          ]);
        },
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Sync status + approval PIN
// ---------------------------------------------------------------------------

/// Minutes between this device's clock and the server's `serverTime`.
int _skewMinutes(dynamic serverTime) {
  final d = DateTime.tryParse('${serverTime ?? ''}');
  if (d == null) return 0;
  return DateTime.now().toUtc().difference(d.toUtc()).inMinutes.abs();
}

class _SyncTab extends StatefulWidget {
  const _SyncTab();
  @override
  State<_SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends State<_SyncTab> {
  final _pin = TextEditingController();
  String? _pinError;
  bool _saving = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pin.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _pinError = gt('Use 4 to 8 digits'));
      return;
    }
    setState(() {
      _saving = true;
      _pinError = null;
    });
    try {
      await Api.instance.admin.setApprovalPin(pin);
      _pin.clear();
      showToast(gt('Approval PIN saved'));
    } on ApiException catch (e) {
      setState(() => _pinError = gt(e.fields['pin'] ?? e.message));
    } catch (_) {
      setState(() => _pinError = gt('Could not save the PIN'));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardPanel(
        title: 'Offline sync status',
        child: _Loader<Map<String, dynamic>>(
          load: () => Api.instance.pos.syncStatus(),
          builder: (ctx, d, reload) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Server time', _at(d['serverTime'])),
                if (_skewMinutes(d['serverTime']) > 5)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                        gt('This computer clock differs from the server by several minutes. Offline bills can be refused until it is corrected.'),
                        style: _t(12, FontWeight.w700, AppColors.red)),
                  ),
                _kv('Catalog version', _at(d['catalogVersion'])),
                _kv('Offline bills accepted for', '${_i(d['maxOfflineDays'])} ${gt('days')}'),
                _kv('Bills per upload', '${_i(d['batchLimit'])}'),
                const SizedBox(height: 8),
                AppButton('Refresh',
                    variant: BtnVariant.secondary,
                    size: BtnSize.sm,
                    onTap: reload),
              ]),
        ),
      ),
      const SizedBox(height: 12),
      CardPanel(
        title: 'My manager approval PIN',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              gt('Cashiers type this PIN at the till to approve a manual discount '
                  'above their limit. It replaces your earlier PIN and is never shown again.'),
              style: _t(12, FontWeight.w600, AppColors.ink3)),
          const SizedBox(height: 10),
          FieldRow(children: [
            AppField(
              label: 'New PIN (4-8 digits)',
              controller: _pin,
              numeric: true,
              obscure: true,
              maxLength: 8,
              error: _pinError,
              onEditingComplete: _save,
            ),
            const SizedBox.shrink(),
          ]),
          const SizedBox(height: 10),
          AppButton('Save PIN', block: true, loading: _saving, onTap: _saving ? null : _save),
        ]),
      ),
    ]);
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(gt(k), style: _t(13, FontWeight.w600, AppColors.ink2))),
          Text(v, style: _t(13, FontWeight.w800, AppColors.ink)),
        ]),
      );
}
