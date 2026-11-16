import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/confirm.dart';
import '../../widgets/toast.dart';
import '../../data/validators.dart';
import '../../state/gu_strings.dart';

/// `#/admin/coins` — coin settings + coin earning rules (inline editor).
class AdminCoinRulesScreen extends StatelessWidget {
  const AdminCoinRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CoinRulesBody();
  }
}

class _CoinRulesBody extends StatefulWidget {
  const _CoinRulesBody();

  @override
  State<_CoinRulesBody> createState() => _CoinRulesBodyState();
}

class _CoinRulesBodyState extends State<_CoinRulesBody> {
  String _coinValue = '';
  String _maxPercent = '';
  String _expiryMonths = '';
  bool _loaded = false;

  bool _editing = false;
  String? _editingId;
  String _rName = '';
  String _rSpend = '1000';
  String _rCoins = '10';
  String _rMode = 'pro-rata';
  String _rStarts = '';
  String _rExpires = '';
  bool _rActive = true;
  Map<String, String> _rErr = const {};
  Map<String, String> _sErr = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final s = StateScope.read(context).coinSettings;
    _coinValue = s.coinValue.toString();
    _maxPercent = s.maxPercent.toString();
    _expiryMonths = s.expiryMonths.toString();
  }

  Future<void> _saveSettings() async {
    final state = StateScope.read(context);
    final e = <String, String>{};
    final cvMsg = Validators.rupees(_coinValue,
        label: 'Coin value', required: true, min: 0.01, max: 1000000);
    if (cvMsg != null) e['coinValue'] = gt(cvMsg);
    final mpMsg = Validators.whole(_maxPercent,
        label: 'Maximum percent', required: true, min: 0, max: 100);
    if (mpMsg != null) e['maxPercent'] = gt(mpMsg);
    final emMsg = Validators.whole(_expiryMonths,
        label: 'Expiry', required: true, min: 1, max: 120);
    if (emMsg != null) e['expiry'] = gt(emMsg);
    setState(() => _sErr = e);
    if (e.isNotEmpty) return;
    final err = await state.saveCoinSettings(
      coinValue: num.tryParse(_coinValue.trim()) ?? 0,
      // An unreadable/blank share keeps the saved one instead of becoming 0
      // (0 now means "no coin redemption").
      maxPercent:
          int.tryParse(_maxPercent.trim()) ?? state.coinSettings.maxPercent,
      expiryMonths: int.tryParse(_expiryMonths.trim()) ?? 0,
    );
    if (!mounted) return;
    // Re-sync the fields with the values actually stored (the clamped ones,
    // or the server's when it refused).
    final saved = state.coinSettings;
    setState(() {
      _coinValue = saved.coinValue.toString();
      _maxPercent = saved.maxPercent.toString();
      _expiryMonths = saved.expiryMonths.toString();
    });
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(gt('Coin settings saved'));
  }

  void _startNew() {
    setState(() {
      _editing = true;
      _editingId = null;
      _rName = '';
      _rSpend = '1000';
      _rCoins = '10';
      _rMode = 'pro-rata';
      _rStarts = '';
      _rExpires = '';
      _rActive = true;
      _rErr = const {};
    });
  }

  void _editRule(CoinRule r) {
    setState(() {
      _editing = true;
      _editingId = r.id;
      _rName = r.name;
      _rSpend = r.spend.toString();
      _rCoins = r.coins.toString();
      _rMode = r.mode;
      _rStarts = r.starts;
      _rExpires = r.expires;
      _rActive = r.active;
      _rErr = const {};
    });
  }

  void _closeEditor() {
    setState(() {
      _editing = false;
      _editingId = null;
    });
  }

  static final _dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  Map<String, String> _validateRule() {
    final e = <String, String>{};
    final n = Validators.text(_rName,
        label: 'Rule name', required: true, min: 2, max: 80);
    if (n != null) e['name'] = gt(n);
    final sp = Validators.whole(_rSpend,
        label: 'Spend', required: true, min: 1, max: 1000000);
    if (sp != null) e['spend'] = gt(sp);
    final c = Validators.whole(_rCoins,
        label: 'Coins', required: true, min: 1, max: 100000);
    if (c != null) e['coins'] = gt(c);
    for (final (key, val) in [('starts', _rStarts), ('expires', _rExpires)]) {
      final t = val.trim();
      if (t.isEmpty) continue;
      if (!_dayRe.hasMatch(t) || DateTime.tryParse(t) == null) {
        e[key] = gt('Use the date format yyyy-MM-dd');
      }
    }
    if (!e.containsKey('starts') &&
        !e.containsKey('expires') &&
        _rStarts.trim().isNotEmpty &&
        _rExpires.trim().isNotEmpty &&
        _rExpires.trim().compareTo(_rStarts.trim()) < 0) {
      e['expires'] = gt('The end date must be after the start date');
    }
    return e;
  }

  Future<void> _saveRule() async {
    final state = StateScope.read(context);
    final ve = _validateRule();
    setState(() => _rErr = ve);
    if (ve.isNotEmpty) return;
    if (_rActive) {
      final others = state.coinRules
          .where((r) => r.active && r.id != _editingId)
          .toList();
      if (others.isNotEmpty) {
        final ok = await confirmAction(
          context,
          title: 'Switch on this rule?',
          body:
              '${gt('Only one coin rule can be on at a time. This switches off')}: ${others.map((r) => r.name).join(', ')}.',
          confirmLabel: 'Switch on',
        );
        if (!ok || !mounted) return;
        await state.deactivateOtherRules(_editingId);
        if (!mounted) return;
      }
    }
    final draft = CoinRule(
      id: _editingId ?? '',
      name: _rName,
      spend: int.tryParse(_rSpend.trim()) ?? 0,
      coins: int.tryParse(_rCoins.trim()) ?? 0,
      mode: _rMode,
      scope: 'All items',
      active: _rActive,
      starts: _rStarts.trim(),
      expires: _rExpires.trim(),
      everGreen: _rStarts.trim().isEmpty && _rExpires.trim().isEmpty,
    );
    final err = state.saveRule(draft, existingId: _editingId);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    final sync = state.ruleSync;
    if (sync != null) {
      final serverErr = await sync;
      if (!mounted) return;
      if (serverErr != null) {
        showToast(serverErr, 'error');
        return;
      }
    }
    showToast(gt('Coin rule saved'));
    _closeEditor();
  }

  /// Radio-style: switching a rule on switches the others off (confirmed).
  Future<void> _toggle(AppState state, CoinRule r, bool on) async {
    if (!on) {
      state.toggleRule(r.id);
      return;
    }
    final others =
        state.coinRules.where((x) => x.active && x.id != r.id).toList();
    if (others.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Switch on this rule?',
        body:
            '${gt('Only one coin rule can be on at a time. This switches off')}: ${others.map((x) => x.name).join(', ')}.',
        confirmLabel: 'Switch on',
      );
      if (!ok || !mounted) return;
      await state.deactivateOtherRules(r.id);
    }
    if (!r.active) state.toggleRule(r.id);
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _editor() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingId == null ? 'Add rule' : 'Edit rule',
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          AppField(
            label: gt('Rule name'),
            value: _rName,
            maxLength: 80,
            error: _rErr['name'],
            placeholder: gt('Weekend bonus'),
            onChanged: (v) => setState(() => _rName = v),
          ),
          const SizedBox(height: 10),
          FieldRow(
            children: [
              AppField(
                label: gt('Spend (₹)'),
                value: _rSpend,
                error: _rErr['spend'],
                numeric: true,
                placeholder: '1000',
                onChanged: (v) => setState(() => _rSpend = v),
              ),
              AppField(
                label: gt('Coins'),
                value: _rCoins,
                error: _rErr['coins'],
                numeric: true,
                placeholder: '10',
                onChanged: (v) => setState(() => _rCoins = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _label('Mode'),
          const SizedBox(height: 7),
          Segmented(
            options: const [
              SegmentOption('pro-rata', 'Pro-rata'),
              SegmentOption('slab', 'Slab'),
            ],
            value: _rMode,
            onChanged: (v) => setState(() => _rMode = v),
          ),
          const SizedBox(height: 10),
          FieldRow(
            children: [
              AppField(
                label: gt('Starts'),
                value: _rStarts,
                error: _rErr['starts'],
                placeholder: gt('yyyy-MM-dd'),
                onChanged: (v) => setState(() => _rStarts = v),
              ),
              AppField(
                label: gt('Expires'),
                value: _rExpires,
                error: _rErr['expires'],
                placeholder: gt('yyyy-MM-dd'),
                onChanged: (v) => setState(() => _rExpires = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _switchRow('Active (only one rule can be on)', _rActive,
              (v) => setState(() => _rActive = v)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton('Save rule', block: true, onTap: _saveRule),
              ),
              const SizedBox(width: 10),
              AppButton(
                'Cancel',
                variant: BtnVariant.secondary,
                onTap: _closeEditor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(AppState state, CoinRule r, {required bool divider}) {
    final status = state.ruleWindowStatus(r);
    final Widget pill = switch (status) {
      'active' => Pill.active('Active'),
      'scheduled' => Pill.low('Scheduled'),
      'expired' => Pill.out('Expired'),
      _ => Pill.out('Paused'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: divider ? AppColors.line : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    pill,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${r.spend} → ${r.coins} coins',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 7),
                AppChip(
                  r.mode == 'slab' ? 'Slab' : 'Pro-rata',
                  selected: false,
                  small: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              AppSwitch(
                value: r.active,
                onChanged: (v) => _toggle(state, r, v),
              ),
              const SizedBox(height: 6),
              IconBtn(
                'edit',
                size: 38,
                iconSize: 16,
                onTap: () => _editRule(r),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wideRule(AppState state, CoinRule r, {required bool last}) {
    final status = state.ruleWindowStatus(r);
    final (String lbl, Color fg, Color bg) = switch (status) {
      'active' => ('Active', AppColors.green, AppColors.greenTint),
      'scheduled' => ('Scheduled', AppColors.goldInk, AppColors.goldTint),
      'expired' => ('Expired', AppColors.red3, AppColors.redTint),
      _ => ('Paused', AppColors.ink2, AppColors.bg),
    };
    const t = TextStyle(
        fontFamily: AppTheme.uiFont, fontSize: 12.5, color: AppColors.ink2);
    return TableRowShell(
      last: last,
      semanticLabel: r.name,
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Text(r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ),
        Expanded(
            flex: 3,
            child: Text('₹${r.spend} → ${r.coins} coins',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t)),
        Expanded(
            flex: 2,
            child: Text(gt(r.mode == 'slab' ? 'Slab' : 'Pro-rata'),
                maxLines: 1, style: t)),
        Expanded(
          flex: 2,
          child: Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(gt(lbl), fg: fg, bg: bg)),
        ),
        SizedBox(
          width: 112,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppSwitch(
                  value: r.active, onChanged: (v) => _toggle(state, r, v)),
              const SizedBox(width: 8),
              IconBtn('edit', size: 38, iconSize: 16, onTap: () => _editRule(r)),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final rules = state.coinRules;
    final nActive =
        rules.where((r) => state.ruleWindowStatus(r) == 'active').length;
    final nScheduled =
        rules.where((r) => state.ruleWindowStatus(r) == 'scheduled').length;
    final wide = MediaQuery.of(context).size.width >= 860;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Rewards'),
                  sub: '${state.coinSettings.coinValue}₹ per coin · ${state.coinRules.length} rules',
                  bell: false,
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KpiGrid([
                        KpiCard(
                          icon: 'bolt',
                          tint: AppColors.green,
                          bg: AppColors.greenTint,
                          label: gt('Active rules'),
                          value: '$nActive',
                        ),
                        KpiCard(
                          icon: 'clock',
                          tint: AppColors.goldInk,
                          bg: AppColors.goldTint,
                          label: gt('Scheduled rules'),
                          value: '$nScheduled',
                        ),
                        KpiCard(
                          icon: 'coin',
                          tint: AppColors.navy2,
                          bg: AppColors.navyTint,
                          label: gt('Total rules'),
                          value: '${rules.length}',
                        ),
                      ]),
                      const SizedBox(height: 12),
                      CardPanel(
                        title: gt('Coin settings'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldRow(
                              minWidth: 420,
                              children: [
                                AppField(
                                  label: gt('Coin value (₹ per coin)'),
                                  value: _coinValue,
                                  error: _sErr['coinValue'],
                                  numeric: true,
                                  onChanged: (v) => setState(() => _coinValue = v),
                                ),
                                AppField(
                                  label: gt('Maximum percent of bill'),
                                  value: _maxPercent,
                                  error: _sErr['maxPercent'],
                                  numeric: true,
                                  onChanged: (v) => setState(() => _maxPercent = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Expiry (months)'),
                              value: _expiryMonths,
                              error: _sErr['expiry'],
                              numeric: true,
                              onChanged: (v) =>
                                  setState(() => _expiryMonths = v),
                            ),
                            const SizedBox(height: 14),
                            AppButton(
                              'Save coin settings',
                              block: true,
                              onTap: _saveSettings,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_editing) ...[
                        _editor(),
                      ],
                      if (rules.isEmpty && !_editing)
                        const CardPanel(
                          child: Hint('No coin rules yet. Tap Add rule to create one.'),
                        )
                      else if (wide && rules.isNotEmpty)
                        TableCard(
                          header: const TableHeadRow([
                            TableCol('Rule', 4),
                            TableCol('Earn', 3),
                            TableCol('Mode', 2),
                            TableCol('Status', 2),
                          ], trailing: 112),
                          rows: [
                            for (var i = 0; i < rules.length; i++)
                              _wideRule(state, rules[i],
                                  last: i == rules.length - 1),
                          ],
                        )
                      else if (rules.isNotEmpty)
                        CardPanel(
                          title: gt('Coin rules'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < rules.length; i++)
                                _ruleRow(
                                  state,
                                  rules[i],
                                  divider: i < rules.length - 1,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      AppButton(
                        'Add rule',
                        variant: BtnVariant.secondary,
                        icon: 'plus',
                        block: true,
                        onTap: _startNew,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'coins'),
          ],
        ),
      ),
    );
  }
}
