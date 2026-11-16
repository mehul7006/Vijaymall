import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'controls.dart';
import 'skeleton.dart';
import '../state/gu_strings.dart';

/// `sheetShell(title, sub, body)` — scrim + grab handle + head + body.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  String? sub,
  required Widget Function(BuildContext context) builder,
  bool showClose = true,
  Widget? footer,
  Future<void> Function()? onRefresh,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x6614162B),
    builder: (ctx) => LayoutBuilder(builder: (ctx, cons) {
      final safeBottom = MediaQuery.of(ctx).padding.bottom;
      // The sheet lives in the navigator area (below the site header), which
      // is shorter than the window: cap to what is really available so the
      // title row is never pushed off the top.
      final avail = cons.maxHeight.isFinite ? cons.maxHeight - 8 : double.infinity;
      final cap = MediaQuery.of(ctx).size.height * .88;
      return Container(
        constraints: BoxConstraints(
          maxHeight: avail < cap ? avail : cap,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.ink3.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gt(title),
                          style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        if (sub != null && sub.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            gt(sub),
                            style: const TextStyle(
                              fontFamily: AppTheme.uiFont,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showClose)
                    Semantics(
                      button: true,
                      label: gt('Close'),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(ctx).maybePop(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: AppIcon('close',
                                    size: 16, color: AppColors.ink2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: _sheetScroll(
                onRefresh: onRefresh,
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, footer != null ? 12 : 20 + safeBottom),
                child: FadeSlideIn(child: builder(ctx)),
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + safeBottom),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: footer,
              ),
          ],
        ),
      );
    }),
  );
}

Widget _sheetScroll({
  required Widget child,
  required EdgeInsets padding,
  Future<void> Function()? onRefresh,
}) {
  final scroll = SingleChildScrollView(
    padding: padding,
    physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
    child: child,
  );
  if (onRefresh == null) return scroll;
  return RefreshIndicator(
    color: AppColors.red,
    onRefresh: onRefresh,
    child: scroll,
  );
}

/// `.sheet-option` — label + sub + radio selection row.
class SheetOption extends StatelessWidget {
  final String title;
  final String? sub;
  final bool selected;
  final VoidCallback? onTap;
  final String? leading;

  const SheetOption({
    super.key,
    required this.title,
    this.sub,
    required this.selected,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.redTint : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.red : AppColors.line,
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              AppIcon(leading!, size: 18, color: AppColors.red, sw: 1.9),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gt(title),
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      gt(sub!),
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AppRadio(selected: selected, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

/// `label + radio list row` used inside sheets/forms.
class RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? sub;

  const RadioRow({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            AppRadio(selected: selected, onTap: onTap),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gt(label),
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      gt(sub!),
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
