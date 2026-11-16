import 'package:flutter/material.dart';

import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'controls.dart' show statusKey, statusPillClass;

/// Customer-side order status chip: coloured dot + soft gradient fill.
/// Same status to colour mapping as the shared StatusPill; [label] is the
/// already-translated status text.
class StoreStatusChip extends StatelessWidget {
  final String status;
  final String label;
  const StoreStatusChip(this.status, {super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final kind = statusPillClass[statusKey(status)] ?? 'grey';
    final (a, b, fg) = switch (kind) {
      'placed' => (AppColors.navyTint, const Color(0xFFC9D2F5), AppColors.navy2),
      'confirmed' =>
        (const Color(0xFFE8EBF8), const Color(0xFFBBC6F0), AppColors.navy),
      'packed' ||
      'ready' =>
        (AppColors.goldTint, const Color(0xFFFFE08A), AppColors.goldInk),
      'out' => (
          const Color(0xFFFFE9DC),
          const Color(0xFFFFC49A),
          AppColors.orange
        ),
      'done' => (
          AppColors.greenTint,
          const Color(0xFFA6E3C3),
          AppColors.green
        ),
      'cancelled' =>
        (AppColors.redTint, const Color(0xFFFFB9BF), AppColors.red3),
      _ => (AppColors.bg, const Color(0xFFE6E2D8), AppColors.ink2),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [a, b]),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: .25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: fg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: fg.withValues(alpha: .5), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            gt(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 1.2,
            ),
          ),
        ),
      ]),
    );
  }
}
