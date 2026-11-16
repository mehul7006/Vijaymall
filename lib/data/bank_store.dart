import 'package:flutter/foundation.dart';

import 'api/api_exception.dart';
import 'api/api_service.dart';
import 'api/bank_api.dart';
import 'api/bank_dto.dart';

/// Shared state of the bank module: the API handle, the money accounts used
/// by dropdowns and the OPEN-exception count (badge).
///
/// Uses `BankApi(Api.instance.client)` so no change to `api_service.dart` is
/// needed; if the coordinator adds `Api.instance.bank` it can point here.
class BankStore extends ChangeNotifier {
  BankStore._();
  static final BankStore instance = BankStore._();

  BankApi get api => BankApi(Api.instance.client);

  List<MoneyAccount> accounts = const [];
  bool accountsLoaded = false;
  int openExceptions = 0;
  bool _loadingAccounts = false;

  /// Loads every account (page by page, at most 10 pages of 50).
  Future<void> loadAccounts({bool force = false}) async {
    if (_loadingAccounts) return;
    if (accountsLoaded && !force) return;
    _loadingAccounts = true;
    try {
      final all = <MoneyAccount>[];
      for (var p = 0; p < 10; p++) {
        final r = await api.accounts(page: p, size: 50);
        all.addAll(r.items);
        if (!r.hasMore) break;
      }
      accounts = all;
      accountsLoaded = true;
      notifyListeners();
    } on ApiException {
      // keep the previous list; the screen shows its own error
    } finally {
      _loadingAccounts = false;
    }
  }

  Future<void> refreshBadge() async {
    try {
      final n = await api.openExceptionCount();
      if (n != openExceptions) {
        openExceptions = n;
        notifyListeners();
      }
    } on ApiException {
      // badge is optional
    }
  }

  void setBadge(int n) {
    if (n == openExceptions) return;
    openExceptions = n;
    notifyListeners();
  }

  MoneyAccount? byId(String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Active accounts of the given kinds (all kinds when empty).
  List<MoneyAccount> active(Iterable<String> kinds) => [
        for (final a in accounts)
          if (a.active && (kinds.isEmpty || kinds.contains(a.kind))) a
      ];
}
