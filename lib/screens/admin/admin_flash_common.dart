import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/ist.dart';
import '../../nav/nav.dart';
import '../../state/app_state.dart' show money;
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/sheet.dart';
import '../../widgets/flash_widgets.dart' show flashWhen;

/// Whole paise as rupees text (`Rs 1,250.50`), exact.
String fmtPaise(int paise) => money(paise / 100);

/// `12.5` / `12` / `12.50` -> paise without floating point. null = invalid.
int? rupeesTextToPaise(String text) {
  final t = text.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final whole = int.parse(m.group(1)!);
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(frac.isEmpty ? '0' : frac);
}

/// Paise as plain editable rupees text (`4500` -> `45`, `4550` -> `45.50`).
String paiseToRupeesText(int paise) {
  final w = paise ~/ 100;
  final f = paise % 100;
  if (f == 0) return '$w';
  return '$w.${f.toString().padLeft(2, '0')}'.replaceFirst(RegExp(r'0$'), '');
}

String fmtWindow(DateTime? a, DateTime? b) =>
    '${flashWhen(a)}  ->  ${flashWhen(b)}';

/// Status chip colours: scheduled / active / ended / cancelled.
Widget flashStatusPill(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return Pill.active('Active');
    case 'SCHEDULED':
      return const Pill(
          label: 'Scheduled', bg: AppColors.goldTint, fg: AppColors.goldInk);
    case 'ENDED':
      return const Pill(label: 'Ended', bg: AppColors.bg, fg: AppColors.ink2);
    case 'CANCELLED':
      return Pill.out('Cancelled');
  }
  return Pill(label: status, bg: AppColors.bg, fg: AppColors.ink2);
}

String channelLabel(String c) {
  switch (c.toUpperCase()) {
    case 'ONLINE':
      return gt('Online');
    case 'POS':
      return gt('Counter');
  }
  return gt('Online + Counter');
}

/// Error text for a failed call: the server's own message (it names the
/// product / sale), with the support reference on 5xx.
String flashError(Object e) {
  if (e is ApiException) return e.messageWithRef;
  return gt('Could not reach the server. Please try again.');
}

Future<DateTime?> pickIstDateTime(BuildContext context, DateTime initial) async {
  final d = await showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(istNow().year - 1),
    lastDate: DateTime(istNow().year + 2),
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(primary: AppColors.navy),
      ),
      child: child!,
    ),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
  );
  if (t == null) return null;
  // IST wall-clock value (UTC-flagged), see data/ist.dart.
  return DateTime.utc(d.year, d.month, d.day, t.hour, t.minute);
}

/// Confirm sheet. Returns true when the staff member confirms.
Future<bool> flashConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = false,
}) async {
  final r = await showAppSheet<bool>(
    context: context,
    title: title,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: Text(gt(body),
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.ink2,
              )),
        ),
        AppButton(confirmLabel,
            variant: danger ? BtnVariant.danger : BtnVariant.primary,
            block: true,
            onTap: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: 8),
        AppButton('Keep as it is',
            variant: BtnVariant.secondary,
            block: true,
            onTap: () => Navigator.of(ctx).pop(false)),
        const SizedBox(height: 8),
      ],
    ),
  );
  return r == true;
}

/// Back to the list (or one step back when there is history).
void flashBack([String fallback = '/admin/flash-sales']) {
  if (!Nav.instance.pop()) go(fallback);
}

/// Standard admin page chrome (head + body + bottom nav) for the module.
class FlashAdminPage extends StatelessWidget {
  final String title;
  final String sub;
  final Widget child;
  final bool backToList;
  final Future<void> Function()? onRefresh;

  const FlashAdminPage({
    super.key,
    required this.title,
    required this.sub,
    required this.child,
    this.backToList = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: title,
                  sub: sub,
                  bell: false,
                  onBack: backToList ? () => flashBack() : null,
                ),
                ScreenScroll(onRefresh: onRefresh, child: child),
              ],
            ),
            const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }
}

/// Small bold label/value line.
class FlashKv extends StatelessWidget {
  final String k;
  final String v;
  const FlashKv(this.k, this.v, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(gt(k),
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink3,
                  )),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  )),
            ),
          ],
        ),
      );
}

/// Inline red/neutral message under a section.
class FlashNote extends StatelessWidget {
  final String text;
  final bool error;
  const FlashNote(this.text, {super.key, this.error = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: error ? AppColors.red : AppColors.ink2,
            )),
      );
}

/// Status filter chips used by the list.
class FlashStatusChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const FlashStatusChips(
      {super.key, required this.value, required this.onChanged});

  static const _tabs = [
    ('', 'All'),
    ('ACTIVE', 'Running'),
    ('SCHEDULED', 'Scheduled'),
    ('ENDED', 'Ended'),
    ('CANCELLED', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) => ChipRail(children: [
        for (final t in _tabs)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip(t.$2,
                selected: value == t.$1, onTap: () => onChanged(t.$1)),
          ),
      ]);
}
