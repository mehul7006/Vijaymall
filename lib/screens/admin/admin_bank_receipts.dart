import 'package:flutter/material.dart';

import '../../data/api/api_service.dart';
import '../../data/api/bank_dto.dart';
import '../../data/bank_store.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/payer_detail.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_bank_common.dart';

/// Receipts section: summary, all receipts, per-account report, fees report
/// and the payment channels overview.
class BankReceiptsTab extends StatefulWidget {
  const BankReceiptsTab({super.key});

  @override
  State<BankReceiptsTab> createState() => _BankReceiptsTabState();
}

class _BankReceiptsTabState extends State<BankReceiptsTab> {
  String _sub = 'summary';
  // Filters handed from a summary row to the list.
  String _provider = '';
  String _account = '';
  String _method = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipRail(children: [
          for (final t in const [
            ('summary', 'Summary'),
            ('list', 'All receipts'),
            ('byaccount', 'By account'),
            ('fees', 'Fees'),
            ('channels', 'Channels'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(t.$2,
                  selected: _sub == t.$1, onTap: () => setState(() => _sub = t.$1)),
            ),
        ]),
        const SizedBox(height: 12),
        switch (_sub) {
          'summary' => _SummaryView(onDrill: (provider, account, method) {
              setState(() {
                _provider = provider;
                _account = account;
                _method = method;
                _sub = 'list';
              });
            }),
          'list' => _ReceiptListView(
              key: ValueKey('$_provider|$_account|$_method'),
              provider: _provider,
              account: _account,
              method: _method),
          'byaccount' => const _ByAccountView(),
          'fees' => const _FeesView(),
          _ => const _ChannelsView(),
        },
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary cards
// ---------------------------------------------------------------------------

class _SummaryView extends StatefulWidget {
  final void Function(String provider, String account, String method) onDrill;
  const _SummaryView({required this.onDrill});

  @override
  State<_SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<_SummaryView> {
  BankRange _range = BankRange.lastDays(30);
  List<ReceiptTotal>? _rows;
  bool _loading = true;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_range.error != null) return;
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await BankStore.instance.api
          .receiptSummary(from: _range.fromText, to: _range.toText);
      if (!mounted || gen != _gen) return;
      setState(() {
        _rows = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e, _range);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    var gross = 0, fee = 0, tax = 0, count = 0;
    for (final r in rows ?? const <ReceiptTotal>[]) {
      gross += r.grossPaise;
      fee += r.feePaise;
      tax += r.taxPaise;
      count += r.receipts;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BankRangeBar(
            range: _range,
            onChanged: (r) {
              setState(() => _range = r);
              _load();
            }),
        const SizedBox(height: 12),
        if (_loading && rows == null)
          const SkeletonRows(rows: 3)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (rows != null && rows.isEmpty)
          EmptyState(
              icon: 'wallet',
              title: gt('No receipts in this period'),
              copy: gt('Try a longer period.'))
        else if (rows != null) ...[
          CardPanel(
            title: gt('Total of the groups below'),
            child: Column(children: [
              BankKv('Receipts', '$count'),
              BankKv('Gross', bankMoney(gross), strong: true),
              BankKv('Fees', bankMoney(fee)),
              BankKv('GST on fees', bankMoney(tax)),
            ]),
          ),
          const SizedBox(height: 12),
          for (final r in rows)
            BankCard(
              onTap: () => widget.onDrill(
                  r.provider == 'counter' && r.moneyAccountId == null ? 'counter' : r.provider,
                  r.moneyAccountId ?? '',
                  r.method),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            r.accountName == 'Unassigned'
                                ? gt('Unassigned')
                                : r.accountName,
                            style: bankStyle(14, FontWeight.w800, AppColors.ink)),
                        const SizedBox(height: 3),
                        Text('${r.provider} · ${r.method} · ${r.receipts} ${gt('receipts')}',
                            style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
                        if (r.feePaise > 0 || r.taxPaise > 0)
                          Text(
                              '${gt('Fee')} ${bankMoney(r.feePaise)} · GST ${bankMoney(r.taxPaise)}',
                              style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
                      ],
                    ),
                  ),
                  Text(bankMoney(r.grossPaise),
                      style: bankStyle(14.5, FontWeight.w800, AppColors.ink)),
                ],
              ),
            ),
          const BankInfoLine('Tap a group to see its receipts. Unassigned is normal for old receipts.'),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Receipts list
// ---------------------------------------------------------------------------

class _ReceiptListView extends StatefulWidget {
  final String provider, account, method;
  const _ReceiptListView(
      {super.key, this.provider = '', this.account = '', this.method = ''});

  @override
  State<_ReceiptListView> createState() => _ReceiptListViewState();
}

class _ReceiptListViewState extends State<_ReceiptListView> {
  late String _provider = widget.provider;
  late String _account = widget.account;
  late String _method = widget.method;
  BankRange _range = BankRange.lastDays(30);
  BankPage<ReceiptLine>? _page;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    BankStore.instance.loadAccounts().then((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load({int? page}) async {
    if (_range.error != null) return;
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _pageNo = page;
    });
    try {
      final r = await BankStore.instance.api.receipts(
          from: _range.fromText,
          to: _range.toText,
          provider: _provider,
          account: _account,
          method: _method,
          page: _pageNo,
          size: 20);
      if (!mounted || gen != _gen) return;
      setState(() {
        _page = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e, _range);
        _loading = false;
      });
    }
  }

  void _filter(VoidCallback f) {
    setState(f);
    _pageNo = 0;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    final accName = BankStore.instance.byId(_account)?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BankRangeBar(range: _range, onChanged: (r) => _filter(() => _range = r)),
        const SizedBox(height: 10),
        ChipRail(children: [
          for (final v in const ['', 'razorpay', 'paytm', 'manual', 'counter'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(v.isEmpty ? gt('All vendors') : v,
                  small: true,
                  selected: _provider == v,
                  onTap: () => _filter(() => _provider = v)),
            ),
        ]),
        const SizedBox(height: 8),
        ChipRail(children: [
          for (final v in const ['', 'UPI', 'CARD', 'CASH', 'NETBANKING', 'WALLET', 'ONLINE'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(v.isEmpty ? gt('All methods') : v,
                  small: true,
                  selected: _method == v,
                  onTap: () => _filter(() => _method = v)),
            ),
        ]),
        const SizedBox(height: 10),
        SelectField(
          label: 'Account',
          value: _account.isEmpty ? '' : accName,
          placeholder: gt('All accounts'),
          onTap: () async {
            final k = await pickBankOption(context,
                title: 'Account',
                selected: _account,
                options: [
                  ('', gt('All accounts')),
                  for (final a in BankStore.instance.accounts) (a.id, a.name),
                ]);
            if (k != null) _filter(() => _account = k);
          },
        ),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 4)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
              icon: 'wallet',
              title: gt('No receipts in this period'),
              copy: gt('Change the filters or the dates.'))
        else if (p != null) ...[
          ResultSummary('${p.totalText} ${gt(p.total == 1 ? 'receipt' : 'receipts')}'),
          for (final r in p.items) _row(r),
          BankPager(page: p, onPage: (n) => _load(page: n)),
        ],
      ],
    );
  }

  /// Counter bill: find it by invoice number (`GET /pos/sales?invoiceNo=`)
  /// and show who paid how (`GET /admin/payments/by-sale/{id}`).
  Future<void> _openBill(String invoiceNo) async {
    try {
      final sales = await Api.instance.pos.listSales(invoiceNo: invoiceNo);
      final id = sales.isEmpty ? null : sales.first.id;
      if (id == null) {
        showToast('Bill not found', 'error');
        return;
      }
      if (!mounted) return;
      await showAppSheet<void>(
        context: context,
        title: invoiceNo,
        sub: 'Counter bill: how it was paid',
        builder: (_) => PayerDetail.sale(id),
      );
    } catch (e) {
      showToast(bankError(e), 'error');
    }
  }

  Widget _row(ReceiptLine r) {
    final online = r.source == 'ONLINE_ORDER';
    return BankCard(
      onTap: r.documentNo == null
          ? null
          : () {
              if (online) {
                go('/admin/order/${r.documentNo}');
              } else {
                _openBill(r.documentNo!);
              }
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r.documentNo ?? '-',
                  style: bankStyle(14, FontWeight.w800, AppColors.ink)),
            ),
            Text(bankMoney(r.grossPaise),
                style: bankStyle(14.5, FontWeight.w800, AppColors.ink)),
          ]),
          const SizedBox(height: 3),
          Text(
              '${bankWhen(r.at)} · ${online ? gt('Online order') : gt('Counter bill')}',
              style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            bankPill(r.method),
            bankPill(r.provider),
            bankPill(r.status,
                tone: r.status == 'REFUNDED' ? 'warn' : 'good'),
          ]),
          const SizedBox(height: 6),
          Text(
              [
                r.accountName ?? gt('Unassigned'),
                if (r.terminalId != null) r.terminalId!,
                if (r.payer != null) r.payer!,
                if (r.reference != null) r.reference!,
              ].join(' · '),
              style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
          const SizedBox(height: 4),
          Text(
              '${gt('Fee')} ${r.feePaise == null ? '-' : bankMoney(r.feePaise!)} · GST ${r.taxPaise == null ? '-' : bankMoney(r.taxPaise!)} · ${gt('Net')} ${r.netPaise == null ? '-' : bankMoney(r.netPaise!)}'
              '${r.utr == null ? '' : ' · UTR ${r.utr}'}',
              style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Receipts by account and method (with refunds)
// ---------------------------------------------------------------------------

class _ByAccountView extends StatefulWidget {
  const _ByAccountView();

  @override
  State<_ByAccountView> createState() => _ByAccountViewState();
}

class _ByAccountViewState extends State<_ByAccountView> {
  BankRange _range = BankRange.lastDays(30);
  BankPage<ReceiptByAccount>? _page;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    if (_range.error != null) return;
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _pageNo = page;
    });
    try {
      final r = await BankStore.instance.api.receiptsByAccount(
          from: _range.fromText, to: _range.toText, page: _pageNo, size: 50);
      if (!mounted || gen != _gen) return;
      setState(() {
        _page = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e, _range);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BankRangeBar(
            range: _range,
            onChanged: (r) {
              setState(() => _range = r);
              _pageNo = 0;
              _load();
            }),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 3)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
              icon: 'wallet',
              title: gt('No receipts in this period'),
              copy: gt('Try a longer period.'))
        else if (p != null) ...[
          for (final r in p.items)
            BankCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          r.moneyAccountId == null ? gt('Unassigned') : r.accountName,
                          style: bankStyle(14, FontWeight.w800, AppColors.ink)),
                    ),
                    bankPill(r.method),
                  ]),
                  if (r.accountKind != null)
                    Text(kindLabel(r.accountKind!),
                        style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
                  const SizedBox(height: 6),
                  BankKv('Receipts', '${r.receipts}'),
                  BankKv('Gross', bankMoney(r.grossPaise)),
                  BankKv('Refunded', bankMoney(r.refundedPaise)),
                  BankKv('Net', bankMoney(r.netPaise), strong: true),
                ],
              ),
            ),
          BankPager(page: p, onPage: (n) => _load(page: n)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fees report
// ---------------------------------------------------------------------------

class _FeesView extends StatefulWidget {
  const _FeesView();

  @override
  State<_FeesView> createState() => _FeesViewState();
}

class _FeesViewState extends State<_FeesView> {
  BankRange _range = BankRange.lastDays(90);
  BankPage<FeeRow>? _page;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    if (_range.error != null) return;
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _pageNo = page;
    });
    try {
      final r = await BankStore.instance.api.fees(
          from: _range.fromText, to: _range.toText, page: _pageNo, size: 50);
      if (!mounted || gen != _gen) return;
      setState(() {
        _page = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e, _range);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BankRangeBar(
            range: _range,
            onChanged: (r) {
              setState(() => _range = r);
              _pageNo = 0;
              _load();
            }),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 3)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
              icon: 'percent',
              title: gt('No online payments in this period'),
              copy: gt('Fees are reported for online payments only.'))
        else if (p != null) ...[
          for (final r in p.items)
            BankCard(
              alert: r.missingFee > 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${r.month} · ${r.accountName == 'Unassigned' ? gt('Unassigned') : r.accountName}',
                          style: bankStyle(14, FontWeight.w800, AppColors.ink)),
                    ),
                    if (r.missingFee > 0)
                      bankPill('${r.missingFee} ${gt('fees pending')}', tone: 'warn'),
                  ]),
                  const SizedBox(height: 6),
                  BankKv('Payments', '${r.payments}'),
                  BankKv('Gross', bankMoney(r.grossPaise)),
                  BankKv('Fees', bankMoney(r.feePaise), strong: true),
                  BankKv('GST on fees', bankMoney(r.taxPaise)),
                  if (r.missingFee > 0)
                    BankNote(
                        '${r.missingFee} ${gt('payments have no fee yet: the totals are incomplete until the provider reports them.')}'),
                ],
              ),
            ),
          BankPager(page: p, onPage: (n) => _load(page: n)),
          const BankInfoLine(
              'GST on the fee is an input credit for accounting. Fees are never estimated here.'),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Channels overview (what the till offers)
// ---------------------------------------------------------------------------

class _ChannelsView extends StatefulWidget {
  const _ChannelsView();

  @override
  State<_ChannelsView> createState() => _ChannelsViewState();
}

class _ChannelsViewState extends State<_ChannelsView> {
  List<PayChannel>? _rows;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await BankStore.instance.api.channels();
      if (!mounted) return;
      setState(() {
        _rows = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = bankError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BankInfoLine(
            'Payment channels are the active accounts the cashier can pick for each payment. A gateway shows under both UPI and Card. A bank account is never a channel.'),
        const SizedBox(height: 8),
        if (_loading && rows == null)
          const SkeletonRows(rows: 3)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (rows != null && rows.isEmpty)
          EmptyState(
              icon: 'card',
              title: gt('No channels'),
              copy: gt('Add an active cash, UPI or card account first.'))
        else if (rows != null)
          for (final mode in const ['CASH', 'UPI', 'CARD']) ...[
            if (rows.any((c) => c.mode == mode)) bankTitle(_modeLabel(mode)),
            for (final c in rows.where((c) => c.mode == mode))
              BankCard(
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: bankStyle(14, FontWeight.w800, AppColors.ink)),
                        Text(
                            [kindLabel(c.kind), c.provider, if (c.terminalId != null) c.terminalId!]
                                .join(' · '),
                            style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
                      ],
                    ),
                  ),
                  if (c.isDefault) bankPill(gt('Default'), tone: 'good'),
                ]),
              ),
          ],
        const SizedBox(height: 4),
        AppButton('Refresh',
            variant: BtnVariant.secondary, size: BtnSize.sm, onTap: _load),
      ],
    );
  }

  String _modeLabel(String m) =>
      m == 'CASH' ? gt('Cash') : (m == 'UPI' ? gt('UPI') : gt('Card'));
}
