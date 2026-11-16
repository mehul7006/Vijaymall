import 'package:flutter/material.dart';

import '../../data/bank_store.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/controls.dart';
import 'admin_bank_accounts.dart';
import 'admin_bank_common.dart';
import 'admin_bank_defaults.dart';
import 'admin_bank_exceptions.dart';
import 'admin_bank_machines.dart';
import 'admin_bank_receipts.dart';
import 'admin_bank_settlements.dart';

/// `#/admin/bank` - Bank and settlements (`71-bank-and-settlements.md`,
/// `playbooks/P4-bank-settlements-receipts.md`, admin side).
///
/// Query: `tab` = accounts | receipts | settlements | exceptions | unsettled |
/// machines | defaults; `book=<accountId>` opens one account book;
/// `settlement=<id>` (+ `unmatched=1`) opens one settlement's items.
class AdminBankScreen extends StatefulWidget {
  final Map<String, String> query;
  const AdminBankScreen({super.key, this.query = const {}});

  @override
  State<AdminBankScreen> createState() => _AdminBankScreenState();
}

class _AdminBankScreenState extends State<AdminBankScreen> {
  static const _tabs = [
    ('accounts', 'Accounts'),
    ('receipts', 'Receipts'),
    ('settlements', 'Settlements'),
    ('exceptions', 'Exceptions'),
    ('unsettled', 'Unsettled'),
    ('machines', 'Paytm machines'),
    ('defaults', 'Defaults'),
  ];

  late String _tab = _fromQuery();

  String _fromQuery() {
    final t = widget.query['tab'] ?? 'accounts';
    return _tabs.any((e) => e.$1 == t) ? t : 'accounts';
  }

  @override
  void initState() {
    super.initState();
    BankStore.instance.loadAccounts();
    BankStore.instance.refreshBadge();
  }

  @override
  void didUpdateWidget(covariant AdminBankScreen old) {
    super.didUpdateWidget(old);
    if (old.query['tab'] != widget.query['tab']) _tab = _fromQuery();
  }

  void _back() {
    if (!Nav.instance.pop()) go('/admin/bank?tab=${_tab == 'defaults' ? 'accounts' : _tab}');
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.query['book'];
    if (book != null && book.isNotEmpty) {
      return BankPageShell(
        title: gt('Account book'),
        sub: gt('Running balance with manual entries'),
        onBack: _back,
        child: AccountBookView(key: ValueKey(book), accountId: book),
      );
    }
    final settlement = widget.query['settlement'];
    if (settlement != null && settlement.isNotEmpty) {
      return BankPageShell(
        title: gt('Settlement'),
        sub: gt('What the provider or bank paid out, line by line'),
        onBack: _back,
        child: SettlementDetailView(
            key: ValueKey('$settlement|${widget.query['unmatched']}'),
            id: settlement,
            unmatchedOnly: widget.query['unmatched'] == '1'),
      );
    }
    return BankPageShell(
      title: gt('Bank and settlements'),
      sub: gt('Accounts, receipts, payouts and exceptions'),
      onRefresh: () async {
        await BankStore.instance.loadAccounts(force: true);
        await BankStore.instance.refreshBadge();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListenableBuilder(
            listenable: BankStore.instance,
            builder: (_, __) => ChipRail(children: [
              for (final t in _tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(
                    t.$1 == 'exceptions' && BankStore.instance.openExceptions > 0
                        ? '${gt(t.$2)} (${BankStore.instance.openExceptions})'
                        : t.$2,
                    selected: _tab == t.$1,
                    onTap: () => setState(() => _tab = t.$1),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          // A key per tab: leaving a tab drops its state, coming back reloads.
          KeyedSubtree(key: ValueKey(_tab), child: _body()),
          const SizedBox(height: 8),
          Text(
              gt('Amounts are in rupees; the server keeps them in exact paise.'),
              style: bankStyle(11, FontWeight.w600, AppColors.ink3)),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 'receipts':
        return const BankReceiptsTab();
      case 'settlements':
        return const BankSettlementsTab();
      case 'exceptions':
        return const BankExceptionsTab();
      case 'unsettled':
        return const BankUnsettledTab();
      case 'machines':
        return const BankMachinesTab();
      case 'defaults':
        return const BankDefaultsTab();
    }
    return const BankAccountsTab();
  }
}
