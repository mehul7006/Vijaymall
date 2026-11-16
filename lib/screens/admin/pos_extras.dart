import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_config.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto.dart';
import '../../data/api/pos_api.dart' show PosApi;
import '../../data/api/pos_dto.dart';
import '../../data/print_text.dart';
import '../../data/validators.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

String _rs(int paise) {
  final a = paise.abs();
  final p = a % 100;
  final base = money(a ~/ 100);
  return '${paise < 0 ? '-' : ''}$base${p == 0 ? '' : '.${p.toString().padLeft(2, '0')}'}';
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

/// Runs one till call and hands back either the value or the API error
/// (never throws), so the sheets can show `message` / `details.fields`.
Future<(T?, ApiException?)> posTry<T>(Future<T> Function(PosApi api) f) async {
  try {
    return (await f(Api.instance.pos), null);
  } on ApiException catch (e) {
    return (null, e);
  } catch (_) {
    return (
      null,
      const ApiException(
          0, 'Could not reach the server. Check the connection and try again.')
    );
  }
}

/// A catalogue image URL as the browser must fetch it: absolute URLs stay,
/// a backend-relative `/img/...` path gets the API origin (same-origin, the
/// backend sends no CORS headers). Anything else (an art key) has no photo.
String? posImageUrl(String? raw) {
  final u = (raw ?? '').trim();
  if (u.isEmpty) return null;
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  if (u.startsWith('/')) return '${ApiConfig.baseUrl}$u';
  return null;
}

/// Small rounded product picture for tiles and bill lines. Lazy (the network
/// image only loads when the tile is built), decoded at thumbnail size, and a
/// quiet initial-letter placeholder when there is no photo or it fails.
class PosThumb extends StatelessWidget {
  const PosThumb({super.key, required this.imageUrl, required this.name, this.size = 48});

  final String? imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = posImageUrl(imageUrl);
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final ph = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.bg,
      child: Text(letter,
          style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: size * .42,
              fontWeight: FontWeight.w800,
              color: AppColors.ink3)),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? ph
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).round(),
                  errorBuilder: (_, __, ___) => ph,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : ph,
                ),
        ),
      ),
    );
  }
}

/// GST by slab: taxable value, CGST and SGST per slab and in total. For a
/// recorded sale pass exact server sums; for a quote pass [estimate] true so
/// the table is labelled as an estimate (the quote carries no per-slab split).
class PosGstTable extends StatelessWidget {
  const PosGstTable({
    super.key,
    required this.rows,
    required this.taxablePaise,
    required this.cgstPaise,
    required this.sgstPaise,
    this.estimate = false,
  });

  final List<GstSlabRow> rows;
  final int taxablePaise;
  final int cgstPaise;
  final int sgstPaise;
  final bool estimate;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    TextStyle st({bool b = false}) => TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: 12,
        fontWeight: b ? FontWeight.w800 : FontWeight.w600,
        color: b ? AppColors.ink : AppColors.ink2);
    Widget cell(String t, {bool b = false, bool left = false, int flex = 2}) =>
        Expanded(
          flex: flex,
          child: Text(t,
              textAlign: left ? TextAlign.left : TextAlign.right, style: st(b: b)),
        );
    Widget row(String a, String b, String c, String d, {bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            cell(a, b: bold, left: true, flex: 2),
            cell(b, b: bold, flex: 3),
            cell(c, b: bold, flex: 3),
            cell(d, b: bold, flex: 3),
          ]),
        );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            estimate
                ? gt('GST by slab (estimate; the bill total is exact)')
                : gt('GST by slab'),
            style: st(b: true)),
        const SizedBox(height: 4),
        row(gt('Rate'), gt('Taxable'), 'CGST', 'SGST', bold: true),
        for (final r in rows)
          row('${r.percent}%', _rs(r.taxablePaise), _rs(r.cgstPaise),
              _rs(r.sgstPaise)),
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line))),
          child: row(gt('Total'), _rs(taxablePaise), _rs(cgstPaise),
              _rs(sgstPaise),
              bold: true),
        ),
      ]),
    );
  }
}

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Text(k,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink2,
              )),
        ),
        Text(v, style: _h),
      ]),
    );

/// Receipt text box (monospaced) with a 58 mm / 80 mm switch and a Copy
/// button. [load] fetches `{width, text}` for the chosen width; used for the
/// credit note after a return and the receipt after a credit repayment.
class PosReceiptBox extends StatefulWidget {
  const PosReceiptBox({super.key, required this.load, this.title = 'Receipt'});

  final Future<ReceiptDto?> Function(int width) load;
  final String title;

  @override
  State<PosReceiptBox> createState() => _PosReceiptBoxState();
}

class _PosReceiptBoxState extends State<PosReceiptBox> {
  int _width = 32;
  ReceiptDto? _r;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final r = await widget.load(_width);
    if (!mounted) return;
    setState(() {
      _r = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipRail(children: [
          AppChip('58 mm', small: true, selected: _width == 32, onTap: () {
            _width = 32;
            _fetch();
          }),
          const SizedBox(width: 8),
          AppChip('80 mm', small: true, selected: _width == 48, onTap: () {
            _width = 48;
            _fetch();
          }),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: AppColors.red),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _r?.text ?? gt('Receipt is not available right now.'),
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.ink),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        AppButton(gt('Print receipt'),
            block: true,
            onTap: _r == null
                ? null
                : () {
                    final ok = printText(_r!.text,
                        width: _width, title: widget.title);
                    if (!ok) {
                      showToast(
                          gt('The browser blocked the print window. Allow pop-ups, or copy the receipt.'),
                          'error');
                    }
                  }),
        const SizedBox(height: 8),
        AppButton(gt('Copy receipt'),
            variant: BtnVariant.secondary,
            block: true,
            onTap: _r == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: _r!.text));
                    showToast(gt('Receipt copied'));
                  }),
      ],
    );
  }
}

/// Field error for a payment row: picks `<prefix>[i].mode` from the 400's
/// `details.fields` (or the bare `refundMode` key).
String? posModeError(Map<String, String> f, String prefix, int i) =>
    f['$prefix[$i].mode'];

EdgeInsets _pad(BuildContext c) => EdgeInsets.fromLTRB(
    20, 6, 20, 24 + MediaQuery.of(c).viewInsets.bottom);

/// Till action: pick a recent sale, choose items + quantities, refund
/// (`GET /pos/sales`, `POST /pos/sales/{id}/returns`).
Future<void> showPosReturnSheet(BuildContext context) => showAppSheet<void>(
      context: context,
      title: gt('Return / refund'),
      sub: gt('Pick the sale, then the items coming back'),
      builder: (_) => const _ReturnBody(),
    );

/// Till action: collect a payment against a customer's udhar
/// (`/pos/credit/account|ledger|payments`).
Future<void> showPosCollectCreditSheet(BuildContext context) =>
    showAppSheet<void>(
      context: context,
      title: gt('Collect credit payment'),
      sub: gt('Customer pays back what they owe'),
      builder: (_) => const _CollectBody(),
    );

/// Till action: open / close the cash-drawer shift
/// (`GET /pos/shifts/current`, `POST /pos/shifts/open|close`).
Future<void> showPosShiftSheet(BuildContext context) => showAppSheet<void>(
      context: context,
      title: gt('Cash drawer shift'),
      sub: gt('Open with the float, close with the cash counted'),
      builder: (_) => const _ShiftBody(),
    );

class _ShiftBody extends StatefulWidget {
  const _ShiftBody();

  @override
  State<_ShiftBody> createState() => _ShiftBodyState();
}

class _ShiftBodyState extends State<_ShiftBody> {
  final _float = TextEditingController(text: '0');
  final _counted = TextEditingController();
  final _note = TextEditingController();
  bool _busy = true;
  bool _needsNote = false;
  ShiftViewDto? _closed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await StateScope.read(context).posLoadShift();
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _paise(String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null || v < 0) return null;
    return (v * 100).round();
  }

  Future<void> _open() async {
    final p = _paise(_float.text);
    if (p == null) {
      showToast(gt('Enter the opening float (0 or more)'), 'error');
      return;
    }
    setState(() => _busy = true);
    final err = await StateScope.read(context).posOpenShift(p);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(gt('Shift opened'));
  }

  Future<void> _close() async {
    final p = _paise(_counted.text);
    if (p == null) {
      showToast(gt('Enter the cash counted in the drawer'), 'error');
      return;
    }
    setState(() => _busy = true);
    final (s, err, code) = await StateScope.read(context)
        .posCloseShift(p, note: _note.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _closed = s;
      if (code == 'VARIANCE_NEEDS_NOTE') _needsNote = true;
    });
    if (err != null) showToast(err, 'error');
  }

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    final s = st.posShift;
    final c = _closed;
    return Padding(
      padding: _pad(context),
      child: SingleChildScrollView(
        child: _busy
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.red)),
              )
            : c != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(gt('Shift closed'),
                          textAlign: TextAlign.center,
                          style: _h.copyWith(fontSize: 16)),
                      const SizedBox(height: 10),
                      _kv(gt('Expected'), _rs(c.expectedCashPaise)),
                      _kv(gt('Counted'), _rs(c.countedCashPaise ?? 0)),
                      _kv(gt('Difference'), _rs(c.variancePaise ?? 0)),
                      const SizedBox(height: 14),
                      AppButton(gt('Done'),
                          block: true,
                          onTap: () => Navigator.of(context).pop()),
                    ],
                  )
                : s == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Hint(gt('No shift is open. Count the drawer and '
                              'enter the float to start billing.')),
                          const SizedBox(height: 10),
                          AppField(
                            label: gt('Opening float (Rs)'),
                            controller: _float,
                            numeric: true,
                          ),
                          const SizedBox(height: 12),
                          AppButton(gt('Open shift'),
                              block: true, onTap: _open),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _kv(gt('Opened'), (s.openedAt ?? '').replaceFirst('T', ' ').split('.').first),
                          _kv(gt('Opening float'), _rs(s.openingFloatPaise)),
                          _kv(gt('Cash expected now'), _rs(s.expectedCashPaise)),
                          const SizedBox(height: 10),
                          AppField(
                            label: gt('Cash counted (Rs)'),
                            controller: _counted,
                            numeric: true,
                            placeholder: (s.expectedCashPaise / 100)
                                .toStringAsFixed(0),
                          ),
                          const SizedBox(height: 10),
                          AppField(
                            label: _needsNote
                                ? gt('Reason for the difference (required)')
                                : gt('Note (needed only if the cash differs)'),
                            controller: _note,
                            maxLength: 200,
                          ),
                          const SizedBox(height: 12),
                          AppButton(gt('Close shift'),
                              block: true, onTap: _close),
                        ],
                      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Return
// ---------------------------------------------------------------------------

class _ReturnBody extends StatefulWidget {
  const _ReturnBody();

  @override
  State<_ReturnBody> createState() => _ReturnBodyState();
}

class _ReturnBodyState extends State<_ReturnBody> {
  final _query = TextEditingController();
  final _reason = TextEditingController();
  List<SaleRecordDto> _sales = const [];
  SaleRecordDto? _sale;
  List<ReturnRecordDto> _past = const [];
  final Map<String, int> _qty = {};
  /// Sale-item ids whose returned units are damaged (`restock:false`).
  final Set<String> _damaged = {};
  ReturnRecordDto? _done;
  bool _loading = true;
  bool _busy = false;

  /// Exact refund the server worked out for the ticked lines
  /// (`POST /pos/sales/{id}/returns/preview`); cleared whenever the ticks
  /// change, so "Confirm" always matches what was shown.
  ReturnPreviewDto? _pv;
  bool _pvBusy = false;
  String _refundMode = 'BILL';
  String? _modeErr;
  String _fp = '';
  String _key = '';

  /// Idempotency key for the current return attempt: stable while the same
  /// selection is retried, fresh as soon as it changes.
  String _keyFor(String fp) {
    if (fp != _fp) {
      _fp = fp;
      _key = newIdempotencyKey();
    }
    return _key;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _query.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final st = StateScope.read(context);
    final q = _query.text.trim();
    setState(() => _loading = true);
    final isMobile = RegExp(r'^\d{10}$').hasMatch(q);
    final list = await st.posRecentSales(
      invoiceNo: q.isNotEmpty && !isMobile ? q : null,
      mobile: isMobile ? q : null,
    );
    if (!mounted) return;
    setState(() {
      _sales = list;
      _loading = false;
    });
  }

  Future<void> _pick(SaleRecordDto s, {String? keepMessage}) async {
    final st = StateScope.read(context);
    if (s.id == null) return;
    setState(() => _loading = true);
    final fresh = await st.posSale(s.id!) ?? s;
    final past = await st.posReturnsOf(s.id!);
    if (!mounted) return;
    setState(() {
      _sale = fresh;
      _past = past;
      _qty.clear();
      _damaged.clear();
      _msg = keepMessage ??
          (fresh.items.isNotEmpty && fresh.items.every((i) => _left(i) <= 0)
              ? gt('This bill has already been fully returned. There is nothing left to refund.')
              : null);
      _loading = false;
    });
  }

  int _left(SaleItemRecordDto i) => i.qty - i.returnedQty;

  /// The plain-sentence banner above the button (nothing ticked, too many,
  /// already returned, return window passed ...). Cleared when the selection
  /// changes.
  String? _msg;

  int _selectedCount(SaleRecordDto sale) => sale.items
      .where((i) => (_qty[i.id ?? ''] ?? 0) > 0 && _left(i) > 0)
      .length;

  /// Rough money value of what is ticked (the server prices the real refund).
  int _estimate(SaleRecordDto sale) {
    var t = 0;
    for (final i in sale.items) {
      final q = _qty[i.id ?? ''] ?? 0;
      if (q > 0 && i.qty > 0) t += (i.netPaise * q / i.qty).round();
    }
    return t;
  }

  /// Ticks / unticks one line: a tick returns everything still returnable
  /// on it; the stepper then trims it.
  void _toggle(SaleItemRecordDto i) {
    final id = i.id;
    if (id == null) return;
    final left = _left(i);
    if (left <= 0) {
      setState(() => _msg = gt('This item has already been fully returned.'));
      return;
    }
    setState(() {
      _msg = null;
      _pv = null;
      if ((_qty[id] ?? 0) > 0) {
        _qty.remove(id);
        _damaged.remove(id);
      } else {
        _qty[id] = left;
      }
    });
  }

  void _setLine(SaleItemRecordDto i, int q) {
    final id = i.id;
    if (id == null) return;
    final left = _left(i);
    setState(() {
      _pv = null;
      if (q > left) {
        _msg = left <= 0
            ? gt('This item has already been fully returned.')
            : '${gt('Only')} ${i.soldBy == 'WEIGHT' ? '$left g' : left} '
                '${gt('can still be returned for')} ${i.name ?? gt('this item')}.';
        q = left;
      } else {
        _msg = null;
      }
      if (q <= 0) {
        _qty.remove(id);
        _damaged.remove(id);
      } else {
        _qty[id] = q;
      }
    });
  }

  void _selectAll(SaleRecordDto sale) {
    setState(() {
      _msg = null;
      _pv = null;
      final refundable = sale.items.where((i) => i.id != null && _left(i) > 0);
      final allOn = refundable.isNotEmpty &&
          refundable.every((i) => (_qty[i.id!] ?? 0) >= _left(i));
      if (allOn) {
        _qty.clear();
        _damaged.clear();
      } else {
        for (final i in refundable) {
          _qty[i.id!] = _left(i);
        }
      }
    });
  }

  /// One plain sentence for a failed return, from the backend's `code`,
  /// `details` and field errors.
  String _explain(AppState st, String fallback) {
    final code = st.posLastErrorCode;
    final d = st.posLastErrorDetails;
    final f = st.posLastFieldErrors;
    switch (code) {
      case 'RETURN_EXCEEDS_SOLD':
        final id = '${d['saleItemId'] ?? ''}';
        final it = _sale?.items.where((x) => x.id == id).toList() ?? const [];
        final name = it.isEmpty ? gt('this item') : (it.first.name ?? gt('this item'));
        final n = (d['returnable'] as num?)?.toInt();
        if (n == null) return gt('That is more than what is left to return.');
        if (n <= 0) {
          return '$name: ${gt('already fully returned. Nothing more can be refunded for it.')}';
        }
        return '$name: ${gt('only')} $n ${gt('can still be returned.')}';
      case 'RETURN_NEEDS_ADMIN':
        final days = (d['days'] as num?)?.toInt();
        return days == null
            ? gt('This bill is too old for a cashier to take a return. Ask an admin.')
            : '${gt('This bill is older than')} $days ${gt('days, so a cashier cannot take the return. Ask an admin to do it.')}';
      case 'NOT_FOUND':
        return gt('This bill could not be found. Pick it again.');
      case 'FORBIDDEN':
        return gt('You are not allowed to take this return. Ask an admin.');
      case 'IDEMPOTENCY_KEY_REUSED':
        return gt('This return was already sent with different items. Close and start it again.');
    }
    if (f.containsKey('items')) return gt('Tick at least one item to refund.');
    if (f.containsKey('saleItemId')) {
      return gt('One of the ticked items is not on this bill. Pick the bill again.');
    }
    if (f.containsKey('qty')) return gt('Each ticked item needs a quantity of at least 1.');
    if (f.containsKey('refundMode')) return f['refundMode']!;
    if (f.keys.any((k) => k.startsWith('refunds'))) {
      return f.values.first;
    }
    return fallback;
  }

  List<Map<String, dynamic>> _ticked() => [
        for (final e in _qty.entries)
          if (e.value > 0)
            {
              'saleItemId': e.key,
              'qty': e.value,
              if (_damaged.contains(e.key)) 'restock': false,
            },
      ];

  /// Step 1 of a refund: ask the server what each line will refund (coupon
  /// share, coin/discount share, clawback) and show it before anything is
  /// booked. Step 2 is [_submit].
  Future<void> _preview() async {
    final sale = _sale;
    if (sale?.id == null) return;
    final items = _ticked();
    if (items.isEmpty) {
      setState(() => _msg =
          gt('Tick at least one item to refund, then press Check refund.'));
      showToast(_msg!, 'error');
      return;
    }
    final reasonErr =
        Validators.text(_reason.text, label: gt('Reason'), max: 200);
    if (reasonErr != null) {
      setState(() => _msg = reasonErr);
      return;
    }
    setState(() {
      _pvBusy = true;
      _msg = null;
    });
    final (pv, e) = await posTry((api) => api.previewReturn(sale!.id!, items));
    if (!mounted) return;
    if (e != null || pv == null) {
      final st = StateScope.read(context);
      st.posLastErrorCode = e?.code;
      st.posLastErrorDetails = e?.details ?? const {};
      st.posLastFieldErrors = e?.fields ?? const {};
      final text =
          _explain(st, e?.message ?? gt('Could not work out the refund.'));
      setState(() {
        _pvBusy = false;
        _msg = text;
      });
      showToast(text, 'error');
      if (e?.code == 'RETURN_EXCEEDS_SOLD') await _pick(sale!, keepMessage: text);
      return;
    }
    setState(() {
      _pvBusy = false;
      _pv = pv;
    });
  }

  Future<void> _submit() async {
    final sale = _sale;
    if (sale?.id == null) return;
    final items = _ticked();
    if (sale!.items.isNotEmpty && sale.items.every((i) => _left(i) <= 0)) {
      setState(() => _msg = gt('This bill has already been fully returned. There is nothing left to refund.'));
      showToast(_msg!, 'error');
      return;
    }
    if (items.isEmpty) {
      setState(() => _msg = gt('Tick at least one item to refund, then press Refund selected items.'));
      showToast(_msg!, 'error');
      return;
    }
    // The backend takes `refundMode` (CASH | UPI | CARD) for the whole
    // pay-out; 'BILL' sends nothing so the server uses the bill's own mode.
    final refundMode = _refundMode == 'BILL' ? null : _refundMode;
    setState(() {
      _busy = true;
      _msg = null;
    });
    final st = StateScope.read(context);
    final (rec, err) = await st.posRefund(
      sale.id!,
      items: items,
      reason: _reason.text.trim(),
      refundMode: refundMode,
      // One key per return action, reused when the same selection is retried
      // after a timeout so the server cannot book the return twice.
      idempotencyKey: _keyFor(
          '${sale.id}|$_refundMode|${items.map((e) => '${e['saleItemId']}:${e['qty']}:${e['restock'] ?? ''}').join(',')}'),
    );
    if (!mounted) return;
    if (err != null) {
      final text = _explain(st, err);
      final stale = st.posLastErrorCode == 'RETURN_EXCEEDS_SOLD';
      setState(() {
        _busy = false;
        _msg = text;
        _modeErr = st.posLastFieldErrors['refundMode'];
      });
      showToast(text, 'error');
      // Someone else returned part of this bill meanwhile: reload the
      // returnable quantities so the steppers tell the truth.
      if (stale) await _pick(sale, keepMessage: text);
      return;
    }
    setState(() {
      _busy = false;
      _modeErr = null;
      _done = rec;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _pad(context),
      child: SingleChildScrollView(
        child: _done != null
            ? _doneView(_done!)
            : _sale == null
                ? _pickView()
                : _itemsView(_sale!),
      ),
    );
  }

  Widget _pickView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: AppField(
              label: gt('Invoice no. or customer mobile'),
              controller: _query,
              placeholder: gt('Leave empty for recent sales'),
              onEditingComplete: _search,
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: AppButton(gt('Find'), onTap: _search),
          ),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: AppColors.red)),
          )
        else if (_sales.isEmpty)
          Hint(gt('No sales found.'))
        else
          for (final s in _sales.take(30))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pick(s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.invoiceNo ?? '-', style: _h),
                        Text(
                          '${s.items.length} ${gt('items')}'
                          '${(s.customerMobile ?? '').isEmpty ? '' : ' - ${s.customerMobile}'}'
                          '${s.items.isNotEmpty && s.items.every((x) => x.qty - x.returnedQty <= 0) ? ' - ${gt('Fully returned')}' : ''}',
                          style: _sub,
                        ),
                      ],
                    ),
                  ),
                  Text(_rs(s.totalPaise), style: _h),
                ]),
              ),
            ),
      ],
    );
  }

  Widget _itemsView(SaleRecordDto sale) {
    final anyLeft = sale.items.any((i) => _left(i) > 0);
    final picked = _selectedCount(sale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text('${sale.invoiceNo ?? ''} - ${_rs(sale.totalPaise)}',
                style: _h),
          ),
          AppButton(gt('Change'),
              size: BtnSize.xs,
              variant: BtnVariant.secondary,
              onTap: () => setState(() {
                    _sale = null;
                    _msg = null;
                  })),
        ]),
        const SizedBox(height: 6),
        if (anyLeft)
          Row(children: [
            Expanded(
              child: Text(
                  picked == 0
                      ? gt('Tap an item to tick it for refund')
                      : '$picked ${gt(picked == 1 ? 'item ticked' : 'items ticked')}'
                          ' - ${gt('about')} ${_rs(_estimate(sale))}',
                  style: _sub),
            ),
            AppButton(gt('Select all'),
                size: BtnSize.xs,
                variant: BtnVariant.secondary,
                onTap: () => _selectAll(sale)),
          ]),
        const SizedBox(height: 4),
        for (final i in sale.items) _lineTile(i),
        if (_past.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(gt('Earlier returns'), style: _h),
          for (final r in _past)
            _kv(r.creditNoteNo ?? '', _rs(r.refundPaise)),
        ],
        const SizedBox(height: 10),
        if (sale.creditPaise > 0)
          Hint(gt('Part of this bill was on udhar: the refund first reduces '
              'what the customer owes, the rest is paid out below.')),
        Text(gt('Pay the refund by'), style: _sub),
        const SizedBox(height: 4),
        ChipRail(children: [
          for (final m in const ['BILL', 'CASH', 'UPI', 'CARD'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(m == 'BILL' ? gt('Same as bill') : m,
                  selected: _refundMode == m,
                  onTap: () => setState(() {
                        _refundMode = m;
                        _modeErr = null;
                      })),
            ),
        ]),
        if (_modeErr != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_modeErr!,
                style: _sub.copyWith(color: AppColors.red)),
          ),
        const SizedBox(height: 10),
        AppField(label: gt('Reason'), controller: _reason, maxLength: 200),
        if (_msg != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.redTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_msg!,
                style: _sub.copyWith(
                    color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        if (_pv != null) _previewCard(_pv!),
        const SizedBox(height: 12),
        if (_pv == null)
          AppButton(
              picked > 0
                  ? '${gt('Check refund')} ($picked)'
                  : gt('Check refund'),
              block: true,
              loading: _pvBusy,
              onTap: _pvBusy || !anyLeft ? null : _preview)
        else
          AppButton('${gt('Confirm refund')} ${_rs(_pv!.refundPaise)}',
              block: true,
              loading: _busy,
              onTap: _busy ? null : _submit),
      ],
    );
  }

  /// The server's exact refund: per line the price of the returned units,
  /// less the coupon share, less the coins/counter-discount share, less any
  /// coupon clawback, then the GST reversal.
  Widget _previewCard(ReturnPreviewDto pv) {
    Widget minus(String label, int paise) => paise == 0
        ? const SizedBox.shrink()
        : _kv(label, '- ${_rs(paise)}');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(gt('Refund worked out by the server'), style: _h),
        const SizedBox(height: 6),
        for (final l in pv.lines) ...[
          Text('${l.name} x ${l.qty}', style: _h.copyWith(fontSize: 13)),
          _kv(gt('Price of returned units'), _rs(l.grossPaise)),
          minus(gt('Coupon share (leaves with the units)'), l.couponSharePaise),
          minus(gt('Coins / discount share'), l.otherSharePaise),
          minus(gt('Coupon taken back'), l.clawbackPaise),
          _kv(gt('Refund for this line'), _rs(l.refundPaise)),
          const Divider(height: 10, color: AppColors.line),
        ],
        if (pv.couponClawbackPaise != 0)
          _kv(gt('Coupon taken back from this refund'),
              _rs(pv.couponClawbackPaise)),
        if (pv.couponPolicy.isNotEmpty)
          _kv(gt('Coupon policy'), pv.couponPolicy),
        _kv(gt('GST in refund'),
            'CGST ${_rs(pv.cgstPaise)} + SGST ${_rs(pv.sgstPaise)} (${gt('taxable')} ${_rs(pv.taxablePaise)})'),
        Text('${gt('Total refund')}: ${_rs(pv.refundPaise)}',
            style: _h.copyWith(fontSize: 16, color: AppColors.green)),
        const SizedBox(height: 4),
        Text(
            gt('Coins taken back or restored, and any part set against udhar, are shown after the refund is confirmed.'),
            style: _sub),
      ]),
    );
  }

  /// One bill line: tap anywhere on it to tick it; the stepper trims the
  /// quantity (never above what is still returnable).
  Widget _lineTile(SaleItemRecordDto i) {
    final left = _left(i);
    final cur = _qty[i.id ?? ''] ?? 0;
    final on = cur > 0 && left > 0;
    final weighed = i.soldBy == 'WEIGHT';
    final step = weighed ? 100 : 1;
    String qtyText(int n) => weighed ? '$n g' : '$n';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: on ? SectionPalette.sales.tint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? SectionPalette.sales.accent : AppColors.line),
      ),
      child: Column(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggle(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
            child: Row(children: [
              Checkbox(
                visualDensity: VisualDensity.compact,
                value: on,
                activeColor: SectionPalette.sales.accent,
                onChanged: left <= 0 ? null : (_) => _toggle(i),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name ?? '-', style: _h),
                    Text(
                      '${_rs(i.unitPricePaise)} x ${qtyText(i.qty)}'
                      '${i.returnedQty > 0 ? ' - ${qtyText(i.returnedQty)} ${gt('already returned')}' : ''}'
                      '${left > 0 ? ' - ${qtyText(left)} ${gt('can be returned')}' : ''}',
                      style: _sub,
                    ),
                  ],
                ),
              ),
              if (left <= 0)
                Text(gt('Fully returned'),
                    style: _sub.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        if (on && i.id != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(children: [
              Row(children: [
                Text(gt('Quantity to return'), style: _sub),
                const Spacer(),
                IconBtn('minus',
                    size: 32,
                    iconSize: 14,
                    onTap: () => _setLine(i, cur - step)),
                SizedBox(
                  width: weighed ? 64 : 34,
                  child: Text(qtyText(cur),
                      textAlign: TextAlign.center, style: _h),
                ),
                IconBtn('plus',
                    size: 32,
                    iconSize: 14,
                    onTap: cur >= left ? null : () => _setLine(i, cur + step)),
                if (left > 1)
                  GestureDetector(
                    onTap: () => _setLine(i, left),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(gt('All'),
                          style: _sub.copyWith(
                              color: AppColors.red,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  if (!_damaged.add(i.id!)) _damaged.remove(i.id!);
                }),
                child: Row(children: [
                  Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: _damaged.contains(i.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _damaged.add(i.id!);
                      } else {
                        _damaged.remove(i.id);
                      }
                    }),
                  ),
                  Expanded(
                    child: Text(gt('Damaged - do not put back on the shelf'),
                        style: _sub),
                  ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _doneView(ReturnRecordDto r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(gt('Return recorded'),
            textAlign: TextAlign.center, style: _h.copyWith(fontSize: 16)),
        const SizedBox(height: 10),
        _kv(gt('Credit note'), r.creditNoteNo ?? '-'),
        _kv(gt('Refund'), _rs(r.refundPaise)),
        for (final p in r.refunds)
          _kv('  ${p.mode ?? ''}', _rs(p.amountPaise)),
        if (r.id != null && r.saleId != null) ...[
          const SizedBox(height: 8),
          PosReceiptBox(
            load: (w) => StateScope.read(context).posReturnReceipt(
                _sale?.id ?? r.saleId!, r.id!,
                width: w),
          ),
        ],
        if (r.creditAdjustedPaise != 0)
          _kv(gt('Adjusted against udhar'), _rs(r.creditAdjustedPaise)),
        if (r.couponClawbackPaise != 0)
          _kv(gt('Coupon taken back'), _rs(r.couponClawbackPaise)),
        if (r.coinsClawedBack != 0)
          _kv(gt('Coins taken back'), '${r.coinsClawedBack}'),
        if (r.coinsRestored != 0)
          _kv(gt('Coins restored'), '${r.coinsRestored}'),
        const SizedBox(height: 14),
        AppButton(gt('Done'),
            block: true, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Collect credit payment
// ---------------------------------------------------------------------------

class _CollectBody extends StatefulWidget {
  const _CollectBody();

  @override
  State<_CollectBody> createState() => _CollectBodyState();
}

class _CollectBodyState extends State<_CollectBody> {
  final _mobile = TextEditingController();
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _note = TextEditingController();
  CreditAccountDto? _acc;
  List<CreditLedgerEntryDto> _ledger = const [];
  CreditReceiptDto? _receipt;
  String _mode = 'CASH';
  String? _modeErr;
  bool _busy = false;
  String _fp = '';
  String _key = '';

  String _keyFor(String fp) {
    if (fp != _fp) {
      _fp = fp;
      _key = newIdempotencyKey();
    }
    return _key;
  }

  @override
  void dispose() {
    _mobile.dispose();
    _amount.dispose();
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final m = _mobile.text.trim();
    if (m.isEmpty) {
      showToast(gt('Enter the customer mobile'), 'error');
      return;
    }
    setState(() => _busy = true);
    final (acc, led, err) = await StateScope.read(context).posCreditLookup(m);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _acc = acc;
      _ledger = led;
    });
    if (err != null) showToast(err, 'error');
  }

  Future<void> _collect() async {
    final rupees = double.tryParse(_amount.text.trim());
    if (rupees == null || rupees <= 0) {
      showToast(gt('Enter a valid amount'), 'error');
      return;
    }
    final ref = _ref.text.trim();
    setState(() => _busy = true);
    final (rec, err) = await StateScope.read(context).posCollectCredit(
      mobile: _mobile.text.trim(),
      payments: [
        {
          'mode': _mode,
          'amountPaise': (rupees * 100).round(),
          if (ref.isNotEmpty) 'reference': ref,
        }
      ],
      note: _note.text.trim(),
      // Same payment retried after a timeout re-uses the key (no double
      // repayment); a different amount/mode/customer gets a fresh one.
      idempotencyKey:
          _keyFor('${_mobile.text.trim()}|$_mode|${(rupees * 100).round()}'),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _modeErr = posModeError(
          StateScope.read(context).posLastFieldErrors, 'payments', 0));
      showToast(err, 'error');
      return;
    }
    setState(() {
      _modeErr = null;
      _receipt = rec;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _acc;
    final r = _receipt;
    return Padding(
      padding: _pad(context),
      child: SingleChildScrollView(
        child: r != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(gt('Payment received'),
                      textAlign: TextAlign.center,
                      style: _h.copyWith(fontSize: 16)),
                  const SizedBox(height: 10),
                  _kv(gt('Receipt'), r.receiptNo ?? '-'),
                  _kv(gt('Paid'), _rs(r.amountPaise)),
                  _kv(gt('Still owes'), _rs(r.balanceDuePaise)),
                  if (r.id != null) ...[
                    const SizedBox(height: 8),
                    PosReceiptBox(
                      load: (w) => StateScope.read(context)
                          .posCreditReceipt(r.id!, width: w),
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppButton(gt('Done'),
                      block: true, onTap: () => Navigator.of(context).pop()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: AppField(
                        label: gt('Customer mobile'),
                        controller: _mobile,
                        numeric: true,
                        maxLength: 10,
                        onEditingComplete: _lookup,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: AppButton(gt('Find'),
                          onTap: _busy ? null : _lookup),
                    ),
                  ]),
                  if (a != null) ...[
                    const SizedBox(height: 12),
                    Text(a.name?.isNotEmpty == true ? a.name! : (a.mobile ?? ''),
                        style: _h),
                    _kv(gt('Owes'), _rs(a.balancePaise)),
                    _kv(gt('Limit'), _rs(a.limitPaise)),
                    if (_ledger.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(gt('Recent activity'), style: _h),
                      for (final e in _ledger.take(5))
                        _kv('${e.kind ?? ''} ${(e.refNo ?? '')}',
                            _rs(e.deltaPaise)),
                    ],
                    const SizedBox(height: 12),
                    if (a.balancePaise <= 0)
                      Hint(gt('This customer has no dues.'))
                    else ...[
                      AppField(
                        label: gt('Amount (Rs)'),
                        controller: _amount,
                        numeric: true,
                        placeholder: (a.balancePaise / 100).toStringAsFixed(0),
                      ),
                      const SizedBox(height: 10),
                      ChipRail(children: [
                        for (final m in const ['CASH', 'UPI', 'CARD'])
                          AppChip(m,
                              selected: _mode == m,
                              onTap: () => setState(() {
                                    _mode = m;
                                    _modeErr = null;
                                  })),
                      ]),
                      if (_modeErr != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_modeErr!,
                              style: _sub.copyWith(color: AppColors.red)),
                        ),
                      const SizedBox(height: 10),
                      FieldRow(
                        flex: const [2, 3],
                        children: [
                          if (_mode != 'CASH')
                            AppField(
                                label: gt('Reference'), controller: _ref),
                          AppField(
                              label: gt('Note'),
                              controller: _note,
                              maxLength: 200),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppButton(gt('Collect payment'),
                          block: true,
                          loading: _busy,
                          onTap: _busy ? null : _collect),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Credit eligibility at the till
// ---------------------------------------------------------------------------

/// Default udhar limit offered by the one-click "Enable credit" sheet. The
/// backend has no default limit setting (credit is off until an admin sets a
/// limit above zero), so this is only a starting value the admin can edit.
const int kDefaultCreditLimitPaise = 500000;

/// Digits-only 10-digit mobile for the till, or null when [raw] is not one.
/// Accepts `+91 98765 43210`, `09876543210`, `91-9876543210` like the server.
String? cleanMobile(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return RegExp(r'^[6-9]\d{9}$').hasMatch(d) ? d : null;
}

/// Why [acc] cannot take [billCreditPaise] on credit, in plain words with the
/// exact numbers; null when it can. [status] is the HTTP status of the
/// lookup (404 = the shop has never seen the number).
String? creditWhyNot(CreditAccountDto? acc, int status, String mobile,
    {int billCreditPaise = 0}) {
  if (acc == null) {
    if (status == 404) {
      return '$mobile ${gt('is new to the shop, so credit is not enabled yet (limit')} ${_rs(0)}).';
    }
    return null;
  }
  final who = (acc.name ?? '').isNotEmpty ? acc.name! : (acc.mobile ?? mobile);
  if (acc.blocked && acc.limitPaise > 0) {
    return '$who: ${gt('This customer is blocked, so credit cannot be given.')}';
  }
  if (acc.limitPaise <= 0) {
    return '${gt('Credit is not enabled for')} $who: ${gt('no credit limit is set (limit')} ${_rs(0)}'
        '${acc.balancePaise > 0 ? ', ${gt('owes')} ${_rs(acc.balancePaise)}' : ''}).';
  }
  if (acc.availablePaise <= 0) {
    return '$who ${gt('has used the whole credit limit')}: ${gt('limit')} ${_rs(acc.limitPaise)}, '
        '${gt('owes')} ${_rs(acc.balancePaise)}, ${gt('available')} ${_rs(0)}.';
  }
  if (billCreditPaise > acc.availablePaise) {
    return '$who ${gt('can take only')} ${_rs(acc.availablePaise)} ${gt('more on credit')} '
        '(${gt('limit')} ${_rs(acc.limitPaise)}, ${gt('owes')} ${_rs(acc.balancePaise)}). '
        '${gt('This bill needs')} ${_rs(billCreditPaise)} ${gt('on credit.')}';
  }
  return null;
}

/// Small sheet to switch credit on for [mobile] with an editable limit.
/// Returns the saved account, or null when dismissed / refused. Only an
/// ADMIN may do this (`PUT /admin/credit/limit`); a cashier gets a clear
/// "ask an admin" message.
Future<CreditAccountDto?> showEnableCreditSheet(
  BuildContext context, {
  required String mobile,
  String? name,
  int? currentLimitPaise,
}) =>
    showAppSheet<CreditAccountDto>(
      context: context,
      title: gt('Enable credit'),
      sub: (name ?? '').isNotEmpty ? '$name - $mobile' : mobile,
      builder: (_) => _EnableCreditBody(
          mobile: mobile, currentLimitPaise: currentLimitPaise),
    );

class _EnableCreditBody extends StatefulWidget {
  const _EnableCreditBody({required this.mobile, this.currentLimitPaise});
  final String mobile;
  final int? currentLimitPaise;

  @override
  State<_EnableCreditBody> createState() => _EnableCreditBodyState();
}

class _EnableCreditBodyState extends State<_EnableCreditBody> {
  late final TextEditingController _limit = TextEditingController(
      text: ((widget.currentLimitPaise ?? 0) > 0
              ? widget.currentLimitPaise!
              : kDefaultCreditLimitPaise)
          .div100());
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final rupees = double.tryParse(_limit.text.trim());
    if (rupees == null || !rupees.isFinite || rupees <= 0 || rupees > 1e9) {
      setState(() => _err = gt('Enter a credit limit above zero (in rupees).'));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final (acc, err, forbidden) = await StateScope.read(context)
        .posEnableCredit(widget.mobile, (rupees * 100).round());
    if (!mounted) return;
    if (acc != null) {
      showToast('${gt('Credit enabled, limit')} ${_rs(acc.limitPaise)}');
      Navigator.of(context).pop(acc);
      return;
    }
    setState(() {
      _busy = false;
      _err = forbidden
          ? gt('Only an admin can enable credit. Ask an admin to do it.')
          : (err ?? gt('Could not enable credit.'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = StateScope.of(context).isBackendAdmin;
    return Padding(
      padding: _pad(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Hint(gt('Credit (udhar) is off until a limit above zero is set. '
              'The customer can then pay part or all of a bill later, up to this limit.')),
          const SizedBox(height: 10),
          if (!admin)
            Hint(gt('Only an admin can enable credit. Ask an admin to do it.'))
          else ...[
            AppField(
              label: gt('Credit limit (Rs)'),
              controller: _limit,
              numeric: true,
              autofocus: true,
              error: _err,
            ),
            const SizedBox(height: 6),
            Text(gt('You can change the limit later on the Credit screen.'),
                style: _sub),
            const SizedBox(height: 14),
            AppButton(gt('Enable credit'),
                block: true, loading: _busy, onTap: _busy ? null : _go),
          ],
        ],
      ),
    );
  }
}

extension on int {
  /// Paise as a plain rupee string for an input box ("5000", "250.5").
  String div100() => this % 100 == 0
      ? '${this ~/ 100}'
      : (this / 100).toStringAsFixed(2);
}

/// Read-only credit customer picker for the till (`GET /pos/credit/customers`,
/// open to cashiers). Rows show a MASKED mobile, so tapping one asks for the
/// full number (checked against the mask) and then reads the account. A typed
/// 10-digit mobile can also be checked directly. Returns the chosen account.
Future<CreditAccountDto?> showPosCreditPicker(BuildContext context) =>
    showAppSheet<CreditAccountDto>(
      context: context,
      title: gt('Credit customers'),
      sub: gt('Pick who is buying on credit'),
      builder: (_) => const _CreditPickerBody(),
    );

class _CreditPickerBody extends StatefulWidget {
  const _CreditPickerBody();

  @override
  State<_CreditPickerBody> createState() => _CreditPickerBodyState();
}

class _CreditPickerBodyState extends State<_CreditPickerBody> {
  final _q = TextEditingController();
  final _full = TextEditingController();
  final List<CreditPickDto> _rows = [];
  bool _loading = true;
  bool _more = false;
  bool _hasMore = false;
  bool _looking = false;
  bool _all = false;
  int _page = 0;
  String? _err;
  String? _qErr;
  String? _fullErr;
  String? _lookupMsg;
  CreditPickDto? _sel;
  bool _booted = false;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _full.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final q = _q.text.trim();
    // `all=true` needs at least 2 characters of search (else 400 `q`).
    if (_all && q.length < 2) {
      setState(() {
        _rows.clear();
        _hasMore = false;
        _loading = false;
        _err = null;
        _qErr = gt('Type at least 2 letters to search all customers.');
      });
      return;
    }
    final lenErr = Validators.text(q, label: gt('Search'), max: 100);
    if (lenErr != null) {
      setState(() => _qErr = lenErr);
      return;
    }
    if (more) {
      if (_more || !_hasMore) return;
      setState(() => _more = true);
    } else {
      setState(() {
        _loading = true;
        _err = null;
        _qErr = null;
        _sel = null;
        _page = 0;
      });
    }
    final page = more ? _page + 1 : 0;
    final (res, e) = await posTry(
        (api) => api.creditCustomers(q: q, all: _all, page: page, size: 20));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _more = false;
      if (e != null || res == null) {
        _err = e?.fields['q'] ??
            e?.message ??
            gt('Could not load credit customers.');
        return;
      }
      if (!more) _rows.clear();
      _page = page;
      _rows.addAll(res.items);
      _hasMore = res.hasMore;
    });
  }

  void _onQ(String _) {
    setState(() => _lookupMsg = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load();
    });
  }

  void _select(CreditPickDto d) {
    // Same order as the server: no limit first (CREDIT_NOT_ALLOWED), then
    // blocked (CUSTOMER_BLOCKED).
    if (d.limitPaise <= 0) {
      setState(() {
        _sel = null;
        _lookupMsg =
            '${d.name}: ${gt('Credit is not enabled for this customer. An admin must set a credit limit first.')}';
      });
      return;
    }
    if (d.blocked) {
      setState(() {
        _sel = null;
        _lookupMsg =
            '${d.name}: ${gt('This customer is blocked, so credit cannot be given.')}';
      });
      return;
    }
    setState(() {
      _sel = d;
      _full.clear();
      _fullErr = null;
      _lookupMsg = null;
    });
  }

  Future<void> _check(String mobile, {CreditPickDto? pick}) async {
    if (pick != null && !pick.matches(mobile)) {
      setState(() =>
          _fullErr = '${gt('This does not match')} ${pick.maskedMobile}');
      return;
    }
    setState(() {
      _looking = true;
      _lookupMsg = null;
    });
    final (acc, status, msg) =
        await StateScope.read(context).posCreditAccountOf(mobile);
    if (!mounted) return;
    if (acc != null) {
      Navigator.of(context).pop(acc);
      return;
    }
    // A new number is still usable: the till explains why credit is off.
    if (status == 404) {
      Navigator.of(context).pop(CreditAccountDto(mobile: mobile));
      return;
    }
    setState(() {
      _looking = false;
      _lookupMsg = msg ?? gt('Could not look up that customer.');
    });
  }

  void _confirmFull() {
    final sel = _sel;
    if (sel == null) return;
    final v = Validators.mobile(_full.text, required: true);
    if (v != null) {
      setState(() => _fullErr = gt(v));
      return;
    }
    unawaited(_check(_full.text.trim(), pick: sel));
  }

  @override
  Widget build(BuildContext context) {
    final typed = cleanMobile(_q.text);
    return Padding(
      padding: _pad(context),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: gt('Search name or mobile'),
              controller: _q,
              maxLength: 100,
              placeholder: gt('Name or mobile'),
              error: _qErr,
              onChanged: _onQ,
            ),
            const SizedBox(height: 8),
            ChipRail(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppChip(gt('With credit'),
                    selected: !_all,
                    onTap: () {
                      setState(() => _all = false);
                      _load();
                    }),
              ),
              AppChip(gt('All customers'),
                  selected: _all,
                  onTap: () {
                    setState(() => _all = true);
                    _load();
                  }),
            ]),
            if (typed != null) ...[
              const SizedBox(height: 8),
              AppButton('${gt('Check credit for')} $typed',
                  variant: BtnVariant.secondary,
                  block: true,
                  loading: _looking && _sel == null,
                  onTap: _looking ? null : () => _check(typed)),
            ],
            if (_lookupMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_lookupMsg!,
                    style: _sub.copyWith(color: AppColors.red)),
              ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.red)),
              )
            else if (_err != null)
              Hint(_err!)
            else if (_rows.isEmpty && _qErr == null)
              Hint(_q.text.trim().isEmpty
                  ? gt('No customer has credit yet. Type a mobile number to check one.')
                  : gt('No credit customer matches that. Type the full 10-digit mobile to check it.'))
            else
              for (final d in _rows) _pickRow(d),
            if (_hasMore && !_loading) ...[
              const SizedBox(height: 8),
              AppButton(gt('Load more'),
                  variant: BtnVariant.secondary,
                  block: true,
                  loading: _more,
                  onTap: _more ? null : () => _load(more: true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pickRow(CreditPickDto d) {
    final low = d.availablePaise <= 0;
    final off = d.limitPaise <= 0 || d.blocked;
    final sel = _sel != null && _sel!.customerId == d.customerId;
    return Container(
      decoration: BoxDecoration(
        color: sel ? SectionPalette.sales.tint : Colors.transparent,
        border: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(d),
          child: Opacity(
            opacity: off ? .6 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name.isNotEmpty ? d.name : gt('Name not saved'),
                          style: _h),
                      Text(
                          '${d.maskedMobile} - ${gt('Limit')} ${_rs(d.limitPaise)}'
                          ' - ${gt('Owes')} ${_rs(d.balancePaise)}',
                          style: _sub),
                      if (d.limitPaise <= 0)
                        Text(gt('Credit not enabled'),
                            style: _sub.copyWith(
                                color: AppColors.red,
                                fontWeight: FontWeight.w800))
                      else if (d.blocked)
                        Text(gt('Blocked'),
                            style: _sub.copyWith(
                                color: AppColors.red,
                                fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_rs(d.availablePaise),
                        style: _h.copyWith(
                            color: low ? AppColors.red : AppColors.green)),
                    Text(gt('available'), style: _sub),
                  ],
                ),
              ]),
            ),
          ),
        ),
        if (sel)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppField(
                    label:
                        '${gt('Type the full mobile of')} ${d.name.isEmpty ? d.maskedMobile : d.name} (${d.maskedMobile})',
                    controller: _full,
                    numeric: true,
                    maxLength: 10,
                    autofocus: true,
                    error: _fullErr,
                    onChanged: (_) => setState(() => _fullErr = null),
                    onEditingComplete: _confirmFull,
                  ),
                  const SizedBox(height: 8),
                  AppButton(gt('Use this customer'),
                      block: true,
                      size: BtnSize.sm,
                      loading: _looking,
                      onTap: _looking ? null : _confirmFull),
                ]),
          ),
      ]),
    );
  }
}
