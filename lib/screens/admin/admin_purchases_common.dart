import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart' show Api;
import '../../data/api/purchase_api.dart' show PurchaseApi;
import '../../data/api/purchase_dto.dart';
import '../../data/ist.dart';
import '../../data/purchase_file_view.dart';
import '../../data/purchase_store.dart';
import '../../nav/nav.dart';
import '../../state/app_state.dart' show money;
import '../../state/gu_purchases.dart' show guPurchasesDynamic;
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart' show Hint;
import '../../widgets/toast.dart';

// ---------------------------------------------------------------------------
// Money / dates
// ---------------------------------------------------------------------------

/// Whole paise as rupees text (`Rs 1,250.50`), exact.
String pRs(int paise) => money(paise / 100);

/// A fractional-paise amount (landed unit cost) as rupees. With more than two
/// [decimals] the extra digits show only when they are not zero
/// (`8333.3333` paise -> `83.3333`, `7750.0000` -> `77.50`).
String pRsD(double paise, {int decimals = 2}) {
  final r = paise / 100;
  if (decimals <= 2) return money(r);
  var t = r.abs().toStringAsFixed(decimals);
  final dot = t.indexOf('.');
  var end = t.length;
  while (end > dot + 3 && t[end - 1] == '0') {
    end--;
  }
  t = t.substring(0, end);
  final whole = money(int.parse(t.substring(0, dot)));
  return '${r < 0 ? '-' : ''}$whole${t.substring(dot)}';
}

/// `12.5` / `12` / `12.50` -> paise without floating point. null = invalid.
int? rsToPaise(String text) {
  final t = text.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + int.parse(frac.isEmpty ? '0' : frac);
}

String paiseToText(int paise) {
  final w = paise ~/ 100;
  final f = paise % 100;
  if (f == 0) return '$w';
  return '$w.${f.toString().padLeft(2, '0')}'.replaceFirst(RegExp(r'0$'), '');
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// `2026-11-09` (or an ISO instant) -> `9 Nov 2026`, in India time.
String pDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = iso.length > 10 ? parseIst(iso) : DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String todayYmd() => ymd(istNow());

Future<String?> pickYmd(BuildContext context, String? initial,
    {DateTime? first, DateTime? last}) async {
  final now = istNow();
  final init = DateTime.tryParse(initial ?? '') ?? DateTime(now.year, now.month, now.day);
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first ?? DateTime(now.year - 5),
    lastDate: last ?? DateTime(now.year + 5),
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.navy)),
      child: child!,
    ),
  );
  return d == null ? null : ymd(d);
}

/// [gt] plus the sentence patterns of the purchases module (validator
/// messages such as `Invoice no. must be 60 characters or fewer`).
String pgt(String en) {
  final hit = gt(en);
  if (!GuLang.active || hit != en) return hit;
  return guPurchasesDynamic(en, gt) ?? en;
}

/// Parameterised sentence: [template] has `{0}`, `{1}` placeholders and is
/// looked up in Gujarati as a whole, then filled in.
String pf(String template, List<Object?> args) {
  var s = pgt(template);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

String purchaseError(Object e) =>
    e is ApiException ? e.messageWithRef : gt('Could not reach the server. Please try again.');

// ---------------------------------------------------------------------------
// Page chrome
// ---------------------------------------------------------------------------

const pHead = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
    color: AppColors.ink);
const pSub = TextStyle(
    fontFamily: AppTheme.uiFont, fontSize: 11.5, color: AppColors.ink3);
const pBody = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.ink2);

/// Back to the previous screen, or to [fallback] on a fresh deep link.
void pBack([String fallback = '/admin/purchases']) {
  if (!Nav.instance.pop()) go(fallback);
}

class PurchasePage extends StatelessWidget {
  final String title, sub;
  final Widget child;
  final bool back;
  final Future<void> Function()? onRefresh;
  const PurchasePage({
    super.key,
    required this.title,
    required this.sub,
    required this.child,
    this.back = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            AdminHead(
                title: title,
                sub: sub,
                bell: false,
                onBack: back ? () => pBack() : null),
            ScreenScroll(onRefresh: onRefresh, child: child),
          ]),
          const AdminNav(active: 'more'),
        ]),
      ),
    );
  }
}

/// Label / value line.
class PKv extends StatelessWidget {
  final String k, v;
  final bool bold;
  final Color? color;
  const PKv(this.k, this.v, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(gt(k),
                  style: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12.5,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: bold ? AppColors.ink : AppColors.ink3))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: bold ? 14 : 12.5,
                    fontWeight: FontWeight.w800,
                    color: color ?? AppColors.ink)),
          ),
        ]),
      );
}

/// [Hint] with the Gujarati lookup applied.
class PHint extends StatelessWidget {
  final String text;
  const PHint(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Hint(gt(text));
}

class PNote extends StatelessWidget {
  final String text;
  final bool error;
  const PNote(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: error ? AppColors.red : AppColors.ink2)),
      );
}

/// Row of chips for a small closed choice.
class PChoice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool wrap;
  const PChoice(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged,
      this.wrap = true});

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final o in options)
        AppChip(gt(o.$2),
            small: true, selected: value == o.$1, onTap: () => onChanged(o.$1)),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

/// Paid / part paid / pending, plus Overdue and Supplier credit.
Widget payBadges(String status, bool overdue, int due) {
  final out = <Widget>[];
  switch (status.toUpperCase()) {
    case 'PAID':
      out.add(Pill.active(gt('Paid')));
      break;
    case 'PARTIAL':
      out.add(Pill.low(gt('Part paid')));
      break;
    default:
      out.add(Pill(
          label: gt('Pending'), bg: AppColors.orangeTint, fg: AppColors.orange));
  }
  if (overdue) out.add(Pill.out(gt('Overdue')));
  if (due < 0) {
    out.add(Pill(
        label: gt('Supplier credit'),
        bg: AppColors.navyTint,
        fg: AppColors.navy));
  }
  return Wrap(spacing: 6, runSpacing: 6, children: out);
}

String modeLabel(String m) {
  switch (m.toUpperCase()) {
    case 'CASH':
      return gt('Cash');
    case 'UPI':
      return gt('UPI');
    case 'CARD':
      return gt('Card');
    case 'BANK':
      return gt('Bank');
    case 'CHEQUE':
      return gt('Cheque');
    case 'CREDIT_NOTE':
      return gt('Credit note');
  }
  return m;
}

String gstModeLabel(String m) {
  switch (m.toUpperCase()) {
    case 'REGULAR':
      return gt('Regular (input credit)');
    case 'COMPOSITION':
      return gt('Composition (tax in cost)');
    case 'NONE':
      return gt('No GST');
  }
  return m;
}

// ---------------------------------------------------------------------------
// GST bifurcation by slab
// ---------------------------------------------------------------------------

class SlabRow {
  final String label;
  final int rate;
  int taxable, cgst, sgst, igst, cess;
  SlabRow(this.label, this.rate,
      {this.taxable = 0, this.cgst = 0, this.sgst = 0, this.igst = 0, this.cess = 0});
  int get tax => cgst + sgst + igst + cess;
}

/// Slab table of a recorded purchase from the server's own figures. Freight
/// is shown as its own row (its GST is whatever the document total carries
/// beyond the lines).
List<SlabRow> slabsOf(PurchaseDto p) {
  final by = <int, SlabRow>{};
  var lc = 0, ls = 0, li = 0, lx = 0;
  for (final l in p.items) {
    final r = by.putIfAbsent(l.gstPercent, () => SlabRow('${l.gstPercent}%', l.gstPercent));
    r.taxable += l.taxablePaise;
    r.cgst += l.cgstPaise;
    r.sgst += l.sgstPaise;
    r.igst += l.igstPaise;
    r.cess += l.cessPaise;
    lc += l.cgstPaise;
    ls += l.sgstPaise;
    li += l.igstPaise;
    lx += l.cessPaise;
  }
  final rows = by.values.toList()..sort((a, b) => a.rate.compareTo(b.rate));
  final fc = p.cgstPaise - lc, fs = p.sgstPaise - ls, fi = p.igstPaise - li;
  if (p.freightPaise > 0 || fc + fs + fi + (p.cessPaise - lx) > 0) {
    rows.add(SlabRow(
        '${gt('Freight')} ${p.freightGstPercent}%', p.freightGstPercent,
        taxable: p.freightPaise,
        cgst: fc,
        sgst: fs,
        igst: fi,
        cess: p.cessPaise - lx));
  }
  return rows;
}

class GstSlabTable extends StatelessWidget {
  final List<SlabRow> rows;
  final bool estimate;
  const GstSlabTable({super.key, required this.rows, this.estimate = false});

  @override
  Widget build(BuildContext context) {
    final total = SlabRow(gt('Total'), -1);
    for (final r in rows) {
      total.taxable += r.taxable;
      total.cgst += r.cgst;
      total.sgst += r.sgst;
      total.igst += r.igst;
      total.cess += r.cess;
    }
    Widget cell(String t, double w,
        {bool head = false, bool bold = false, bool left = false}) {
      return SizedBox(
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
    }

    Widget line(List<String> c, {bool head = false, bool bold = false}) {
      const w = [78.0, 86.0, 72.0, 72.0, 72.0, 64.0];
      return Container(
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: AppColors.line, width: head || bold ? 1.2 : .6))),
        child: Row(children: [
          for (var i = 0; i < 6; i++)
            cell(c[i], w[i], head: head, bold: bold, left: i == 0),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(children: [
          line([gt('GST'), gt('Taxable'), 'CGST', 'SGST', 'IGST', gt('Cess')],
              head: true),
          for (final r in rows)
            line([
              r.label,
              pRs(r.taxable),
              pRs(r.cgst),
              pRs(r.sgst),
              pRs(r.igst),
              pRs(r.cess)
            ]),
          line([
            total.label,
            pRs(total.taxable),
            pRs(total.cgst),
            pRs(total.sgst),
            pRs(total.igst),
            pRs(total.cess)
          ], bold: true),
        ]),
      ),
      if (estimate)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              gt('Estimate - the final amounts are calculated by the server when you save.'),
              style: pSub),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// CSV export (built in the browser from the fetched rows)
// ---------------------------------------------------------------------------

/// Paise as a plain rupee number for a spreadsheet (`1250.50`).
String csvRs(int paise) {
  final a = paise.abs();
  return '${paise < 0 ? '-' : ''}${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

String _csvCell(String v) {
  // Quote when needed and defuse spreadsheet formulas.
  var t = v;
  if (t.isNotEmpty && '=+-@'.contains(t[0]) && double.tryParse(t) == null) {
    t = "'$t";
  }
  if (t.contains(',') || t.contains('"') || t.contains('\n') || t.contains('\r')) {
    t = '"${t.replaceAll('"', '""')}"';
  }
  return t;
}

String toCsv(List<String> head, List<List<String>> rows) =>
    [head, ...rows].map((r) => r.map(_csvCell).join(',')).join('\r\n');

/// Saves [csv] as a download (UTF-8 with a byte-order mark so Excel reads
/// the text correctly).
void saveCsv(String name, String csv) {
  final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
  final ok = downloadBytes(bytes, name, 'text/csv;charset=utf-8');
  showToast(
      ok ? pgt('CSV file downloaded') : pgt('Could not download the file here.'),
      ok ? 'success' : 'error');
}

// ---------------------------------------------------------------------------
// Pick one supplier or product to filter by (search, tap a hit, clear)
// ---------------------------------------------------------------------------

class PPickFilter extends StatefulWidget {
  /// `supplier` or `product`.
  final String kind;
  final String? selectedName;
  final void Function(String id, String name) onPick;
  final VoidCallback onClear;
  const PPickFilter({
    super.key,
    required this.kind,
    required this.selectedName,
    required this.onPick,
    required this.onClear,
  });
  @override
  State<PPickFilter> createState() => _PPickFilterState();
}

class _PPickFilterState extends State<PPickFilter> {
  final _q = TextEditingController();
  Timer? _t;
  int _gen = 0;
  List<({String id, String name})> _hits = const [];

  @override
  void dispose() {
    _t?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _t?.cancel();
    if (v.trim().isEmpty) {
      setState(() => _hits = const []);
      return;
    }
    _t = Timer(const Duration(milliseconds: 300), () async {
      final gen = ++_gen;
      try {
        final List<({String id, String name})> r;
        if (widget.kind == 'supplier') {
          final PurchaseApi api = PurchaseStore.instance.api;
          r = (await api.suppliers(q: v, size: 8))
              .items
              .map((s) => (id: s.id, name: s.name))
              .toList();
        } else {
          final page = await Api.instance.admin.listProducts(q: v.trim(), size: 8);
          r = [
            for (final p in page.items)
              if (p.id != null)
                (
                  id: p.id!,
                  name: '${p.nameEn ?? 'Item'}'
                      '${(p.packSize ?? '').isEmpty ? '' : ' · ${normalizePack(p.packSize!)}'}'
                )
          ];
        }
        if (mounted && gen == _gen) setState(() => _hits = r);
      } catch (_) {
        // the filter just stays empty
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sup = widget.kind == 'supplier';
    if (widget.selectedName != null) {
      return Row(children: [
        Text('${pgt(sup ? 'Supplier' : 'Product')}: ', style: pSub),
        Flexible(
          child: AppChip(widget.selectedName!,
              small: true, selected: true, onTap: widget.onClear),
        ),
        const SizedBox(width: 6),
        AppLink('Clear', onTap: widget.onClear),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppField(
        label: sup ? 'Filter by supplier' : 'Filter by product',
        controller: _q,
        placeholder: sup ? 'Type a supplier name' : 'Type a product name',
        onChanged: _changed,
      ),
      if (_hits.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final h in _hits)
            AppChip(h.name, small: true, selected: false, onTap: () {
              _q.clear();
              setState(() => _hits = const []);
              widget.onPick(h.id, h.name);
            }),
        ]),
      ],
    ]);
  }
}
