import 'package:flutter/material.dart';

import '../data/ist.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';
import 'controls.dart';

/// A report period: `week` (7 days), `month` (30), `quarter` (90), all ending
/// today in shop time, or `custom` with explicit `from`/`to` (`yyyy-MM-dd`,
/// both days included). The backend: `from` wins over `period`, a range over
/// 366 days (93 for the audit log) is a 400 on `to`.
class PeriodSel {
  const PeriodSel(this.period, [this.from, this.to]);

  final String period;
  final String? from;
  final String? to;

  bool get custom => period == 'custom';

  /// Query values for the API: `period` for the presets, `from`/`to` custom.
  String? get apiPeriod => custom ? null : period;
  String? get apiFrom => custom ? from : null;
  String? get apiTo => custom ? to : null;

  /// Stable key to rebuild a loader when the selection changes.
  String get key => custom ? 'c|$from|$to' : period;
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

DateTime? _parseYmd(String? s) {
  if (s == null || s.length != 10) return null;
  return DateTime.tryParse(s);
}

/// Period chips (7 / 30 / 90 days / custom range) with From and To date
/// buttons. The range is checked here (To not before From, at most [maxDays]
/// days, both ends included) and only a valid range is reported through
/// [onChanged]. [error] shows the server's `fields.to` message under the
/// dates.
class PeriodPicker extends StatefulWidget {
  const PeriodPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxDays = 366,
    this.error,
  });

  final PeriodSel value;
  final ValueChanged<PeriodSel> onChanged;
  final int maxDays;
  final String? error;

  @override
  State<PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<PeriodPicker> {
  DateTime? _from;
  DateTime? _to;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _from = _parseYmd(widget.value.from);
    _to = _parseYmd(widget.value.to);
  }

  DateTime get _today {
    final n = istNow();
    return DateTime(n.year, n.month, n.day);
  }

  String? _check(DateTime? from, DateTime? to) {
    if (from == null) return gt('Choose the From date');
    if (to == null) return gt('Choose the To date');
    if (to.isBefore(from)) return gt('To must not be before From');
    final days = to.difference(from).inDays + 1;
    if (days > widget.maxDays) {
      return '${gt('The range is limited to')} ${widget.maxDays} ${gt('days')}';
    }
    return null;
  }

  void _emit() {
    final e = _check(_from, _to);
    setState(() => _localError = e);
    if (e == null) {
      widget.onChanged(PeriodSel('custom', ymd(_from!), ymd(_to!)));
    }
  }

  Future<void> _pick(bool isFrom) async {
    final initial = (isFrom ? _from : _to) ?? _today;
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(_today) ? _today : initial,
      firstDate: DateTime(2020),
      lastDate: _today,
    );
    if (d == null || !mounted) return;
    setState(() => isFrom ? _from = d : _to = d);
    _emit();
  }

  void _preset(String p) {
    setState(() => _localError = null);
    widget.onChanged(PeriodSel(p));
  }

  void _custom() {
    if (widget.value.custom) return;
    final t = _today;
    _from ??= t.subtract(const Duration(days: 29));
    _to ??= t;
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.value;
    final err = _localError ?? widget.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipRail(children: [
          for (final p in const ['week', 'month', 'quarter'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(
                  gt(p == 'week'
                      ? '7 days'
                      : p == 'month'
                          ? '30 days'
                          : '90 days'),
                  small: true,
                  selected: sel.period == p,
                  onTap: () => _preset(p)),
            ),
          AppChip(gt('Custom range'),
              small: true, selected: sel.custom, onTap: _custom),
        ]),
        if (sel.custom) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            AppButton(
                '${gt('From')} ${_from == null ? '-' : _dmy(_from!)}',
                variant: BtnVariant.secondary,
                size: BtnSize.sm,
                icon: 'clock',
                onTap: () => _pick(true)),
            AppButton('${gt('To')} ${_to == null ? '-' : _dmy(_to!)}',
                variant: BtnVariant.secondary,
                size: BtnSize.sm,
                icon: 'clock',
                onTap: () => _pick(false)),
          ]),
        ],
        if (err != null && err.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(err,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red)),
          ),
      ],
    );
  }
}
