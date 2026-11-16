import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/ist.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/sheet.dart';
import '../../data/api/bank_dto.dart';

// ---------------------------------------------------------------------------
// Formatting (money is exact: whole paise, never a double)
// ---------------------------------------------------------------------------

/// `Rs 1,25,000.50` from paise. Whole rupees show no decimals.
String bankMoney(int paise) {
  final neg = paise < 0;
  final a = paise.abs();
  final rupees = (a ~/ 100).toString();
  final frac = a % 100;
  String grouped;
  if (rupees.length > 3) {
    final last3 = rupees.substring(rupees.length - 3);
    var rest = rupees.substring(0, rupees.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  } else {
    grouped = rupees;
  }
  final f = frac == 0 ? '' : '.${frac.toString().padLeft(2, '0')}';
  return '${neg ? '-' : ''}Rs $grouped$f';
}

/// Amount that the provider may not have reported yet: null shows "Pending"
/// (never 0), as the guide requires for fee, GST and net.
String bankMoneyOrPending(int? paise) =>
    paise == null ? gt('Pending') : bankMoney(paise);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// `09 Nov 2026` in India time.
String bankDay(DateTime? d) {
  if (d == null) return '-';
  final i = toIst(d);
  return '${i.day.toString().padLeft(2, '0')} ${_months[i.month - 1]} ${i.year}';
}

/// `09 Nov 2026, 10:45 pm` in India time.
String bankWhen(DateTime? d) {
  if (d == null) return '-';
  final i = toIst(d);
  final h = i.hour % 12 == 0 ? 12 : i.hour % 12;
  final ap = i.hour >= 12 ? 'pm' : 'am';
  return '${bankDay(d)}, $h:${i.minute.toString().padLeft(2, '0')} $ap';
}

/// [range]: when the server rejects `from` / `to` (400 VALIDATION_FAILED) the
/// text is stored on the range so the date bar shows it under the date.
String bankError(Object e, [BankRange? range]) {
  if (e is ApiException) {
    if (range != null) {
      range.serverError = ApiException.fieldError(e.fields, ['to']) ??
          ApiException.fieldError(e.fields, ['from']);
    }
    switch (e.code) {
      case 'ACCOUNT_IN_USE':
        // The server says which rule (history, active accounts settle into
        // it, kind change); only fall back to a general line when it is blank.
        return e.message.trim().isEmpty
            ? gt('This account is in use. Switch it off instead.')
            : gt(e.message.trim());
      case 'LAST_CASH_ACCOUNT':
        return gt('Keep at least one active cash account.');
      case 'DUPLICATE_ACCOUNT_NAME':
        return gt('An account with this name already exists.');
      case 'SETTLEMENT_NOT_CONFIGURED':
        return gt('This provider is not set up yet. Add its keys first.');
      case 'DUPLICATE_TERMINAL':
        return gt('This machine is already added.');
    }
    return e.messageWithRef;
  }
  return gt('Could not reach the server. Please try again.');
}

String kindLabel(String kind) {
  switch (kind) {
    case 'BANK':
      return gt('Bank');
    case 'GATEWAY':
      return gt('Online gateway');
    case 'UPI':
      return gt('UPI QR');
    case 'CARD_TERMINAL':
      return gt('Card machine');
    case 'CASH':
      return gt('Cash drawer');
  }
  return kind;
}

// ---------------------------------------------------------------------------
// Date range (India calendar days, both included, at most 400 days)
// ---------------------------------------------------------------------------

class BankRange {
  DateTime from;
  DateTime to;
  BankRange(this.from, this.to);

  /// Message the server gave for `from` / `to` (shown under the dates).
  String? serverError;

  factory BankRange.lastDays(int days) {
    final t = istNow();
    final today = DateTime.utc(t.year, t.month, t.day);
    return BankRange(today.subtract(Duration(days: days - 1)), today);
  }

  static String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get fromText => fmt(from);
  String get toText => fmt(to);

  String? get error {
    if (from.isAfter(to)) return 'The start date is after the end date';
    if (to.difference(from).inDays >= 400) return 'At most 400 days at a time';
    return null;
  }

  BankRange copy() => BankRange(from, to);
}

Future<DateTime?> pickBankDay(BuildContext context, DateTime initial) {
  final now = istNow();
  return showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(now.year - 3),
    lastDate: DateTime(now.year, now.month, now.day),
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(primary: AppColors.navy),
      ),
      child: child!,
    ),
  ).then((d) => d == null ? null : DateTime.utc(d.year, d.month, d.day));
}

/// From / To pickers with quick chips.
class BankRangeBar extends StatelessWidget {
  final BankRange range;
  final ValueChanged<BankRange> onChanged;
  const BankRangeBar({super.key, required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final err = range.error ?? range.serverError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipRail(children: [
          for (final d in const [7, 30, 90, 365])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(
                d == 365 ? gt('1 year') : '$d ${gt('days')}',
                selected: range.to == BankRange.lastDays(d).to &&
                    range.from == BankRange.lastDays(d).from,
                onTap: () => onChanged(BankRange.lastDays(d)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SelectField(
              label: 'From',
              value: BankRange.fmt(range.from),
              onTap: () async {
                final d = await pickBankDay(context, range.from);
                if (d != null) onChanged(BankRange(d, range.to));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectField(
              label: 'To',
              value: BankRange.fmt(range.to),
              onTap: () async {
                final d = await pickBankDay(context, range.to);
                if (d != null) onChanged(BankRange(range.from, d));
              },
            ),
          ),
        ]),
        if (err != null) BankNote(gt(err), error: true),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

TextStyle bankStyle(double size, FontWeight w, Color c) =>
    TextStyle(fontFamily: AppTheme.uiFont, fontSize: size, fontWeight: w, color: c);

class BankNote extends StatelessWidget {
  final String text;
  final bool error;
  const BankNote(this.text, {super.key, this.error = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: bankStyle(12, FontWeight.w700,
                error ? AppColors.red : AppColors.ink2)),
      );
}

/// Label / value line.
class BankKv extends StatelessWidget {
  final String k;
  final String v;
  final bool strong;
  const BankKv(this.k, this.v, {super.key, this.strong = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 116,
                child: Text(gt(k),
                    style: bankStyle(12, FontWeight.w700, AppColors.ink3))),
            Expanded(
                child: Text(v,
                    style: bankStyle(13, strong ? FontWeight.w800 : FontWeight.w700,
                        AppColors.ink))),
          ],
        ),
      );
}

/// White bordered card used for every list row.
class BankCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool alert;
  const BankCard({super.key, required this.child, this.onTap, this.alert = false});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: alert ? AppColors.red : AppColors.line),
        boxShadow: AppColors.sh1,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

Pill bankPill(String label, {String tone = 'neutral'}) {
  switch (tone) {
    case 'good':
      return Pill(label: label, bg: AppColors.greenTint, fg: AppColors.green);
    case 'bad':
      return Pill(label: label, bg: AppColors.redTint, fg: AppColors.red);
    case 'warn':
      return Pill(label: label, bg: AppColors.goldTint, fg: AppColors.goldInk);
  }
  return Pill(label: label, bg: AppColors.bg, fg: AppColors.ink2);
}

/// Previous / next pager under a list.
class BankPager extends StatelessWidget {
  final BankPage<dynamic> page;
  final ValueChanged<int> onPage;
  const BankPager({super.key, required this.page, required this.onPage});

  @override
  Widget build(BuildContext context) {
    if (page.page == 0 && !page.hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(children: [
        Expanded(
          child: AppButton('Previous',
              variant: BtnVariant.secondary,
              size: BtnSize.sm,
              disabled: page.page == 0,
              onTap: page.page == 0 ? null : () => onPage(page.page - 1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('${gt('Page')} ${page.page + 1}',
              style: bankStyle(12.5, FontWeight.w800, AppColors.ink2)),
        ),
        Expanded(
          child: AppButton('Next',
              variant: BtnVariant.secondary,
              size: BtnSize.sm,
              disabled: !page.hasMore,
              onTap: page.hasMore ? () => onPage(page.page + 1) : null),
        ),
      ]),
    );
  }
}

/// Dropdown-style chooser (bottom sheet) over a short list of options.
Future<String?> pickBankOption(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
  String? selected,
}) {
  return showAppSheet<String>(
    context: context,
    title: title,
    builder: (ctx) => Column(
      children: [
        for (final o in options)
          SheetOption(
              title: o.$2,
              selected: o.$1 == selected,
              onTap: () => Navigator.of(ctx).pop(o.$1)),
      ],
    ),
  );
}

/// Confirm sheet; true when confirmed.
Future<bool> bankConfirm(
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
              style: bankStyle(13.5, FontWeight.w600, AppColors.ink2)
                  .copyWith(height: 1.45)),
        ),
        AppButton(confirmLabel,
            variant: danger ? BtnVariant.danger : BtnVariant.primary,
            block: true,
            onTap: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: 8),
        AppButton('Cancel',
            variant: BtnVariant.secondary,
            block: true,
            onTap: () => Navigator.of(ctx).pop(false)),
        const SizedBox(height: 8),
      ],
    ),
  );
  return r == true;
}

/// Small icon + text status line (empty / info).
class BankInfoLine extends StatelessWidget {
  final String text;
  final Color color;
  const BankInfoLine(this.text, {super.key, this.color = AppColors.ink3});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon('info', size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
              child: Text(gt(text),
                  style: bankStyle(12, FontWeight.w600, color))),
        ]),
      );
}

/// Shared section title.
Widget bankTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(gt(t), style: bankStyle(14, FontWeight.w800, AppColors.ink)),
    );

/// Screen chrome for the bank module: head + scroll body + bottom nav.
class BankPageShell extends StatelessWidget {
  final String title;
  final String sub;
  final Widget child;
  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;
  final List<Widget> actions;

  const BankPageShell({
    super.key,
    required this.title,
    required this.sub,
    required this.child,
    this.onBack,
    this.onRefresh,
    this.actions = const [],
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
                    actions: actions,
                    onBack: onBack),
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

/// `12.5` / `12` / `1,250.50` -> paise without floating point; null = invalid.
int? bankRupeesToPaise(String text) {
  final t = text.trim().replaceAll(',', '');
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + int.parse(frac.isEmpty ? '0' : frac);
}

/// A rule-bound "section header + children" used by the forms.
Widget bankGap([double h = 12]) => SizedBox(height: h);
