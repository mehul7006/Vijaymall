import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Stepper;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/api/dto.dart';
import '../../data/api/pos_api.dart' show kPosPayModes, normalizePayMode;
import '../../data/api/pos_dto.dart';
import '../../data/validators.dart';
import '../../data/ist.dart';
import '../../data/local_store.dart';
import '../../data/pos_offline.dart';
import '../../data/api/api_service.dart' show Api;
import '../../widgets/payer_detail.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';
import 'pos_extras.dart';
import 'pos_offline_ui.dart';
import 'pos_terminal.dart';

/// `#/admin/pos` — the counter till.
///
/// Fully server-driven: catalog from `GET /pos/products`, barcode lookups
/// via `GET /pos/barcode/{code}`, authoritative pricing from `POST /pos/quote`,
/// sales via `POST /pos/sales` (+ printable receipt), parked carts under
/// `/pos/holds` and today's totals from `GET /pos/reports/day`.
class AdminPosScreen extends StatelessWidget {
  const AdminPosScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PosBody();
}

class _PosBody extends StatefulWidget {
  const _PosBody();

  @override
  State<_PosBody> createState() => _PosBodyState();
}

class _PosBodyState extends State<_PosBody> {
  final _barcode = TextEditingController();
  final _search = TextEditingController();
  final _mobile = TextEditingController();
  final _coupon = TextEditingController();
  final _tendered = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _mdAmount = TextEditingController();
  final _mdReason = TextEditingController();
  final _mdPin = TextEditingController();

  /// Ticket lines: `{'productId': String, 'qty': int}` (the wire `Item`).
  final List<Map<String, dynamic>> _items = [];

  /// Payment lines already locked in for a split/hybrid sale, each
  /// `{'mode': String, 'amountPaise': int, 'reference': String?}`. The line
  /// currently being taken is NOT in here yet — it defaults to whatever is
  /// still outstanding, so the whole set always sums to the bill exactly.
  final List<Map<String, dynamic>> _splits = [];

  String _payMode = 'CASH';
  bool _gu = false;
  String _scanMsg = '';
  bool _discOpen = false;
  bool _discOn = false;
  String? _discErr;
  bool _splitOpen = false;
  SaleRecordDto? _done;
  String _saleFp = '';
  String _saleKey = '';
  String? _resumedHoldId;
  bool _busy = false;
  bool _booted = false;
  Timer? _debounce;

  /// `details.fields` of the last failed charge (`payments[i].mode` ...).
  Map<String, String> _payErrors = const {};
  bool _needPin = false;

  /// Every product the cashier has touched (search chip, scan, resumed hold),
  /// so the stock cap still works after the catalogue list is replaced by a
  /// search result.
  final Map<String, PosProductDto> _known = {};

  /// Credit panel: the customer behind the typed mobile, as last looked up
  /// (`GET /pos/credit/account`). [_credStatus] 404 = number new to the shop.
  CreditAccountDto? _credAcc;
  int _credStatus = 0;
  String? _credMobile;
  String? _credErr;
  bool _credBusy = false;
  String? _lastQuotedMobile;

  /// Money channels per mode (`GET /pos/payment-channels`) and the one chosen
  /// for each mode (mode -> moneyAccountId). The chosen channel's
  /// `moneyAccountId` rides on the payment line.
  List<PayChannelDto> _channels = const [];
  final Map<String, String> _chosen = {};

  /// The card/UPI machine payment of the current bill (P3 F6), if any.
  PosMachineHolder? _machine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    final state = StateScope.read(context);
    final off = PosOffline.instance..init();
    off.addListener(_onOfflineChanged);
    off.startWatch();
    if (off.offline && off.hasCatalogue) state.posProducts = off.products;
    state.posLoadProducts();
    state.posLoadHolds();
    state.posLoadDayReport();
    state.posLoadShop();
    state.posLoadShift();
    unawaited(_loadChannels());
  }

  Future<void> _loadChannels() async {
    final (list, _) = await posTry((api) => api.paymentChannels());
    if (!mounted || list == null) return;
    unawaited(_recoverMachine());
    setState(() {
      _channels = list;
      for (final m in const ['CASH', 'UPI', 'CARD']) {
        final of = list.where((c) => c.mode == m).toList();
        if (of.isEmpty) {
          _chosen.remove(m);
          continue;
        }
        if (of.any((c) => c.moneyAccountId == _chosen[m])) continue;
        final def = of.where((c) => c.isDefault).toList();
        if (def.isNotEmpty) {
          _chosen[m] = def.first.moneyAccountId ?? '';
        } else if (of.length == 1) {
          _chosen[m] = of.first.moneyAccountId ?? '';
        } else {
          _chosen.remove(m);
        }
      }
    });
  }

  static const _kMachineKey = 'vsm.pos.machine';
  bool _recovered = false;

  /// Keeps the open machine payment (and the basket it belongs to) in browser
  /// storage; cleared when the payment ends without money or the bill is made.
  void _persistMachine(PosMachineHolder h, TerminalSessionDto s) {
    final live = s.posSaleId == null && (s.open || s.paid || s.state == 'EXPIRED');
    if (!live) {
      LocalStore.remove(_kMachineKey);
      return;
    }
    LocalStore.set(
        _kMachineKey,
        jsonEncode({
          'sessionId': s.id,
          'reference': h.reference,
          'moneyAccountId': h.channel.moneyAccountId,
          'mode': h.mode,
          'amountPaise': s.amountPaise,
          'items': _items,
          'mobile': _mobileOrNull,
          'holdId': _resumedHoldId,
        }));
  }

  /// After a refresh/crash: read the saved session id and resume (P3 F6).
  Future<void> _recoverMachine() async {
    if (_recovered) return;
    _recovered = true;
    final raw = LocalStore.get(_kMachineKey);
    if (raw == null || raw.isEmpty) return;
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      LocalStore.remove(_kMachineKey);
      return;
    }
    final (s, e) = await posTry((api) => api.getTerminalPayment('${m['sessionId']}'));
    if (!mounted) return;
    if (s == null) {
      if (e != null && e.statusCode == 404) LocalStore.remove(_kMachineKey);
      showToast(gt('A card machine payment was open before the refresh but the server could not be reached. Reload the page to resume it.'), 'error');
      _recovered = false;
      return;
    }
    final state = StateScope.read(context);
    if (s.posSaleId != null) {
      // The bill exists: go to its receipt.
      LocalStore.remove(_kMachineKey);
      final (sale, _) = await posTry((api) => api.getSale(s.posSaleId!));
      if (!mounted || sale == null) return;
      setState(() => _done = sale);
      showToast(gt('The machine payment was already put on a bill. Showing that bill.'));
      return;
    }
    if (!(s.open || s.paid || s.state == 'EXPIRED')) {
      LocalStore.remove(_kMachineKey);
      showToast(gt('The last card machine payment did not go through. You can start a new one.'), 'error');
      return;
    }
    final ch = _channels.where((c) => c.moneyAccountId == m['moneyAccountId']).firstOrNull ??
        PayChannelDto(
            mode: '${m['mode']}',
            moneyAccountId: s.moneyAccountId,
            provider: s.provider,
            name: s.terminalName ?? '',
            terminalId: s.terminalId,
            kind: s.provider == 'manual' ? 'CARD_TERMINAL' : 'CARD_TERMINAL');
    final h = PosMachineHolder(
        reference: '${m['reference'] ?? s.reference}', channel: ch, mode: '${m['mode']}')
      ..session = s;
    h.onSession = (x) => _persistMachine(h, x);
    if (_items.isEmpty) {
      final items = (m['items'] as List? ?? [])
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      setState(() {
        _items.addAll(items);
        if ('${m['mobile'] ?? ''}'.isNotEmpty) _mobile.text = '${m['mobile']}';
        _resumedHoldId = m['holdId']?.toString();
      });
      _quote(state);
    }
    setState(() {
      _machine = h;
      _payMode = h.mode;
    });
    showToast(s.paid
        ? gt('A machine payment was received before the refresh. Press Charge to put it on the bill.')
        : gt('Resuming the card machine payment that was open.'));
    if (!s.paid) unawaited(_takeOnMachine(state));
  }

  List<PayChannelDto> _channelsOf(String mode) =>
      _channels.where((c) => c.mode == mode).toList();

  /// The channel picked (or defaulted) for [mode]; null when the mode has
  /// none, or several with no default and none picked yet.
  PayChannelDto? _channelOf(String mode) {
    final id = _chosen[mode];
    if (id == null) return null;
    for (final c in _channels) {
      if (c.mode == mode && c.moneyAccountId == id) return c;
    }
    return null;
  }

  /// A machine payment is open or paid but not on a bill yet: the basket and
  /// the card amount are frozen until it is used, cancelled or voided.
  bool _machineBusy() {
    final s = _machine?.session;
    return s != null && s.posSaleId == null && (s.open || s.paid);
  }

  bool _blockedByMachine() {
    if (!_machineBusy()) return false;
    showToast(
        gt('A card/UPI machine payment is waiting on this bill. Use it, cancel it or void it first.'),
        'error');
    return true;
  }

  bool _wasOffline = false;

  /// Coin redemption (guide 30 / P3 F3): NONE, ALL or PERCENT of the allowed
  /// maximum. Needs a customer mobile; not available offline.
  String _coinMode = 'NONE';
  int _coinPct = 50;

  /// The connection state changed: switch the catalogue and re-price.
  void _onOfflineChanged() {
    if (!mounted) return;
    final off = PosOffline.instance;
    if (off.offline != _wasOffline) {
      _wasOffline = off.offline;
      _coinMode = 'NONE';
      final state = StateScope.read(context);
      if (off.offline) {
        if (off.hasCatalogue) state.posProducts = off.products;
        if (_items.isNotEmpty) _quote(state);
        showToast(gt('Offline: bills are saved on this device'), 'error');
      } else {
        unawaited(state.posLoadProducts());
        if (_items.isNotEmpty) _quote(state);
        showToast(gt('Back online'));
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    PosOffline.instance.removeListener(_onOfflineChanged);
    PosOffline.instance.stopWatch();
    _debounce?.cancel();
    _barcode.dispose();
    _search.dispose();
    _mobile.dispose();
    _coupon.dispose();
    _tendered.dispose();
    _amount.dispose();
    _reference.dispose();
    _mdAmount.dispose();
    _mdReason.dispose();
    _mdPin.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Ticket helpers
  // -------------------------------------------------------------------------

  /// Units (grams for a weighed item) on the shelf for [id]; null when the
  /// product has not been seen yet.
  int? _stockOf(AppState state, String id) {
    // Offline the shelf count is a day-old copy: never cap on it (the server
    // records any shortfall as an OVERSOLD exception for the manager).
    if (PosOffline.instance.offline) return null;
    for (final p in state.posProducts) {
      if (p.productId == id) return p.qtyOnHand < 0 ? 0 : p.qtyOnHand;
    }
    final k = _known[id];
    return k == null ? null : (k.qtyOnHand < 0 ? 0 : k.qtyOnHand);
  }

  /// "Only N in stock" (or "Out of stock") for [p], grams for weighed items.
  String _stockMsg(PosProductDto? p, int stock) {
    final name = p == null ? '' : '${_label(p)}: ';
    if (stock <= 0) return '$name${gt('Out of stock')}';
    final unit = p?.soldBy == 'WEIGHT' ? ' g' : '';
    return '$name${gt('Only $stock$unit in stock')}';
  }

  /// Trims every ticket line to what is on the shelf. Returns one message per
  /// line that had to be cut (empty when nothing changed).
  List<String> _capToStock(AppState state) {
    final msgs = <String>[];
    for (var i = _items.length - 1; i >= 0; i--) {
      final id = '${_items[i]['productId']}';
      final stock = _stockOf(state, id);
      final qty = (_items[i]['qty'] as num?)?.toInt() ?? 0;
      if (stock == null || qty <= stock) continue;
      final p = _known[id] ??
          state.posProducts.where((x) => x.productId == id).firstOrNull;
      msgs.add(_stockMsg(p, stock));
      if (stock <= 0) {
        _items.removeAt(i);
      } else {
        _items[i]['qty'] = stock;
      }
    }
    return msgs;
  }

  /// Adds [qty] of [p] (pieces, or **grams** for a weighed product). A weighed
  /// product picked by hand has no weight yet, so the cashier is asked for it;
  /// a scanned scale label already carries its grams. The line can never go
  /// above the stock on hand: the quantity is capped and "Only N in stock" is
  /// shown instead.
  Future<void> _add(AppState state, PosProductDto p, {int? qty}) async {
    if (p.productId == null) return;
    if (_blockedByMachine()) return;
    final id = p.productId!;
    _known[id] = p;
    var add = qty ?? 1;
    if (qty == null && p.soldBy == 'WEIGHT') {
      final g = await _askGrams(p);
      if (g == null || !mounted) return;
      add = g;
    }
    final stock = PosOffline.instance.offline
        ? 1000000000
        : (p.qtyOnHand < 0 ? 0 : p.qtyOnHand);
    final idx = _items.indexWhere((it) => it['productId'] == id);
    final have = idx >= 0 ? (_items[idx]['qty'] as int) : 0;
    final room = stock - have;
    if (room <= 0) {
      showToast(_stockMsg(p, stock), 'error');
      return;
    }
    var take = add > room ? room : add;
    if (take < add) showToast(_stockMsg(p, stock), 'error');
    // Largest quantity on one line: 9999 pieces or 100000 grams.
    final lineMax = p.soldBy == 'WEIGHT' ? 100000 : 9999;
    if (have + take > lineMax) {
      take = lineMax - have;
      showToast(
          '${gt('Most you can bill on one line is')} $lineMax${p.soldBy == 'WEIGHT' ? ' g' : ''}',
          'error');
      if (take <= 0) return;
    }
    setState(() {
      if (idx >= 0) {
        _items[idx]['qty'] = have + take;
      } else {
        _items.add({'productId': id, 'qty': take});
      }
    });
    _quote(state);
  }

  /// Weight prompt for a loose (weighed) item, in grams (1..100000).
  Future<int?> _askGrams(PosProductDto p) {
    final ctrl = TextEditingController();
    return showAppSheet<int>(
      context: context,
      title: _label(p),
      sub: 'Enter the weight in grams · ${_rs(p.pricePaise)} per kg',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 6, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: 'Weight (g)',
              controller: ctrl,
              numeric: true,
              placeholder: 'e.g. 750',
              autofocus: true,
            ),
            const SizedBox(height: 14),
            AppButton(
              'Add to ticket',
              block: true,
              onTap: () {
                final bad = Validators.whole(ctrl.text,
                    label: gt('Weight'), required: true, min: 1, max: 100000);
                if (bad != null) {
                  showToast(gt(bad), 'error');
                  return;
                }
                Navigator.of(ctx).pop(int.parse(ctrl.text.trim()));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Applies a typed quantity: live backend stock check, cap, re-quote.
  Future<void> _commitQty(AppState state, int index, int v) async {
    if (!mounted || index >= _items.length) return;
    final id = '${_items[index]['productId']}';
    final p = _known[id] ??
        state.posProducts.where((x) => x.productId == id).firstOrNull;
    final weighed = p?.soldBy == 'WEIGHT';
    // Ask the backend for the live shelf count of this product, so the check
    // is not made against a stale list.
    if (v > 0 && p != null && !PosOffline.instance.offline) {
      final fresh = await _liveStock(state, p);
      if (!mounted || index >= _items.length || '${_items[index]['productId']}' != id) return;
      if (fresh != null) {
        final onHand = fresh < 0 ? 0 : fresh;
        _known[id]?.qtyOnHand = onHand;
        for (final sp in state.posProducts) {
          if (sp.productId == id) sp.qtyOnHand = onHand;
        }
        if (v > onHand) {
          final unit = weighed ? ' g' : ' ${gt('units')}';
          showToast(
              onHand <= 0
                  ? '${_label(p)}: ${gt('Stock not available in store')}'
                  : '${_label(p)}: ${gt('Stock not available in store. Only')} $onHand$unit ${gt('available')}',
              'error');
          // Bill only what is there; the price is re-quoted for that quantity.
          setState(() {
            if (onHand <= 0) {
              _items.removeAt(index);
            } else {
              _items[index]['qty'] = onHand;
            }
          });
          _quote(state);
          return;
        }
      }
    }
    _setQty(state, index, v);
  }

  /// Live `qtyOnHand` of [p] from the server (null when it cannot be read).
  Future<int?> _liveStock(AppState state, PosProductDto p) async {
    try {
      final q = p.barcodes.isNotEmpty
          ? p.barcodes.first
          : (p.plu?.isNotEmpty == true ? p.plu! : (p.name ?? ''));
      if (q.isEmpty) return null;
      final page = await Api.instance.pos.getProducts(q: q, size: 50);
      for (final r in page.items) {
        if (r.productId == p.productId) return r.qtyOnHand;
      }
    } catch (_) {}
    return null;
  }

  void _setQty(AppState state, int index, int qty) {
    if (_blockedByMachine()) return;
    final id = '${_items[index]['productId']}';
    final stock = _stockOf(state, id);
    if (stock != null && qty > stock) {
      final p = _known[id] ??
          state.posProducts.where((x) => x.productId == id).firstOrNull;
      showToast(_stockMsg(p, stock), 'error');
      qty = stock;
    }
    final pq = _known[id] ??
        state.posProducts.where((x) => x.productId == id).firstOrNull;
    final lineMax = pq?.soldBy == 'WEIGHT' ? 100000 : 9999;
    if (qty > lineMax) {
      showToast('${gt('Most you can bill on one line is')} $lineMax', 'error');
      qty = lineMax;
    }
    setState(() {
      if (qty <= 0) {
        _items.removeAt(index);
      } else {
        _items[index]['qty'] = qty;
      }
    });
    _quote(state);
  }

  /// Drop every payment line and field — used when the ticket is cleared,
  /// parked or successfully charged, so a stale split never carries into the
  /// next sale.
  void _resetPayment() {
    _machine = null;
    LocalStore.remove(_kMachineKey);
    _splits.clear();
    _tendered.clear();
    _amount.clear();
    _reference.clear();
  }

  void _clear(AppState state) {
    if (_blockedByMachine()) return;
    _resumedHoldId = null;
    setState(() {
      _items.clear();
      _resetPayment();
      _discOn = false;
      _discOpen = false;
      _mdAmount.clear();
      _mdReason.clear();
      _mdPin.clear();
    });
    state.posQuote(const []);
  }


  /// The manual discount typed at the till as the wire object, or null when
  /// the amount is empty/zero. [withPin] adds the manager PIN (sales only).
  Map<String, dynamic>? _manual({bool withPin = false}) {
    if (!_discOn) return null;
    final rupees = double.tryParse(_mdAmount.text.trim());
    if (rupees == null || rupees <= 0) return null;
    final pin = _mdPin.text.trim();
    return {
      'amountPaise': (rupees * 100).round(),
      'reason': _mdReason.text.trim(),
      if (withPin && pin.isNotEmpty) 'approverPin': pin,
    };
  }

  /// The typed mobile when it is a valid 10-digit number, else null. An empty
  /// or half-typed number is never sent: the mobile is optional, and a bad
  /// one used to make the quote fail so the ticket could not be charged.
  String? get _mobileOrNull => cleanMobile(_mobile.text);

  /// True when something is typed in the mobile box that is not a valid number.
  bool get _mobileBad =>
      _mobile.text.trim().isNotEmpty && cleanMobile(_mobile.text) == null;

  LocalQuote? _localQuote;

  void _quote(AppState state) {
    _lastQuotedMobile = _mobileOrNull;
    if (PosOffline.instance.offline) {
      // Priced on the device with the server's rules (no coupon/coins).
      if (_items.isEmpty) {
        _localQuote = null;
        setState(() => state.posBill = null);
        return;
      }
      final md = _manual();
      final q = PosOffline.instance.quoteLocal(List.of(_items),
          manualPaise: (md?['amountPaise'] as int?) ?? 0);
      _localQuote = q;
      setState(() => state.posBill = q.bill);
      return;
    }
    _localQuote = null;
    state.posQuote(
      List.of(_items),
      mobile: _mobileOrNull,
      coupon: _coupon.text.trim().isEmpty ? null : _coupon.text.trim(),
      manualDiscount: _manual(),
      coinMode: _mobileOrNull != null && _coinMode != 'NONE' ? _coinMode : null,
      coinPercent: _coinMode == 'PERCENT' ? _coinPct : null,
    );
  }

  void _onSearchChanged(AppState state) {
    setState(() {}); // re-filter the chip list as the user types
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (PosOffline.instance.offline) return; // filtered on the device
      state.posLoadProducts(q: _search.text.trim());
    });
  }

  /// Enter in the search box: an exact barcode adds the item straight away
  /// (`GET /pos/barcode/{code}`); anything else just searches the catalog.
  Future<void> _searchEnter(AppState state) async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    state.apiLastError = null;
    if (PosOffline.instance.offline) {
      final ls = PosOffline.instance.scanLocal(q);
      if (ls.product != null && !ls.askWeight) {
        _search.clear();
        await _add(state, ls.product!, qty: ls.qty);
        _announceAdded(ls.product!, ls.qty);
        return;
      }
      if (ls.product != null && ls.askWeight) {
        _search.clear();
        await _add(state, ls.product!);
        return;
      }
      if (ls.error != null) showToast(gt(ls.error!), 'error');
      if (_visible(state).isEmpty) {
        setState(() => _scanMsg =
            '${gt('No product found for')} “$q”. ${gt('Check the barcode or search by name.')}');
      }
      return;
    }
    final scan = await state.posScan(q);
    if (!mounted) return;
    if (scan != null) {
      _search.clear();
      scan.product.lot ??= scan.lot;
      await _add(state, scan.product, qty: scan.qty);
      state.posLoadProducts();
      _announceAdded(scan.product, scan.qty);
      return;
    }
    // A readable 400 (bad check digit, "weighed item: enter the weight") is
    // worth showing; a plain 404 just falls through to the name search.
    if (state.apiLastError != null && RegExp(r'^[0-9A-Za-z-]{4,32}$').hasMatch(q)) {
      showToast(state.apiLastError!, 'error');
    }
    await state.posLoadProducts(q: q);
    if (!mounted) return;
    if (_visible(state).isEmpty) {
      setState(() => _scanMsg =
          '${gt('No product found for')} “$q”. ${gt('Check the barcode or search by name.')}');
    }
  }

  /// Weight as kg/g text.
  String _kg(int grams) {
    if (grams < 1000) return '$grams g';
    final kg = grams / 1000;
    return '${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 3).replaceFirst(RegExp(r'0+$'), '')} kg';
  }

  /// `+2 x 1 kg` style: the quantity with the pack size / unit, a weighed
  /// item as kg or g (grams on the wire).
  String _addedText(PosProductDto p, int qty) {
    if (p.soldBy == 'WEIGHT') return '+${_kg(qty)}';
    final pack = (p.packSize ?? '').trim().isNotEmpty
        ? p.packSize!.trim()
        : _unitOf(p);
    return pack.isEmpty ? '+$qty' : '+$qty x $pack';
  }

  /// "After 3 more the price is Rs 170" when the next unit sold moves to a
  /// dearer/cheaper lot (guide 74 section 3); null otherwise.
  String? _lotNote(PosProductDto? p) {
    final n = p?.lot?.nextPriceChange;
    if (p == null || n == null || p.soldBy == 'WEIGHT') return null;
    return '${gt('After')} ${n.afterQty} ${gt('more the price is')} ${_rs(n.newPricePaise)}';
  }

  void _announceAdded(PosProductDto p, int qty) {
    final note = _lotNote(p);
    showToast(
        '${_addedText(p, qty)} · ${p.name ?? _label(p)} ${gt('added')}'
        '${note == null ? '' : ' · $note'}');
  }

  // -------------------------------------------------------------------------
  // Credit (udhar) eligibility
  // -------------------------------------------------------------------------

  void _forgetCredit() {
    _credAcc = null;
    _credStatus = 0;
    _credMobile = null;
    _credErr = null;
    _credBusy = false;
  }

  /// Looks the typed mobile up (`GET /pos/credit/account`) so the credit panel
  /// can show the limit, what is owed and what is still available.
  Future<void> _refreshCredit(AppState state) async {
    final m = cleanMobile(_mobile.text);
    if (m == null) {
      setState(_forgetCredit);
      return;
    }
    setState(() {
      _credBusy = true;
      _credMobile = m;
      _credErr = null;
    });
    final (acc, status, msg) = await state.posCreditAccountOf(m);
    if (!mounted || _credMobile != m) return;
    setState(() {
      _credBusy = false;
      _credAcc = acc;
      _credStatus = status;
      _credErr = acc == null && status != 404 ? msg : null;
    });
  }

  Future<void> _pickCredit(AppState state) async {
    final acc = await showPosCreditPicker(context);
    final m = cleanMobile(acc?.mobile ?? '');
    if (acc == null || m == null || !mounted) return;
    setState(() {
      _mobile.text = m;
      _payMode = 'CREDIT';
      _amount.clear();
    });
    _quote(state);
    await _refreshCredit(state);
  }

  Future<void> _enableCredit(AppState state) async {
    final m = cleanMobile(_mobile.text);
    if (m == null) return;
    final acc = await showEnableCreditSheet(context,
        mobile: m, name: _credAcc?.name, currentLimitPaise: _credAcc?.limitPaise);
    if (acc == null || !mounted) return;
    setState(() {
      _credAcc = acc;
      _credStatus = 200;
      _credMobile = m;
      _credErr = null;
    });
  }

  /// The "pay on credit" box under the payment modes: who, limit, owed and
  /// available; or exactly why credit is not possible with a button to fix it.
  Widget _creditPanel(AppState state, PosBillViewDto? bill) {
    final m = cleanMobile(_mobile.text);
    final outstanding = _outstanding(bill);
    Widget box(Color bg, List<Widget> kids) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(12)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: kids),
        );
    const body = TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.ink2);
    if (m == null) {
      return box(AppColors.goldTint, [
        Text(
            _mobileBad
                ? gt('Fix the mobile number above to check this customer’s credit.')
                : gt('Credit needs a customer. Pick one who has credit, or type their mobile number above.'),
            style: body),
        const SizedBox(height: 8),
        AppButton(gt('Pick credit customer'),
            size: BtnSize.xs,
            variant: BtnVariant.secondary,
            onTap: () => unawaited(_pickCredit(state))),
      ]);
    }
    if (_credBusy || (_credMobile != m && _credAcc == null && _credErr == null)) {
      return box(AppColors.goldTint, [
        Text(gt('Checking credit…'), style: body),
      ]);
    }
    if (_credErr != null) {
      return box(AppColors.redTint, [
        Text(_credErr!, style: body.copyWith(color: AppColors.red)),
        const SizedBox(height: 8),
        AppButton(gt('Try again'),
            size: BtnSize.xs,
            variant: BtnVariant.secondary,
            onTap: () => unawaited(_refreshCredit(state))),
      ]);
    }
    final acc = _credAcc;
    final why = creditWhyNot(acc, _credStatus, m, billCreditPaise: outstanding);
    final who = (acc?.name ?? '').isNotEmpty ? acc!.name! : m;
    if (acc != null && why == null) {
      return box(AppColors.greenTint, [
        Text('$who - $m', style: body.copyWith(color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(
            '${gt('Limit')} ${_rs(acc.limitPaise)}  ·  ${gt('Owes')} ${_rs(acc.balancePaise)}'
            '  ·  ${gt('Available')} ${_rs(acc.availablePaise)}',
            style: body.copyWith(color: AppColors.green)),
      ]);
    }
    final notEnabled = acc == null || acc.limitPaise <= 0;
    final used = acc != null && acc.limitPaise > 0;
    final admin = state.isBackendAdmin;
    return box(AppColors.redTint, [
      Text(why ?? gt('Credit is not available for this customer.'),
          style: body.copyWith(color: AppColors.red)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (notEnabled && admin)
          AppButton('${gt('Enable credit for')} $who',
              size: BtnSize.sm, onTap: () => unawaited(_enableCredit(state))),
        if (used && admin)
          AppButton(gt('Raise the credit limit'),
              size: BtnSize.sm,
              variant: BtnVariant.secondary,
              onTap: () => unawaited(_enableCredit(state))),
        if (used && acc.availablePaise > 0 && outstanding > acc.availablePaise)
          AppButton('${gt('Put')} ${_rs(acc.availablePaise)} ${gt('on credit, rest another way')}',
              size: BtnSize.sm,
              variant: BtnVariant.secondary,
              onTap: () => setState(() {
                    _amount.text = (acc.availablePaise / 100).toStringAsFixed(
                        acc.availablePaise % 100 == 0 ? 0 : 2);
                  })),
        AppButton(gt('Pick another customer'),
            size: BtnSize.sm,
            variant: BtnVariant.secondary,
            onTap: () => unawaited(_pickCredit(state))),
      ]),
      if (!admin && (notEnabled || (used && acc.availablePaise <= 0))) ...[
        const SizedBox(height: 8),
        Text(
            notEnabled
                ? gt('Ask an admin to enable credit for this customer.')
                : gt('Ask an admin to raise this customer’s credit limit.'),
            style: body),
      ],
    ]);
  }

  /// A plain sentence for a failed sale from the backend's code + details
  /// (stock left, credit numbers); null to fall back to the server text.
  String? _explainSaleError(AppState state) {
    final d = state.posLastErrorDetails;
    switch (state.posLastErrorCode) {
      case 'OUT_OF_STOCK':
        final items = d['items'];
        final msgs = <String>[];
        if (items is List) {
          for (final it in items.whereType<Map>()) {
            final id = '${it['productId']}';
            final avail = (it['available'] as num?)?.toInt() ?? 0;
            _known[id]?.qtyOnHand = avail;
            for (final sp in state.posProducts) {
              if (sp.productId == id) sp.qtyOnHand = avail;
            }
            final p = _known[id] ??
                state.posProducts.where((x) => x.productId == id).firstOrNull;
            msgs.add(_stockMsg(p, avail));
          }
        }
        _capToStock(state);
        unawaited(state.posLoadProducts());
        _quote(state);
        return msgs.isEmpty
            ? null
            : '${msgs.join(' · ')}. ${gt('The ticket now shows what is in stock.')}';
      case 'CREDIT_NOT_ALLOWED':
        unawaited(_refreshCredit(state));
        return gt('Credit is not enabled for this customer (no credit limit is set). Use “Enable credit” in the Payment box, or ask an admin.');
      case 'CUSTOMER_BLOCKED':
        unawaited(_refreshCredit(state));
        return gt('This customer is blocked, so credit cannot be given. Take the money another way.');
      case 'TERMINAL_PAYMENT_NOT_PAID':
        return gt('The card/UPI machine payment is not confirmed as paid yet. Open it and wait for the result, or choose another way.');
      case 'TERMINAL_PAYMENT_USED':
        setState(() => _machine = null);
        return gt('That machine payment is already on another bill. Take the payment again.');
      case 'TERMINAL_PAYMENT_AMOUNT':
        return gt('The card/UPI line must be exactly the machine payment amount. Split the payment so that line matches.');
      case 'TERMINAL_PAYMENT_MODE':
        return gt('The machine payment was taken by the other method (UPI vs card). Choose the matching payment method.');
      case 'RATE_LIMITED':
        return gt('Too many tries. Ask the manager to sign in.');
      case 'COUPON_INVALID':
        final short = (d['shortfallPaise'] as num?)?.toInt();
        _coupon.clear();
        _quote(state);
        return '${state.apiLastError ?? gt('That coupon cannot be used.')}'
            '${short == null ? '' : ' ${gt('Add')} ${_rs(short)} ${gt('more to use it.')}'}';
      case 'CREDIT_LIMIT_EXCEEDED':
        unawaited(_refreshCredit(state));
        final lim = (d['limitPaise'] as num?)?.toInt();
        final bal = (d['balancePaise'] as num?)?.toInt();
        final av = (d['availablePaise'] as num?)?.toInt();
        final rq = (d['requestedPaise'] as num?)?.toInt();
        if (lim == null || bal == null || av == null) return null;
        return '${gt('Over the credit limit')}: ${gt('limit')} ${_rs(lim)}, ${gt('owes')} ${_rs(bal)}, '
            '${gt('available')} ${_rs(av)}'
            '${rq == null ? '' : ', ${gt('this bill needs')} ${_rs(rq)}'}.';
    }
    return null;
  }

  Future<void> _dropHold(AppState state, String id) async {
    final ok = await state.posDeleteHold(id);
    if (!ok && mounted) {
      showToast(
          '${gt('Done, but the parked ticket could not be removed')}: ${state.posHoldError ?? ''}',
          'error');
    }
  }

  // -------------------------------------------------------------------------
  // Charge → receipt
  // -------------------------------------------------------------------------

  /// What the payment lines have not covered yet, in paise.
  int _outstanding(PosBillViewDto? bill) {
    if (bill == null) return 0;
    var left = bill.totalPaise;
    for (final l in _splits) {
      left -= (l['amountPaise'] as num?)?.toInt() ?? 0;
    }
    return left < 0 ? 0 : left;
  }

  /// The payment line the form describes right now. An empty amount means
  /// "whatever is still outstanding", which is what makes a plain single-mode
  /// sale work without typing anything.
  ///
  /// Returns the line, or the message to show instead.
  (Map<String, dynamic>?, String?) _lineFromForm(int outstanding) {
    final mode = normalizePayMode(_payMode);
    if (!kPosPayModes.contains(mode)) {
      return (null, '“$_payMode” is not a payment mode the till accepts');
    }
    if (mode == 'CREDIT' &&
        _splits.any((l) => l['mode'] == 'CREDIT')) {
      // `PaymentRules` allows at most one credit line per bill.
      return (null, 'A bill can only carry one credit payment');
    }
    final onMachine = mode == 'CARD' || mode == 'UPI';
    final ms = _machine?.session;
    if (onMachine && ms != null && ms.open && ms.posSaleId == null) {
      return (
        null,
        gt('The machine payment is still open. Finish, cancel or void it first.')
      );
    }
    final machineUsed =
        ms != null && _splits.any((l) => l['terminalPaymentId'] == ms.id);
    final useMachine = onMachine &&
        ms != null &&
        ms.paid &&
        ms.posSaleId == null &&
        !machineUsed;
    var paise = outstanding;
    if (useMachine) {
      // The line must equal the session amount (TERMINAL_PAYMENT_AMOUNT).
      paise = ms.amountPaise;
    } else {
      final raw = _amount.text.trim();
      if (raw.isNotEmpty) {
        final bad = Validators.rupees(raw,
            label: gt('Amount'), required: true, min: 0.01, max: 1000000);
        if (bad != null) return (null, gt(bad));
        paise = (double.parse(raw) * 100).round();
      }
    }
    if (paise <= 0) return (null, 'This bill is already fully paid');
    if (paise > outstanding) {
      return (
        null,
        useMachine
            ? '${gt('The machine payment of')} ${_rs(paise)} ${gt('is more than the')} ${_rs(outstanding)} ${gt('still due')}'
            : 'That is more than the ${_rs(outstanding)} outstanding'
      );
    }
    final chans = _channelsOf(mode);
    final ch = _channelOf(mode);
    if (!useMachine && chans.length > 1 && ch == null) {
      return (
        null,
        '${gt('Choose which')} $mode ${gt('channel the money goes to')}'
      );
    }
    final ref = _reference.text.trim();
    if (ref.length > 100) {
      return (null, gt('Reference must be 100 characters or fewer'));
    }
    final acct = useMachine ? (ms.moneyAccountId ?? ch?.moneyAccountId) : ch?.moneyAccountId;
    return (
      {
        'mode': useMachine ? ms.billMode(_machine!.mode) : mode,
        'amountPaise': paise,
        if (!useMachine && ref.isNotEmpty) 'reference': ref,
        // The one id the sale needs: the server takes the machine's account,
        // reference (RRN) and payer detail from the session.
        if (useMachine) 'terminalPaymentId': ms.id,
        if (acct != null && acct.isNotEmpty) 'moneyAccountId': acct,
      },
      null,
    );
  }

  /// Locks the current line in and leaves the rest of the bill outstanding —
  /// the split path (part cash, part UPI, or some of it on credit).
  void _addSplit(AppState state) {
    final outstanding = _outstanding(state.posBill);
    final (line, err) = _lineFromForm(outstanding);
    if (line == null) {
      showToast(err!, 'error');
      return;
    }
    if ((line['amountPaise'] as int) >= outstanding) {
      showToast('That covers the whole bill — press Charge', 'error');
      return;
    }
    setState(() {
      _splits.add(line);
      _amount.clear();
      _reference.clear();
    });
  }

  Future<void> _charge(AppState state) async {
    if (_items.isEmpty) {
      showToast('Add something to the ticket first', 'error');
      return;
    }
    final bill = state.posBill;
    if (bill == null) {
      showToast('Pricing the ticket — try again in a moment', 'error');
      return;
    }
    // Never ring up more than the shelf holds: trim the ticket and make the
    // cashier look at it again before charging.
    final capped = _capToStock(state);
    if (capped.isNotEmpty) {
      setState(() {});
      _quote(state);
      showToast(
          '${capped.join(' · ')}. ${gt('The ticket now shows what is in stock. Check it and press Charge again.')}',
          'error');
      return;
    }
    final (line, err) = _lineFromForm(_outstanding(bill));
    if (line == null) {
      showToast(err!, 'error');
      return;
    }
    final payments = <Map<String, dynamic>>[..._splits, line];
    final ms = _machine?.session;
    if (ms != null &&
        ms.paid &&
        ms.posSaleId == null &&
        !payments.any((p) => p['terminalPaymentId'] == ms.id)) {
      showToast(
          '${gt('A machine payment of')} ${_rs(ms.amountPaise)} ${gt('is waiting. Choose Card/UPI to put it on the bill, or open it and void it.')}',
          'error');
      return;
    }
    final paidSum = payments.fold<int>(
        0, (t, p) => t + ((p['amountPaise'] as num?)?.toInt() ?? 0));
    if (paidSum != bill.totalPaise) {
      showToast(
          '${gt('The payments add up to')} ${_rs(paidSum)} ${gt('but the bill is')} ${_rs(bill.totalPaise)}. '
          '${gt('Use “Split this payment” to add the part already taken, then pay the rest.')}',
          'error');
      return;
    }
    if (_coupon.text.trim().length > 30) {
      showToast(gt('A coupon code is at most 30 characters.'), 'error');
      return;
    }
    // The mobile is OPTIONAL for cash / UPI / card. It is needed only to sell
    // on credit, to use a coupon or coins; a typed number must be valid.
    final mobileClean = _mobileOrNull;
    if (_mobileBad) {
      showToast(
          gt('Enter a 10-digit mobile number, or clear the box. It is optional unless you sell on credit or use a coupon.'),
          'error');
      return;
    }
    if (mobileClean == null && _coupon.text.trim().isNotEmpty) {
      showToast(gt('Add the customer mobile to use a coupon.'), 'error');
      return;
    }
    if (PosOffline.instance.offline) {
      final why = PosOffline.refuseReason(
          payments: payments,
          coupon: _coupon.text,
          coins: _coinMode != 'NONE');
      if (why != null) {
        showToast(gt(why), 'error');
        return;
      }
      if (PosOffline.instance.clockBad) {
        showToast(
            gt('The clock on this device differs from the server. Fix the device time before billing offline.'),
            'error');
        return;
      }
    }
    final creditPaise = payments
        .where((p) => p['mode'] == 'CREDIT')
        .fold<int>(0, (t, p) => t + ((p['amountPaise'] as num?)?.toInt() ?? 0));
    if (creditPaise > 0) {
      if (mobileClean == null) {
        showToast(gt('Credit needs a customer. Pick one with “Pick credit customer” or type their mobile.'),
            'error');
        return;
      }
      // Fresh numbers, then say exactly why if credit is not possible.
      setState(() => _busy = true);
      final (acc, status, msg) = await state.posCreditAccountOf(mobileClean);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _credAcc = acc;
        _credStatus = status;
        _credMobile = mobileClean;
        _credErr = acc == null && status != 404 ? msg : null;
      });
      if (acc == null && status != 404) {
        showToast(msg ?? gt('Could not check this customer’s credit.'), 'error');
        return;
      }
      final why = creditWhyNot(acc, status, mobileClean, billCreditPaise: creditPaise);
      if (why != null) {
        showToast(why, 'error');
        return;
      }
    }

    // Change only makes sense against the cash part of a split.
    int? tendered;
    final cash = payments
        .where((p) => p['mode'] == 'CASH')
        .fold<int>(0, (s, p) => s + ((p['amountPaise'] as num?)?.toInt() ?? 0));
    if (cash > 0 && _tendered.text.trim().isNotEmpty) {
      final tErr = Validators.rupees(_tendered.text,
          label: gt('Cash received'), min: 0.01, max: 1000000);
      if (tErr != null) {
        showToast(gt(tErr), 'error');
        return;
      }
      final t = (double.tryParse(_tendered.text.trim()) ?? -1) * 100;
      if (t < 0) {
        showToast('Enter a valid cash amount tendered', 'error');
        return;
      }
      if (t.round() < cash) {
        showToast('Cash tendered is less than the cash payment', 'error');
        return;
      }
      tendered = t.round();
    }

    // One Idempotency-Key per basket: the same basket+payments retried after
    // a timeout / 5xx re-uses it (the server then returns the first bill and
    // never rings a second one); any change to the basket gets a fresh key.
    final mobile = mobileClean;
    final coupon = _coupon.text.trim().isEmpty ? null : _coupon.text.trim();
    final manual = _manual(withPin: true);
    if (manual != null && '${manual['reason']}'.isEmpty) {
      showToast('Enter a reason for the manual discount', 'error');
      return;
    }
    if (manual != null &&
        '${manual['approverPin'] ?? ''}'.isNotEmpty &&
        !RegExp(r'^\d{4,8}$').hasMatch('${manual['approverPin']}')) {
      showToast(gt('PIN must be 4 to 8 digits'), 'error');
      return;
    }
    if (PosOffline.instance.offline) {
      _chargeOffline(state, payments, mobile, tendered, manual);
      return;
    }
    final fp =
        jsonEncode([_items, payments, mobile, coupon, tendered, manual, _coinMode, _coinPct]);
    if (fp != _saleFp) {
      _saleFp = fp;
      _saleKey = newIdempotencyKey();
    }

    setState(() => _busy = true);
    final sale = await state.posCharge(
      items: List.of(_items),
      payments: payments,
      mobile: mobile,
      coupon: coupon,
      cashTenderedPaise: tendered,
      manualDiscount: manual,
      idempotencyKey: _saleKey,
      coinMode: mobile != null && _coinMode != 'NONE' ? _coinMode : null,
      coinPercent: _coinMode == 'PERCENT' ? _coinPct : null,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _payErrors = state.posLastFieldErrors;
    });
    if (sale == null) {
      if (state.posLastErrorCode == null &&
          PosOffline.isNetworkMessage(state.apiLastError)) {
        // The server cannot be reached: switch to offline billing. The
        // earlier attempt may or may not have been recorded; check Today's
        // bills once the connection is back.
        PosOffline.instance.markUnreachable();
        showToast(
            gt('The server cannot be reached. Offline mode is on: press Charge again to save the bill on this device. When the connection is back, check Today’s bills in case the first attempt was recorded.'),
            'error');
        return;
      }
      if (state.posLastErrorCode == 'DISCOUNT_NEEDS_APPROVAL') {
        setState(() => _needPin = true);
      }
      // The backend's own 400 text (a split that does not add up, an unknown
      // mode, a credit rule) is the most useful thing to put on screen.
      showToast(
          _explainSaleError(state) ??
              state.apiLastError ??
              'The sale could not be recorded',
          'error');
      // The shop requires an open shift before billing: take the cashier
      // straight to the open-shift sheet, then they press Charge again.
      if (state.posLastErrorCode == 'SHIFT_NOT_OPEN') {
        go('/admin/shift');
      }
      return;
    }
    _saleFp = '';
    final heldId = _resumedHoldId;
    _resumedHoldId = null;
    if (heldId != null) unawaited(_dropHold(state, heldId));
    setState(() {
      _items.clear();
      _resetPayment();
      _forgetCredit();
      _mobile.clear();
      _coupon.clear();
      _mdAmount.clear();
      _mdReason.clear();
      _mdPin.clear();
      _needPin = false;
      _coinMode = 'NONE';
      _discOn = false;
      _discOpen = false;
      _splitOpen = false;
      _payErrors = const {};
      _done = sale;
      _doneEntry = null;
    });
    state.posQuote(const []);
  }

  /// Offline: the bill is saved on this device with its own Idempotency-Key
  /// and sent by [PosOffline.sync] when the server is reachable again.
  void _chargeOffline(AppState state, List<Map<String, dynamic>> payments,
      String? mobile, int? tendered, Map<String, dynamic>? manual) {
    final off = PosOffline.instance;
    final q = _localQuote ??
        off.quoteLocal(List.of(_items),
            manualPaise: (manual?['amountPaise'] as int?) ?? 0);
    if (q.missing.isNotEmpty || q.bill.lines.isEmpty) {
      showToast(
          gt('Some items are not in the offline product copy. Remove them or go online.'),
          'error');
      return;
    }
    final paid = payments.fold<int>(
        0, (t, p) => t + ((p['amountPaise'] as num?)?.toInt() ?? 0));
    if (paid != q.bill.totalPaise) {
      showToast(
          '${gt('The payments add up to')} ${_rs(paid)} ${gt('but the bill is')} ${_rs(q.bill.totalPaise)}',
          'error');
      return;
    }
    final entry = off.enqueue(
      quote: q,
      payments: [
        for (final p in payments)
          {
            'mode': p['mode'],
            'amountPaise': p['amountPaise'],
            if ('${p['reference'] ?? ''}'.isNotEmpty) 'reference': p['reference'],
            if ('${p['moneyAccountId'] ?? ''}'.isNotEmpty)
              'moneyAccountId': p['moneyAccountId'],
          }
      ],
      mobile: mobile,
      tenderedPaise: tendered,
      discountReason: manual == null ? null : '${manual['reason']}',
    );
    _saleFp = '';
    _resumedHoldId = null;
    setState(() {
      _items.clear();
      _resetPayment();
      _forgetCredit();
      _mobile.clear();
      _coupon.clear();
      _mdAmount.clear();
      _mdReason.clear();
      _mdPin.clear();
      _needPin = false;
      _discOn = false;
      _discOpen = false;
      _splitOpen = false;
      _payErrors = const {};
      _doneEntry = entry;
      _done = off.saleOf(entry);
      _localQuote = null;
    });
    state.posBill = null;
    showToast(gt('Saved on this device. It will be sent when the connection is back.'));
  }

  Map<String, dynamic>? _doneEntry;

  Future<void> _receiptSheet(AppState state, SaleRecordDto sale) async {
    final entry = _doneEntry;
    final id = sale.id;
    showAppSheet(
      context: context,
      title: entry != null ? gt('Temporary receipt') : gt('Sale complete'),
      sub: sale.invoiceNo ?? '',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PosReceiptBox(
              title: sale.invoiceNo ?? 'Receipt',
              load: (w) async {
                if (entry != null) {
                  return ReceiptDto(
                      width: w,
                      text: PosOffline.instance.receiptText(entry, w));
                }
                if (id == null) return null;
                final (r, _) =
                    await posTry((api) => api.getReceipt(id, width: w));
                return r;
              },
            ),
            const SizedBox(height: 8),
            Text(
              '${gt('Paid')} ${_rs(sale.totalPaise)}${sale.changePaise > 0 ? ' · ${gt('change')} ${_rs(sale.changePaise)}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              gt('New sale'),
              block: true,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Holds (parked carts)
  // -------------------------------------------------------------------------

  Future<void> _park(AppState state) async {
    if (_blockedByMachine()) return;
    if (_items.isEmpty) {
      showToast('Nothing to park — the ticket is empty', 'error');
      return;
    }
    final label = await showAppSheet<String>(
      context: context,
      title: 'Park this ticket',
      sub: 'Give it a name to resume later',
      builder: (ctx) => _labelPrompt(ctx),
    );
    if (label == null || !mounted) return;
    if (_mobileBad) {
      showToast(
          gt('Enter a 10-digit mobile number, or clear the box, before parking.'),
          'error');
      return;
    }
    if (PosOffline.instance.offline) {
      // Holds need the server: keep the basket on this device meanwhile.
      PosOffline.instance.addLocalHold(
          label, [for (final e in _items) Map<String, dynamic>.from(e)], _mobileOrNull);
      setState(() {
        _items.clear();
        _resetPayment();
      });
      _quote(state);
      showToast(gt('Ticket parked on this device'));
      return;
    }
    state.apiLastError = null;
    state.posLastErrorCode = null;
    final holdErr = await state.posSaveHold(
      label,
      PosCartDto(
        items: _items
            .map((e) => OrderItemDto(
                  productId: e['productId']?.toString(),
                  qty: (e['qty'] as num?)?.toInt() ?? 1,
                ))
            .toList(),
        customerMobile: _mobileOrNull,
        couponCode:
            _coupon.text.trim().isEmpty ? null : _coupon.text.trim(),
      ),
    );
    if (!mounted) return;
    if (holdErr != null) {
      // Keep the ticket: it was NOT parked (e.g. the 100-hold cap).
      showToast(holdErr, 'error');
      if (state.posLastErrorCode == 'HOLD_LIMIT') {
        // Too many parked tickets: open the list so some can be discarded.
        await _holdsSheet(state);
      }
      return;
    }
    // Re-parking a resumed ticket replaces the old hold instead of leaving a
    // duplicate behind.
    final oldHold = _resumedHoldId;
    _resumedHoldId = null;
    if (oldHold != null) unawaited(_dropHold(state, oldHold));
    setState(() {
      _items.clear();
      _resetPayment();
    });
    state.posQuote(const []);
    showToast('Ticket parked');
  }

  Widget _labelPrompt(BuildContext ctx) {
    final ctrl =
        TextEditingController(text: 'Hold ${TimeOfDay.now().format(ctx)}');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            label: 'Label',
            controller: ctrl,
            maxLength: 60,
            placeholder: 'Counter 1',
          ),
          const SizedBox(height: 14),
          AppButton(
            'Park ticket',
            block: true,
            onTap: () {
              final t = ctrl.text.trim();
              final bad = Validators.text(t, label: gt('Label'), max: 60);
              if (bad != null) {
                showToast(gt(bad), 'error');
                return;
              }
              Navigator.of(ctx).pop(t);
            },
          ),
        ],
      ),
    );
  }

  final Set<String> _removing = {};

  Future<void> _holdsSheet(AppState state) async {
    await state.posLoadHolds();
    if (!mounted) return;
    await showAppSheet(
      context: context,
      title: 'Parked tickets',
      sub: '${state.posHolds.length} waiting',
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
        // Read the live list on every rebuild: a removed ticket must leave the
        // sheet at once (a stale row used to be tapped twice, and the second
        // DELETE answered 404 "could not remove").
        final holds = state.posHolds;
        return holds.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Hint('No parked tickets. Use “Park” to park the '
                    'current ticket and free the counter.'),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final h in holds) _holdRow(ctx, state, h, refresh),
                  ],
                ),
              );
      }),
    );
  }

  Widget _holdRow(BuildContext ctx, AppState state, HoldViewDto h,
      void Function(VoidCallback) refresh) {
    final items = h.cart?.items.length ?? 0;
    final busy = h.id != null && _removing.contains(h.id);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (h.label ?? '').isEmpty ? 'Ticket' : h.label!,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$items item${items == 1 ? '' : 's'}'
                  '${h.customerMobile == null || h.customerMobile!.isEmpty ? '' : ' · ${h.customerMobile}'}',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11.5,
                    color: AppColors.ink3,
                  ),
                ),
                if (parseIst(h.expiresAt) != null)
                  Text(
                    '${gt('Removed automatically on')} ${_stamp(parseIst(h.expiresAt)!)}',
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 11.5,
                      color: AppColors.ink3,
                    ),
                  ),
              ],
            ),
          ),
          AppButton(
            'Resume',
            variant: BtnVariant.secondary,
            onTap: h.id == null || busy
                ? null
                : () async {
                    if (_blockedByMachine()) return;
                    final cart = await state.posResumeHold(h.id!);
                    if (!mounted) return;
                    if (cart == null) {
                      showToast(
                          state.posHoldError ?? 'Could not resume that ticket',
                          'error');
                      refresh(() {});
                      return;
                    }
                    Navigator.of(ctx).pop();
                    // The server never deletes a hold when its basket is
                    // sold: remember it and discard it after the sale.
                    _resumedHoldId = h.id;
                    setState(() {
                      _items
                        ..clear()
                        ..addAll(cart.items
                            .map((e) => <String, dynamic>{
                                  'productId': e.productId,
                                  'qty': e.qty,
                                })
                            .where((e) => e['productId'] != null));
                      _mobile.text = cart.customerMobile ?? '';
                      _coupon.text = cart.couponCode ?? '';
                      _forgetCredit();
                    });
                    _quote(state);
                    showToast('Ticket resumed');
                    unawaited(_capResumed(state));
                  },
          ),
          const SizedBox(width: 6),
          IconBtn(
            'trash',
            size: 34,
            iconSize: 14,
            onTap: h.id == null || busy
                ? null
                : () async {
                    final id = h.id!;
                    _removing.add(id);
                    refresh(() {});
                    final ok = await state.posDeleteHold(id);
                    _removing.remove(id);
                    if (!ok) {
                      showToast(
                          state.posHoldError ??
                              'Could not remove the parked ticket',
                          'error');
                    } else if (_resumedHoldId == id) {
                      // The open ticket came from this hold: it is now a
                      // normal unsaved ticket, nothing left to delete later.
                      _resumedHoldId = null;
                    }
                    if (mounted) setState(() {});
                    refresh(() {});
                  },
          ),
        ],
      ),
    );
  }

  static const _mon = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// `9 Nov, 3:05 pm` for an IST wall-clock time.
  String _stamp(DateTime t) => '${t.day} ${_mon[t.month - 1]}, ${_clock(t)}';

  /// After a hold is resumed: make sure every product's stock is known, then
  /// cut any line above the shelf count ("Only N in stock").
  Future<void> _capResumed(AppState state) async {
    final unknown =
        _items.any((it) => _stockOf(state, '${it['productId']}') == null);
    if (unknown) await state.posLoadProducts();
    if (!mounted) return;
    final cut = _capToStock(state);
    if (cut.isNotEmpty) {
      setState(() {});
      _quote(state);
      showToast('${cut.join(' · ')}. ${gt('The resumed ticket was trimmed to what is in stock.')}',
          'error');
    }
  }

  // -------------------------------------------------------------------------
  // Day report + UPI
  // -------------------------------------------------------------------------

  Future<void> _daySheet(AppState state) async {
    await state.posLoadDayReport();
    if (!mounted) return;
    final r = state.posDayReport;
    await showAppSheet(
      context: context,
      title: 'Today at the till',
      sub: r?.date ?? '',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: r == null
            ? const Hint('No sales recorded today yet.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow('Bills', '${r.bills}'),
                  _statRow('Sales', _rs(r.salesPaise)),
                  _statRow('CGST / SGST',
                      '${_rs(r.cgstPaise)} / ${_rs(r.sgstPaise)}'),
                  _statRow('Cash expected', _rs(r.cashExpectedPaise)),
                  _statRow('Refunds', _rs(r.refundsPaise)),
                  _statRow('Net', _rs(r.netPaise)),
                  if (r.creditGivenPaise > 0)
                    _statRow('Udhar given', _rs(r.creditGivenPaise)),
                  if (r.creditRecoveredPaise > 0)
                    _statRow('Udhar recovered', _rs(r.creditRecoveredPaise)),
                  if (r.creditReturnedPaise > 0)
                    _statRow('Udhar cancelled by returns',
                        _rs(r.creditReturnedPaise)),
                  if (r.paidByMode.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'By payment mode',
                      style: TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final e in r.paidByMode.entries)
                      _statRow(e.key, _rs(e.value)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink2,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upiSheet(AppState state, int amountPaise) async {
    showToast('Generating UPI link…');
    final link = await state.posUpiLink(amountPaise);
    if (!mounted) return;
    await showAppSheet(
      context: context,
      title: 'UPI payment',
      sub: _rs(amountPaise),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: link == null
            ? Hint(state.apiLastError == null
                ? 'Could not generate a UPI link — check the shop’s '
                    'UPI ID in shop settings (UPI is not set up).'
                : 'Could not generate a UPI link — check the shop’s '
                    'UPI ID in shop settings.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.white,
                      child: QrImageView(
                        data: link,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: SelectableText(
                      link,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Hint('Share this link, or open it on the customer’s '
                      'phone to collect the payment.'),
                ],
              ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  List<PosProductDto> _visible(AppState state) {
    final q = _search.text.trim().toLowerCase();
    final list = state.posProducts;
    if (q.isEmpty) return list;
    return list.where((p) {
      final name = (p.name ?? '').toLowerCase();
      final gu = (p.nameGu ?? '').toLowerCase();
      return name.contains(q) ||
          gu.contains(q) ||
          // Pack detail: a till operator types "500 g" or "1 kg" as often as
          // they type the product name, and two variants of one product are
          // only told apart by these.
          (p.displayName ?? '').toLowerCase().contains(q) ||
          (p.variantName ?? '').toLowerCase().contains(q) ||
          (p.packSize ?? '').toLowerCase().contains(q) ||
          (p.unit ?? '').toLowerCase().contains(q) ||
          (p.unitLabel ?? '').toLowerCase().contains(q) ||
          (p.plu ?? '').toLowerCase() == q ||
          p.barcodes.any((b) => b.toLowerCase().contains(q));
    }).toList();
  }

  /// What the till calls a pack. The backend already composes this as
  /// `displayName` — `Name (Variant, 500 g)` (see
  /// `PosCatalogService.displayName`) — so prefer it and only fall back to
  /// building the same shape from the parts for an older payload.
  String _label(PosProductDto p) {
    final d = p.displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    final name = (p.name ?? '').trim().isEmpty ? 'Item' : p.name!.trim();
    final parts = [
      (p.variantName ?? '').trim(),
      (p.packSize ?? '').trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? name : '$name (${parts.join(', ')})';
  }

  /// Selling unit shown beside the price (`kg`, `pcs`, …).
  String _unitOf(PosProductDto p) {
    final u = (p.unitLabel ?? '').trim().isNotEmpty
        ? p.unitLabel!.trim()
        : (p.unit ?? '').trim();
    return u;
  }

  String _rs(int paise) {
    final rupees = paise ~/ 100;
    final p = (paise % 100).abs();
    final base = money(rupees);
    return p == 0 ? base : '$base.${p.toString().padLeft(2, '0')}';
  }

  String _modeLabel(String code) {
    final c = code.toUpperCase();
    if (c == 'CREDIT') return 'Credit (udhar)';
    if (c.contains('UPI')) return 'UPI';
    if (c.contains('COD') || c.contains('CASH')) return 'Cash';
    if (c.contains('CARD')) return 'Card';
    if (c.contains('STORE') || c.contains('PICKUP')) return 'At store';
    if (c.contains('NET') || c.contains('BANK')) return 'Net banking';
    if (c.contains('WALLET')) return 'Wallet';
    return c.isEmpty ? 'Pay' : c[0] + c.substring(1).toLowerCase();
  }

  List<String> _payModes(AppState state) {
    // The counter's modes are fixed by the backend (`PaymentRules.MODES` =
    // CASH, UPI, CARD, plus one CREDIT line on a bill). They do NOT come from
    // `/payment-methods`, whose rows (`COD`, `ONLINE`) describe the online
    // order flow: deriving the till's modes from them used to send `COD` /
    // `ONLINE` as a payment mode and offered no Cash/Card/Credit at all.
    // CREDIT needs a customer mobile (checked in [_charge]).
    return kPosPayModes;
  }

  // -------------------------------------------------------------------------
  // UI - laid out like the "POS counter" design sample: a teal bar, the scan
  // field + product tiles on the left, one "Current bill" card on the right.
  // -------------------------------------------------------------------------

  static const _line2 = AppColors.line;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final bill = state.posBill;
    final modes = _payModes(state);
    if (!modes.contains(_payMode)) _payMode = modes.first;
    final products = _visible(state);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(state),
                const PosOfflineBanner(),
                ScreenScroll(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _posLayout(
                      left: _findPanel(state, products),
                      right: _billPanel(state, bill, modes),
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

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
  }

  Widget _header(AppState state) {
    final shift = state.posShift;
    final open = shift != null;
    String pill;
    if (!state.posShiftLoaded) {
      pill = gt('Checking shift…');
    } else if (!open) {
      pill = gt('No shift open');
    } else {
      final t = parseIst(shift.openedAt);
      pill = '${gt('Shift open')}'
          '${t == null ? '' : ' · ${gt('since')} ${_clock(t)}'}'
          ' · ${gt('float')} ${_rs(shift.openingFloatPaise)}';
    }
    return AdminHead(
      title: gt('POS till'),
      sub: pill,
      bell: false,
      onBack: () => go(state.adminPagesAllowed ? '/admin' : '/admin/orders'),
      actions: [
        const PosOfflineChip(),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: AppButton(
            open ? gt('Close shift') : gt('Start shift'),
            size: BtnSize.sm,
            variant: BtnVariant.gold,
            onTap: () => go('/admin/shift'),
          ),
        ),
      ],
    );
  }

  // --- left: scan + tiles ----------------------------------------------------

  Widget _langTab(String label, bool on, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? SectionPalette.sales.tint : AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            border: Border.all(
                color: on ? SectionPalette.sales.accent : _line2, width: 1.5),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: on ? SectionPalette.sales.accent : AppColors.ink2)),
        ),
      ),
    );
  }

  Widget _scanField(AppState state) {
    return TextField(
      controller: _search,
      autofocus: true,
      textInputAction: TextInputAction.done,
      style: const TextStyle(
          fontFamily: AppTheme.uiFont, fontSize: 18, color: AppColors.ink),
      onChanged: (_) {
        _scanMsg = '';
        _onSearchChanged(state);
      },
      onSubmitted: (_) => unawaited(_searchEnter(state)),
      decoration: InputDecoration(
        hintText: gt('Scan barcode or type a name, then press Enter'),
        hintStyle: const TextStyle(
            fontFamily: AppTheme.uiFont, fontSize: 17, color: AppColors.ink3),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: gt('Clear'),
                icon: const Icon(Icons.close, color: AppColors.ink3),
                onPressed: () {
                  _search.clear();
                  _scanMsg = '';
                  _onSearchChanged(state);
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
          borderSide: BorderSide(color: SectionPalette.sales.accent, width: 2),
        ),
      ),
    );
  }

  String _tileName(PosProductDto p) {
    if (_gu && (p.nameGu ?? '').trim().isNotEmpty) {
      final extra = [(p.variantName ?? '').trim(), (p.packSize ?? '').trim()]
          .where((s) => s.isNotEmpty)
          .join(', ');
      return extra.isEmpty ? p.nameGu!.trim() : '${p.nameGu!.trim()} ($extra)';
    }
    return _label(p);
  }

  Widget _tile(AppState state, PosProductDto p, double width) {
    final weighed = p.soldBy == 'WEIGHT';
    final out = p.qtyOnHand <= 0;
    final tag = out
        ? gt('Out of stock')
        : weighed
            ? gt('Sold by weight')
            : (p.gstPercent == 0
                ? gt('No GST')
                : '${gt('GST')} ${p.gstPercent}%');
    final unit = weighed ? gt('per kg') : '';
    return SizedBox(
      width: width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _add(state, p),
          child: Semantics(
            button: true,
            label: '${gt('Add')} ${_tileName(p)}, ${_rs(p.pricePaise)} $unit',
            child: Container(
              constraints: const BoxConstraints(minHeight: 132),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
                border: Border.all(color: AppColors.line, width: 1.5),
              ),
              child: Opacity(
                opacity: out ? .55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(_tileName(p),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: AppTheme.uiFont,
                                  fontSize: 15.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                        const SizedBox(width: 8),
                        PosThumb(
                            imageUrl: p.imageUrl,
                            name: p.name ?? '',
                            size: 48),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(tag,
                        style: TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 13,
                            color: out ? AppColors.red : AppColors.ink2)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_rs(p.pricePaise),
                            style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                      fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.ink)),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(unit,
                              style: const TextStyle(
                                  fontFamily: AppTheme.uiFont,
                                  fontSize: 13,
                                  color: AppColors.ink2)),
                        ],
                      ],
                    ),
                    if (_lotNote(p) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_lotNote(p)!,
                            style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.goldInk)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _findPanel(AppState state, List<PosProductDto> products) {
    final q = _search.text.trim();
    final shown = products.take(150).toList();
    final noHit = q.isNotEmpty && _scanMsg.isNotEmpty && products.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          final tabs = Row(mainAxisSize: MainAxisSize.min, children: [
            _langTab('English', !_gu, () => setState(() => _gu = false)),
            const SizedBox(width: 6),
            _langTab('ગુજરાતી', _gu, () => setState(() => _gu = true)),
          ]);
          if (c.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_scanField(state), const SizedBox(height: 10), tabs],
            );
          }
          return Row(children: [
            Expanded(child: _scanField(state)),
            const SizedBox(width: 12),
            tabs,
          ]);
        }),
        if (noHit) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_scanMsg,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldInk)),
          ),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          const gap = 12.0;
          final cols = ((c.maxWidth + gap) ~/ (170 + gap)).clamp(1, 8);
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final p in shown) _tile(state, p, w)],
          );
        }),
        const SizedBox(height: 14),
        Text(
          gt('Scan a barcode or type a name and press Enter. Tap a product to add it; weighed items ask for the weight.'),
          style: const TextStyle(
              fontFamily: AppTheme.uiFont, fontSize: 14, color: AppColors.ink2),
        ),
      ],
    );
  }

  // --- right: Current bill ---------------------------------------------------

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.sh1,
        ),
        child: child,
      );

  Widget _billPanel(AppState state, PosBillViewDto? bill, List<String> modes) {
    final done = _done;
    if (done != null) return _card(child: _donePanel(state, done));
    final empty = _items.isEmpty;
    final due = bill == null ? 0 : _outstanding(bill);
    final cashMode = normalizePayMode(_payMode) == 'CASH';
    final hasCashSplit = _splits.any((l) => l['mode'] == 'CASH');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // title + Hold / Held / Clear
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(gt('Current bill'),
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.ink)),
              Wrap(spacing: 8, children: [
                AppButton(gt('Hold'),
                    size: BtnSize.sm,
                    variant: BtnVariant.secondary,
                    disabled: empty,
                    onTap: empty ? null : () => unawaited(_park(state))),
                AppButton(
                    '${gt('Held')} (${PosOffline.instance.offline ? PosOffline.instance.localHolds().length : state.posHolds.length})',
                    size: BtnSize.sm,
                    variant: BtnVariant.secondary,
                    disabled: !PosOffline.instance.offline && state.posHolds.isEmpty,
                    onTap: PosOffline.instance.offline
                        ? () => unawaited(showLocalHoldsSheet(context, (items, mobile) {
                              setState(() {
                                _items
                                  ..clear()
                                  ..addAll(items);
                                _mobile.text = mobile ?? '';
                              });
                              _quote(state);
                            }))
                        : (state.posHolds.isEmpty
                            ? null
                            : () => unawaited(_holdsSheet(state)))),
                AppButton(gt('Clear'),
                    size: BtnSize.sm,
                    variant: BtnVariant.secondary,
                    disabled: empty,
                    onTap: empty ? null : () => _clear(state)),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          // customer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppField(
                  label: gt('Customer mobile (optional)'),
                  controller: _mobile,
                  numeric: true,
                  maxLength: 10,
                  placeholder: gt('10-digit number for coins or credit'),
                  error: _mobileBad
                      ? gt(Validators.mobile(_mobile.text) ??
                          'Enter 10 digits, or clear this box')
                      : null,
                  onChanged: (_) {
                    setState(() {});
                    final m = _mobileOrNull;
                    if (m != null && m != _lastQuotedMobile) _quote(state);
                    if (m != null && m != _credMobile) {
                      unawaited(_refreshCredit(state));
                    }
                    if (m == null && _credMobile != null) {
                      setState(_forgetCredit);
                    }
                  },
                  onEditingComplete: () => _quote(state),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppField(
                  label: gt('Coupon'),
                  controller: _coupon,
                  uppercase: true,
                  maxLength: 30,
                  placeholder: gt('Optional'),
                  onEditingComplete: () => _quote(state),
                ),
              ),
            ],
          ),
          _customerBox(state, bill),
          _coinBox(state, bill),
          const SizedBox(height: 16),

          // lines
          if (empty)
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line2, width: 2),
              ),
              child: Text(gt('Scan an item or tap a product to start'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 14,
                      color: AppColors.ink2)),
            )
          else
            for (var i = 0; i < _items.length; i++) _lineRow(state, i),

          // discount
          const SizedBox(height: 12),
          _discountBlock(state, bill, empty),

          // totals
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              children: [
                _totalRow(
                    gt('Subtotal'),
                    bill != null
                        ? _rs(bill.subtotalPaise)
                        : (empty ? _rs(0) : '…')),
                if (bill != null && bill.couponDiscountPaise > 0)
                  _totalRow('${gt('Coupon')} ${bill.couponCode ?? ''}',
                      '− ${_rs(bill.couponDiscountPaise)}'),
                if (bill != null && bill.coinDiscountPaise > 0)
                  _totalRow(gt('Coins'), '− ${_rs(bill.coinDiscountPaise)}'),
                if (bill != null && bill.manualDiscountPaise > 0)
                  _totalRow(
                      '${gt('Discount')} (${_mdReason.text.trim().isEmpty ? gt('manual') : _mdReason.text.trim()})',
                      '− ${_rs(bill.manualDiscountPaise)}'),
                if (bill != null && bill.lines.isNotEmpty)
                  PosGstTable(
                    rows: gstSlabs([
                      for (final l in bill.lines) GstLine(l.gstPercent, l.netPaise)
                    ]),
                    taxablePaise: bill.taxablePaise,
                    cgstPaise: bill.cgstPaise,
                    sgstPaise: bill.sgstPaise,
                    estimate: true,
                  ),
                if (bill != null && bill.roundOffPaise != 0)
                  _totalRow(gt('Round-off'),
                      '${bill.roundOffPaise < 0 ? '−' : '+'} ${_rs(bill.roundOffPaise.abs())}'),
                if (_splits.isNotEmpty && bill != null)
                  _totalRow(gt('Still due'), _rs(due)),
                if (bill != null && bill.warnings.isNotEmpty)
                  for (final w in bill.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(w,
                            style: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 12,
                                color: AppColors.red)),
                      ),
                    ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(gt('To pay'),
                          style: const TextStyle(
                              fontFamily: AppTheme.uiFont,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              bill != null ? _rs(bill.totalPaise) : (empty ? _rs(0) : '…'),
                              style: const TextStyle(
                                  fontFamily: AppTheme.uiFont,
                      fontWeight: FontWeight.w800,
                                  fontSize: 34,
                                  color: AppColors.ink)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // payment method
          const SizedBox(height: 16),
          Row(children: [
            for (var i = 0; i < modes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _payBtn(state, modes[i])),
            ],
          ]),
          if (_modeErrFor(_splits.length) != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_modeErrFor(_splits.length)!,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12,
                      color: AppColors.red)),
            ),
          const SizedBox(height: 12),
          if (cashMode || hasCashSplit) _cashBlock(bill),
          if (normalizePayMode(_payMode) == 'UPI' && bill != null)
            _upiBox(state, due),
          _channelBox(state, bill),
          if ((normalizePayMode(_payMode) == 'CARD' ||
                  normalizePayMode(_payMode) == 'UPI') &&
              _machine?.session?.paid != true)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AppField(
                label: gt('Reference (optional)'),
                controller: _reference,
                placeholder: gt('UPI txn / last 4'),
              ),
            ),
          if (normalizePayMode(_payMode) == 'CREDIT') _creditPanel(state, bill),
          _splitBlock(state, bill),

          // charge
          const SizedBox(height: 16),
          SizedBox(
            height: 68,
            child: AppButton(
              bill == null && _items.isNotEmpty
                  ? gt('Pricing…')
                  : '${gt('Charge')} ${bill == null ? '' : _rs(due)}',
              block: true,
              size: BtnSize.lg,
              loading: _busy,
              disabled: empty,
              onTap: (_busy || empty) ? null : () => unawaited(_charge(state)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(gt('Find old bill / Return'),
                  size: BtnSize.sm,
                  variant: BtnVariant.secondary,
                  onTap: () => showPosReturnSheet(context)),
              AppButton(gt('Take credit repayment'),
                  size: BtnSize.sm,
                  variant: BtnVariant.secondary,
                  onTap: () => showPosCollectCreditSheet(context)),
              AppButton(gt('Today’s totals'),
                  size: BtnSize.sm,
                  variant: BtnVariant.secondary,
                  onTap: () => _daySheet(state)),
            ],
          ),
        ],
      ),
    );
  }

  /// "Use coins" chooser: shown when the typed customer has coins.
  Widget _coinBox(AppState state, PosBillViewDto? bill) {
    if (PosOffline.instance.offline || _mobileOrNull == null) {
      return const SizedBox.shrink();
    }
    final bal = bill?.customerCoinBalance ?? 0;
    if (bal <= 0 && _coinMode == 'NONE') return const SizedBox.shrink();
    void pick(String mode, [int pct = 50]) {
      setState(() {
        _coinMode = mode;
        _coinPct = pct;
      });
      _quote(state);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${gt('Use coins')} ($bal ${gt('available')})',
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink2)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          AppChip(gt('No coins'),
              small: true,
              selected: _coinMode == 'NONE',
              onTap: () => pick('NONE')),
          AppChip(gt('All'),
              small: true,
              selected: _coinMode == 'ALL',
              onTap: () => pick('ALL')),
          for (final p in const [25, 50, 75])
            AppChip('$p%',
                small: true,
                selected: _coinMode == 'PERCENT' && _coinPct == p,
                onTap: () => pick('PERCENT', p)),
        ]),
        if (bill != null && bill.coinsUsed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                '${bill.coinsUsed} ${gt('coins used')} = ${_rs(bill.coinDiscountPaise)}',
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12.5,
                    color: AppColors.ink)),
          ),
      ]),
    );
  }

  Widget _customerBox(AppState state, PosBillViewDto? bill) {
    final m = _mobileOrNull;
    if (m == null) return const SizedBox.shrink();
    const body = TextStyle(
        fontFamily: AppTheme.uiFont, fontSize: 14, color: AppColors.ink);
    Widget box(Color bg, List<Widget> kids) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: kids),
        );
    if (_credBusy || _credMobile != m) return const SizedBox.shrink();
    final acc = _credAcc;
    if (acc != null) {
      final coins = bill?.customerCoinBalance;
      final credit = acc.limitPaise > 0
          ? '${gt('credit available')} ${_rs(acc.availablePaise)}'
          : gt('credit not enabled');
      return box(AppColors.greenTint, [
        Text((acc.name ?? '').trim().isEmpty ? m : acc.name!.trim(),
            style: body.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
            '${coins == null ? '' : '$coins ${gt('coins')} · '}$credit',
            style: body.copyWith(fontSize: 13)),
      ]);
    }
    if (_credStatus == 404) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(gt('New customer. They will earn coins on this bill.'),
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 14,
                color: AppColors.ink2)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _discountBlock(AppState state, PosBillViewDto? bill, bool empty) {
    final admin = state.adminPagesAllowed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          _discOn ? gt('Change discount') : gt('Give a discount'),
          size: BtnSize.sm,
          variant: BtnVariant.secondary,
          disabled: empty,
          onTap: empty
              ? null
              : () => setState(() {
                    _discOpen = !_discOpen;
                    _discErr = null;
                  }),
        ),
        if (_discOpen)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line2, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldRow(
                  flex: const [2, 3],
                  children: [
                    AppField(
                      label: gt('Amount (₹)'),
                      controller: _mdAmount,
                      numeric: true,
                      error: _rupeeErr(_mdAmount.text, gt('Discount')),
                      onChanged: (_) => setState(() {}),
                    ),
                    AppField(
                      label: gt('Reason'),
                      controller: _mdReason,
                      maxLength: 100,
                      placeholder: gt('e.g. damaged pack'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppField(
                  label: admin
                      ? gt('Manager PIN (optional for admins)')
                      : gt('Manager PIN (4–8 digits, asked from cashiers)'),
                  controller: _mdPin,
                  numeric: true,
                  obscure: true,
                  maxLength: 8,
                  onChanged: (_) => setState(() {}),
                  error: _needPin && _mdPin.text.trim().isEmpty
                      ? gt('Ask a manager to enter their PIN')
                      : (_mdPin.text.trim().isNotEmpty &&
                              !RegExp(r'^\d{4,8}$').hasMatch(_mdPin.text.trim())
                          ? gt('PIN must be 4 to 8 digits')
                          : null),
                ),
                if (_discErr != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_discErr!,
                        style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red3)),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: AppButton(gt('Apply discount'),
                        size: BtnSize.sm,
                        onTap: () => _applyDiscount(state)),
                  ),
                  if (_discOn) ...[
                    const SizedBox(width: 8),
                    AppButton(gt('Remove'),
                        size: BtnSize.sm,
                        variant: BtnVariant.danger,
                        onTap: () => _removeDiscount(state)),
                  ],
                ]),
              ],
            ),
          ),
      ],
    );
  }

  void _applyDiscount(AppState state) {
    String? err;
    final aErr = Validators.rupees(_mdAmount.text,
        label: gt('Discount'), required: true, min: 0.01, max: 1000000);
    if (aErr != null) {
      err = gt(aErr);
    } else if (_mdReason.text.trim().isEmpty) {
      err = gt('A reason is needed for every discount.');
    } else if (_mdReason.text.trim().length > 100) {
      err = gt('The reason must be 100 characters or fewer.');
    } else if (_mdPin.text.trim().isNotEmpty &&
        !RegExp(r'^\d{4,8}$').hasMatch(_mdPin.text.trim())) {
      err = gt('PIN must be 4 to 8 digits');
    } else if (!state.adminPagesAllowed && _mdPin.text.trim().isEmpty) {
      err = gt('Ask a manager to enter their PIN (4–8 digits).');
    }
    if (err != null) {
      setState(() => _discErr = err);
      return;
    }
    setState(() {
      _discOn = true;
      _discOpen = false;
      _discErr = null;
    });
    _quote(state);
  }

  void _removeDiscount(AppState state) {
    setState(() {
      _discOn = false;
      _discOpen = false;
      _discErr = null;
      _mdAmount.clear();
      _mdReason.clear();
      _mdPin.clear();
      _needPin = false;
    });
    _quote(state);
  }

  Widget _payBtn(AppState state, String m) {
    final on = normalizePayMode(_payMode) == m;
    final label = switch (m) {
      'CASH' => gt('Cash'),
      'UPI' => 'UPI',
      'CARD' => gt('Card'),
      'CREDIT' => gt('Udhar'),
      _ => _modeLabel(m),
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _payMode = m;
            _amount.clear();
          });
          if (m == 'CREDIT') unawaited(_refreshCredit(state));
        },
        child: Semantics(
          button: true,
          selected: on,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? SectionPalette.sales.tint : AppColors.white,
              borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
              border: Border.all(
                  color: on ? SectionPalette.sales.accent : _line2, width: 1.5),
            ),
            child: Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: on ? SectionPalette.sales.accent : AppColors.ink2)),
          ),
        ),
      ),
    );
  }

  /// Where the money of the chosen mode goes (one channel per vendor: a Paytm
  /// machine, a bank machine, a QR account ...) and the machine flow. The
  /// chosen channel's `moneyAccountId` is sent on the payment line.
  Widget _channelBox(AppState state, PosBillViewDto? bill) {
    final mode = normalizePayMode(_payMode);
    if (mode != 'CASH' && mode != 'UPI' && mode != 'CARD') {
      return const SizedBox.shrink();
    }
    final list = _channelsOf(mode);
    final ch = _channelOf(mode);
    final ms = _machine?.session;
    const lab = TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.ink2);
    final kids = <Widget>[];
    if (list.length > 1) {
      kids.add(Text(gt('Money goes to'), style: lab));
      kids.add(const SizedBox(height: 6));
      kids.add(Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in list)
          AppChip(c.label,
              small: true,
              selected: _chosen[mode] == c.moneyAccountId,
              onTap: _machineBusy()
                  ? null
                  : () => setState(() => _chosen[mode] = c.moneyAccountId ?? '')),
      ]));
    } else if (list.length == 1) {
      kids.add(Text('${gt('Money goes to')}: ${list.first.label}', style: lab));
    }
    final canMachine = (mode == 'CARD' || mode == 'UPI') &&
        ((ch != null && ch.isMachine) || (ms != null && (ms.open || ms.paid)));
    if (canMachine) {
      final live = ms != null && ms.posSaleId == null && (ms.open || ms.paid);
      kids.add(const SizedBox(height: 10));
      if (live) {
        kids.add(Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ms.paid ? AppColors.greenTint : AppColors.goldTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
              ms.paid
                  ? '${gt('Machine payment received')} ${_rs(ms.amountPaise)}. ${gt('Press Charge to put it on the bill.')}'
                  : '${gt('Waiting for the machine payment of')} ${_rs(ms.amountPaise)}',
              style: lab.copyWith(color: AppColors.ink)),
        ));
        kids.add(const SizedBox(height: 8));
      }
      kids.add(AppButton(
          live
              ? gt('Open machine payment')
              : (ch != null && ch.isManual
                  ? gt('Charge on bank machine')
                  : gt('Take on card machine')),
          size: BtnSize.sm,
          block: true,
          variant: live ? BtnVariant.secondary : BtnVariant.primary,
          disabled: bill == null || _items.isEmpty,
          onTap: bill == null || _items.isEmpty
              ? null
              : () => unawaited(_takeOnMachine(state))));
      kids.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
            gt('Needs the internet. Without it, type the slip reference below instead.'),
            style: lab.copyWith(fontWeight: FontWeight.w500)),
      ));
    }
    if (kids.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );
  }

  /// Start (or reopen) the card/UPI machine payment for the amount on the form.
  Future<void> _takeOnMachine(AppState state) async {
    if (PosOffline.instance.offline) {
      showToast(gt('A card machine needs the internet. Type the slip reference instead.'), 'error');
      return;
    }
    final bill = state.posBill;
    if (bill == null || _items.isEmpty) {
      showToast(gt('Add items and wait for the price first'), 'error');
      return;
    }
    final mode = normalizePayMode(_payMode);
    final ch = _channelOf(mode);
    var h = _machine;
    final live = h?.session;
    int amt;
    if (h != null && live != null && live.posSaleId == null && (live.open || live.paid)) {
      amt = live.amountPaise;
    } else {
      if (ch == null || !ch.isMachine) return;
      final out = _outstanding(bill);
      var paise = out;
      final raw = _amount.text.trim();
      if (raw.isNotEmpty) {
        final bad = Validators.rupees(raw,
            label: gt('Amount'), required: true, min: 0.01, max: 1000000);
        if (bad != null) {
          showToast(gt(bad), 'error');
          return;
        }
        paise = (double.parse(raw) * 100).round();
      }
      if (paise < 1 || paise > out) {
        showToast(gt('The machine amount must be between Rs 0.01 and the amount still due'),
            'error');
        return;
      }
      amt = paise;
      // Park the basket BEFORE the machine starts, so a crash can restore it
      // (P3 F6 / F8). The sale later removes this hold.
      if (_resumedHoldId == null) {
        try {
          final hold = await Api.instance.pos.createHold(
              label: 'Card payment ${DateTime.now().millisecondsSinceEpoch % 100000}',
              cart: PosCartDto(
                items: _items
                    .map((e) => OrderItemDto(
                        productId: e['productId']?.toString(),
                        qty: (e['qty'] as num?)?.toInt() ?? 1))
                    .toList(),
                customerMobile: _mobileOrNull,
              ).toJson());
          _resumedHoldId = hold.id;
          state.posHolds = [hold, ...state.posHolds.where((x) => x.id != hold.id)];
        } on ApiException catch (e) {
          showToast('${gt('Could not park the basket first')}: ${e.message}', 'error');
        } catch (_) {}
      }
      if (!mounted) return;
      h = PosMachineHolder(
          reference: 'VSM${DateTime.now().millisecondsSinceEpoch}',
          channel: ch,
          mode: mode);
      final hh = h;
      h.onSession = (x) => _persistMachine(hh, x);
      setState(() => _machine = h);
    }
    final used = await showPosTerminalSheet(context, holder: h, amountPaise: amt);
    if (!mounted) return;
    final sess = h.session;
    setState(() {
      // Nothing live (never started, declined, cancelled, voided): forget it.
      _machine = (sess != null && sess.posSaleId == null && (sess.open || sess.paid))
          ? h
          : null;
    });
    if (used != null) {
      final b = state.posBill;
      // Paid in full by the machine: finish the bill without a Charge tap.
      if (b != null && !_busy && _outstanding(b) == used.amountPaise) {
        showToast(gt('Payment received. Completing the bill…'));
        unawaited(_charge(state));
      } else {
        showToast(gt('Machine payment ready. Press Charge to put it on the bill.'));
      }
    }
  }

  /// Message under a rupee input (empty is fine), up to Rs 10 lakh.
  String? _rupeeErr(String v, String label) {
    if (v.trim().isEmpty) return null;
    final e = Validators.rupees(v, label: label, min: 0.01, max: 1000000);
    return e == null ? null : gt(e);
  }

  Widget _cashBlock(PosBillViewDto? bill) {
    final dueRupees = (_cashDue(bill) / 100).ceil();
    final tendered = (double.tryParse(_tendered.text.trim()) ?? -1) * 100;
    final change = tendered.round() - _cashDue(bill);
    final short = tendered >= 0 && change < 0;
    final notes = <(String, int)>[
      (gt('Exact'), dueRupees),
      ('₹500', 500),
      ('₹1,000', 1000),
      ('₹2,000', 2000),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          label: gt('Cash received (₹)'),
          controller: _tendered,
          numeric: true,
          error: _rupeeErr(_tendered.text, gt('Cash received')),
          placeholder: bill == null ? '0' : (dueRupees).toString(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < notes.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: AppButton(notes[i].$1,
                  size: BtnSize.sm,
                  variant: BtnVariant.secondary,
                  onTap: () =>
                      setState(() => _tendered.text = '${notes[i].$2}')),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Text(
          tendered < 0
              ? '${gt('Give change')}: ${_rs(0)}'
              : short
                  ? '${gt('Short by')} ${_rs(-change)}'
                  : '${gt('Give change')}: ${_rs(change)}',
          style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: short ? AppColors.red3 : AppColors.ink),
        ),
      ],
    );
  }

  Widget _upiBox(AppState state, int due) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line2, width: 1.5),
      ),
      child: Column(children: [
        Text('${gt('UPI QR for')} ${_rs(due)} ${gt('shows here for the customer to scan.')}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 14,
                color: AppColors.ink2)),
        const SizedBox(height: 10),
        AppButton('${gt('Show UPI link for')} ${_rs(due)}',
            size: BtnSize.sm,
            variant: BtnVariant.secondary,
            onTap: () => unawaited(_upiSheet(state, due))),
      ]),
    );
  }

  /// Split / hybrid payment (part cash, part UPI, some on credit). Folded away
  /// until asked for, so a plain single-mode sale stays as simple as the
  /// design sample.
  Widget _splitBlock(AppState state, PosBillViewDto? bill) {
    final open = _splitOpen || _splits.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppButton(
              open && _splits.isEmpty
                  ? gt('Hide split payment')
                  : gt('Split this payment'),
              size: BtnSize.xs,
              variant: BtnVariant.ghost,
              onTap: _splits.isNotEmpty
                  ? null
                  : () => setState(() => _splitOpen = !_splitOpen),
            ),
          ),
        ),
        if (open)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line2, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _splits.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${_modeLabel('${_splits[i]['mode']}')} · '
                          '${_rs((_splits[i]['amountPaise'] as num).toInt())}'
                          '${(_splits[i]['reference'] ?? '').toString().isEmpty ? '' : ' · ${_splits[i]['reference']}'}'
                          '${_modeErrFor(i) == null ? '' : ' - ${_modeErrFor(i)}'}',
                          style: TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _modeErrFor(i) == null
                                ? AppColors.ink2
                                : AppColors.red,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _splits.removeAt(i)),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 16, color: AppColors.ink3),
                        ),
                      ),
                    ]),
                  ),
                Text(
                  gt('Pick a payment method above, type how much of the bill it covers, then add it. The rest is charged with the method you pick last.'),
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12.5,
                      color: AppColors.ink2),
                ),
                const SizedBox(height: 10),
                AppField(
                  label: gt('Amount (₹)'),
                  controller: _amount,
                  numeric: true,
                  placeholder: bill == null ? '0' : _rs(_outstanding(bill)),
                  error: _rupeeErr(_amount.text, gt('Amount')),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                AppButton(
                  '${gt('Add')} ${_amount.text.trim().isEmpty ? _rs(_outstanding(bill)) : gt('this')} ${gt('as a split line')}',
                  block: true,
                  size: BtnSize.sm,
                  variant: BtnVariant.secondary,
                  onTap: () => _addSplit(state),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _donePanel(AppState state, SaleRecordDto sale) {
    String mode = (sale.paymentType ?? '').toUpperCase();
    mode = switch (mode) {
      'CREDIT' => gt('Udhar (credit)'),
      'CASH' => gt('Cash'),
      'CARD' => gt('Card'),
      'SPLIT' || 'HYBRID' => gt('Split payment'),
      '' || 'NONE' => '',
      _ => mode,
    };
    final cash = sale.changePaise > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.greenTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${gt('Paid')} ${_rs(sale.totalPaise)}',
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: AppColors.green)),
              const SizedBox(height: 6),
              Text(
                  '${gt('Bill')} ${sale.invoiceNo ?? ''}'
                  '${mode.isEmpty ? '' : ' · $mode'}',
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 15,
                      color: AppColors.ink)),
              const SizedBox(height: 6),
              Text(
                  cash
                      ? '${gt('Give change')}: ${_rs(sale.changePaise)}'
                      : gt('Payment confirmed'),
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
            ],
          ),
        ),
        if (sale.items.isNotEmpty)
          PosGstTable(
            rows: gstSlabs([
              for (final i in sale.items)
                GstLine(i.gstPercent, i.netPaise,
                    taxable: i.taxablePaise,
                    cgst: i.cgstPaise,
                    sgst: i.sgstPaise)
            ]),
            taxablePaise: sale.taxablePaise,
            cgstPaise: sale.cgstPaise,
            sgstPaise: sale.sgstPaise,
          ),
        if (_doneEntry != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                gt('Saved offline. This number is temporary: the real invoice number comes after the bill is sent.'),
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    color: AppColors.red)),
          ),
        if (sale.id != null && _doneEntry == null) PayerDetail.sale(sale.id!),
        if ((sale.manualDiscountApprover ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                '${gt('Discount approved by')} ${sale.manualDiscountApprover}',
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    color: AppColors.ink2)),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 56,
          child: AppButton(gt('Receipt: view / print (58 mm, 80 mm)'),
              block: true,
              variant: BtnVariant.secondary,
              onTap: () => unawaited(_receiptSheet(state, sale))),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 64,
          child: AppButton(gt('Start next sale'),
              block: true,
              size: BtnSize.lg,
              onTap: () => setState(() {
                _done = null;
                _doneEntry = null;
              })),
        ),
      ],
    );
  }

  /// `payments[i].mode` error of the last failed charge, for payment row [i]
  /// (locked split lines come first, the form line is the last index).
  String? _modeErrFor(int i) => _payErrors['payments[$i].mode'];

  /// One bill line: name + unit price, - qty +, amount (design sample).
  Widget _lineRow(AppState state, int i) {
    final it = _items[i];
    final id = it['productId']?.toString() ?? '';
    final qty = (it['qty'] as num?)?.toInt() ?? 1;
    // One basket row can come back as SEVERAL bill lines (a lot price change
    // or a flash sale splits it into price runs): group them by product.
    final runs = state.posBill?.lines.where((l) => l.productId == id).toList() ??
        const <BillLineDto>[];
    final billLine = runs.isEmpty ? null : runs.first;
    PosProductDto? known = _known[id];
    for (final p in state.posProducts) {
      if (p.productId == id) {
        known = p;
        break;
      }
    }
    final stock = _stockOf(state, id);
    final name = billLine?.name ?? (known == null ? 'Item' : _label(known));
    final net =
        runs.isEmpty ? null : runs.fold<int>(0, (t, l) => t + l.netPaise);
    // Weighed lines hold grams: step 100 g and show the weight in kg.
    final weighed = (billLine?.soldBy ?? known?.soldBy) == 'WEIGHT';
    final step = weighed ? 100 : 1;
    final unitPaise = billLine?.unitPricePaise ?? known?.pricePaise;
    final unitText = runs.length > 1
        ? runs
            .map((l) =>
                '${weighed ? _kg(l.qty) : l.qty} x ${_rs(l.unitPricePaise)}')
            .join(' + ')
        : unitPaise == null
        ? ''
        : weighed
            ? '${_rs(unitPaise)} ${gt('per kg')}'
            : '${_rs(unitPaise)} ${gt('each')}';

    Widget qbtn(String t, VoidCallback onTap, String tip) => Semantics(
          button: true,
          label: tip,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line2, width: 1.5),
                ),
                child: Text(t,
                    style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          PosThumb(imageUrl: known?.imageUrl, name: name, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                if (unitText.isNotEmpty)
                  Text(unitText,
                      style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 13,
                          color: AppColors.ink2)),
                if (_lotNote(known) != null)
                  Text(_lotNote(known)!,
                      style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldInk)),
                if (stock != null && qty >= stock)
                  Text(
                    stock <= 0
                        ? gt('Out of stock')
                        : gt('Only $stock${weighed ? ' g' : ''} in stock'),
                    style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          qbtn('−', () => _setQty(state, i, qty - step), '${gt('Less')} $name'),
          SizedBox(
            width: 78,
            child: _QtyBox(
              key: ValueKey('qty-${_items[i]['productId']}-$i'),
              qty: qty,
              weighed: weighed,
              line: _line2,
              onCommit: (v) => unawaited(_commitQty(state, i, v)),
            ),
          ),
          qbtn('+', () => _setQty(state, i, qty + step), '${gt('More')} $name'),
          SizedBox(
            width: 82,
            child: Text(net == null ? '…' : _rs(net),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: bold ? 14.5 : 13,
                fontWeight: FontWeight.w800,
                color: bold ? AppColors.ink : AppColors.ink2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: bold ? 16 : 13.5,
              fontWeight: FontWeight.w800,
              color: bold ? SectionPalette.sales.accent : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  /// The cash the change box is figured against: every cash line in the
  /// payment set — a cash split already locked in plus the one being taken
  /// now (which defaults to whatever is still due).
  int _cashDue(PosBillViewDto? bill) {
    var cash = 0;
    for (final l in _splits) {
      if (l['mode'] == 'CASH') {
        cash += (l['amountPaise'] as num?)?.toInt() ?? 0;
      }
    }
    if (normalizePayMode(_payMode) != 'CASH') return cash;
    final raw = _amount.text.trim();
    if (raw.isEmpty) return cash + _outstanding(bill);
    final rupees = double.tryParse(raw);
    return rupees == null || rupees <= 0 ? cash : cash + (rupees * 100).round();
  }

  Widget _posLayout({required Widget left, required Widget right}) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 860) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: right),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, const SizedBox(height: 20), right, const SizedBox(height: 8)],
      );
    });
  }
}

/// Inline quantity box on a ticket line: the cashier types the number (e.g.
/// 100) and presses Enter or leaves the box; no repeated scans or taps.
class _QtyBox extends StatefulWidget {
  const _QtyBox(
      {super.key,
      required this.qty,
      required this.weighed,
      required this.line,
      required this.onCommit});
  final int qty;
  final bool weighed;
  final Color line;
  final void Function(int) onCommit;

  @override
  State<_QtyBox> createState() => _QtyBoxState();
}

class _QtyBoxState extends State<_QtyBox> {
  late final TextEditingController _c;
  final _f = FocusNode();

  String get _shown => '${widget.qty}';

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _shown);
    _f.addListener(() {
      if (_f.hasFocus) {
        _c.selection = TextSelection(baseOffset: 0, extentOffset: _c.text.length);
      } else {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(_QtyBox old) {
    super.didUpdateWidget(old);
    if (!_f.hasFocus && old.qty != widget.qty) _c.text = _shown;
  }

  void _commit() {
    final v = int.tryParse(_c.text.trim());
    if (v == null || v < 0) {
      _c.text = _shown;
      return;
    }
    if (v != widget.qty) widget.onCommit(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.weighed ? 'Type grams' : 'Type quantity',
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _c,
          focusNode: _f,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _commit(),
          style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixText: widget.weighed ? 'g' : null,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.line, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 1.5)),
          ),
        ),
      ),
    );
  }
}
