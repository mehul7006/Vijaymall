import 'api_client.dart';
import 'bank_dto.dart';

/// Bank module, ADMIN side (`71-bank-and-settlements.md`,
/// `playbooks/P4-bank-settlements-receipts.md`, `73-paytm-terminal.md`).
class BankApi {
  BankApi(this._client);

  final ApiClient _client;

  Map<String, dynamic> _m(dynamic raw) => Map<String, dynamic>.from(raw as Map);

  Map<String, String> _q(Map<String, Object?> q) => {
        for (final e in q.entries)
          if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
      };

  Map<String, String>? _idem(String? key) =>
      key == null ? null : {'Idempotency-Key': key};

  // ---- money accounts -------------------------------------------------------

  Future<BankPage<MoneyAccount>> accounts(
          {String? kind,
          bool? active,
          String? q,
          int page = 0,
          int size = 20}) async =>
      BankPage.fromJson(
          await _client.get('/admin/money-accounts', query: _q({
            'kind': kind,
            'active': active,
            'q': q,
            'page': page,
            'size': size,
          })),
          MoneyAccount.fromJson);

  Future<MoneyAccount> account(String id) async => MoneyAccount.fromJson(
      _m(await _client.get('/admin/money-accounts/$id')));

  /// [idempotencyKey]: one per button tap, reused on a retry.
  Future<MoneyAccount> createAccount(Map<String, dynamic> body,
          {String? idempotencyKey}) async =>
      MoneyAccount.fromJson(_m(await _client.post('/admin/money-accounts',
          body: body, headers: _idem(idempotencyKey))));

  Future<MoneyAccount> updateAccount(String id, Map<String, dynamic> body) async =>
      MoneyAccount.fromJson(
          _m(await _client.put('/admin/money-accounts/$id', body: body)));

  Future<MoneyAccount> setAccountActive(String id, bool active) async =>
      MoneyAccount.fromJson(_m(await _client.post(
          '/admin/money-accounts/$id/${active ? 'activate' : 'deactivate'}')));

  Future<void> deleteAccount(String id) =>
      _client.delete('/admin/money-accounts/$id');

  Future<AccountBook> book(String id,
          {String? from, String? to, int page = 0, int size = 20}) async =>
      AccountBook.fromJson(_m(await _client.get('/admin/money-accounts/$id/book',
          query: _q({'from': from, 'to': to, 'page': page, 'size': size}))));

  Future<void> addEntry(String id, Map<String, dynamic> body,
          {String? idempotencyKey}) =>
      _client.post('/admin/money-accounts/$id/entries',
          body: body, headers: _idem(idempotencyKey));

  /// Channels the till offers (`/pos/payment-channels`, CASHIER and ADMIN).
  Future<List<PayChannel>> channels() async => [
        for (final e in (await _client.get('/pos/payment-channels')) as List)
          PayChannel.fromJson(_m(e))
      ];

  // ---- receipts and reports -------------------------------------------------

  Future<List<ReceiptTotal>> receiptSummary({String? from, String? to}) async => [
        for (final e in (await _client.get('/admin/receipts/summary',
            query: _q({'from': from, 'to': to}))) as List)
          ReceiptTotal.fromJson(_m(e))
      ];

  Future<BankPage<ReceiptLine>> receipts(
          {String? from,
          String? to,
          String? provider,
          String? account,
          String? method,
          int page = 0,
          int size = 20}) async =>
      BankPage.fromJson(
          await _client.get('/admin/receipts', query: _q({
            'from': from,
            'to': to,
            'provider': provider,
            'account': account,
            'method': method,
            'page': page,
            'size': size,
          })),
          ReceiptLine.fromJson);

  Future<BankPage<ReceiptByAccount>> receiptsByAccount(
          {String? from, String? to, int page = 0, int size = 50}) async =>
      BankPage.fromJson(
          await _client.get('/admin/bank-reports/receipts',
              query: _q({'from': from, 'to': to, 'page': page, 'size': size})),
          ReceiptByAccount.fromJson);

  Future<BankPage<FeeRow>> fees(
          {String? from, String? to, int page = 0, int size = 50}) async =>
      BankPage.fromJson(
          await _client.get('/admin/bank-reports/fees',
              query: _q({'from': from, 'to': to, 'page': page, 'size': size})),
          FeeRow.fromJson);

  // ---- settlements ----------------------------------------------------------

  Future<BankPage<SettlementRow>> settlements(
          {String? from,
          String? to,
          String? accountId,
          String? provider,
          String? source,
          int page = 0,
          int size = 20}) async =>
      BankPage.fromJson(
          await _client.get('/admin/settlements', query: _q({
            'from': from,
            'to': to,
            'accountId': accountId,
            'provider': provider,
            'source': source,
            'page': page,
            'size': size,
          })),
          SettlementRow.fromJson);

  Future<SettlementRow> settlement(String id) async => SettlementRow.fromJson(
      _m(await _client.get('/admin/settlements/$id')));

  Future<BankPage<SettlementItem>> settlementItems(String id,
          {bool unmatchedOnly = false, int page = 0, int size = 50}) async =>
      BankPage.fromJson(
          await _client.get('/admin/settlements/$id/items', query: _q({
            'unmatchedOnly': unmatchedOnly ? 'true' : null,
            'page': page,
            'size': size,
          })),
          SettlementItem.fromJson);

  Future<SyncResult> sync(String provider, {int? days}) async =>
      SyncResult.fromJson(_m(await _client.post('/admin/settlements/sync',
          body: {'provider': provider, if (days != null) 'days': days})));

  /// CSV statement import. The options travel as query parameters (that is
  /// how Swagger declares them; the server reads them as request params).
  Future<ImportResult> importStatement(
          {required List<int> bytes,
          required String filename,
          required Map<String, String> options}) async =>
      ImportResult.fromJson(_m(await _client.postMultipart(
          '/admin/settlements/import',
          fileField: 'file',
          bytes: bytes,
          filename: filename,
          query: options)));

  Future<BankPage<UnsettledItem>> unsettled(
          {bool overdueOnly = false, int page = 0, int size = 20}) async =>
      BankPage.fromJson(
          await _client.get('/admin/settlements/unsettled', query: _q({
            'overdueOnly': overdueOnly ? 'true' : null,
            'page': page,
            'size': size,
          })),
          UnsettledItem.fromJson);

  Future<BankPage<SettlementException>> exceptions(
          {String status = 'OPEN', String? kind, int page = 0, int size = 20}) async =>
      BankPage.fromJson(
          await _client.get('/admin/settlements/exceptions', query: _q({
            'status': status,
            'kind': kind,
            'page': page,
            'size': size,
          })),
          SettlementException.fromJson);

  /// Number of OPEN exceptions (the badge).
  Future<int> openExceptionCount() async =>
      (await exceptions(status: 'OPEN', size: 1)).total;

  Future<SettlementException> resolveException(String id, String note) async =>
      SettlementException.fromJson(_m(await _client.post(
          '/admin/settlements/exceptions/$id/resolve',
          body: {'note': note})));

  // ---- Paytm machines -------------------------------------------------------

  Future<BankPage<TerminalView>> terminals({int page = 0, int size = 20}) async =>
      BankPage.fromJson(
          await _client.get('/admin/payment-terminals',
              query: _q({'page': page, 'size': size})),
          TerminalView.fromJson);

  Future<TerminalView> createTerminal(Map<String, dynamic> body) async =>
      TerminalView.fromJson(
          _m(await _client.post('/admin/payment-terminals', body: body)));

  Future<TerminalView> updateTerminal(String id, Map<String, dynamic> body) async =>
      TerminalView.fromJson(
          _m(await _client.put('/admin/payment-terminals/$id', body: body)));

  Future<TerminalView> deactivateTerminal(String id) async =>
      TerminalView.fromJson(
          _m(await _client.post('/admin/payment-terminals/$id/deactivate')));

  Future<TerminalTestResult> testTerminal(String id) async =>
      TerminalTestResult.fromJson(
          _m(await _client.post('/admin/payment-terminals/$id/test')));

  // ---- payer detail ---------------------------------------------------------

  Future<List<OrderPayerRow>> payersByOrder(String orderId) async => [
        for (final e in (await _client.get('/admin/payments/by-order/$orderId')) as List)
          OrderPayerRow.fromJson(_m(e))
      ];

  Future<List<SalePayerRow>> payersBySale(String saleId) async => [
        for (final e in (await _client.get('/admin/payments/by-sale/$saleId')) as List)
          SalePayerRow.fromJson(_m(e))
      ];
}
