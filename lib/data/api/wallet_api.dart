import 'api_client.dart';
import 'dto.dart';

/// Wallet + payment methods: `/wallet`, `/wallet/ledger`, `/payment-methods`.
class WalletApi {
  WalletApi(this._client);

  final ApiClient _client;

  Future<WalletViewDto> getWallet() async {
    final raw = await _client.get('/wallet');
    return WalletViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<PageLedgerViewDto> getLedger({int page = 0, int size = 50}) async {
    final raw = await _client.get('/wallet/ledger', query: {
      'page': '$page',
      'size': '$size',
    });
    return PageLedgerViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /payment-methods` (public set of enabled methods).
  Future<List<SettingDto>> getPaymentMethods() async {
    final raw = await _client.get('/payment-methods') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => SettingDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
