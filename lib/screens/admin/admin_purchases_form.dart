import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto.dart';
import '../../data/api/purchase_dto.dart';
import '../../data/purchase_store.dart';
import '../../data/validators.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import '../../widgets/gst_picker.dart';
import 'admin_purchases_common.dart';
import 'admin_purchases_newitem.dart';
import 'admin_purchases_reports.dart' show showPriceHistory;
import 'admin_purchases_suppliers.dart' show normPhone;

// ---------------------------------------------------------------------------
// Estimate (display only; the server calculates the real figures)
// ---------------------------------------------------------------------------

/// Percent text with at most 2 decimals -> hundredths (`2.5` -> 250).
int? _pctH(String t) {
  final s = t.trim();
  if (s.isEmpty) return 0;
  if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(s)) return null;
  final v = (double.parse(s) * 100).round();
  return v > 10000 ? null : v;
}

/// Spread [total] over [weights] by largest remainder (adds up exactly).
List<int> _spread(int total, List<int> weights) {
  final sum = weights.fold<int>(0, (a, b) => a + b);
  if (total <= 0 || sum <= 0) return List<int>.filled(weights.length, 0);
  final base = [for (final w in weights) total * w ~/ sum];
  var left = total - base.fold<int>(0, (a, b) => a + b);
  final order = List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) => ((total * weights[b]) % sum).compareTo((total * weights[a]) % sum));
  for (final i in order) {
    if (left <= 0) break;
    base[i]++;
    left--;
  }
  return base;
}

class _EstLine {
  int taxable = 0, cgst = 0, sgst = 0, igst = 0, cess = 0, total = 0;
  double landedUnit = 0;
}

/// What goes on the wire for one line. A weighed product is stocked in grams
/// (ml), but the cashier works in the product's own unit: `12` kg at Rs 55 per
/// kg. The line converts: qty 12000 g; cost per gram is a whole number of paise
/// on the server, so when Rs 55/kg is not a whole paise per gram the cost is
/// rounded up and [adj] (a rounding discount) brings the line back to the exact
/// amount.
class _Wire {
  int q = 0, f = 0, unitCost = 0, adj = 0, exactGross = 0;
  bool ok = true;
}

double? _dec(String s) {
  final t = s.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

class _Est {
  final lines = <_EstLine>[];
  final slabs = <SlabRow>[];
  int taxable = 0, tax = 0, freight = 0, freightGst = 0, roundOff = 0, total = 0;
  int units = 0;
}

class _L {
  _L(this.productId, this.name, this.unit, this.packSize);
  final String productId, name, unit, packSize;
  final qty = TextEditingController();
  final free = TextEditingController();
  final cost = TextEditingController();
  final disc = TextEditingController();
  final cess = TextEditingController();
  final hsn = TextEditingController();
  final mrp = TextEditingController();
  final price = TextEditingController();
  final batch = TextEditingController();
  int gst = 0;

  /// False until the product's own GST rate was read or the user chose one;
  /// then `gstPercent` is left out and the server uses the product's rate.
  bool gstSet = false;

  /// Product defaults (GST / HSN) were read or the read failed.
  bool lookupDone = false;
  bool weighed = false;
  bool discPct = true;
  bool more = false;
  bool apply = false;
  String? expiry;
  PurchaseLookupDto? lookup;

  PackInfo get pack => PackInfo(unit, packSize, weighed: weighed);

  /// Unit the user typed the quantity and cost in (weighed lines only).
  String wUnit = '';

  /// `kg`, `g`, `L` or `ml`: the chosen unit, else the product's own unit.
  String get wu {
    if (wUnit.isNotEmpty) return wUnit;
    final u = unit.trim().toLowerCase();
    if (const ['l', 'ltr', 'litre', 'liter'].contains(u)) return 'L';
    if (u == 'ml') return 'ml';
    if (const ['g', 'gm', 'gms', 'gram', 'grams'].contains(u)) return 'g';
    return 'kg';
  }

  bool get liquid => wu == 'L' || wu == 'ml';

  /// Grams (ml) in one [wu].
  int get factor => (wu == 'kg' || wu == 'L') ? 1000 : 1;

  /// Qty, free qty and cost converted to what the server stores.
  _Wire wire(String Function(TextEditingController) t) {
    final w = _Wire();
    if (!weighed) {
      w.q = int.tryParse(t(qty).trim()) ?? 0;
      final fr = t(free).trim();
      w.f = fr.isEmpty ? 0 : (int.tryParse(fr) ?? -1);
      w.unitCost = rsToPaise(t(cost)) ?? 0;
      w.exactGross = w.q * w.unitCost;
      w.ok = int.tryParse(t(qty).trim()) != null && w.f >= 0;
      return w;
    }
    final qd = _dec(t(qty));
    final fd = t(free).trim().isEmpty ? 0.0 : _dec(t(free));
    final c = rsToPaise(t(cost)) ?? 0; // paise per chosen unit
    w.ok = qd != null && fd != null;
    w.q = qd == null ? 0 : (qd * factor).round();
    w.f = fd == null ? 0 : (fd * factor).round();
    w.unitCost = (c + factor - 1) ~/ factor;
    w.exactGross = (w.q * c + factor ~/ 2) ~/ factor;
    final gross = w.q * w.unitCost;
    w.adj = gross > w.exactGross ? gross - w.exactGross : 0;
    return w;
  }

  void dispose() {
    for (final c in [qty, free, cost, disc, cess, hsn, mrp, price, batch]) {
      c.dispose();
    }
  }
}

/// `#/admin/purchases?new=1[&supplier=<id>]` - record a supplier delivery
/// (`POST /admin/purchases`, `70-purchases.md` section 5).
class AdminPurchaseFormScreen extends StatefulWidget {
  final String? supplierId;
  const AdminPurchaseFormScreen({super.key, this.supplierId});
  @override
  State<AdminPurchaseFormScreen> createState() => _AdminPurchaseFormScreenState();
}

class _AdminPurchaseFormScreenState extends State<AdminPurchaseFormScreen> {
  final _store = PurchaseStore.instance;

  /// One key per delivery form: created on open, kept through retries,
  /// replaced only after a save or a "key reused" refusal.
  String _key = newIdempotencyKey();

  // supplier
  final _supName = TextEditingController();
  final _supPhone = TextEditingController();
  final _supGstin = TextEditingController();
  final _supStateCode = TextEditingController();
  SupplierDto? _sup;
  List<SupplierDto> _supHits = const [];
  Timer? _supDebounce;
  int _supGen = 0;
  // document
  final _invoice = TextEditingController();
  final _note = TextEditingController();
  final _attachNote = TextEditingController();
  String _invDate = todayYmd();
  String _recDate = todayYmd();
  String? _dueDate;
  String _gstMode = 'REGULAR';
  String _shopState = '24';
  // lines
  final _find = TextEditingController();
  Timer? _findDebounce;
  List<AdminProductDto> _prodHits = const [];
  String? _searchedQ;
  final List<_L> _lines = [];
  // discount / freight / rounding
  final _docDisc = TextEditingController();
  bool _docPct = true;
  final _freight = TextEditingController();
  int _freightGst = 0;
  bool _round = false;
  final _billTotal = TextEditingController();
  // payment
  String _pay = 'unpaid'; // unpaid | full | part
  final _payAmt = TextEditingController();
  String _payMode = 'CASH';
  final _payRef = TextEditingController();

  Map<String, String> _err = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _store.shopStateCode().then((s) {
      if (mounted) setState(() => _shopState = s);
    });
    _store.defaultGstMode().then((m) {
      if (mounted && _lines.isEmpty) setState(() => _gstMode = m);
    });
    final sid = widget.supplierId;
    if (sid != null && sid.isNotEmpty) {
      _store.api.supplier(sid).then((s) {
        if (mounted && s.active) _pickSupplier(s);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _supDebounce?.cancel();
    _findDebounce?.cancel();
    for (final c in [
      _supName, _supPhone, _supGstin, _supStateCode, _invoice, _note, _attachNote, _find,
      _docDisc, _freight, _billTotal, _payAmt, _payRef
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  /// Field error by the form's own key. The server names some fields
  /// differently (`phone`, `gstin`) or without the `items[n].` prefix; those
  /// are matched here, and anything not shown anywhere ends up in the note
  /// at the bottom ([_leftovers]).
  static const _alias = {'supplierPhone': 'phone', 'supplierGstin': 'gstin'};

  String? _e(String f) {
    final hit = _err[f];
    if (hit != null) return hit;
    final a = _alias[f];
    if (a != null && _err[a] != null) return _err[a];
    final m = RegExp(r'^items\[(\d+)\]\.(\w+)$').firstMatch(f);
    if (m != null && _lines.length == 1) return _err[m.group(2)!];
    return null;
  }

  static const _itemKeys = {
    'qty', 'freeQty', 'unitCostPaise', 'discountPercent', 'discountPaise',
    'gstPercent', 'cessPercent', 'hsn', 'mrpPaise', 'sellingPricePaise',
    'batchNo', 'applyToVariant', 'expiryDate', 'productId'
  };
  static const _headerKeys = {
    'supplierName', 'supplierId', 'supplierPhone', 'supplierGstin',
    'supplierStateCode', 'phone', 'gstin', 'invoiceNo', 'invoiceDate',
    'receivedDate', 'note', 'attachmentNote', 'gstMode', 'docDiscountPercent',
    'docDiscountPaise', 'freightPaise', 'freightGstPercent',
    'expectedTotalPaise', 'paidPaise', 'paymentMode', 'paymentRef', 'dueDate',
    'items', '_'
  };

  /// Server messages that no input shows (an item error with several lines,
  /// an unknown key): listed so nothing is lost.
  String? get _leftovers {
    final out = <String>[];
    _err.forEach((k, v) {
      if (k == '_') return;
      final indexed = RegExp(r'^items\[\d+\]\.').hasMatch(k);
      if (indexed) return;
      if (_itemKeys.contains(k) && _lines.length == 1) return;
      if (_headerKeys.contains(k)) return;
      out.add('$k: $v');
    });
    for (final k in _itemKeys) {
      if (_err[k] != null && _lines.length > 1) out.add('$k: ${_err[k]}');
    }
    return out.isEmpty ? null : out.join('\n');
  }

  // ---- supplier ------------------------------------------------------------

  void _supChanged(String v) {
    setState(() => _sup = null);
    _supDebounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) {
      setState(() => _supHits = const []);
      return;
    }
    _supDebounce = Timer(const Duration(milliseconds: 300), () async {
      final gen = ++_supGen;
      try {
        final r = await _store.api.suppliers(q: q, active: true, size: 10);
        if (mounted && gen == _supGen) setState(() => _supHits = r.items);
      } catch (_) {
        // typing a new name still works
      }
    });
  }

  void _pickSupplier(SupplierDto s) {
    setState(() {
      _sup = s;
      _supName.text = s.name;
      _supHits = const [];
    });
  }

  String get _supState {
    final s = _sup;
    if (s != null) {
      if (s.stateCode.isNotEmpty) return s.stateCode;
      if (s.gstin.length >= 2) return s.gstin.substring(0, 2);
      return '';
    }
    final g = _supGstin.text.trim();
    if (g.length >= 2 && RegExp(r'^\d\d').hasMatch(g)) return g.substring(0, 2);
    final st = _supStateCode.text.trim();
    return RegExp(r'^\d\d$').hasMatch(st) ? st : '';
  }

  bool get _inter => _supState.isNotEmpty && _supState != _shopState;

  // ---- products ------------------------------------------------------------

  void _findChanged(String v) {
    _findDebounce?.cancel();
    _searchedQ = null;
    if (v.trim().isEmpty) {
      setState(() => _prodHits = const []);
      return;
    }
    _findDebounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final q = _find.text.trim();
    if (q.isEmpty) {
      setState(() => _prodHits = const []);
      return;
    }
    try {
      final page = await Api.instance.admin.listProducts(q: q, size: 20);
      if (mounted) {
        setState(() {
          _prodHits = page.items;
          _searchedQ = q;
        });
      }
    } catch (e) {
      if (mounted) showToast(purchaseError(e), 'error');
    }
  }

  Future<void> _addLine(AdminProductDto p) async {
    final id = p.id;
    if (id == null) return;
    if (_lines.any((l) => l.productId == id)) {
      showToast(gt('This product is already in the list.'), 'info');
      return;
    }
    _store.rememberPack(id, p.unit, p.packSize);
    final l = _L(id, p.nameEn ?? 'Item', p.unit ?? '', p.packSize ?? '');
    setState(() {
      _lines.add(l);
      _prodHits = const [];
      _searchedQ = null;
      _find.clear();
    });
    _store.api.isWeighed(id).then((w) {
      _store.rememberPack(id, p.unit, p.packSize, weighed: w);
      if (mounted) setState(() => l.weighed = w);
    }).catchError((_) {});
    try {
      final lk = await _store.api.lookup(id);
      if (!mounted) return;
      setState(() {
        l.lookup = lk;
        if (Validators.gstSlabs.contains(lk.gstPercent)) {
          l.gst = lk.gstPercent;
          l.gstSet = true;
        }
        if (l.hsn.text.isEmpty) l.hsn.text = lk.hsn;
        l.lookupDone = true;
      });
    } catch (_) {
      // defaults are a convenience only
      if (mounted) setState(() => l.lookupDone = true);
    }
  }

  /// "+ Add new item": create the product without leaving the bill, then put
  /// it straight on a line (GST from what was just entered).
  Future<void> _newItem() async {
    final r = await showNewItemSheet(context, presetName: _find.text.trim());
    if (r == null || !mounted) return;
    final p = r.product;
    final id = p.id;
    if (id == null) return;
    _store.rememberPack(id, p.unit, p.packSize, weighed: r.weighed);
    final l = _L(id, p.nameEn ?? 'Item', p.unit ?? '', p.packSize ?? '')
      ..weighed = r.weighed
      ..gst = r.gstPercent
      ..gstSet = true
      ..lookupDone = true;
    l.hsn.text = r.hsn;
    if (p.mrpPaise > 0) l.mrp.text = paiseToText(p.mrpPaise);
    setState(() {
      _lines.add(l);
      _prodHits = const [];
      _searchedQ = null;
      _find.clear();
    });
    showToast(pgt('Item added to inventory and to this bill'));
  }

  // ---- estimate ------------------------------------------------------------

  _Est _estimate() {
    final e = _Est();
    final n = _lines.length;
    final gross = <int>[], before = <int>[], qtys = <int>[], frees = <int>[];
    for (final l in _lines) {
      final w = l.wire((c) => c.text);
      final q = w.q;
      final f = w.f < 0 ? 0 : w.f;
      final g = q * w.unitCost;
      var d = 0;
      if (l.discPct) {
        d = (w.exactGross * (_pctH(l.disc.text) ?? 0) + 5000) ~/ 10000;
      } else {
        d = rsToPaise(l.disc.text) ?? 0;
      }
      d += w.adj;
      if (d > g) d = g;
      qtys.add(q);
      frees.add(f);
      gross.add(g);
      before.add(g - d);
    }
    final sumBefore = before.fold<int>(0, (a, b) => a + b);
    var doc = 0;
    if (_docPct) {
      doc = (sumBefore * (_pctH(_docDisc.text) ?? 0) + 5000) ~/ 10000;
    } else {
      doc = rsToPaise(_docDisc.text) ?? 0;
    }
    if (doc > sumBefore) doc = sumBefore;
    final shares = _spread(doc, before);
    final none = _gstMode == 'NONE';
    final comp = _gstMode == 'COMPOSITION';
    final by = <int, SlabRow>{};
    final taxables = <int>[];
    for (var i = 0; i < n; i++) {
      final l = _lines[i];
      final t = before[i] - shares[i];
      final rate = none ? 0 : l.gst;
      final cessH = none ? 0 : (_pctH(l.cess.text) ?? 0);
      final gst = (t * rate + 50) ~/ 100;
      final cess = (t * cessH + 5000) ~/ 10000;
      final x = _EstLine()..taxable = t;
      if (_inter) {
        x.igst = gst;
      } else {
        x.cgst = gst ~/ 2;
        x.sgst = gst - gst ~/ 2;
      }
      x.cess = cess;
      x.total = t + gst + cess;
      e.lines.add(x);
      taxables.add(t);
      final r = by.putIfAbsent(rate, () => SlabRow('$rate%', rate));
      r.taxable += t;
      r.cgst += x.cgst;
      r.sgst += x.sgst;
      r.igst += x.igst;
      r.cess += cess;
      e.taxable += t;
      e.tax += gst + cess;
      e.units += qtys[i] + frees[i];
    }
    e.slabs.addAll(by.values.toList()..sort((a, b) => a.rate.compareTo(b.rate)));
    final fr = rsToPaise(_freight.text) ?? 0;
    final fg = none || fr == 0 ? 0 : (fr * _freightGst + 50) ~/ 100;
    e.freight = fr;
    e.freightGst = fg;
    if (fr > 0 || fg > 0) {
      final row = SlabRow('${gt('Freight')} $_freightGst%', _freightGst, taxable: fr);
      if (_inter) {
        row.igst = fg;
      } else {
        row.cgst = fg ~/ 2;
        row.sgst = fg - fg ~/ 2;
      }
      e.slabs.add(row);
    }
    final w = taxables.fold<int>(0, (a, b) => a + b) > 0 ? taxables : qtys;
    final frShare = _spread(fr, w);
    final fgShare = _spread(fg, w);
    var sub = fr + fg;
    for (var i = 0; i < n; i++) {
      final x = e.lines[i];
      sub += x.total;
      final units = qtys[i] + frees[i];
      final cost = x.taxable +
          (comp ? x.cgst + x.sgst + x.igst + x.cess + fgShare[i] : 0) +
          frShare[i];
      x.landedUnit = units > 0 ? cost / units : 0;
    }
    e.roundOff = _round ? ((sub + 50) ~/ 100) * 100 - sub : 0;
    e.total = sub + e.roundOff;
    return e;
  }

  // ---- save ----------------------------------------------------------------

  Future<void> _save({int? acceptTotal}) async {
    final err = <String, String>{};
    void chk(String f, String? m) {
      if (m != null) err[f] = pgt(m);
    }

    if (_sup == null) {
      final st = _supStateCode.text.trim();
      final g = _supGstin.text.trim().toUpperCase();
      if (st.isNotEmpty && !RegExp(r'^\d{2}$').hasMatch(st)) {
        err['supplierStateCode'] = gt('State code is 2 digits');
      } else if (st.isNotEmpty && g.length >= 2 && RegExp(r'^\d\d').hasMatch(g) && st != g.substring(0, 2)) {
        err['supplierStateCode'] = gt('State must match the GSTIN');
      }
      chk('supplierName', Validators.text(_supName.text, label: 'Supplier name', required: true, max: 120));
      chk('supplierPhone', Validators.mobile(normPhone(_supPhone.text)));
      chk('supplierGstin', Validators.gstin(_supGstin.text));
    }
    chk('invoiceNo', Validators.text(_invoice.text, label: 'Invoice no.', max: 60));
    chk('note', Validators.text(_note.text, label: 'Note', max: 200));
    chk('attachmentNote', Validators.text(_attachNote.text, label: 'Link or note', max: 500));
    final today = todayYmd();
    if (_invDate.compareTo(today) > 0) err['invoiceDate'] = gt('Invoice date cannot be in the future');
    if (_recDate.compareTo(today) > 0) err['receivedDate'] = gt('Received date cannot be in the future');
    if (_dueDate != null && _dueDate!.compareTo(_invDate) < 0) {
      err['dueDate'] = gt('Due date cannot be before the invoice date');
    }
    if (_lines.isEmpty) err['items'] = gt('Add at least one product');
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final p = 'items[$i]';
      final w = l.wire((c) => c.text);
      final int? q = w.ok && w.q > 0 ? w.q : (w.ok ? 0 : null);
      final int? f = w.ok && w.f >= 0 ? w.f : null;
      final c = rsToPaise(l.cost.text) == null ? null : w.unitCost;
      if (l.weighed && (_dec(l.qty.text) ?? 0) > 0 && w.q < 1) {
        err['$p.qty'] = gt('That is less than 1 ${l.wu == 'kg' ? 'g' : l.wu == 'L' ? 'ml' : l.wu}: enter a larger quantity');
      } else if (q == null || q < 1 || q > 1000000) {
        err['$p.qty'] = l.weighed
            ? gt('Quantity must be at most ${(1000000 / l.factor).toStringAsFixed(0)} ${l.wu}')
            : gt('Quantity must be 1 to 1,000,000');
      }
      if (f == null || f < 0) {
        err['$p.freeQty'] = gt('Free quantity must be 0 or more');
      } else if (q != null && q + f > 1000000) {
        err['$p.freeQty'] = gt('Paid + free units can be 1,000,000 at most');
      }
      if (c == null) {
        err['$p.unitCostPaise'] = gt('Enter the cost per unit (before tax)');
      } else if (c > 100000000) {
        err['$p.unitCostPaise'] = gt('Cost is too high');
      }
      int? discPaise;
      double? discPct;
      if (l.disc.text.trim().isNotEmpty) {
        if (l.discPct) {
          final h = _pctH(l.disc.text);
          if (h == null) {
            err['$p.discountPercent'] = gt('0 to 100 with at most 2 decimals');
          } else {
            discPct = h / 100;
          }
        } else {
          discPaise = rsToPaise(l.disc.text);
          if (discPaise == null) {
            err['$p.discountPaise'] = gt('Enter a valid amount');
          } else if (q != null && c != null && discPaise > w.exactGross) {
            err['$p.discountPaise'] = gt('Discount cannot be more than the line amount');
          }
        }
      }
      final cessH = l.cess.text.trim().isEmpty ? 0 : _pctH(l.cess.text);
      if (cessH == null) err['$p.cessPercent'] = gt('0 to 100 with at most 2 decimals');
      final hsn = l.hsn.text.trim();
      if (hsn.isNotEmpty && !RegExp(r'^\d{4,8}$').hasMatch(hsn)) {
        err['$p.hsn'] = gt('HSN is 4 to 8 digits');
      }
      int? mrp, price;
      if (l.mrp.text.trim().isNotEmpty) {
        mrp = rsToPaise(l.mrp.text);
        if (mrp == null) err['$p.mrpPaise'] = gt('Enter a valid amount');
      }
      if (l.price.text.trim().isNotEmpty) {
        price = rsToPaise(l.price.text);
        if (price == null) err['$p.sellingPricePaise'] = gt('Enter a valid amount');
      }
      if (mrp != null && price != null && price > mrp) {
        err['$p.sellingPricePaise'] = gt('Selling price cannot be above the MRP');
      }
      if (l.apply && mrp == null && price == null) {
        err['$p.applyToVariant'] = gt('Enter the MRP or the selling price to apply it');
      }
      if (l.batch.text.trim().length > 40) err['$p.batchNo'] = gt('Batch no. is 40 characters at most');
      items.add({
        'productId': l.productId,
        'qty': q ?? 0,
        if ((f ?? 0) > 0) 'freeQty': f,
        'unitCostPaise': c ?? 0,
        // A weighed line whose cost per gram is not a whole paise sends its
        // rounding as an amount (the percent is worked out on the exact line).
        if (discPct != null && discPct > 0 && w.adj == 0) 'discountPercent': discPct,
        if (w.adj > 0)
          'discountPaise': w.adj +
              (discPct != null
                  ? (w.exactGross * ((discPct * 100).round()) + 5000) ~/ 10000
                  : (discPaise ?? 0))
        else if (discPaise != null && discPaise > 0)
          'discountPaise': discPaise,
        if (l.gstSet) 'gstPercent': l.gst,
        if ((cessH ?? 0) > 0) 'cessPercent': cessH! / 100,
        if (hsn.isNotEmpty) 'hsn': hsn,
        if (mrp != null) 'mrpPaise': mrp,
        if (price != null) 'sellingPricePaise': price,
        if (l.batch.text.trim().isNotEmpty) 'batchNo': l.batch.text.trim(),
        if (l.expiry != null) 'expiryDate': l.expiry,
        if (l.apply) 'applyToVariant': true,
      });
    }
    int? docPaise;
    double? docPct;
    if (_docDisc.text.trim().isNotEmpty) {
      if (_docPct) {
        final h = _pctH(_docDisc.text);
        if (h == null) {
          err['docDiscountPercent'] = gt('0 to 100 with at most 2 decimals');
        } else if (h > 0) {
          docPct = h / 100;
        }
      } else {
        docPaise = rsToPaise(_docDisc.text);
        if (docPaise == null) err['docDiscountPaise'] = gt('Enter a valid amount');
      }
    }
    int? freight;
    if (_freight.text.trim().isNotEmpty) {
      freight = rsToPaise(_freight.text);
      if (freight == null) err['freightPaise'] = gt('Enter a valid amount');
    }
    int? billTotal = acceptTotal;
    if (billTotal == null && _billTotal.text.trim().isNotEmpty) {
      billTotal = rsToPaise(_billTotal.text);
      if (billTotal == null) err['expectedTotalPaise'] = gt('Enter a valid amount');
    }
    int? paid;
    if (_pay == 'part') {
      paid = rsToPaise(_payAmt.text);
      if (paid == null || paid < 1) err['paidPaise'] = gt('Enter the amount paid now');
    }
    if (_pay != 'unpaid') {
      chk('paymentRef', Validators.text(_payRef.text, label: 'Reference', max: 80));
    }
    if (err.isNotEmpty) {
      setState(() => _err = err);
      showToast(gt('Please check the highlighted fields'), 'error');
      return;
    }

    final body = <String, dynamic>{
      if (_sup != null) 'supplierId': _sup!.id else 'supplierName': _supName.text.trim(),
      if (_sup == null && _supPhone.text.trim().isNotEmpty) 'supplierPhone': normPhone(_supPhone.text),
      if (_sup == null && _supGstin.text.trim().isNotEmpty) 'supplierGstin': _supGstin.text.trim().toUpperCase(),
      if (_sup == null && _supStateCode.text.trim().isNotEmpty) 'supplierStateCode': _supStateCode.text.trim(),
      if (_invoice.text.trim().isNotEmpty) 'invoiceNo': _invoice.text.trim(),
      'invoiceDate': _invDate,
      'receivedDate': _recDate,
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      if (_attachNote.text.trim().isNotEmpty) 'attachmentNote': _attachNote.text.trim(),
      'gstMode': _gstMode,
      if (docPct != null) 'docDiscountPercent': docPct,
      if (docPaise != null && docPaise > 0) 'docDiscountPaise': docPaise,
      if ((freight ?? 0) > 0) 'freightPaise': freight,
      if ((freight ?? 0) > 0) 'freightGstPercent': _gstMode == 'NONE' ? 0 : _freightGst,
      'roundToRupee': _round,
      if (billTotal != null) 'expectedTotalPaise': billTotal,
      if (_pay == 'full') 'paymentStatus': 'PAID',
      if (_pay == 'part') 'paymentStatus': 'PARTIAL',
      if (_pay == 'part') 'paidPaise': paid,
      if (_pay != 'unpaid') 'paymentMode': _payMode,
      if (_pay != 'unpaid' && _payRef.text.trim().isNotEmpty) 'paymentRef': _payRef.text.trim(),
      if (_dueDate != null) 'dueDate': _dueDate,
      'items': items,
    };

    setState(() {
      _busy = true;
      _err = {};
    });
    ApiException.clearFields();
    try {
      final p = await _store.api.create(body, _key);
      if (!mounted) return;
      if (p.warnings.isNotEmpty) _store.postWarnings[p.id] = p.warnings;
      showToast('${gt('Purchase recorded')} · ${pRs(p.totalCostPaise)}');
      _key = newIdempotencyKey();
      _store.loadPayables();
      Nav.instance.replace('/admin/purchases?id=${p.id}');
    } on ApiException catch (ex) {
      if (!mounted) return;
      if (ex.code == 'TOTAL_MISMATCH') {
        final server = _serverTotal(ex);
        setState(() => _busy = false);
        if (server != null) _askTotal(server, billTotal);
        return;
      }
      if (ex.code == 'IDEMPOTENCY_KEY_REUSED') {
        _key = newIdempotencyKey();
        showToast(
            gt('This form was already used with other details. Check the purchase list before saving again.'),
            'error');
        setState(() => _err = {'_': gt('This form was already used with other details. Check the purchase list before saving again.')});
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _err = ex.fields.isNotEmpty ? ex.fields : {'_': ex.messageWithRef};
        _busy = false;
      });
      showToast(ex.messageWithRef, 'error');
    } catch (ex) {
      // Outcome unknown: the SAME key stays so a retry cannot double-receive.
      if (mounted) {
        setState(() {
          _err = {'_': purchaseError(ex)};
          _busy = false;
        });
      }
    }
  }

  int? _serverTotal(ApiException ex) {
    final p = ex.payload;
    if (p is Map && p['details'] is Map) {
      final t = (p['details'] as Map)['totalPaise'];
      if (t is num) return t.toInt();
    }
    return null;
  }

  Future<void> _askTotal(int server, int? typed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gt('Total does not match')),
        content: Text('${gt('The calculated total is')} ${pRs(server)}'
            '${typed == null ? '' : ', ${gt('not')} ${pRs(typed)}'}. '
            '${gt('Check the quantities, costs and GST, or accept the calculated total.')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(gt('Check lines'))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(gt('Accept and save'),
                  style: const TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) {
      _billTotal.text = paiseToText(server);
      _save(acceptTotal: server);
    }
  }

  // ---- UI ------------------------------------------------------------------

  Widget _dateField(String label, String? value, ValueChanged<String?> onPick,
      {String? error, String hint = '', DateTime? last, bool clearable = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () async {
          final r = await pickYmd(context, value, last: last);
          if (r != null) onPick(r);
        },
        child: AbsorbPointer(
          child: AppField(
            label: label,
            value: value == null ? hint : pDate(value),
            readOnly: true,
            error: error,
          ),
        ),
      ),
      if (clearable && value != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: AppLink('Clear', onTap: () => onPick(null)),
        ),
    ]);
  }

  Widget _supplierCard() {
    return CardPanel(
      title: gt('Supplier'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppField(
          label: 'Supplier',
          controller: _supName,
          maxLength: 120,
          placeholder: 'Type to search, or a new name',
          error: _e('supplierName') ?? _e('supplierId'),
          onChanged: _supChanged,
        ),
        if (_supHits.isNotEmpty && _sup == null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
              boxShadow: AppColors.sh1,
            ),
            child: Column(children: [
              for (final s in _supHits)
                InkWell(
                  onTap: () => _pickSupplier(s),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: pHead),
                      Text(
                          [
                            if (s.phone.isNotEmpty) s.phone,
                            if (s.gstin.isNotEmpty) s.gstin,
                            '${s.purchaseCount} ${gt('purchases')}',
                            if (s.totalDuePaise > 0) '${gt('You owe')} ${pRs(s.totalDuePaise)}',
                          ].join(' · '),
                          style: pSub),
                    ]),
                  ),
                ),
            ]),
          ),
        if (_sup != null) ...[
          const SizedBox(height: 6),
          Text(
              [
                if (_sup!.gstin.isNotEmpty) 'GSTIN ${_sup!.gstin}',
                if (_sup!.paymentTermsDays > 0) '${gt('Terms')} ${_sup!.paymentTermsDays} ${gt('days')}',
                if (_sup!.totalDuePaise > 0) '${gt('You owe')} ${pRs(_sup!.totalDuePaise)}',
                if (_sup!.creditPaise > 0) '${gt('Credit')} ${pRs(_sup!.creditPaise)}',
              ].join(' · '),
              style: pSub),
        ] else if (_supName.text.trim().isNotEmpty) ...[
          const PHint('No supplier picked: this name is found or added as a new supplier.'),
          const SizedBox(height: 10),
          FieldRow(children: [
            AppField(
                label: 'Supplier mobile (optional)',
                controller: _supPhone,
                keyboardType: TextInputType.phone,
                maxLength: 20,
                error: _e('supplierPhone'),
                onChanged: (_) => setState(() {})),
            AppField(
                label: 'Supplier GSTIN (optional)',
                controller: _supGstin,
                uppercase: true,
                maxLength: 15,
                error: _e('supplierGstin'),
                onChanged: (_) => setState(() {})),
          ]),
          if (_supGstin.text.trim().length < 2) ...[
            const SizedBox(height: 10),
            FieldRow(children: [
              AppField(
                  label: 'Supplier state code (optional, 2 digits)',
                  controller: _supStateCode,
                  numeric: true,
                  maxLength: 2,
                  error: _e('supplierStateCode'),
                  onChanged: (_) => setState(() {})),
              const SizedBox.shrink(),
            ]),
            const PHint('Needed for an inter-state purchase when the supplier has no GSTIN: another state means IGST.'),
          ] else if (_e('supplierStateCode') != null)
            PNote(_e('supplierStateCode')!, error: true),
        ],
        if (_supState.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                _inter
                    ? '${gt('Inter-state purchase: IGST applies')} (${gt('supplier state')} $_supState, ${gt('shop')} $_shopState).'
                    : gt('Same state: CGST + SGST applies.'),
                style: pSub.copyWith(color: AppColors.navy)),
          ),
      ]),
    );
  }

  Widget _invoiceCard() {
    return CardPanel(
      title: gt('Invoice'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppField(
            label: 'Supplier invoice no. (optional)',
            controller: _invoice,
            maxLength: 60,
            error: _e('invoiceNo')),
        const SizedBox(height: 10),
        FieldRow(children: [
          _dateField('Invoice date', _invDate, (v) => setState(() => _invDate = v ?? _invDate),
              error: _e('invoiceDate'), last: DateTime.now()),
          _dateField('Received date', _recDate, (v) => setState(() => _recDate = v ?? _recDate),
              error: _e('receivedDate'), last: DateTime.now()),
        ]),
        const SizedBox(height: 10),
        AppField(label: 'Note (optional)', controller: _note, maxLength: 200, error: _e('note')),
        const SizedBox(height: 10),
        AppField(
            label: 'Invoice link or note (optional)',
            controller: _attachNote,
            maxLength: 500,
            error: _e('attachmentNote')),
        const PHint('You can upload the invoice photo or PDF after saving.'),
        const SizedBox(height: 10),
        Text(gt('GST on this purchase'), style: pHead),
        const SizedBox(height: 6),
        PChoice<String>(
          options: const [
            ('REGULAR', 'Regular'),
            ('COMPOSITION', 'Composition'),
            ('NONE', 'No GST'),
          ],
          value: _gstMode,
          onChanged: (v) => setState(() => _gstMode = v),
        ),
        PNote(
            _gstMode == 'REGULAR'
                ? gt('Regular: GST is claimed back as input credit and is not part of the product cost.')
                : _gstMode == 'COMPOSITION'
                    ? gt('Composition: no credit, all GST is part of the product cost.')
                    : gt('No GST: every rate is treated as 0.')),
        if (_e('gstMode') != null) PNote(_e('gstMode')!, error: true),
      ]),
    );
  }

  Widget _productsCard(_Est est) {
    return CardPanel(
      title: gt('Products received'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppField(
          label: 'Find product',
          controller: _find,
          placeholder: 'Type a name, press Enter',
          onChanged: _findChanged,
          onEditingComplete: _search,
          textInputAction: TextInputAction.search,
        ),
        if (_prodHits.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in _prodHits.take(20))
              AppChip(
                '${p.nameEn ?? 'Item'}${(p.packSize ?? '').isEmpty ? '' : ' · ${normalizePack(p.packSize!)}'}'
                ' · ${p.qtyOnHand} ${gt('in stock')}',
                small: true,
                selected: false,
                onTap: () => _addLine(p),
              ),
          ]),
        ],
        if (_prodHits.isEmpty &&
            _find.text.trim().isNotEmpty &&
            _searchedQ == _find.text.trim()) ...[
          const SizedBox(height: 10),
          PNote(pf('No match for "{0}".', [_find.text.trim()])),
          const SizedBox(height: 6),
          AppButton(pf('No match - add "{0}" as a new item', [_find.text.trim()]),
              icon: 'plus', variant: BtnVariant.secondary, block: true, onTap: _newItem),
        ] else ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AppLink('+ Add new item', onTap: _newItem),
          ),
        ],
        const SizedBox(height: 10),
        if (_lines.isEmpty)
          const PHint('Search for a product and tap it to add a line. Weighed items are entered in their own unit (kg, g, L or ml).')
        else
          for (var i = 0; i < _lines.length; i++) _lineCard(i, est),
        if (_e('items') != null) PNote(_e('items')!, error: true),
      ]),
    );
  }

  Widget _lineCard(int i, _Est est) {
    final l = _lines[i];
    final p = 'items[$i]';
    final x = est.lines[i];
    final wr = l.wire((c) => c.text);
    final q = wr.q;
    final f = wr.f < 0 ? 0 : wr.f;
    final weighed = l.weighed;
    final pack = normalizePack(l.packSize);
    final lk = l.lookup;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('${l.name}${pack.isEmpty || weighed ? '' : ' · $pack'}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: pHead)),
          IconBtn('trash', size: 34, iconSize: 14, onTap: () {
            setState(() {
              _lines.removeAt(i);
              l.dispose();
            });
          }),
        ]),
        if (lk != null && lk.lastPurchaseCostPaise != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Expanded(
                child: Text(
                    '${gt('Last cost')} ${pRs(lk.lastPurchaseCostPaise!)}'
                    '${lk.lastLandedUnitCostPaise == null ? '' : ' (${gt('landed')} ${pRsD(lk.lastLandedUnitCostPaise!, decimals: 4)})'}'
                    '${lk.lastSupplierName == null ? '' : ' · ${lk.lastSupplierName}'}'
                    '${lk.lastInvoiceDate == null ? '' : ' · ${pDate(lk.lastInvoiceDate)}'}',
                    style: pSub),
              ),
              AppLink('Price history', size: 12,
                  onTap: () => showPriceHistory(context, l.productId, l.name)),
            ]),
          ),
        const SizedBox(height: 8),
        FieldRow(children: [
          AppField(
              label: weighed ? 'Qty (${l.wu})' : 'Qty received',
              controller: l.qty,
              numeric: true,
              maxLength: 10,
              error: _e('$p.qty'),
              onChanged: (_) => setState(() {})),
          AppField(
              label: weighed ? 'Free qty (${l.wu})' : 'Free qty',
              controller: l.free,
              numeric: true,
              maxLength: 10,
              error: _e('$p.freeQty'),
              onChanged: (_) => setState(() {})),
          AppField(
              label: weighed ? 'Cost / ${l.wu} (Rs)' : 'Cost / unit (Rs)',
              controller: l.cost,
              numeric: true,
              maxLength: 10,
              error: _e('$p.unitCostPaise'),
              onChanged: (_) => setState(() {})),
        ]),
        if (weighed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Text(gt('Measured in'), style: pSub),
              const SizedBox(width: 8),
              PChoice<String>(
                  options: l.liquid || l.wu == 'ml' || l.wu == 'L'
                      ? const [('L', 'L'), ('ml', 'ml')]
                      : const [('kg', 'kg'), ('g', 'g')],
                  value: l.wu,
                  onChanged: (v) => setState(() => l.wUnit = v)),
            ]),
          ),
        if (q + f > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                '${gt('Stock')} ${qtyWithPack(q + f, l.pack)}'
                '${f > 0 ? ' (${qtyWithPack(q, l.pack, plus: false)} ${gt('paid')} + ${qtyWithPack(f, l.pack, plus: false)} ${gt('free')})' : ''}',
                style: pHead.copyWith(color: AppColors.green)),
          ),
        if (weighed && wr.adj > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                '${gt('The server stores the cost per')} ${l.liquid ? 'ml' : 'gram'} ${gt('in whole paise')} '
                '(${pRs(wr.unitCost)}); ${gt('a rounding adjustment of')} ${pRs(wr.adj)} '
                '${gt('is sent as a line discount so the line total stays exact.')}',
                style: pSub),
          ),
        const SizedBox(height: 10),
        if (!l.lookupDone)
          Text(gt('Reading the product GST rate...'), style: pSub)
        else ...[
          if (lk != null)
            Text('${gt('GST rate')} (${gt('product')}: ${lk.gstPercent}%)', style: pHead),
          GstPicker(
            key: ValueKey('gst-${l.productId}-${l.lookup != null}'),
            productName: l.name,
            initialGst: l.gst,
            initialHsn: l.hsn.text,
            autoApply: l.lookup == null,
            suggestOnlyIfBlank: l.lookup != null,
            hsnError: _e('$p.hsn'),
            onChanged: (g, h) {
              if (g == l.gst && h == l.hsn.text && l.gstSet) return;
              setState(() {
                l.gst = g;
                l.gstSet = true;
                l.hsn.text = h;
              });
            },
          ),
        ],
        if (_e('$p.gstPercent') != null) PNote(_e('$p.gstPercent')!, error: true),
        if (q > 0 && (rsToPaise(l.cost.text) ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                '${gt('Landed cost about')} ${pRsD(x.landedUnit * (weighed ? l.factor : 1))} ${weighed ? '${gt('per')} ${l.wu}' : gt('per unit')} (${gt('estimate')}) · '
                '${gt('line total about')} ${pRs(x.total)}',
                style: pSub.copyWith(color: AppColors.ink2)),
          ),
        const SizedBox(height: 6),
        AppLink(l.more ? 'Hide discount, HSN, MRP, batch, expiry' : 'Discount, HSN, MRP, batch, expiry',
            onTap: () => setState(() => l.more = !l.more)),
        if (l.more) _moreFields(l, p),
      ]),
    );
  }

  Widget _moreFields(_L l, String p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Row(children: [
        Text(gt('Discount'), style: pHead),
        const SizedBox(width: 10),
        PChoice<bool>(
            options: const [(true, '%'), (false, 'Rs')],
            value: l.discPct,
            onChanged: (v) => setState(() {
                  l.discPct = v;
                  l.disc.clear();
                })),
      ]),
      const SizedBox(height: 6),
      FieldRow(children: [
        AppField(
            label: l.discPct ? 'Discount (%)' : 'Discount (Rs)',
            controller: l.disc,
            numeric: true,
            maxLength: 10,
            error: _e('$p.discountPercent') ?? _e('$p.discountPaise'),
            onChanged: (_) => setState(() {})),
        AppField(
            label: 'Cess (%)',
            controller: l.cess,
            numeric: true,
            maxLength: 6,
            error: _e('$p.cessPercent'),
            onChanged: (_) => setState(() {})),
      ]),
      const SizedBox(height: 10),
      FieldRow(children: [
        AppField(
            label: 'MRP (Rs)',
            controller: l.mrp,
            numeric: true,
            maxLength: 10,
            error: _e('$p.mrpPaise'),
            onChanged: (_) => setState(() {})),
        AppField(
            label: 'Selling price (Rs)',
            controller: l.price,
            numeric: true,
            maxLength: 10,
            error: _e('$p.sellingPricePaise'),
            onChanged: (_) => setState(() {})),
      ]),
      if (l.lookup != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
              '${gt('Now in the shop')}: MRP ${pRs(l.lookup!.mrpPaise)} · ${gt('Price')} ${pRs(l.lookup!.pricePaise)}',
              style: pSub),
        ),
      if (l.mrp.text.trim().isNotEmpty || l.price.text.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [
          AppSwitch(value: l.apply, onChanged: (v) => setState(() => l.apply = v)),
          const SizedBox(width: 10),
          Expanded(child: Text(gt('Apply this MRP / price to the product'), style: pBody)),
        ]),
        if (_e('$p.applyToVariant') != null) PNote(_e('$p.applyToVariant')!, error: true),
      ],
      const SizedBox(height: 8),
      FieldRow(children: [
        AppField(
            label: 'Batch no.',
            controller: l.batch,
            maxLength: 40,
            error: _e('$p.batchNo')),
        _dateField('Expiry date', l.expiry,
            (v) => setState(() => l.expiry = v),
            hint: '', last: DateTime(DateTime.now().year + 10), clearable: true),
      ]),
    ]);
  }

  Widget _discountCard(_Est est) {
    return CardPanel(
      title: gt('Discount, freight and rounding'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(gt('Bill discount'), style: pHead),
          const SizedBox(width: 10),
          PChoice<bool>(
              options: const [(true, '%'), (false, 'Rs')],
              value: _docPct,
              onChanged: (v) => setState(() {
                    _docPct = v;
                    _docDisc.clear();
                  })),
        ]),
        const SizedBox(height: 6),
        FieldRow(children: [
          AppField(
              label: _docPct ? 'Discount on whole bill (%)' : 'Discount on whole bill (Rs)',
              controller: _docDisc,
              numeric: true,
              maxLength: 10,
              error: _e('docDiscountPercent') ?? _e('docDiscountPaise'),
              onChanged: (_) => setState(() {})),
          AppField(
              label: 'Freight / transport (Rs, optional)',
              controller: _freight,
              numeric: true,
              maxLength: 10,
              error: _e('freightPaise'),
              onChanged: (_) => setState(() {})),
        ]),
        const PHint('The discount lowers the amount GST is charged on.'),
        if ((rsToPaise(_freight.text) ?? 0) > 0 && _gstMode != 'NONE') ...[
          const SizedBox(height: 8),
          Text(gt('GST on freight'), style: pHead),
          const SizedBox(height: 6),
          PChoice<int>(
            options: [for (final s in Validators.gstSlabs) (s, '$s%')],
            value: _freightGst,
            onChanged: (v) => setState(() => _freightGst = v),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          AppSwitch(value: _round, onChanged: (v) => setState(() => _round = v)),
          const SizedBox(width: 10),
          Expanded(child: Text(gt('Round the total to the nearest rupee'), style: pBody)),
        ]),
        const SizedBox(height: 12),
        AppField(
            label: 'Bill total from the paper invoice (Rs, optional check)',
            controller: _billTotal,
            numeric: true,
            maxLength: 12,
            error: _e('expectedTotalPaise')),
        const PHint('If you type it and our calculation differs, you will be asked before anything is saved.'),
      ]),
    );
  }

  Widget _summaryCard(_Est est) {
    return CardPanel(
      title: gt('GST by slab'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (est.slabs.isEmpty)
          Text(gt('Add products to see the GST split.'), style: pSub)
        else ...[
          GstSlabTable(rows: est.slabs, estimate: true),
          const SizedBox(height: 8),
          PKv('Goods (taxable)', pRs(est.taxable)),
          PKv('GST + cess', pRs(est.tax + est.freightGst)),
          if (est.freight > 0) PKv('Freight', pRs(est.freight)),
          if (est.roundOff != 0) PKv('Round off', pRs(est.roundOff)),
          PKv('Total about', pRs(est.total), bold: true),
        ],
      ]),
    );
  }

  Widget _paymentCard(_Est est) {
    final today = todayYmd();
    return CardPanel(
      title: gt('Payment to supplier'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PChoice<String>(
          options: const [
            ('unpaid', 'Pay later'),
            ('part', 'Part paid'),
            ('full', 'Paid in full'),
          ],
          value: _pay,
          onChanged: (v) => setState(() => _pay = v),
        ),
        if (_pay == 'part') ...[
          const SizedBox(height: 10),
          AppField(
              label: 'Paid now (Rs)',
              controller: _payAmt,
              numeric: true,
              maxLength: 12,
              error: _e('paidPaise')),
        ],
        if (_pay != 'unpaid') ...[
          const SizedBox(height: 10),
          Text(gt('Paid by'), style: pHead),
          const SizedBox(height: 6),
          PChoice<String>(
            options: const [
              ('CASH', 'Cash'),
              ('UPI', 'UPI'),
              ('CARD', 'Card'),
              ('BANK', 'Bank'),
              ('CHEQUE', 'Cheque'),
            ],
            value: _payMode,
            onChanged: (v) => setState(() => _payMode = v),
          ),
          if (_e('paymentMode') != null) PNote(_e('paymentMode')!, error: true),
          const SizedBox(height: 10),
          AppField(
              label: 'Reference (UTR / cheque no., optional)',
              controller: _payRef,
              maxLength: 80,
              error: _e('paymentRef')),
        ],
        if (_pay != 'full') ...[
          const SizedBox(height: 10),
          _dateField(
              'Pay by (due date)',
              _dueDate,
              (v) => setState(() => _dueDate = v),
              error: _e('dueDate'),
              hint: _sup != null && _sup!.paymentTermsDays > 0
                  ? '${gt('Automatic')}: ${_sup!.paymentTermsDays} ${gt('days after the invoice')}'
                  : gt('Not set'),
              last: DateTime.now().add(const Duration(days: 730)),
              clearable: true),
        ],
        if (_pay == 'full' && est.total > 0)
          PNote('${gt('About')} ${pRs(est.total)} ${gt('will be recorded as paid.')}'),
        if (_dueDate != null && _dueDate!.compareTo(today) < 0)
          PNote(gt('This due date is already past, so the purchase will show as overdue.')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final est = _estimate();
    return PurchasePage(
      title: gt('New purchase'),
      sub: gt('Record a supplier delivery with GST'),
      back: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _supplierCard(),
        const SizedBox(height: 12),
        _invoiceCard(),
        const SizedBox(height: 12),
        _productsCard(est),
        const SizedBox(height: 12),
        _discountCard(est),
        const SizedBox(height: 12),
        _summaryCard(est),
        const SizedBox(height: 12),
        _paymentCard(est),
        const SizedBox(height: 14),
        if (_err['_'] != null) PNote(_err['_']!, error: true),
        if (_leftovers != null) PNote(_leftovers!, error: true),
        AppButton('Record purchase',
            block: true, loading: _busy, onTap: _busy ? null : _save),
        const SizedBox(height: 8),
        AppButton('Cancel',
            block: true,
            variant: BtnVariant.secondary,
            onTap: _busy ? null : () => pBack()),
        const SizedBox(height: 12),
      ]),
    );
  }
}
