/// DTOs of the bank module (`71-bank-and-settlements.md`, `73-paytm-terminal.md`).
/// Money is whole paise (`int`); instants are ISO-8601 UTC text kept as
/// [DateTime] (UTC) and shown through `lib/data/ist.dart`.
library;

String? _n(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String _s(dynamic v) => v?.toString() ?? '';
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _ni(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
bool _b(dynamic v) => v == true;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

List<Map<String, dynamic>> _maps(dynamic v) => [
      for (final e in (v as List? ?? const [])) Map<String, dynamic>.from(e as Map)
    ];

/// `{ items, page, size, total, totalExact, hasMore }`.
class BankPage<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;
  final bool totalExact;
  final bool hasMore;

  const BankPage(this.items, this.page, this.size, this.total, this.totalExact,
      this.hasMore);

  factory BankPage.fromJson(
      dynamic raw, T Function(Map<String, dynamic>) f) {
    final j = Map<String, dynamic>.from(raw as Map);
    return BankPage<T>(
      _maps(j['items']).map(f).toList(),
      _i(j['page']),
      _i(j['size']),
      _i(j['total']),
      j['totalExact'] != false,
      _b(j['hasMore']),
    );
  }

  /// `1,234` or `10,000+` when the server only knows a lower bound.
  String get totalText {
    final s = total.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return totalExact ? b.toString() : '$b+';
  }
}

const accountKinds = ['BANK', 'GATEWAY', 'UPI', 'CARD_TERMINAL', 'CASH'];

class MoneyAccount {
  final String id, name, kind, provider, identifier, note;
  final String? settlesToAccountId;
  final bool active;
  final DateTime? createdAt, updatedAt;

  MoneyAccount.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        kind = _s(j['kind']).toUpperCase(),
        provider = _s(j['provider']),
        identifier = _s(j['identifier']),
        note = _s(j['note']),
        settlesToAccountId = _n(j['settlesToAccountId']),
        active = j['active'] != false,
        createdAt = _dt(j['createdAt']),
        updatedAt = _dt(j['updatedAt']);
}

class BookRow {
  final DateTime? at;
  final String type, direction, sourceType, sourceId, description;
  final int amountPaise, balancePaise;

  BookRow.fromJson(Map<String, dynamic> j)
      : at = _dt(j['at']),
        type = _s(j['type']),
        direction = _s(j['direction']).toUpperCase(),
        sourceType = _s(j['sourceType']),
        sourceId = _s(j['sourceId']),
        description = _s(j['description']),
        amountPaise = _i(j['amountPaise']),
        balancePaise = _i(j['balancePaise']);
}

class AccountBook {
  final String moneyAccountId, accountName;
  final int openingBalancePaise;
  final BankPage<BookRow> lines;

  AccountBook.fromJson(Map<String, dynamic> j)
      : moneyAccountId = _s(j['moneyAccountId']),
        accountName = _s(j['accountName']),
        openingBalancePaise = _i(j['openingBalancePaise']),
        lines = BankPage.fromJson(j['lines'], BookRow.fromJson);
}

class PayChannel {
  final String mode, moneyAccountId, provider, name, kind;
  final String? terminalId;
  final bool isDefault;

  PayChannel.fromJson(Map<String, dynamic> j)
      : mode = _s(j['mode']).toUpperCase(),
        moneyAccountId = _s(j['moneyAccountId']),
        provider = _s(j['provider']),
        name = _s(j['name']),
        kind = _s(j['kind']),
        terminalId = _n(j['terminalId']),
        isDefault = _b(j['default']);
}

class ReceiptLine {
  final String source, id, provider, method, status;
  final String? moneyAccountId,
      accountName,
      terminalId,
      payer,
      reference,
      utr,
      settlementRef,
      documentNo;
  final int grossPaise;
  final int? feePaise, taxPaise, netPaise;
  final DateTime? at;

  ReceiptLine.fromJson(Map<String, dynamic> j)
      : source = _s(j['source']),
        id = _s(j['id']),
        provider = _s(j['provider']),
        method = _s(j['method']),
        status = _s(j['status']),
        moneyAccountId = _n(j['moneyAccountId']),
        accountName = _n(j['accountName']),
        terminalId = _n(j['terminalId']),
        payer = _n(j['payer']),
        reference = _n(j['reference']),
        utr = _n(j['utr']),
        settlementRef = _n(j['settlementRef']),
        documentNo = _n(j['documentNo']),
        grossPaise = _i(j['grossPaise']),
        feePaise = _ni(j['feePaise']),
        taxPaise = _ni(j['taxPaise']),
        netPaise = _ni(j['netPaise']),
        at = _dt(j['at']);
}

class ReceiptTotal {
  final String provider, accountName, method;
  final String? moneyAccountId;
  final int receipts, grossPaise, feePaise, taxPaise;

  ReceiptTotal.fromJson(Map<String, dynamic> j)
      : provider = _s(j['provider']),
        accountName = _n(j['accountName']) ?? 'Unassigned',
        method = _s(j['method']),
        moneyAccountId = _n(j['moneyAccountId']),
        receipts = _i(j['receipts']),
        grossPaise = _i(j['grossPaise']),
        feePaise = _i(j['feePaise']),
        taxPaise = _i(j['taxPaise']);
}

class ReceiptByAccount {
  final String? moneyAccountId, accountKind;
  final String accountName, method;
  final int receipts, grossPaise, refundedPaise, netPaise;

  ReceiptByAccount.fromJson(Map<String, dynamic> j)
      : moneyAccountId = _n(j['moneyAccountId']),
        accountKind = _n(j['accountKind']),
        accountName = _n(j['accountName']) ?? 'Unassigned',
        method = _s(j['method']),
        receipts = _i(j['receipts']),
        grossPaise = _i(j['grossPaise']),
        refundedPaise = _i(j['refundedPaise']),
        netPaise = _i(j['netPaise']);
}

class FeeRow {
  final String month, accountName;
  final String? moneyAccountId;
  final int payments, grossPaise, feePaise, taxPaise, missingFee;

  FeeRow.fromJson(Map<String, dynamic> j)
      : month = _s(j['month']),
        accountName = _n(j['accountName']) ?? 'Unassigned',
        moneyAccountId = _n(j['moneyAccountId']),
        payments = _i(j['payments']),
        grossPaise = _i(j['grossPaise']),
        feePaise = _i(j['feePaise']),
        taxPaise = _i(j['taxPaise']),
        missingFee = _i(j['missingFee']);
}

class SettlementRow {
  final String id, provider, providerSettlementId, status, source;
  final String? utr, moneyAccountId, accountName;
  final DateTime? settledAt;
  final int grossPaise, feePaise, taxPaise, netPaise, items, unmatchedItems;

  SettlementRow.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        provider = _s(j['provider']),
        providerSettlementId = _s(j['providerSettlementId']),
        status = _s(j['status']),
        source = _s(j['source']),
        utr = _n(j['utr']),
        moneyAccountId = _n(j['moneyAccountId']),
        accountName = _n(j['accountName']),
        settledAt = _dt(j['settledAt']),
        grossPaise = _i(j['grossPaise']),
        feePaise = _i(j['feePaise']),
        taxPaise = _i(j['taxPaise']),
        netPaise = _i(j['netPaise']),
        items = _i(j['items']),
        unmatchedItems = _i(j['unmatchedItems']);
}

class SettlementItem {
  final String id, kind, providerEntityId;
  final int grossPaise, feePaise, taxPaise, netPaise;
  final bool matched;
  final String? method,
      utr,
      reference,
      paymentId,
      orderId,
      orderNo,
      refundId,
      posPaymentId,
      invoiceNo;
  final DateTime? settledAt;

  SettlementItem.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        kind = _s(j['kind']),
        providerEntityId = _s(j['providerEntityId']),
        grossPaise = _i(j['grossPaise']),
        feePaise = _i(j['feePaise']),
        taxPaise = _i(j['taxPaise']),
        netPaise = _i(j['netPaise']),
        matched = _b(j['matched']),
        method = _n(j['method']),
        utr = _n(j['utr']),
        reference = _n(j['reference']),
        paymentId = _n(j['paymentId']),
        orderId = _n(j['orderId']),
        orderNo = _n(j['orderNo']),
        refundId = _n(j['refundId']),
        posPaymentId = _n(j['posPaymentId']),
        invoiceNo = _n(j['invoiceNo']),
        settledAt = _dt(j['settledAt']);
}

class SyncResult {
  final String provider;
  final int settlementsSeen, settlementsStored, itemsStored;
  final bool skipped;

  SyncResult.fromJson(Map<String, dynamic> j)
      : provider = _s(j['provider']),
        settlementsSeen = _i(j['settlementsSeen']),
        settlementsStored = _i(j['settlementsStored']),
        itemsStored = _i(j['itemsStored']),
        skipped = _b(j['skipped']);
}

class ImportResult {
  final String settlementId;
  final bool alreadyImported;
  final int rows, matched, unmatched, netPaise;

  ImportResult.fromJson(Map<String, dynamic> j)
      : settlementId = _s(j['settlementId']),
        alreadyImported = _b(j['alreadyImported']),
        rows = _i(j['rows']),
        matched = _i(j['matched']),
        unmatched = _i(j['unmatched']),
        netPaise = _i(j['netPaise']);
}

class UnsettledItem {
  final String source, id, reference;
  final String? moneyAccountId, accountName;
  final int amountPaise;
  final DateTime? receivedAt, expectedBy;
  final bool overdue;

  UnsettledItem.fromJson(Map<String, dynamic> j)
      : source = _s((j['row'] as Map?)?['source']),
        id = _s((j['row'] as Map?)?['id']),
        reference = _s((j['row'] as Map?)?['reference']),
        moneyAccountId = _n((j['row'] as Map?)?['moneyAccountId']),
        accountName = _n((j['row'] as Map?)?['accountName']),
        amountPaise = _i((j['row'] as Map?)?['amountPaise']),
        receivedAt = _dt((j['row'] as Map?)?['receivedAt']),
        expectedBy = _dt(j['expectedBy']),
        overdue = _b(j['overdue']);
}

class SettlementException {
  final String id, kind, status;
  final String? settlementId, settlementItemId, paymentId, reference, note;
  final int? expectedPaise, actualPaise;
  final DateTime? createdAt, resolvedAt;

  SettlementException.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        kind = _s(j['kind']),
        status = _s(j['status']),
        settlementId = _n(j['settlementId']),
        settlementItemId = _n(j['settlementItemId']),
        paymentId = _n(j['paymentId']),
        reference = _n(j['reference']),
        note = _n(j['note']),
        expectedPaise = _ni(j['expectedPaise']),
        actualPaise = _ni(j['actualPaise']),
        createdAt = _dt(j['createdAt']),
        resolvedAt = _dt(j['resolvedAt']);
}

/// A Paytm machine (`/admin/payment-terminals`).
class TerminalView {
  final String id, provider, terminalId, name;
  final String? moneyAccountId, settlesToAccountId;
  final bool active;
  final DateTime? createdAt;

  TerminalView.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        provider = _s(j['provider']),
        terminalId = _s(j['terminalId']),
        name = _s(j['name']),
        moneyAccountId = _n(j['moneyAccountId']),
        settlesToAccountId = _n(j['settlesToAccountId']),
        active = j['active'] != false,
        createdAt = _dt(j['createdAt']);
}

class TerminalTestResult {
  final bool ok;
  final String code, message;

  TerminalTestResult.fromJson(Map<String, dynamic> j)
      : ok = _b(j['ok']),
        code = _s(j['code']),
        message = _s(j['message']);
}

/// One online payment of an order (`GET /admin/payments/by-order/{id}`).
class OrderPayerRow {
  final String paymentId, provider, status;
  final int amountPaise;
  final String? instrument,
      upiVpa,
      cardNetwork,
      cardLast4,
      bank,
      settlementRef,
      utr,
      moneyAccountId,
      accountName,
      providerRef;
  final int? feePaise, taxPaise, netPaise;
  final DateTime? settledAt, capturedAt;

  OrderPayerRow.fromJson(Map<String, dynamic> j)
      : paymentId = _s(j['paymentId']),
        provider = _s(j['provider']),
        status = _s(j['status']),
        amountPaise = _i(j['amountPaise']),
        instrument = _n(j['instrument']),
        upiVpa = _n(j['upiVpa']),
        cardNetwork = _n(j['cardNetwork']),
        cardLast4 = _n(j['cardLast4']),
        bank = _n(j['bank']),
        settlementRef = _n(j['settlementRef']),
        utr = _n(j['utr']),
        moneyAccountId = _n(j['moneyAccountId']),
        accountName = _n(j['accountName']),
        providerRef = _n(j['providerRef']),
        feePaise = _ni(j['feePaise']),
        taxPaise = _ni(j['taxPaise']),
        netPaise = _ni(j['netPaise']),
        settledAt = _dt(j['settledAt']),
        capturedAt = _dt(j['capturedAt']);
}

/// One payment line of a counter bill (`GET /admin/payments/by-sale/{id}`).
class SalePayerRow {
  final String posPaymentId, mode, provider;
  final int amountPaise;
  final String? reference,
      terminalId,
      moneyAccountId,
      accountName,
      payMethod,
      cardScheme,
      cardLast4,
      issuingBank,
      upiVpa,
      authCode,
      settlementRef,
      utr;
  final int? feePaise, taxPaise, netPaise;
  final DateTime? settledAt;

  SalePayerRow.fromJson(Map<String, dynamic> j)
      : posPaymentId = _s(j['posPaymentId']),
        mode = _s(j['mode']),
        provider = _s(j['provider']),
        amountPaise = _i(j['amountPaise']),
        reference = _n(j['reference']),
        terminalId = _n(j['terminalId']),
        moneyAccountId = _n(j['moneyAccountId']),
        accountName = _n(j['accountName']),
        payMethod = _n(j['payMethod']),
        cardScheme = _n(j['cardScheme']),
        cardLast4 = _n(j['cardLast4']),
        issuingBank = _n(j['issuingBank']),
        upiVpa = _n(j['upiVpa']),
        authCode = _n(j['authCode']),
        settlementRef = _n(j['settlementRef']),
        utr = _n(j['utr']),
        feePaise = _ni(j['feePaise']),
        taxPaise = _ni(j['taxPaise']),
        netPaise = _ni(j['netPaise']),
        settledAt = _dt(j['settledAt']);
}
