import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api/api_client.dart' show newIdempotencyKey;
import 'api/api_exception.dart';
import 'api/api_service.dart';
import 'api/dto.dart';
import 'ist.dart';
import 'local_store.dart';

/// Offline billing for the counter till (guide 30 "Offline mode" and the
/// "as rung" addendum, playbook P3 F11, guide 74 / P5 section 13).
///
/// What it does, in the guide's own words:
///  * keeps a copy of the product list + shop details in the browser (a full
///    download at least once a day, `updatedSince` in between, decided from
///    `GET /pos/sync/status` `catalogVersion`);
///  * detects that the server cannot be reached (or lets the cashier switch to
///    offline on purpose) and prices the basket on the device with the same
///    rules as the server (GST-inclusive prices, weighed lines per 1000 g,
///    half-up, the shop's round-off setting);
///  * queues every bill in browser storage with its own `Idempotency-Key`
///    (`idempotencyKey`, generated once, never regenerated) and the `soldAt`
///    moment, as a `rung` snapshot of the prices the till charged;
///  * refuses what cannot be checked offline: coupons, coins, credit (udhar)
///    and card/UPI machine payments;
///  * uploads the queue, oldest first, 50 per call, to `POST /pos/sync/sales`
///    and reads every per-bill result (`CREATED`, `DUPLICATE`, `REJECTED`,
///    `exceptions` incl. `OVERSOLD`); a rejected bill stays on the device in a
///    "needs attention" list, a transient `INTERNAL_ERROR` is retried.
///
/// Nothing here invents an invoice number: a bill gets a temporary local
/// number (`OFF-...`) that is replaced by the server's `invoiceNo` after sync.
class PosOffline extends ChangeNotifier {
  PosOffline._();
  static final PosOffline instance = PosOffline._();

  static const _kCat = 'vsm.posoff.catalog';
  static const _kMeta = 'vsm.posoff.meta';
  static const _kQueue = 'vsm.posoff.queue';
  static const _kHolds = 'vsm.posoff.holds';
  static const _kForced = 'vsm.posoff.forced';

  /// Bill states kept in [queue].
  static const queued = 'QUEUED';
  static const attention = 'ATTENTION';
  static const synced = 'SYNCED';

  bool _inited = false;

  // --- connection -----------------------------------------------------------

  /// The cashier chose "work offline" (kept across a refresh).
  bool forced = false;

  /// False when the last call to the server failed at the transport level.
  bool reachable = true;

  /// The till should bill offline now.
  bool get offline => forced || !reachable;

  /// Server clock minus device clock, from `GET /pos/sync/status`.
  Duration? clockSkew;

  /// More than a few minutes of difference: offline bills would carry a wrong
  /// `soldAt`, so the till refuses to ring them.
  bool get clockBad =>
      clockSkew != null && clockSkew!.inMinutes.abs() >= 4;

  int maxOfflineDays = 7;
  int batchLimit = 50;
  Timer? _watch;
  bool _probing = false;

  // --- catalogue copy -------------------------------------------------------

  final Map<String, Map<String, dynamic>> _raw = {};
  final Map<String, PosProductDto> _byId = {};
  List<PosProductDto> products = const [];
  Map<String, dynamic> shop = const {};
  String catalogVersion = '';
  DateTime? lastFull;
  DateTime? lastRefresh;
  bool refreshing = false;
  String? refreshError;

  bool get hasCatalogue => _raw.isNotEmpty;

  // --- queue ----------------------------------------------------------------

  /// Offline bills, oldest first. Each entry is a JSON map, see [enqueue].
  List<Map<String, dynamic>> queue = [];
  bool syncing = false;
  String? syncMessage;

  int get waiting => queue.where((b) => b['status'] == queued).length;
  int get needAttention => queue.where((b) => b['status'] == attention).length;
  int get unsent => waiting + needAttention;

  // ---------------------------------------------------------------------------
  // Start-up and storage
  // ---------------------------------------------------------------------------

  void init() {
    if (_inited) return;
    _inited = true;
    forced = LocalStore.get(_kForced) == '1';
    try {
      final c = LocalStore.get(_kCat);
      if (c != null && c.isNotEmpty) {
        for (final e in (jsonDecode(c) as List).whereType<Map>()) {
          final m = Map<String, dynamic>.from(e);
          final id = '${m['productId'] ?? ''}';
          if (id.isNotEmpty) _raw[id] = m;
        }
        _rebuild();
      }
      final meta = LocalStore.get(_kMeta);
      if (meta != null && meta.isNotEmpty) {
        final m = Map<String, dynamic>.from(jsonDecode(meta) as Map);
        catalogVersion = '${m['version'] ?? ''}';
        lastFull = DateTime.tryParse('${m['lastFull'] ?? ''}');
        lastRefresh = DateTime.tryParse('${m['lastRefresh'] ?? ''}');
        if (m['shop'] is Map) shop = Map<String, dynamic>.from(m['shop'] as Map);
      }
      final q = LocalStore.get(_kQueue);
      if (q != null && q.isNotEmpty) {
        queue = (jsonDecode(q) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      // A damaged copy is simply downloaded again; the queue is never wiped
      // silently, so a parse failure of it leaves what was read so far.
    }
  }

  void _rebuild() {
    _byId
      ..clear()
      ..addEntries(_raw.entries
          .map((e) => MapEntry(e.key, PosProductDto.fromJson(e.value))));
    final list = _byId.values.toList()
      ..sort((a, b) => (a.name ?? '')
          .toLowerCase()
          .compareTo((b.name ?? '').toLowerCase()));
    products = list;
  }

  void _saveCatalogue() {
    LocalStore.set(_kCat, jsonEncode(_raw.values.toList()));
    LocalStore.set(
        _kMeta,
        jsonEncode({
          'version': catalogVersion,
          'lastFull': lastFull?.toUtc().toIso8601String(),
          'lastRefresh': lastRefresh?.toUtc().toIso8601String(),
          'shop': shop,
        }));
  }

  void _saveQueue() => LocalStore.set(_kQueue, jsonEncode(queue));

  PosProductDto? product(String? id) => id == null ? null : _byId[id];

  void setForced(bool on) {
    forced = on;
    LocalStore.set(_kForced, on ? '1' : '0');
    notifyListeners();
    if (!on) unawaited(probe());
  }

  // ---------------------------------------------------------------------------
  // Connection watch
  // ---------------------------------------------------------------------------

  /// Starts the periodic reachability check (also on the first call).
  void startWatch() {
    init();
    _watch ??= Timer.periodic(const Duration(seconds: 15), (_) => probe());
    unawaited(probe());
  }

  void stopWatch() {
    _watch?.cancel();
    _watch = null;
  }

  /// A till call failed at the transport level: switch to offline billing.
  void markUnreachable() {
    if (reachable) {
      reachable = false;
      notifyListeners();
    }
  }

  static bool isNetworkMessage(String? m) {
    final t = (m ?? '').toLowerCase();
    return t.contains('could not reach') ||
        t.contains('taking too long') ||
        t.contains('check your connection');
  }

  /// `GET /pos/sync/status`: reachability, the server clock, the limits and
  /// (when back online) the automatic upload of the queue.
  Future<bool> probe() async {
    if (_probing) return reachable;
    _probing = true;
    final was = reachable;
    try {
      final m = await Api.instance.pos
          .syncStatus()
          .timeout(const Duration(seconds: 8));
      reachable = true;
      _applyStatus(m);
    } on ApiException catch (e) {
      // Any answer from the server (401, 403, 429 ...) proves it is there.
      reachable = !(e.statusCode == 0 || e.statusCode == 502 || e.statusCode == 504);
    } on TimeoutException {
      reachable = false;
    } catch (_) {
      reachable = false;
    } finally {
      _probing = false;
    }
    if (reachable != was || waiting > 0) notifyListeners();
    if (reachable && !forced && waiting > 0 && !syncing) {
      unawaited(sync());
    }
    if (reachable && !forced && _dueForRefresh()) {
      unawaited(refreshCatalogue());
    }
    return reachable;
  }

  Map<String, dynamic>? _lastStatus;

  void _applyStatus(Map<String, dynamic> m) {
    _lastStatus = m;
    final t = DateTime.tryParse('${m['serverTime'] ?? ''}');
    if (t != null) clockSkew = t.toUtc().difference(DateTime.now().toUtc());
    maxOfflineDays = (m['maxOfflineDays'] as num?)?.toInt() ?? maxOfflineDays;
    batchLimit = (m['batchLimit'] as num?)?.toInt() ?? batchLimit;
  }

  bool _dueForRefresh() {
    if (refreshing) return false;
    if (_raw.isEmpty || lastFull == null) return true;
    if (DateTime.now().difference(lastFull!) > const Duration(hours: 24)) {
      return true;
    }
    final v = DateTime.tryParse('${_lastStatus?['catalogVersion'] ?? ''}');
    final have = DateTime.tryParse(catalogVersion);
    return v != null && (have == null || v.isAfter(have));
  }

  // ---------------------------------------------------------------------------
  // Catalogue download (guide 30 offline step 1-2, P3 F2)
  // ---------------------------------------------------------------------------

  /// Full download when there is no copy, [full] is true or the copy is older
  /// than a day; otherwise only what changed since the saved `catalogVersion`
  /// (`updatedSince`, inclusive, so overlaps are harmless).
  Future<void> refreshCatalogue({bool full = false}) async {
    if (refreshing) return;
    refreshing = true;
    refreshError = null;
    notifyListeners();
    try {
      final pos = Api.instance.pos;
      // The version is read BEFORE the download starts (P3 F2).
      final status = await pos.syncStatus();
      _applyStatus(status);
      final version = '${status['catalogVersion'] ?? ''}';
      final needFull = full ||
          _raw.isEmpty ||
          lastFull == null ||
          DateTime.now().difference(lastFull!) > const Duration(hours: 24);
      final since = needFull ? null : catalogVersion;
      final fresh = <String, Map<String, dynamic>>{};
      var page = 0;
      while (page < 400) {
        final r = await pos.getProductsRaw(
            page: page, size: 50, updatedSince: since);
        final items = (r['items'] as List? ?? []).whereType<Map>();
        for (final e in items) {
          final m = Map<String, dynamic>.from(e);
          final id = '${m['productId'] ?? ''}';
          if (id.isNotEmpty) fresh[id] = m;
        }
        page++;
        if (items.isEmpty) break;
        final more = r['hasMore'] is bool
            ? r['hasMore'] as bool
            : page * 50 < ((r['total'] as num?)?.toInt() ?? 0);
        if (!more) break;
      }
      if (needFull) {
        // A product missing from a full download is gone or switched off:
        // drop it (updatedSince never reports that).
        _raw
          ..clear()
          ..addAll(fresh);
        lastFull = DateTime.now();
      } else {
        _raw.addAll(fresh);
      }
      try {
        final s = await pos.getShop();
        shop = {
          'shopName': s.shopName ?? '',
          'address': s.address ?? '',
          'phone': s.phone ?? '',
          'gstin': s.gstin ?? '',
          'stateCode': s.stateCode ?? '',
          'upiId': s.upiId ?? '',
          'invoicePrefix': s.invoicePrefix ?? '',
          'receiptFooter': s.receiptFooter ?? '',
          'weighedPrefix': s.weighedPrefix ?? '2',
          'weighedMode': s.weighedMode ?? 'WEIGHT_GRAMS',
          'roundOffMode': s.roundOffMode ?? 'NONE',
        };
      } catch (_) {
        // Keep the shop copy we have.
      }
      catalogVersion = version;
      lastRefresh = DateTime.now();
      _rebuild();
      _saveCatalogue();
    } on ApiException catch (e) {
      refreshError = e.message;
      if (e.statusCode == 0) reachable = false;
    } catch (_) {
      refreshError = 'Could not download the product list.';
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Scan / search on the device
  // ---------------------------------------------------------------------------

  String get _weighedPrefix {
    final p = '${shop['weighedPrefix'] ?? '2'}'.trim();
    return p.isEmpty ? '2' : p;
  }

  bool get _weighedByPrice => '${shop['weighedMode']}' == 'PRICE_PAISE';

  static String _noZeros(String s) {
    final t = s.replaceFirst(RegExp(r'^0+'), '');
    return t.isEmpty ? '0' : t;
  }

  static bool _ean13Ok(String c) {
    if (!RegExp(r'^\d{13}$').hasMatch(c)) return false;
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final d = c.codeUnitAt(i) - 48;
      sum += i.isEven ? d : d * 3;
    }
    return (10 - sum % 10) % 10 == c.codeUnitAt(12) - 48;
  }

  /// Resolves a scanned/typed [code] against the device copy the way
  /// `GET /pos/barcode/{code}` does: pack barcode, weighed scale label
  /// (prefix + PLU + value + EAN-13 check digit) or a typed item code (PLU).
  LocalScan scanLocal(String code) {
    final c = code.trim();
    if (c.isEmpty) return const LocalScan();
    final lower = c.toLowerCase();
    // 1. A registered pack barcode wins (also one that starts with the prefix).
    for (final p in products) {
      if (p.barcodes.any((b) => b.toLowerCase() == lower)) {
        if (p.soldBy == 'WEIGHT') {
          return LocalScan(
              product: p,
              askWeight: true,
              error: 'Weighed item: enter the weight');
        }
        return LocalScan(product: p, qty: 1);
      }
    }
    // 2. A weighed scale label.
    final prefix = _weighedPrefix;
    if (RegExp(r'^\d{13}$').hasMatch(c) && c.startsWith(prefix)) {
      if (!_ean13Ok(c)) {
        return const LocalScan(error: 'Invalid check digit on weighed label');
      }
      final plu = _noZeros(c.substring(prefix.length, 7));
      final value = int.parse(c.substring(7, 12));
      PosProductDto? hit;
      for (final p in products) {
        if (p.soldBy == 'WEIGHT' && p.plu != null && _noZeros(p.plu!) == plu) {
          hit = p;
          break;
        }
      }
      if (hit == null) return const LocalScan();
      var grams = value;
      if (_weighedByPrice) {
        if (hit.pricePaise <= 0) {
          return const LocalScan(error: 'Weight on the label is out of range');
        }
        grams = (value * 1000 + hit.pricePaise ~/ 2) ~/ hit.pricePaise;
      }
      if (grams < 1 || grams > 100000) {
        return const LocalScan(error: 'Weight on the label is out of range');
      }
      return LocalScan(product: hit, qty: grams);
    }
    // 3. A typed item code (PLU, 1 to 6 digits, leading zeros ignored).
    if (RegExp(r'^\d{1,6}$').hasMatch(c)) {
      final plu = _noZeros(c);
      for (final p in products) {
        if (p.plu != null && p.plu!.isNotEmpty && _noZeros(p.plu!) == plu) {
          return p.soldBy == 'WEIGHT'
              ? LocalScan(product: p, askWeight: true)
              : LocalScan(product: p, qty: 1);
        }
      }
    }
    return const LocalScan();
  }

  // ---------------------------------------------------------------------------
  // Pricing on the device
  // ---------------------------------------------------------------------------

  static int lineAmount(PosProductDto p, int unitPricePaise, int qty) =>
      p.soldBy == 'WEIGHT'
          ? (unitPricePaise * qty + 500) ~/ 1000
          : unitPricePaise * qty;

  /// Prices [items] (`{productId, qty}`) like the server: GST-inclusive
  /// prices, a weighed line per 1000 g (half-up), a lot-price boundary split
  /// (guide 74 / P5 13: the first `afterQty` units at the current price, the
  /// rest at the next lot's), the manual discount spread over the lines by
  /// largest remainder, GST per line (taxable = round(net*100/(100+rate)),
  /// CGST = floor(tax/2), SGST = rest) and the shop's round-off.
  ///
  /// No coupon, no coins (they cannot be checked offline).
  LocalQuote quoteLocal(List<Map<String, dynamic>> items,
      {int manualPaise = 0}) {
    final segs = <_Seg>[];
    final missing = <String>[];
    for (final it in items) {
      final id = '${it['productId']}';
      final qty = (it['qty'] as num?)?.toInt() ?? 0;
      final p = _byId[id];
      if (p == null) {
        missing.add(id);
        continue;
      }
      if (qty <= 0) continue;
      final nxt = p.lot?.nextPriceChange;
      if (p.soldBy != 'WEIGHT' &&
          nxt != null &&
          nxt.afterQty > 0 &&
          qty > nxt.afterQty &&
          nxt.newPricePaise > 0) {
        segs.add(_Seg(p, nxt.afterQty, p.pricePaise));
        segs.add(_Seg(p, qty - nxt.afterQty, nxt.newPricePaise));
      } else {
        segs.add(_Seg(p, qty, p.pricePaise));
      }
    }
    final lines = [for (final s in segs) lineAmount(s.p, s.price, s.qty)];
    final subtotal = lines.fold<int>(0, (a, b) => a + b);
    var manual = manualPaise < 0 ? 0 : manualPaise;
    final warnings = <String>[];
    if (manual > subtotal) {
      warnings.add('The discount is more than the bill');
      manual = subtotal;
    }
    final share = _spread(manual, lines);
    var taxable = 0, cgst = 0, sgst = 0, net = 0;
    final out = <BillLineDto>[];
    final rung = <Map<String, dynamic>>[];
    final tax = <Map<String, int>>[];
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      final n = lines[i] - share[i];
      final g = s.p.gstPercent;
      final tb = (n * 200 + (100 + g)) ~/ (2 * (100 + g));
      final t = n - tb;
      final c = t ~/ 2;
      taxable += tb;
      cgst += c;
      sgst += t - c;
      net += n;
      tax.add({'taxable': tb, 'cgst': c, 'sgst': t - c});
      out.add(BillLineDto(
        productId: s.p.productId,
        name: _label(s.p),
        soldBy: s.p.soldBy,
        qty: s.qty,
        unitPricePaise: s.price,
        linePaise: lines[i],
        discountPaise: share[i],
        netPaise: n,
        gstPercent: g,
      ));
      rung.add({
        'productId': s.p.productId,
        'qty': s.qty,
        'unitPricePaise': s.price,
        'gstPercent': g,
        'discountPaise': 0,
        'name': _label(s.p),
        'linePaise': lines[i],
      });
    }
    var total = net;
    var round = 0;
    if ('${shop['roundOffMode']}' == 'NEAREST_RUPEE' && net > 0) {
      total = ((net + 50) ~/ 100) * 100;
      round = total - net;
    }
    final bill = PosBillViewDto(
      lines: out,
      subtotalPaise: subtotal,
      totalPaise: total,
      taxablePaise: taxable,
      cgstPaise: cgst,
      sgstPaise: sgst,
      warnings: warnings,
      roundOffPaise: round,
      manualDiscountPaise: manual,
    );
    return LocalQuote(bill, rung, tax, missing);
  }

  static List<int> _spread(int amount, List<int> weights) {
    final total = weights.fold<int>(0, (a, b) => a + b);
    if (amount <= 0 || total <= 0) return List<int>.filled(weights.length, 0);
    final base = [for (final w in weights) amount * w ~/ total];
    var left = amount - base.fold<int>(0, (a, b) => a + b);
    final order = List<int>.generate(weights.length, (i) => i)
      ..sort((a, b) =>
          ((amount * weights[b]) % total).compareTo((amount * weights[a]) % total));
    for (var k = 0; left > 0 && k < order.length; k++, left--) {
      base[order[k]] += 1;
    }
    return base;
  }

  static String _label(PosProductDto p) {
    final d = p.displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    final n = (p.name ?? '').trim();
    return n.isEmpty ? 'Item' : n;
  }

  // ---------------------------------------------------------------------------
  // The queue
  // ---------------------------------------------------------------------------

  /// Why an offline bill cannot be rung with [mode]s / coupon, or null.
  static String? refuseReason({
    required List<Map<String, dynamic>> payments,
    String? coupon,
    bool coins = false,
  }) {
    if ((coupon ?? '').trim().isNotEmpty || coins) {
      return 'A coupon or coin redemption cannot be checked offline: ring this bill without it';
    }
    for (final p in payments) {
      if ('${p['mode']}'.toUpperCase() == 'CREDIT') {
        return 'Credit (udhar) cannot be given on an offline bill: it needs the customer’s account';
      }
      if ((p['terminalPaymentId'] ?? '').toString().isNotEmpty) {
        return 'A card machine payment needs the internet. Type the slip reference instead';
      }
    }
    return null;
  }

  int _seq() {
    final m = DateTime.now();
    final day = '${m.year}${m.month.toString().padLeft(2, '0')}${m.day.toString().padLeft(2, '0')}';
    var n = 1;
    for (final b in queue) {
      final no = '${b['localNo'] ?? ''}';
      if (no.startsWith('OFF-$day-')) {
        final k = int.tryParse(no.substring(no.lastIndexOf('-') + 1)) ?? 0;
        if (k >= n) n = k + 1;
      }
    }
    return n;
  }

  /// Stores one bill. [payments] are the final lines (CASH/UPI/CARD) that add
  /// up to [quote]'s total exactly. The `idempotencyKey` is made here, once.
  Map<String, dynamic> enqueue({
    required LocalQuote quote,
    required List<Map<String, dynamic>> payments,
    String? mobile,
    int? tenderedPaise,
    String? discountReason,
  }) {
    final now = DateTime.now().toUtc().add(clockSkew ?? Duration.zero);
    final day =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final no = 'OFF-$day-${_seq().toString().padLeft(4, '0')}';
    final b = quote.bill;
    final entry = <String, dynamic>{
      'key': newIdempotencyKey(),
      'localNo': no,
      'soldAt': now.toIso8601String(),
      'status': queued,
      'totalPaise': b.totalPaise,
      'subtotalPaise': b.subtotalPaise,
      'roundOffPaise': b.roundOffPaise,
      'manualDiscountPaise': b.manualDiscountPaise,
      'manualReason': discountReason ?? '',
      'taxablePaise': b.taxablePaise,
      'cgstPaise': b.cgstPaise,
      'sgstPaise': b.sgstPaise,
      'rung': quote.rung,
      'tax': quote.tax,
      'lines': [
        for (final l in b.lines)
          {
            'name': l.name,
            'soldBy': l.soldBy,
            'qty': l.qty,
            'unitPricePaise': l.unitPricePaise,
            'linePaise': l.linePaise,
            'discountPaise': l.discountPaise,
            'netPaise': l.netPaise,
            'gstPercent': l.gstPercent,
          }
      ],
      'payments': payments,
      if (tenderedPaise != null) 'tenderedPaise': tenderedPaise,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      'shop': shop,
      'exceptions': <Map<String, dynamic>>[],
    };
    queue.add(entry);
    _saveQueue();
    notifyListeners();
    return entry;
  }

  /// The bill as the done panel / returns expect it (no server id yet).
  SaleRecordDto saleOf(Map<String, dynamic> e) {
    final lines = (e['lines'] as List? ?? []).whereType<Map>().toList();
    final tax = (e['tax'] as List? ?? []).whereType<Map>().toList();
    final pays = (e['payments'] as List? ?? []).whereType<Map>().toList();
    final cashPaid = pays
        .where((p) => '${p['mode']}' == 'CASH')
        .fold<int>(0, (a, p) => a + ((p['amountPaise'] as num?)?.toInt() ?? 0));
    final tendered = (e['tenderedPaise'] as num?)?.toInt() ?? 0;
    final modes = pays.map((p) => '${p['mode']}').toSet();
    return SaleRecordDto(
      id: e['saleId']?.toString(),
      invoiceNo: e['invoiceNo']?.toString() ?? e['localNo']?.toString(),
      customerMobile: e['mobile']?.toString(),
      subtotalPaise: (e['subtotalPaise'] as num?)?.toInt() ?? 0,
      totalPaise: (e['totalPaise'] as num?)?.toInt() ?? 0,
      taxablePaise: (e['taxablePaise'] as num?)?.toInt() ?? 0,
      cgstPaise: (e['cgstPaise'] as num?)?.toInt() ?? 0,
      sgstPaise: (e['sgstPaise'] as num?)?.toInt() ?? 0,
      tenderedPaise: tendered,
      changePaise: tendered > cashPaid && cashPaid > 0 ? tendered - cashPaid : 0,
      createdAt: e['soldAt']?.toString(),
      manualDiscountPaise: (e['manualDiscountPaise'] as num?)?.toInt() ?? 0,
      manualDiscountReason: e['manualReason']?.toString(),
      roundOffPaise: (e['roundOffPaise'] as num?)?.toInt() ?? 0,
      paymentType: modes.isEmpty
          ? 'NONE'
          : modes.length == 1
              ? modes.first
              : 'SPLIT',
      items: [
        for (var i = 0; i < lines.length; i++)
          SaleItemRecordDto(
            name: lines[i]['name']?.toString(),
            soldBy: lines[i]['soldBy']?.toString(),
            qty: (lines[i]['qty'] as num?)?.toInt() ?? 0,
            unitPricePaise: (lines[i]['unitPricePaise'] as num?)?.toInt() ?? 0,
            linePaise: (lines[i]['linePaise'] as num?)?.toInt() ?? 0,
            discountPaise: (lines[i]['discountPaise'] as num?)?.toInt() ?? 0,
            netPaise: (lines[i]['netPaise'] as num?)?.toInt() ?? 0,
            gstPercent: (lines[i]['gstPercent'] as num?)?.toInt() ?? 0,
            taxablePaise:
                i < tax.length ? (tax[i]['taxable'] as num?)?.toInt() ?? 0 : 0,
            cgstPaise: i < tax.length ? (tax[i]['cgst'] as num?)?.toInt() ?? 0 : 0,
            sgstPaise: i < tax.length ? (tax[i]['sgst'] as num?)?.toInt() ?? 0 : 0,
          ),
      ],
      payments: [
        for (final p in pays)
          PaymentRecordDto(
            mode: '${p['mode']}',
            amountPaise: (p['amountPaise'] as num?)?.toInt() ?? 0,
            reference: p['reference']?.toString(),
            moneyAccountId: p['moneyAccountId']?.toString(),
          ),
      ],
    );
  }

  Map<String, dynamic>? byKey(String key) {
    for (final b in queue) {
      if (b['key'] == key) return b;
    }
    return null;
  }

  void retry(String key) {
    final b = byKey(key);
    if (b == null) return;
    b['status'] = queued;
    b.remove('message');
    b.remove('errorCode');
    _saveQueue();
    notifyListeners();
  }

  void remove(String key) {
    queue.removeWhere((b) => b['key'] == key);
    _saveQueue();
    notifyListeners();
  }

  /// Whole days a waiting bill has been on the device (7 is the server limit).
  int ageDays(Map<String, dynamic> b) {
    final t = DateTime.tryParse('${b['soldAt']}');
    return t == null ? 0 : DateTime.now().toUtc().difference(t).inDays;
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _wire(Map<String, dynamic> b) => {
        'idempotencyKey': b['key'],
        'soldAt': b['soldAt'],
        'rung': {'lines': b['rung']},
        'payments': [
          for (final p in (b['payments'] as List).whereType<Map>())
            {
              'mode': p['mode'],
              'amountPaise': p['amountPaise'],
              if ('${p['reference'] ?? ''}'.isNotEmpty) 'reference': p['reference'],
              if ('${p['moneyAccountId'] ?? ''}'.isNotEmpty)
                'moneyAccountId': p['moneyAccountId'],
              if ('${p['terminalId'] ?? ''}'.isNotEmpty)
                'terminalId': p['terminalId'],
            }
        ],
        if (b['tenderedPaise'] != null) 'cashTenderedPaise': b['tenderedPaise'],
        if (((b['manualDiscountPaise'] as num?)?.toInt() ?? 0) > 0)
          'manualDiscount': {
            'amountPaise': b['manualDiscountPaise'],
            'reason': '${b['manualReason'] ?? ''}'.isEmpty
                ? 'Manual discount'
                : b['manualReason'],
          },
        if ('${b['mobile'] ?? ''}'.isNotEmpty)
          'cart': {'customerMobile': b['mobile']},
      };

  /// Uploads every waiting bill, oldest first, [batchLimit] per call. Results
  /// are matched by `idempotencyKey`. Returns how many bills were recorded.
  Future<int> sync() async {
    if (syncing) return 0;
    final todo = queue.where((b) => b['status'] == queued).toList()
      ..sort((a, b) => '${a['soldAt']}'.compareTo('${b['soldAt']}'));
    if (todo.isEmpty) return 0;
    syncing = true;
    syncMessage = null;
    notifyListeners();
    var done = 0;
    try {
      for (var i = 0; i < todo.length; i += batchLimit) {
        final batch = todo.sublist(
            i, i + batchLimit > todo.length ? todo.length : i + batchLimit);
        final List<Map<String, dynamic>> results;
        try {
          results = await Api.instance.pos.syncSales([for (final b in batch) _wire(b)]);
        } on ApiException catch (e) {
          if (e.statusCode == 0) {
            reachable = false;
            syncMessage = 'The server cannot be reached. The bills stay on this device.';
          } else {
            // Whole-request error (401/403/429/400): nothing was recorded.
            syncMessage = e.message;
          }
          break;
        }
        for (final r in results) {
          final b = byKey('${r['idempotencyKey']}');
          if (b == null) continue;
          final st = '${r['status']}';
          b['exceptions'] = (r['exceptions'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (st == 'CREATED' || st == 'DUPLICATE') {
            b['status'] = synced;
            b['invoiceNo'] = r['invoiceNo'];
            b['saleId'] = r['saleId'];
            b['syncedAt'] = DateTime.now().toUtc().toIso8601String();
            b.remove('message');
            b.remove('errorCode');
            done++;
          } else if ('${r['errorCode']}' == 'INTERNAL_ERROR') {
            b['message'] = '${r['message'] ?? 'Server error, will retry'}';
            syncMessage = 'The server had a temporary problem. It will retry.';
          } else {
            b['status'] = attention;
            b['errorCode'] = r['errorCode'];
            b['message'] = '${r['message'] ?? 'The bill was not accepted'}';
          }
        }
        _saveQueue();
        notifyListeners();
      }
    } finally {
      _trimSynced();
      syncing = false;
      _saveQueue();
      notifyListeners();
    }
    return done;
  }

  /// Keeps only the 30 newest recorded bills (they only show the new invoice
  /// number and the "manager will review" note).
  void _trimSynced() {
    final s = queue.where((b) => b['status'] == synced).toList();
    if (s.length <= 30) return;
    s.sort((a, b) => '${a['syncedAt']}'.compareTo('${b['syncedAt']}'));
    final drop = s.take(s.length - 30).map((b) => b['key']).toSet();
    queue.removeWhere((b) => drop.contains(b['key']));
  }

  // ---------------------------------------------------------------------------
  // Parked baskets kept on the device (holds need the server)
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> localHolds() {
    try {
      final s = LocalStore.get(_kHolds);
      if (s == null || s.isEmpty) return [];
      return (jsonDecode(s) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void addLocalHold(String label, List<Map<String, dynamic>> items, String? mobile) {
    final list = localHolds()
      ..insert(0, {
        'id': newIdempotencyKey(),
        'label': label,
        'items': items,
        if (mobile != null) 'mobile': mobile,
        'at': DateTime.now().toUtc().toIso8601String(),
      });
    LocalStore.set(_kHolds, jsonEncode(list.take(50).toList()));
    notifyListeners();
  }

  void removeLocalHold(String id) {
    final list = localHolds()..removeWhere((h) => h['id'] == id);
    LocalStore.set(_kHolds, jsonEncode(list));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Temporary receipt text (58 mm = 32 columns, 80 mm = 48)
  // ---------------------------------------------------------------------------

  static String _rupees(int paise) {
    final a = paise.abs();
    return '${paise < 0 ? '-' : ''}${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
  }

  /// Plain monospace text for [e] at [width] columns. It is only a temporary
  /// receipt: the number is local and the footer says so.
  String receiptText(Map<String, dynamic> e, int width) {
    final sh = (e['shop'] is Map) ? Map<String, dynamic>.from(e['shop'] as Map) : shop;
    final b = StringBuffer();
    String center(String s) {
      final t = s.length > width ? s.substring(0, width) : s;
      return '${' ' * ((width - t.length) ~/ 2)}$t\n';
    }

    String two(String l, String r) {
      final room = width - r.length - 1;
      final left = l.length > room ? l.substring(0, room < 0 ? 0 : room) : l;
      return '$left${' ' * (width - left.length - r.length)}$r\n';
    }

    final rule = '${'-' * width}\n';
    if ('${sh['shopName'] ?? ''}'.isNotEmpty) b.write(center('${sh['shopName']}'));
    if ('${sh['address'] ?? ''}'.isNotEmpty) b.write(center('${sh['address']}'));
    if ('${sh['phone'] ?? ''}'.isNotEmpty) b.write(center('Ph: ${sh['phone']}'));
    if ('${sh['gstin'] ?? ''}'.isNotEmpty) b.write(center('GSTIN: ${sh['gstin']}'));
    b.write(rule);
    b.write('TAX INVOICE (TEMPORARY)\n');
    b.write('No: ${e['invoiceNo'] ?? e['localNo']}\n');
    final t = parseIst('${e['soldAt']}');
    if (t != null) {
      String p(int n) => n.toString().padLeft(2, '0');
      b.write('${p(t.day)}-${p(t.month)}-${t.year} ${p(t.hour)}:${p(t.minute)}\n');
    }
    if ('${e['mobile'] ?? ''}'.isNotEmpty) b.write('Cust: ${e['mobile']}\n');
    b.write(rule);
    for (final l in (e['lines'] as List? ?? []).whereType<Map>()) {
      b.write('${l['name']}\n');
      final qty = (l['qty'] as num?)?.toInt() ?? 0;
      final unit = (l['unitPricePaise'] as num?)?.toInt() ?? 0;
      final q = '${l['soldBy']}' == 'WEIGHT'
          ? '${(qty / 1000).toStringAsFixed(3)} kg'
          : '$qty x ${_rupees(unit)}';
      b.write(two('  $q (${l['gstPercent']}%)', _rupees((l['linePaise'] as num?)?.toInt() ?? 0)));
    }
    b.write(rule);
    b.write(two('Subtotal', _rupees((e['subtotalPaise'] as num?)?.toInt() ?? 0)));
    final md = (e['manualDiscountPaise'] as num?)?.toInt() ?? 0;
    if (md > 0) b.write(two('Discount', '-${_rupees(md)}'));
    final ro = (e['roundOffPaise'] as num?)?.toInt() ?? 0;
    if (ro != 0) b.write(two('Round off', _rupees(ro)));
    b.write(two('TOTAL', _rupees((e['totalPaise'] as num?)?.toInt() ?? 0)));
    b.write(rule);
    b.write(two('Taxable', _rupees((e['taxablePaise'] as num?)?.toInt() ?? 0)));
    b.write(two('CGST', _rupees((e['cgstPaise'] as num?)?.toInt() ?? 0)));
    b.write(two('SGST', _rupees((e['sgstPaise'] as num?)?.toInt() ?? 0)));
    b.write(rule);
    for (final p in (e['payments'] as List? ?? []).whereType<Map>()) {
      b.write(two('Paid ${p['mode']}', _rupees((p['amountPaise'] as num?)?.toInt() ?? 0)));
    }
    final sale = saleOf(e);
    if (sale.changePaise > 0) b.write(two('Change', _rupees(sale.changePaise)));
    b.write(rule);
    if ('${sh['receiptFooter'] ?? ''}'.isNotEmpty) b.write(center('${sh['receiptFooter']}'));
    b.write(center('Offline bill: final invoice'));
    b.write(center('number comes after sync'));
    return b.toString();
  }
}

class _Seg {
  _Seg(this.p, this.qty, this.price);
  final PosProductDto p;
  final int qty;
  final int price;
}

/// What [PosOffline.scanLocal] found.
class LocalScan {
  const LocalScan({this.product, this.qty = 1, this.error, this.askWeight = false});
  final PosProductDto? product;
  final int qty;
  final String? error;

  /// The product is weighed and the code carries no weight: ask for grams.
  final bool askWeight;
}

/// A bill priced on the device.
class LocalQuote {
  const LocalQuote(this.bill, this.rung, this.tax, this.missing);
  final PosBillViewDto bill;

  /// `rung.lines[]` of the upload (till prices, no discount on the line).
  final List<Map<String, dynamic>> rung;

  /// Per bill line: taxable / cgst / sgst.
  final List<Map<String, int>> tax;

  /// Product ids that are not in the device copy.
  final List<String> missing;
}
