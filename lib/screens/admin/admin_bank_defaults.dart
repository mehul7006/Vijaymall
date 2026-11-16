import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto_ops.dart';
import '../../data/bank_store.dart';
import '../../data/validators.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import 'admin_bank_common.dart';

/// Config keys that hold a money account id, with the account kinds that make
/// sense for each (`P4` section 3.3).
/// Online gateways the server registers (`PaymentGateway` adapters).
const knownGateways = ['razorpay'];

class BankSettingKeys {
  BankSettingKeys._();

  static const Map<String, List<String>> accountKinds = {
    'pos.defaultAccount.CASH': ['CASH'],
    'pos.defaultAccount.UPI': ['UPI', 'GATEWAY'],
    'pos.defaultAccount.CARD': ['CARD_TERMINAL', 'GATEWAY'],
    'payment.gatewayAccountId': ['GATEWAY'],
  };

  static List<String>? kindsFor(String key) => accountKinds[key];

  /// Every key this module edits.
  static const all = [
    'pos.defaultAccount.CASH',
    'pos.defaultAccount.UPI',
    'pos.defaultAccount.CARD',
    'payment.gatewayAccountId',
    'payment.onlineProvider',
    'payment.settlementDays',
    'pos.terminalProvider',
  ];
}

/// Account chooser for a config key: lists ACTIVE accounts of the right kind,
/// "None" sends an empty value. Used on the bank "Defaults" tab and in the
/// generic configuration screen.
class AccountSettingField extends StatefulWidget {
  final String label;
  final String settingKey;
  final String value;
  final ValueChanged<String> onChanged;
  final String? help;
  final String? error;

  const AccountSettingField({
    super.key,
    required this.label,
    required this.settingKey,
    required this.value,
    required this.onChanged,
    this.help,
    this.error,
  });

  @override
  State<AccountSettingField> createState() => _AccountSettingFieldState();
}

class _AccountSettingFieldState extends State<AccountSettingField> {
  @override
  void initState() {
    super.initState();
    BankStore.instance.loadAccounts().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = BankStore.instance;
    final kinds = BankSettingKeys.kindsFor(widget.settingKey) ?? const <String>[];
    final options = store.active(kinds);
    final cur = store.byId(widget.value);
    String shown = '';
    String? warn;
    if (widget.value.isNotEmpty) {
      if (cur == null) {
        shown = widget.value;
        if (store.accountsLoaded) {
          warn = gt('This account no longer exists. It is ignored at use time.');
        }
      } else {
        shown = cur.name;
        if (!cur.active) {
          warn = gt('This account is switched off. It is ignored until switched on.');
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectField(
          label: widget.label,
          value: shown,
          placeholder: gt('None'),
          onTap: () async {
            final k = await pickBankOption(context,
                title: widget.label,
                selected: widget.value,
                options: [
                  ('', gt('None')),
                  for (final a in options) (a.id, '${a.name} · ${kindLabel(a.kind)}'),
                ]);
            if (k != null) widget.onChanged(k);
          },
        ),
        if (widget.error != null) BankNote(widget.error!, error: true),
        if (warn != null) BankNote(warn, error: true),
        if (widget.help != null && widget.help!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(widget.help!,
                style: bankStyle(11, FontWeight.w600, AppColors.ink3)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "Payments and bank" defaults tab
// ---------------------------------------------------------------------------

class BankDefaultsTab extends StatefulWidget {
  const BankDefaultsTab({super.key});

  @override
  State<BankDefaultsTab> createState() => _BankDefaultsTabState();
}

class _BankDefaultsTabState extends State<BankDefaultsTab> {
  final Map<String, ConfigItemDto> _items = {};
  final Map<String, String> _edits = {};
  final Map<String, String> _err = {};
  bool _loading = true;
  bool _saving = false;
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
      final v = await Api.instance.ops.getConfig();
      if (!mounted) return;
      setState(() {
        _items.clear();
        for (final g in v.groups) {
          for (final i in g.items) {
            if (BankSettingKeys.all.contains(i.key)) _items[i.key] = i;
          }
        }
        _edits.clear();
        _err.clear();
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

  String _val(String key) => _edits[key] ?? _items[key]?.value ?? '';

  void _set(String key, String v) {
    setState(() {
      if (v == (_items[key]?.value ?? '')) {
        _edits.remove(key);
      } else {
        _edits[key] = v;
      }
      _err.remove(key);
    });
  }

  bool _check() {
    final e = <String, String>{};
    final prov = Validators.text(_val('payment.onlineProvider'), label: 'Provider', max: 40);
    if (prov != null) {
      e['payment.onlineProvider'] = gt(prov);
    } else if (_val('payment.onlineProvider').isNotEmpty &&
        !knownGateways.contains(_val('payment.onlineProvider').toLowerCase())) {
      // The server would save it and silently use its default gateway.
      e['payment.onlineProvider'] =
          gt('Not a known gateway. Use razorpay or leave blank for the server default.');
    }
    final term = Validators.text(_val('pos.terminalProvider'), label: 'Provider', max: 40);
    if (term != null) e['pos.terminalProvider'] = gt(term);
    final d = Validators.whole(_val('payment.settlementDays'),
        label: 'Days', required: true, min: 0, max: 30);
    if (d != null) e['payment.settlementDays'] = gt(d);
    setState(() => _err
      ..clear()
      ..addAll(e));
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (_saving || _edits.isEmpty || !_check()) return;
    setState(() => _saving = true);
    try {
      ApiException.clearFields();
      await Api.instance.ops.saveConfig(Map.of(_edits));
      showToast('Saved', 'success');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        for (final en in e.fields.entries) {
          _err[en.key] = en.value;
        }
      });
      showToast(bankError(e), 'error');
    } catch (e) {
      showToast(bankError(e), 'error');
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _account(String key, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AccountSettingField(
          label: label,
          settingKey: key,
          value: _val(key),
          error: _err[key],
          help: _items[key]?.help,
          onChanged: (v) => _set(key, v),
        ),
      );

  Widget _text(String key, String label,
      {List<String> suggestions = const [], bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            label: label,
            value: _val(key),
            maxLength: numeric ? 2 : 40,
            numeric: numeric,
            error: _err[key],
            onChanged: (v) => _set(key, v.trim()),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final s in suggestions)
                AppChip(s.isEmpty ? gt('Server default') : s,
                    small: true, selected: _val(key) == s, onTap: () => _set(key, s)),
            ]),
          ],
          if ((_items[key]?.help ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_items[key]!.help,
                  style: bankStyle(11, FontWeight.w600, AppColors.ink3)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const SkeletonRows(rows: 4);
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardPanel(
          title: gt('Which account gets the money'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BankInfoLine(
                  'Used when the till names no account. A saved account that is later switched off is ignored (the line becomes Unassigned), it is not an error.'),
              const SizedBox(height: 8),
              _account('pos.defaultAccount.CASH', 'Cash default'),
              _account('pos.defaultAccount.UPI', 'UPI default'),
              _account('pos.defaultAccount.CARD', 'Card default'),
              _account('payment.gatewayAccountId', 'Online payments account'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Online gateway and machines'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text('payment.onlineProvider', 'Online payment gateway',
                  suggestions: const ['', 'razorpay']),
              if (_val('payment.onlineProvider').isNotEmpty &&
                  _val('payment.onlineProvider').toLowerCase() != 'razorpay')
                const BankNote(
                    'Only razorpay is a registered gateway today. Another code saves but falls back to the server default.'),
              _text('payment.settlementDays', 'Settlement cycle (days, 0 to 30)', numeric: true),
              _text('pos.terminalProvider', 'Default card-machine adapter',
                  suggestions: const ['manual', 'paytm']),
              const BankInfoLine(
                  'The channel the cashier picks decides the machine. This default is only for a channel whose provider has no adapter.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(_edits.isEmpty ? 'No changes' : 'Save ${_edits.length} change(s)',
            block: true,
            loading: _saving,
            disabled: _edits.isEmpty,
            onTap: _save),
        const SizedBox(height: 8),
        const BankInfoLine(
            'Paytm and Razorpay keys are on the Configuration screen, in their own groups.'),
      ],
    );
  }
}
