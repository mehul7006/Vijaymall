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

/// Paytm machines master (`73-paytm-terminal.md`, "Machines master").
/// Built to the guide; never run against a real Paytm account.
class BankMachinesTab extends StatefulWidget {
  const BankMachinesTab({super.key});

  @override
  State<BankMachinesTab> createState() => _BankMachinesTabState();
}

class _BankMachinesTabState extends State<BankMachinesTab> {
  BankPage<TerminalView>? _page;
  int _pageNo = 0;
  bool _loading = true;
  String? _error;
  int _gen = 0;
  final Set<String> _busy = {};
  final Map<String, TerminalTestResult> _tests = {};

  @override
  void initState() {
    super.initState();
    BankStore.instance.loadAccounts().then((_) {
      if (mounted) setState(() {});
    });
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
      final r = await BankStore.instance.api.terminals(page: _pageNo, size: 20);
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

  Future<void> _edit([TerminalView? t]) async {
    final saved = await showAppSheet<TerminalView>(
      context: context,
      title: t == null ? 'Add a Paytm machine' : 'Edit machine',
      sub: 'Adding a machine also creates its card-machine account.',
      builder: (_) => _MachineForm(existing: t),
    );
    if (saved != null) {
      showToast(t == null ? 'Machine added' : 'Machine saved', 'success');
      BankStore.instance.loadAccounts(force: true);
      _load();
    }
  }

  Future<void> _deactivate(TerminalView t) async {
    final ok = await bankConfirm(context,
        title: 'Switch off this machine?',
        body: 'The machine and its account are switched off together. You can switch it on again by editing it.',
        confirmLabel: 'Switch off');
    if (!ok) return;
    setState(() => _busy.add(t.id));
    try {
      await BankStore.instance.api.deactivateTerminal(t.id);
      showToast('Machine switched off');
      BankStore.instance.loadAccounts(force: true);
      await _load();
    } catch (e) {
      showToast(bankError(e), 'error');
    }
    if (mounted) setState(() => _busy.remove(t.id));
  }

  Future<void> _activate(TerminalView t) async {
    setState(() => _busy.add(t.id));
    try {
      await BankStore.instance.api.updateTerminal(t.id, {
        'name': t.name,
        'active': true,
        if (t.settlesToAccountId != null) 'settlesToAccountId': t.settlesToAccountId,
      });
      showToast('Machine switched on');
      BankStore.instance.loadAccounts(force: true);
      await _load();
    } catch (e) {
      showToast(bankError(e), 'error');
    }
    if (mounted) setState(() => _busy.remove(t.id));
  }

  Future<void> _test(TerminalView t) async {
    if (_busy.contains(t.id)) return;
    setState(() => _busy.add(t.id));
    try {
      final r = await BankStore.instance.api.testTerminal(t.id);
      if (mounted) setState(() => _tests[t.id] = r);
    } catch (e) {
      showToast(bankError(e), 'error');
    }
    if (mounted) setState(() => _busy.remove(t.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton('Add machine', icon: 'plus', block: true, onTap: () => _edit()),
        const SizedBox(height: 8),
        const BankInfoLine(
            'Paytm credentials are on the Configuration screen. Test sends a harmless status call and never moves money. Not verified against a real Paytm account yet.'),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: AppLink('Open Paytm settings', onTap: () => go('/admin/system?tab=config')),
        ),
        const SizedBox(height: 12),
        if (_loading && p == null)
          const SkeletonRows(rows: 2)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (p != null && p.items.isEmpty)
          EmptyState(
              icon: 'card',
              title: gt('No Paytm machines yet'),
              copy: gt('Add the terminal id printed on the machine.'))
        else if (p != null) ...[
          for (final t in p.items) _card(t),
          BankPager(page: p, onPage: (n) => _load(page: n)),
        ],
      ],
    );
  }

  Widget _card(TerminalView t) {
    final busy = _busy.contains(t.id);
    final test = _tests[t.id];
    final bank = BankStore.instance.byId(t.settlesToAccountId)?.name;
    return BankCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(t.name,
                  style: bankStyle(14.5, FontWeight.w800, AppColors.ink)),
            ),
            bankPill(t.active ? gt('Active') : gt('Off'),
                tone: t.active ? 'good' : 'neutral'),
          ]),
          const SizedBox(height: 3),
          Text('${gt('Terminal id')} ${t.terminalId} · ${t.provider}',
              style: bankStyle(12, FontWeight.w700, AppColors.ink2)),
          if (bank != null)
            Text('${gt('Settles into')}: $bank',
                style: bankStyle(12, FontWeight.w600, AppColors.ink3)),
          if (test != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: test.ok ? AppColors.greenTint : AppColors.redTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${test.code}: ${test.message}',
                  style: bankStyle(12, FontWeight.w700,
                      test.ok ? AppColors.green : AppColors.red)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            AppButton('Test',
                size: BtnSize.xs,
                variant: BtnVariant.soft,
                loading: busy,
                onTap: busy ? null : () => _test(t)),
            AppButton('Edit',
                size: BtnSize.xs,
                variant: BtnVariant.secondary,
                onTap: busy ? null : () => _edit(t)),
            if (t.active)
              AppButton('Switch off',
                  size: BtnSize.xs,
                  variant: BtnVariant.secondary,
                  onTap: busy ? null : () => _deactivate(t))
            else
              AppButton('Switch on',
                  size: BtnSize.xs,
                  variant: BtnVariant.secondary,
                  onTap: busy ? null : () => _activate(t)),
          ]),
        ],
      ),
    );
  }
}

class _MachineForm extends StatefulWidget {
  final TerminalView? existing;
  const _MachineForm({this.existing});

  @override
  State<_MachineForm> createState() => _MachineFormState();
}

class _MachineFormState extends State<_MachineForm> {
  late String _tid = widget.existing?.terminalId ?? '';
  late String _name = widget.existing?.name ?? '';
  late bool _active = widget.existing?.active ?? true;
  late String? _bank = widget.existing?.settlesToAccountId;
  final Map<String, String> _err = {};
  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    final e = <String, String>{};
    if (widget.existing == null) {
      final t = _tid.trim();
      if (t.isEmpty) {
        e['terminalId'] = gt('Enter the terminal id');
      } else if (!RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(t)) {
        e['terminalId'] = gt('The terminal id is exactly 8 letters or digits');
      }
    }
    final n = Validators.text(_name, label: 'Name', required: true, max: 60);
    if (n != null) e['name'] = gt(n);
    if (e.isNotEmpty) {
      setState(() => _err
        ..clear()
        ..addAll(e));
      return;
    }
    setState(() {
      _busy = true;
      _err.clear();
    });
    try {
      final api = BankStore.instance.api;
      final saved = widget.existing == null
          ? await api.createTerminal({
              'terminalId': _tid.trim(),
              'name': _name.trim(),
              'active': _active,
              if (_bank != null) 'settlesToAccountId': _bank,
            })
          : await api.updateTerminal(widget.existing!.id, {
              'name': _name.trim(),
              'active': _active,
              if (_bank != null) 'settlesToAccountId': _bank,
            });
      if (mounted) Navigator.of(context).pop(saved);
    } catch (ex) {
      if (!mounted) return;
      final f = ex is ApiException ? ex.fields : const <String, String>{};
      setState(() {
        _busy = false;
        for (final k in ['terminalId', 'name', 'settlesToAccountId']) {
          final m = ApiException.fieldError(f, [k]);
          if (m != null) _err[k] = m;
        }
        if (ex is ApiException && ex.code == 'DUPLICATE_TERMINAL') {
          _err['terminalId'] = gt('This machine is already added');
        }
      });
      showToast(bankError(ex), 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = BankStore.instance.active(const ['BANK']);
    final bankName = BankStore.instance.byId(_bank)?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldRow(
          children: [
            AppField(
                label: 'Terminal id',
                value: _tid,
                maxLength: 20,
                readOnly: widget.existing != null,
                placeholder: 'AB12CD34',
                error: _err['terminalId'],
                onChanged: (v) => _tid = v),
            AppField(
                label: 'Machine name',
                value: _name,
                maxLength: 60,
                placeholder: 'Counter 1',
                error: _err['name'],
                onChanged: (v) => _name = v),
          ],
        ),
        if (widget.existing != null)
          const BankInfoLine('The terminal id cannot change.'),
        bankGap(10),
        SelectField(
          label: 'Settles into (bank)',
          value: bankName,
          placeholder: gt('None'),
          onTap: () async {
            final k = await pickBankOption(context,
                title: 'Settles into',
                selected: _bank ?? '',
                options: [('', gt('None')), for (final b in banks) (b.id, b.name)]);
            if (k != null) setState(() => _bank = k.isEmpty ? null : k);
          },
        ),
        if (_err['settlesToAccountId'] != null)
          BankNote(_err['settlesToAccountId']!, error: true),
        bankGap(10),
        Row(children: [
          AppSwitch(value: _active, onChanged: (v) => setState(() => _active = v)),
          const SizedBox(width: 10),
          Text(gt('Active'), style: bankStyle(13, FontWeight.w700, AppColors.ink)),
        ]),
        bankGap(16),
        AppButton(widget.existing == null ? 'Add machine' : 'Save machine',
            block: true, loading: _busy, onTap: _busy ? null : _save),
        const SizedBox(height: 8),
      ],
    );
  }
}
