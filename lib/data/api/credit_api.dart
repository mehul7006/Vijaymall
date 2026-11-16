import 'api_client.dart';
import 'dto.dart';

/// Customer credit (udhar): `/credit` and `/credit/ledger`.
///
/// Read-only for the signed-in customer — the counter staff takes the credit
/// bill, this is just what they owe and how it moved. Both calls carry the
/// session token (the backend scopes them to `CurrentUser.id()`).
class CreditApi {
  CreditApi(this._client);

  final ApiClient _client;

  /// `GET /credit` — the account as it stands now.
  Future<CreditAccountDto> getAccount() async {
    final raw = await _client.get('/credit');
    return CreditAccountDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /credit/ledger` — newest entries first (paged).
  Future<PageCreditLedgerDto> getLedger({int page = 0, int size = 50}) async {
    final raw = await _client.get('/credit/ledger', query: {
      'page': '$page',
      'size': '$size',
    });
    return PageCreditLedgerDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }
}
