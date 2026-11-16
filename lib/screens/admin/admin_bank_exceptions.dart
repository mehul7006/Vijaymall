import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/bank_dto.dart';
import '../../data/bank_store.dart';
import '../../data/validators.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_bank_common.dart';

String _kindText(String k) {
  switch (k) {
    case 'OVERDUE_UNSETTLED':
      return gt('Overdue, not settled');
    case 'UNMATCHED_ITEM':
      return gt('Unmatched line');
    case 'AMOUNT_MISMATCH':
      return gt('Amount differs');
  }
  return k;
}

// ---------------------------------------------------------------------------
// Exceptions queue
// ---------------------------------------------------------------------------

class BankExceptionsTab extends StatefulWidget {
  const BankExceptionsTab({super.key});

  @override
  State<BankExceptionsTab> createState() => _BankExceptionsTabState();
}

class _BankExceptionsTabState extends State<BankExceptionsTab> {
  String _status = 'OPEN';
  String _kind = '';
  BankPage<SettlementException>? _page;
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
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _pageNo = page;
    });
    try {
      final r = await BankStore.instance.api
          .exceptions(status: _status, kind: _kind, page: _pageNo, size: 20);
      if (!mounted || gen != _gen) return;
      if (_status == 'OPEN' && _kind.isEmpty) BankStore.instance.setBadge(r.total);
      setState(() {
        _page = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e);
        _loading = false;
      });
    }
  }

  void _filter(VoidCallback f) {
    setState(f);
    _pageNo = 0;
    _load();
  }

  Future<void> _resolve(SettlementException x) async {
    final done = await showAppSheet<bool>(
      context: context,
      title: 'Resolve this problem',
      sub: 'Resolving only closes it. Fix the data first (for example import the right statement) if the numbers must change.',
      builder: (_) => _ResolveForm(item: x),
    );
    if (done == true) {
      showToast('Marked as resolved', 'success');
      _load();
      BankStore.instance.refreshBadge();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipRail(children: [
          for (final s in const [('OPEN', 'Open'), ('RESOLVED', 'Resolved')])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(s.$2,
                  selected: _status == s.$1, onTap: () => _filter(() => _status = s.$1)),
            ),
        ]),
        const SizedBox(height: 8),
        ChipRail(children: [
          for (final k in const ['', 'OVERDUE_UNSETTLED', 'UNMATCHED_ITEM', 'AMOUNT_MISMATCH'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(k.isEmpty ? gt('All kinds') : _kindText(k),
                  small: true, selected: _kind == k, onTap: () => _filter(() => _kind = k)),
            ),
        ]),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 3)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
              icon: 'check',
              title: gt('Nothing needs attention'),
              copy: gt(_status == 'OPEN'
                  ? 'Every settlement line and payment adds up.'
                  : 'No resolved problems in this filter.'))
        else if (p != null) ...[
          ResultSummary('${p.totalText} ${gt(p.total == 1 ? 'problem' : 'problems')}'),
          for (final x in p.items) _card(x),
          BankPager(page: p, onPage: (n) => _load(page: n)),
        ],
      ],
    );
  }

  Widget _card(SettlementException x) {
    return BankCard(
      alert: x.status == 'OPEN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(_kindText(x.kind),
                  style: bankStyle(14, FontWeight.w800, AppColors.ink)),
            ),
            bankPill(x.status == 'OPEN' ? gt('Open') : gt('Resolved'),
                tone: x.status == 'OPEN' ? 'bad' : 'good'),
          ]),
          const SizedBox(height: 3),
          Text('${bankWhen(x.createdAt)}${x.reference == null ? '' : ' · ${x.reference}'}',
              style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
          if (x.expectedPaise != null || x.actualPaise != null) ...[
            const SizedBox(height: 6),
            if (x.expectedPaise != null) BankKv('Our amount', bankMoney(x.expectedPaise!)),
            if (x.actualPaise != null) BankKv('Provider amount', bankMoney(x.actualPaise!)),
          ],
          if (x.note != null) ...[
            const SizedBox(height: 4),
            Text('${gt('Note')}: ${x.note}',
                style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
          ],
          if (x.resolvedAt != null)
            Text('${gt('Resolved')} ${bankWhen(x.resolvedAt)}',
                style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (x.settlementId != null)
              AppButton('Open settlement',
                  size: BtnSize.xs,
                  variant: BtnVariant.soft,
                  onTap: () =>
                      go('/admin/bank?tab=settlements&settlement=${x.settlementId}')),
            if (x.kind == 'OVERDUE_UNSETTLED')
              AppButton('See unsettled',
                  size: BtnSize.xs,
                  variant: BtnVariant.soft,
                  onTap: () => go('/admin/bank?tab=unsettled')),
            if (x.status == 'OPEN')
              AppButton('Resolve', size: BtnSize.xs, onTap: () => _resolve(x)),
          ]),
        ],
      ),
    );
  }
}

class _ResolveForm extends StatefulWidget {
  final SettlementException item;
  const _ResolveForm({required this.item});

  @override
  State<_ResolveForm> createState() => _ResolveFormState();
}

class _ResolveFormState extends State<_ResolveForm> {
  String _note = '';
  String? _err;
  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    final v = Validators.text(_note, label: 'Note', required: true, max: 300);
    if (v != null) {
      setState(() => _err = gt(v));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await BankStore.instance.api
          .resolveException(widget.item.id, _note.trim());
      // Resolved twice (another admin first): the server returns the first note.
      if (r.note != null && r.note != _note.trim()) {
        showToast('${gt('Already resolved by someone else. Note')}: ${r.note}', 'info');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is ApiException) _err = ApiException.fieldError(e.fields, ['note']);
      });
      showToast(bankError(e), 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_kindText(widget.item.kind),
            style: bankStyle(13.5, FontWeight.w800, AppColors.ink)),
        if (widget.item.reference != null)
          Text(widget.item.reference!,
              style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
        bankGap(),
        AppField(
            label: 'What was done (note)',
            value: _note,
            maxLength: 300,
            placeholder: gt('For example paid by cash, matched by hand'),
            error: _err,
            onChanged: (v) => _note = v),
        bankGap(16),
        AppButton('Mark as resolved', block: true, loading: _busy, onTap: _busy ? null : _save),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Unsettled report
// ---------------------------------------------------------------------------

class BankUnsettledTab extends StatefulWidget {
  const BankUnsettledTab({super.key});

  @override
  State<BankUnsettledTab> createState() => _BankUnsettledTabState();
}

class _BankUnsettledTabState extends State<BankUnsettledTab> {
  bool _overdueOnly = false;
  BankPage<UnsettledItem>? _page;
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
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _pageNo = page;
    });
    try {
      final r = await BankStore.instance.api
          .unsettled(overdueOnly: _overdueOnly, page: _pageNo, size: 20);
      if (!mounted || gen != _gen) return;
      setState(() {
        _page = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = bankError(e);
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
        const BankInfoLine(
            'Money received but not yet reported in any settlement, oldest first. Expected day = received + the settlement cycle (Config: payment.settlementDays).'),
        const SizedBox(height: 8),
        Row(children: [
          AppSwitch(
              value: _overdueOnly,
              onChanged: (v) {
                _overdueOnly = v;
                _pageNo = 0;
                _load();
              }),
          const SizedBox(width: 10),
          Text(gt('Overdue only'),
              style: bankStyle(12.5, FontWeight.w700, AppColors.ink2)),
        ]),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 3)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
              icon: 'check',
              title: gt('Everything received is settled'),
              copy: gt('Nothing is waiting for a payout.'))
        else if (p != null) ...[
          ResultSummary('${p.totalText} ${gt('waiting')}'),
          for (final u in p.items)
            BankCard(
              alert: u.overdue,
              onTap: u.source == 'ONLINE' ? () => go('/admin/order/${u.reference}') : null,
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.reference,
                          style: bankStyle(14, FontWeight.w800, AppColors.ink)),
                      const SizedBox(height: 3),
                      Text(
                          '${u.source == 'ONLINE' ? gt('Online order') : gt('Counter bill')} · ${u.accountName ?? gt('Unassigned')}',
                          style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
                      Text(
                          '${gt('Received')} ${bankWhen(u.receivedAt)} · ${gt('expected by')} ${bankDay(u.expectedBy)}',
                          style: bankStyle(11.5, FontWeight.w600, AppColors.ink3)),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(bankMoney(u.amountPaise),
                      style: bankStyle(14.5, FontWeight.w800, AppColors.ink)),
                  if (u.overdue) bankPill(gt('Overdue'), tone: 'bad'),
                ]),
              ]),
            ),
          BankPager(page: p, onPage: (n) => _load(page: n)),
        ],
      ],
    );
  }
}
