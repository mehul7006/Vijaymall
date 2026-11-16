import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/push_dto.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/flash_widgets.dart' show flashWhen;

/// Error text for a failed push call: the server's message (with the support
/// reference on 5xx).
String pushError(Object e) {
  if (e is ApiException) {
    if (e.code == 'RATE_LIMITED') {
      final s = e.retryAfterSeconds;
      if (s != null && s > 0) {
        final wait = s >= 120 ? '${(s / 60).ceil()} ${gt('minutes')}' : '$s ${gt('seconds')}';
        return '${gt('You have sent many announcements. Try again in')} $wait.';
      }
    }
    if (e.code == 'SEGMENT_TOO_HEAVY') {
      return gt('This segment is too big to count. Add a condition or use a shorter period.');
    }
    return e.messageWithRef;
  }
  return gt('Could not reach the server. Please try again.');
}

/// `1,250` style count; `10,000+` when the number is only a floor.
String pushCount(int n, {bool exact = true}) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return exact ? b.toString() : '$b+';
}

String pushWhen(DateTime? ist) => flashWhen(ist);

/// `Rs`-labelled catalog text: the server labels money fields "(paise)" but the
/// admin types rupees.
String pushParamLabel(String label) =>
    gt(label.replaceAll('(paise)', '(Rs)'));

/// Friendly name of an ENUM option (`GTE` -> "At least").
String pushOptionLabel(String o) {
  switch (o.toUpperCase()) {
    case 'GTE':
      return gt('At least');
    case 'LTE':
      return gt('At most');
    case 'EQ':
      return gt('Exactly');
    case 'BETWEEN':
      return gt('Between');
    case 'APP':
      return gt('App');
    case 'POS':
      return gt('Counter');
  }
  return o;
}

/// Status chip for a broadcast.
Widget pushStatusPill(String status) {
  switch (status.toUpperCase()) {
    case 'DONE':
      return Pill.active('Done');
    case 'SENDING':
      return const Pill(
          label: 'Sending', bg: AppColors.goldTint, fg: AppColors.goldInk);
    case 'QUEUED':
      return const Pill(
          label: 'Queued', bg: AppColors.navyTint, fg: AppColors.navy);
    case 'FAILED':
      return Pill.out('Failed');
  }
  return Pill(label: status, bg: AppColors.bg, fg: AppColors.ink2);
}

Widget pushAudiencePill(String audience) => Pill(
    label: pushAudienceLabel(audience),
    bg: AppColors.bg,
    fg: AppColors.ink2);

TextStyle pushTs(
        {double size = 13,
        FontWeight w = FontWeight.w700,
        Color color = AppColors.ink,
        double? height}) =>
    TextStyle(
      fontFamily: AppTheme.uiFont,
      fontSize: size,
      fontWeight: w,
      color: color,
      height: height,
    );

/// Field error of a `rules[i].<param>` key (or any other key) from
/// `ApiException.fields`.
String? pushRuleError(Map<String, String> fields, int i, String param) =>
    fields['rules[$i].$param'];

/// Standard admin page chrome (head + body + bottom nav) for this module.
class PushAdminPage extends StatelessWidget {
  final String title;
  final String sub;
  final Widget child;
  final bool back;
  final Widget? bottom;
  final Future<void> Function()? onRefresh;

  const PushAdminPage({
    super.key,
    required this.title,
    required this.sub,
    required this.child,
    this.back = false,
    this.bottom,
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
                  onBack: back ? pushBack : null,
                ),
                ScreenScroll(onRefresh: onRefresh, child: child),
                if (bottom != null) bottom!,
              ],
            ),
            if (bottom == null) const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }
}

void pushBack([String fallback = '/admin/push']) {
  if (!Nav.instance.pop()) go(fallback);
}

/// Small coloured note box.
class PushNote extends StatelessWidget {
  final String text;
  final bool error;
  final bool warn;
  const PushNote(this.text, {super.key, this.error = false, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final fg = error
        ? AppColors.red
        : warn
            ? AppColors.goldInk
            : AppColors.navy;
    final bg = error
        ? AppColors.redTint
        : warn
            ? AppColors.goldTint
            : AppColors.navyTint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(text,
          style: pushTs(size: 12, w: FontWeight.w700, color: fg, height: 1.45)),
    );
  }
}

/// Plain white card used for list rows and sections.
class PushCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsets margin;
  const PushCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
            color: selected ? AppColors.red : AppColors.line,
            width: selected ? 1.6 : 1),
        boxShadow: AppColors.sh1,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

/// Progress bar `done / total`, never above 100%.
class PushProgressBar extends StatelessWidget {
  final int done;
  final int total;
  const PushProgressBar({super.key, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final f = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: f,
        minHeight: 9,
        backgroundColor: AppColors.line,
        color: AppColors.green,
      ),
    );
  }
}

/// Single-line `label  value` row.
class PushKv extends StatelessWidget {
  final String k;
  final String v;
  const PushKv(this.k, this.v, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 118,
                child: Text(gt(k),
                    style: pushTs(size: 12, color: AppColors.ink3))),
            Expanded(child: Text(v, style: pushTs(size: 13))),
          ],
        ),
      );
}
