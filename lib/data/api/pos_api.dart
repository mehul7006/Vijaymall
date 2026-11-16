import 'api_client.dart';
import 'api_exception.dart';
import 'dto.dart';
import 'pos_dto.dart';

/// The four ways a counter bill can be paid (`PaymentRules.MODES` + `CREDIT`
/// on the backend). Anything else the app might hold — a payment-method code
/// such as `ONLINE` or `DEBIT_CARD` — is folded into one of these, matching
/// the backend's own `PaymentRules.normalizeMode`.
const kPosPayModes = ['CASH', 'UPI', 'CARD', 'CREDIT'];

/// Reads a payment mode the way the backend does: case/spacing insensitive,
/// with the common aliases mapped to `CASH` / `UPI` / `CARD` / `CREDIT`.
/// Anything unrecognised is upper-cased so a backend 400 names it exactly.
String normalizePayMode(String raw) {
  final m = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '_');
  switch (m) {
    case 'ONLINE':
    case 'NETBANKING':
    case 'NET_BANKING':
    case 'WALLET':
    case 'QR':
    case 'GPAY':
    case 'PHONEPE':
    case 'PAYTM':
      return 'UPI';
    case 'DEBIT_CARD':
    case 'CREDIT_CARD':
    case 'DEBIT':
    case 'SWIPE':
    case 'POS_MACHINE':
      return 'CARD';
    // Cash-on-delivery / pay-at-store codes of the ONLINE order flow
    // (`/payment-methods` rows are `COD` and `ONLINE`) mean cash at the till.
    case 'COD':
    case 'CASH_ON_DELIVERY':
    case 'STORE':
    case 'PAY_AT_STORE':
    case 'PICKUP':
      return 'CASH';
    case 'PAY_LATER':
    case 'UDHAR':
    case 'UDHARI':
    case 'LATER':
      return 'CREDIT';
    default:
      return m.isEmpty ? 'CASH' : m;
  }
}

/// Point-of-sale endpoints (`/api/v1/pos/*`).
///
/// The POS is the counter till: browse/search products (`/pos/products`),
/// scan barcodes (`/pos/barcode/{code}`), price a ticket server-side
/// (`/pos/quote`), ring up sales with an `Idempotency-Key` (`/pos/sales`),
/// park and resume carts (`/pos/holds`), pull the day's totals
/// (`/pos/reports/day`) and print receipts (`/pos/sales/{id}/receipt`).
class PosApi {
  PosApi(this._client);

  final ApiClient _client;

  // --- catalog ------------------------------------------------------------

  /// `GET /pos/products`. `q` also matches a barcode / PLU exactly (exact
  /// matches first); [updatedSince] (ISO instant) returns only changed rows.
  Future<PagePosProductDto> getProducts(
      {String? q, int page = 0, int size = 50, String? updatedSince}) async {
    final raw = await _client.get('/pos/products', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (updatedSince != null && updatedSince.isNotEmpty)
        'updatedSince': updatedSince,
      'page': '$page',
      'size': '$size',
    });
    return PagePosProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// Same call as [getProducts] but the page is returned as sent (raw JSON),
  /// so the offline copy can be stored and re-read without losing a field.
  Future<Map<String, dynamic>> getProductsRaw(
      {int page = 0, int size = 50, String? updatedSince}) async {
    final raw = await _client.get('/pos/products', query: {
      if (updatedSince != null && updatedSince.isNotEmpty)
        'updatedSince': updatedSince,
      'page': '$page',
      'size': '$size',
    });
    return Map<String, dynamic>.from(raw as Map);
  }

  /// `POST /pos/sync/sales` (guide 30, offline sync): uploads bills rung up
  /// offline, oldest first, 1..50 per call. Always answers 200 with one result
  /// per bill: `{idempotencyKey, status CREATED|DUPLICATE|REJECTED, saleId,
  /// invoiceNo, errorCode, message, exceptions[{kind, detail}]}`. Each bill
  /// carries its own `idempotencyKey`, so no header is sent.
  Future<List<Map<String, dynamic>>> syncSales(
      List<Map<String, dynamic>> sales) async {
    final raw = await _client.post('/pos/sync/sales',
        idempotency: false, body: {'sales': sales});
    final m = Map<String, dynamic>.from(raw as Map);
    return (m['results'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `GET /pos/barcode/{code}` → the matched product + suggested qty.
  Future<PosProductDto> getBarcode(String code) async {
    final raw = await _client.get('/pos/barcode/${Uri.encodeComponent(code)}');
    final map = Map<String, dynamic>.from(raw as Map);
    final product = map['product'];
    if (product is Map) {
      return PosProductDto.fromJson(Map<String, dynamic>.from(product));
    }
    return PosProductDto.fromJson(map);
  }

  /// `GET /pos/barcode/{code}` keeping the quantity the code implies: 1 for a
  /// pack barcode, **grams** for a weighed scale label (plus the line price).
  Future<PosScanDto> scanBarcode(String code) async {
    final raw = await _client.get('/pos/barcode/${Uri.encodeComponent(code)}');
    return PosScanDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // --- shifts (cash drawer) ------------------------------------------------

  /// `POST /pos/shifts/open` - 409 `SHIFT_ALREADY_OPEN` if one is open.
  Future<ShiftViewDto> openShift(int openingFloatPaise) async {
    final raw = await _client
        .post('/pos/shifts/open', body: {'openingFloatPaise': openingFloatPaise});
    return ShiftViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/shifts/current` - null when 404 (no open shift: a normal state).
  Future<ShiftViewDto?> currentShift() async {
    try {
      final raw = await _client.get('/pos/shifts/current');
      return ShiftViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `POST /pos/shifts/close` - 422 `VARIANCE_NEEDS_NOTE` when counted differs
  /// from expected and [note] is empty.
  Future<ShiftViewDto> closeShift(int countedCashPaise, {String? note}) async {
    final raw = await _client.post('/pos/shifts/close', body: {
      'countedCashPaise': countedCashPaise,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return ShiftViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // --- ticket -------------------------------------------------------------

  /// `POST /pos/quote` → authoritative totals (GST split, discounts, warnings).
  Future<PosBillViewDto> quote({
    required List<Map<String, dynamic>> items,
    String? customerMobile,
    String? couponCode,
    String? coinMode,
    int? percent,
    Map<String, dynamic>? manualDiscount,
  }) async {
    final raw = await _client.post('/pos/quote', body: {
      'items': items,
      if (manualDiscount != null) 'manualDiscount': manualDiscount,
      if (customerMobile != null && customerMobile.isNotEmpty)
        'customerMobile': customerMobile,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      if (coinMode != null) 'coinMode': coinMode,
      if (percent != null && coinMode == 'PERCENT') 'percent': percent,
    });
    return PosBillViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // --- sales --------------------------------------------------------------

  /// `POST /pos/sales` → the completed sale. Requires `Idempotency-Key`.
  Future<SaleRecordDto> createSale({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? customerMobile,
    String? couponCode,
    String? coinMode,
    int? percent,
    int? cashTenderedPaise,
    Map<String, dynamic>? manualDiscount,
    String? idempotencyKey,
  }) async {
    // One key per user action: the caller keeps [idempotencyKey] across
    // retries (timeout / 5xx) so the server returns the first bill instead of
    // ringing a second one. Without it a fresh key is generated per call.
    final raw = await _client.post(
      '/pos/sales',
      idempotency: idempotencyKey == null,
      headers:
          idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
      body: {
        'cart': {
          'items': items,
          if (customerMobile != null && customerMobile.isNotEmpty)
            'customerMobile': customerMobile,
          if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
          if (coinMode != null) 'coinMode': coinMode,
          if (percent != null && coinMode == 'PERCENT') 'percent': percent,
        },
        'payments': payments,
        if (cashTenderedPaise != null) 'cashTenderedPaise': cashTenderedPaise,
        if (manualDiscount != null) 'manualDiscount': manualDiscount,
      },
    );
    return SaleRecordDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<SaleRecordDto>> listSales(
      {String? invoiceNo, String? mobile, String? date}) async {
    final raw = await _client.get('/pos/sales', query: {
      if (invoiceNo != null && invoiceNo.isNotEmpty) 'invoiceNo': invoiceNo,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      if (date != null && date.isNotEmpty) 'date': date,
    });
    return (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => SaleRecordDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SaleRecordDto> getSale(String id) async {
    final raw = await _client.get('/pos/sales/$id');
    return SaleRecordDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/sales/{id}/receipt` → printable monospaced text.
  Future<ReceiptDto> getReceipt(String id, {int width = 32}) async {
    // Backend accepts only 32 (58 mm paper) or 48 (80 mm paper).
    final raw = await _client.get('/pos/sales/$id/receipt',
        query: {'width': '${width == 48 ? 48 : 32}'});
    return ReceiptDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/sales/{id}/returns/{returnId}/receipt` - credit-note text.
  Future<ReceiptDto> getReturnReceipt(String saleId, String returnId,
      {int width = 32}) async {
    final raw = await _client.get('/pos/sales/$saleId/returns/$returnId/receipt',
        query: {'width': '${width == 48 ? 48 : 32}'});
    return ReceiptDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/credit/payments/{id}/receipt` - repayment receipt text.
  Future<ReceiptDto> getCreditPaymentReceipt(String paymentId,
      {int width = 32}) async {
    final raw = await _client.get('/pos/credit/payments/$paymentId/receipt',
        query: {'width': '${width == 48 ? 48 : 32}'});
    return ReceiptDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // --- offline sync / defective stock (read-mostly) --------------------------

  /// `GET /pos/sync/status` -> `{serverTime, catalogVersion, maxOfflineDays, batchLimit}`.
  Future<Map<String, dynamic>> syncStatus() async {
    final raw = await _client.get('/pos/sync/status');
    return Map<String, dynamic>.from(raw as Map);
  }

  /// `GET /pos/stock/defective?status=` -> the raw page `{items, page, size, total, ...}`.
  Future<Map<String, dynamic>> defectiveStock(
      {String status = 'PENDING_REVIEW', int page = 0, int size = 20}) async {
    final raw = await _client.get('/pos/stock/defective',
        query: {'status': status, 'page': '$page', 'size': '$size'});
    return Map<String, dynamic>.from(raw as Map);
  }

  /// `POST /pos/stock/defective/{id}/review` with `CONFIRM_DEFECTIVE` or `RESTOCK`.
  Future<Map<String, dynamic>> reviewDefective(String id, String decision,
      {String? note}) async {
    final raw = await _client.post('/pos/stock/defective/$id/review', body: {
      'decision': decision,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return Map<String, dynamic>.from(raw as Map);
  }

  // --- holds (parked carts) ----------------------------------------------

  Future<List<HoldViewDto>> getHolds() async {
    final raw = await _client.get('/pos/holds') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => HoldViewDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<HoldViewDto> createHold({
    String? label,
    required Map<String, dynamic> cart,
  }) async {
    final raw = await _client.post('/pos/holds', body: {
      if (label != null && label.isNotEmpty) 'label': label,
      'cart': cart,
    });
    return HoldViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<HoldViewDto> getHold(String id) async {
    final raw = await _client.get('/pos/holds/$id');
    return HoldViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> deleteHold(String id) => _client.delete('/pos/holds/$id');

  // --- till reports & helpers --------------------------------------------

  Future<DayReportDto> getDayReport({String? date}) async {
    final raw = await _client.get('/pos/reports/day', query: {
      if (date != null && date.isNotEmpty) 'date': date,
    });
    return DayReportDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/shop` — till-facing shop details (name/address/GST/UTR).
  Future<ShopSettingDto> getShop() async {
    final raw = await _client.get('/pos/shop');
    return ShopSettingDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/upi-link` → a UPI deep link for the amount to charge.
  Future<String> getUpiLink({required int amountPaise, String? note}) async {
    final raw = await _client.get('/pos/upi-link', query: {
      'amountPaise': '$amountPaise',
      if (note != null && note.isNotEmpty) 'note': note,
    });
    if (raw is Map) {
      final link = raw['link'];
      return link?.toString() ?? '';
    }
    return raw?.toString() ?? '';
  }

  // --- returns (credit notes) ---------------------------------------------

  /// `GET /pos/sales/{id}/returns` - earlier returns against a sale.
  Future<List<ReturnRecordDto>> getReturns(String saleId) async {
    final raw = await _client.get('/pos/sales/$saleId/returns');
    return (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => ReturnRecordDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /pos/sales/{id}/returns` (needs `Idempotency-Key`). [items] are
  /// `{saleItemId, qty}`; [refunds] are `{mode, amountPaise, reference?}`.
  Future<ReturnRecordDto> refund(
    String saleId, {
    required List<Map<String, dynamic>> items,
    String? reason,
    List<Map<String, dynamic>> refunds = const [],
    String? refundMode,
    String? idempotencyKey,
  }) async {
    final raw = await _client.post(
      '/pos/sales/$saleId/returns',
      idempotency: idempotencyKey == null,
      headers:
          idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
      body: {
        'items': items,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        // `refundMode` and `refunds[]` together are a 400: send one only.
        if (refunds.isNotEmpty)
          'refunds': refunds
        else if (refundMode != null && refundMode.isNotEmpty)
          'refundMode': refundMode,
      },
    );
    return ReturnRecordDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // --- payment channels + card/UPI machine (P3 F6) --------------------------

  /// `GET /pos/payment-channels`.
  Future<List<PayChannelDto>> paymentChannels() async {
    final raw = await _client.get('/pos/payment-channels');
    return (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => PayChannelDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /pos/terminal/payments` (the generic card/UPI machine start; the
  /// Paytm-only `/pos/terminal-payments` is its twin). The same [reference]
  /// and amount return the same session, so a retry is safe.
  Future<TerminalSessionDto> startTerminalPayment({
    required int amountPaise,
    required String reference,
    String? moneyAccountId,
  }) async {
    final raw = await _client.post('/pos/terminal/payments', body: {
      'amountPaise': amountPaise,
      'reference': reference,
      if (moneyAccountId != null && moneyAccountId.isNotEmpty)
        'moneyAccountId': moneyAccountId,
    });
    return TerminalSessionDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/terminal/payments/{id}`.
  Future<TerminalSessionDto> getTerminalPayment(String id) async {
    final raw = await _client.get('/pos/terminal/payments/$id');
    return TerminalSessionDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /pos/terminal/payments/{id}/confirm` (manual machines only).
  Future<TerminalSessionDto> confirmTerminalPayment(String id,
      {required String approvalCode, String? rrn}) async {
    final raw = await _client.post('/pos/terminal/payments/$id/confirm', body: {
      'approvalCode': approvalCode,
      if (rrn != null && rrn.isNotEmpty) 'rrn': rrn,
    });
    return TerminalSessionDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /pos/terminal/payments/{id}/cancel`.
  Future<TerminalSessionDto> cancelTerminalPayment(String id) async {
    final raw = await _client.post('/pos/terminal/payments/$id/cancel');
    return TerminalSessionDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /pos/terminal/payments/{id}/void` (Paytm, same day).
  Future<TerminalSessionDto> voidTerminalPayment(String id) async {
    final raw = await _client.post('/pos/terminal/payments/$id/void');
    return TerminalSessionDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // --- credit picker (read only) -------------------------------------------

  /// `GET /pos/credit/customers?q=&all=&page=&size=`: masked mobiles. With
  /// `all=true` the server wants `q` of at least 2 characters.
  Future<({List<CreditPickDto> items, bool hasMore})> creditCustomers(
      {String? q, bool all = false, int page = 0, int size = 20}) async {
    final raw = await _client.get('/pos/credit/customers', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (all) 'all': 'true',
      'page': '$page',
      'size': '$size',
    });
    final m = Map<String, dynamic>.from(raw as Map);
    final items = (m['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => CreditPickDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (items: items, hasMore: m['hasMore'] as bool? ?? false);
  }

  // --- return preview ------------------------------------------------------

  /// `POST /pos/sales/{id}/returns/preview` (only `items` is used).
  Future<ReturnPreviewDto> previewReturn(
      String saleId, List<Map<String, dynamic>> items) async {
    final raw = await _client
        .post('/pos/sales/$saleId/returns/preview', body: {'items': items});
    return ReturnPreviewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // --- customer credit at the till ----------------------------------------

  /// `GET /pos/credit/account?mobile=`.
  Future<CreditAccountDto> getCreditAccount(String mobile) async {
    final raw = await _client.get('/pos/credit/account', query: {'mobile': mobile});
    return CreditAccountDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /pos/credit/ledger?mobile=`.
  Future<PageCreditLedgerDto> getCreditLedger(String mobile,
      {int page = 0, int size = 20}) async {
    final raw = await _client.get('/pos/credit/ledger',
        query: {'mobile': mobile, 'page': '$page', 'size': '$size'});
    return PageCreditLedgerDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /pos/credit/payments` (needs `Idempotency-Key`) - collect dues.
  Future<CreditReceiptDto> collectCredit({
    required String mobile,
    required List<Map<String, dynamic>> payments,
    String? note,
    String? idempotencyKey,
  }) async {
    final raw = await _client.post(
      '/pos/credit/payments',
      idempotency: idempotencyKey == null,
      headers:
          idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
      body: {
        'customerMobile': mobile,
        'payments': payments,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return CreditReceiptDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }
}
