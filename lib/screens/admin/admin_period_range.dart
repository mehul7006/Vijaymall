import 'package:flutter/material.dart';

import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';

/// The period choice shared by the three period reports (doc 30, "Period
/// rules"): `week` / `month` / `quarter`, or an explicit `from` (+ optional
/// `to`) as `yyyy-MM-dd`. When [from] is set it wins and [period] is ignored.
class PeriodSel {
  const PeriodSel(this.period, {this.from, this.to});

  final String period;
  final String? from;
  final String? to;

  bool get custom => from != null && from!.isNotEmpty;

  /// Query values for the API calls: `from`/`to` win over `period`.
  String? get apiPeriod => custom ? null : period;
  String? get apiFrom => custom ? from : null;
  String? get apiTo => custom && (to ?? '').isNotEmpty ? to : null;

  @override
  bool operator ==(Object o) =>
      o is PeriodSel && o.period == period && o.from == from && o.to == to;

  @override
  int get hashCode => Object.hash(period, from, to);
}

DateTime? _parseDay(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  final d = DateTime.utc(
      int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  // Reject 2026-02-31 style dates that DateTime silently rolls over.
  if (d.month != int.parse(m.group(2)!) || d.day != int.parse(m.group(3)!)) {
    return null;
  }
  return d;
}

/// Checks a custom range the way the server does. Returns field -> English
/// message (`from`, `to`); empty = fine. [maxDays] is 366 for the period
/// reports and 93 for the audit log.
Map<String, String> validateDayRange(String from, String to,
    {int maxDays = 366, bool fromRequired = true}) {
  final out = <String, String>{};
  final f = from.trim(), t = to.trim();
  DateTime? fd, td;
  if (f.isEmpty) {
    if (fromRequired) out['from'] = 'Enter the start date (yyyy-MM-dd)';
  } else {
    fd = _parseDay(f);
    if (fd == null) out['from'] = 'Use the format yyyy-MM-dd';
  }
  if (t.isNotEmpty) {
    td = _parseDay(t);
    if (td == null) out['to'] = 'Use the format yyyy-MM-dd';
  }
  if (fd != null && td != null) {
    if (td.isBefore(fd)) {
      out['to'] = 'The end date cannot be before the start date';
    } else if (td.difference(fd).inDays + 1 > maxDays) {
      out['to'] = 'The range is limited to $maxDays days';
    }
  }
  return out;
}

/// Week / Month / Quarter chips plus a "Custom" range with from/to inputs.
/// Validation errors (also the server's `details.fields` for `period`,
/// `from`, `to`, passed in [serverErrors]) show under the inputs.
class PeriodRangePicker extends StatefulWidget {
  const PeriodRangePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.serverErrors = const {},
    this.chipLabels = const {
      'week': 'Week',
      'month': 'Month',
      'quarter': 'Quarter',
    },
  });

  final PeriodSel value;
  final ValueChanged<PeriodSel> onChanged;
  final Map<String, String> serverErrors;
  final Map<String, String> chipLabels;

  @override
  State<PeriodRangePicker> createState() => _PeriodRangePickerState();
}

class _PeriodRangePickerState extends State<PeriodRangePicker> {
  late final TextEditingController _from =
      TextEditingController(text: widget.value.from ?? '');
  late final TextEditingController _to =
      TextEditingController(text: widget.value.to ?? '');
  late bool _showCustom = widget.value.custom;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _apply() {
    final e = validateDayRange(_from.text, _to.text);
    setState(() => _errors = e);
    if (e.isNotEmpty) return;
    widget.onChanged(PeriodSel(widget.value.period,
        from: _from.text.trim(), to: _to.text.trim()));
  }

  String? _err(String f) {
    final local = _errors[f];
    if (local != null) return gt(local);
    final s = widget.serverErrors[f];
    return s == null ? null : gt(s);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipRail(children: [
          for (final e in widget.chipLabels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(gt(e.value),
                  small: true,
                  selected: !v.custom && !_showCustom && v.period == e.key,
                  onTap: () {
                    setState(() {
                      _showCustom = false;
                      _errors = const {};
                    });
                    widget.onChanged(PeriodSel(e.key));
                  }),
            ),
          AppChip(gt('Custom'),
              small: true,
              selected: v.custom || _showCustom,
              onTap: () => setState(() => _showCustom = true)),
        ]),
        if (_showCustom || v.custom) ...[
          const SizedBox(height: 10),
          FieldRow(children: [
            AppField(
              label: gt('From (yyyy-MM-dd)'),
              controller: _from,
              placeholder: '2026-11-01',
              maxLength: 10,
              error: _err('from'),
              onEditingComplete: _apply,
            ),
            AppField(
              label: gt('To (optional)'),
              controller: _to,
              placeholder: gt('today'),
              maxLength: 10,
              error: _err('to'),
              onEditingComplete: _apply,
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            AppButton('Show range', size: BtnSize.sm, onTap: _apply),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  gt('Both days are included. At most 366 days. Without a start date the period above is used.'),
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink3)),
            ),
          ]),
        ],
        if (!_showCustom && !v.custom && widget.serverErrors['period'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(gt(widget.serverErrors['period']!),
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red)),
          ),
      ],
    );
  }
}
