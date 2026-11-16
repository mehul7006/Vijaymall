import 'package:flutter/material.dart';

import '../provider/state_scope.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'buttons.dart';
import '../state/gu_strings.dart';

/// White surface card (`.card`, radius 20).
class CardPanel extends StatelessWidget {
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? child;
  final Widget? trailing;
  final EdgeInsets padding;
  final Color? color;

  const CardPanel({
    super.key,
    this.title,
    this.actionLabel,
    this.onAction,
    this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.sh1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || actionLabel != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                if (actionLabel != null)
                  AppLink(actionLabel!, onTap: onAction, size: 12),
              ],
            ),
            if (child != null) const SizedBox(height: 12),
          ],
          if (child != null) child!,
          if (trailing != null) ...[const SizedBox(height: 12), trailing!],
        ],
      ),
    );
  }
}

/// Section head with optional "see all" link (`.section-head`).
class SectionHead extends StatelessWidget {
  final String title;
  final String? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHead(
    this.title, {
    super.key,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 18, color: AppColors.red, sw: 2),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              gt(title),
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          if (actionLabel != null)
            AppLink(actionLabel!, onTap: onAction, size: 12),
        ],
      ),
    );
  }
}

/// Bill totals shared by cart / checkout / placed / track.
class BillData {
  final num subtotal;
  final String couponCode;
  final num discount;
  final int coinsUsed;
  final num coinDiscount;
  final num total;

  const BillData({
    required this.subtotal,
    this.couponCode = '',
    this.discount = 0,
    this.coinsUsed = 0,
    this.coinDiscount = 0,
    required this.total,
  });

  factory BillData.fromTotals(CartTotals t) => BillData(
        subtotal: t.subtotal,
        couponCode: t.couponOk ? t.coupon!.coupon!.code : '',
        discount: t.discount,
        coinsUsed: t.coinsUsed,
        coinDiscount: t.coinDiscount,
        total: t.total,
      );
}

/// `.bill-row` label/value pair.
class BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  const BillRow(
    this.label,
    this.value, {
    super.key,
    this.strong = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gt(label),
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: strong ? 15 : 13.5,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: strong ? AppColors.ink : AppColors.ink2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: strong ? 16 : 13.5,
                fontWeight: FontWeight.w800,
                color: valueColor ??
                    (strong ? AppColors.ink : AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `billLines(t)` — the exact 5-row bill block (localized).
class BillLines extends StatelessWidget {
  final BillData bill;

  const BillLines(this.bill, {super.key});

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    final green = AppColors.green;
    final rows = <Widget>[
      BillRow(
        gu ? 'વસ્તુ કુલ' : 'Item total',
        money(bill.subtotal),
      ),
      if (bill.discount > 0)
        BillRow(
          gu
              ? 'કૂપન (${bill.couponCode})'
              : 'Coupon (${bill.couponCode})',
          '−${money(bill.discount)}',
          valueColor: green,
        ),
      if (bill.coinsUsed > 0)
        BillRow(
          gu
              ? '${bill.coinsUsed} કોઈન્સ'
              : '${bill.coinsUsed} coins',
          '−${money(bill.coinDiscount)}',
          valueColor: green,
        ),
      BillRow(
        gu ? 'હોમ ડિલિવરી' : 'Home delivery',
        gu ? 'મફત' : 'FREE',
        valueColor: green,
      ),
      BillRow(
        gu ? 'ચૂકવવાનું' : 'To pay',
        money(bill.total),
        strong: true,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i == rows.length - 1)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.line, width: 1.2)),
              ),
              child: rows[i],
            )
          else
            rows[i],
        ],
      ],
    );
  }
}

/// `earnNote(coins, ruleName)` — the gold "you'll earn" strip.
class EarnNote extends StatelessWidget {
  final int coins;
  final String? ruleName;

  const EarnNote({super.key, required this.coins, this.ruleName});

  @override
  Widget build(BuildContext context) {
    if (coins <= 0) return const SizedBox.shrink();
    final gu = StateScope.of(context).lang == 'gu';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.goldPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33F5B301)),
      ),
      child: Row(
        children: [
          const AppIcon('coin', size: 13, color: AppColors.goldInk, sw: 2),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldInk,
                ),
                children: [
                  TextSpan(
                      text: gu ? 'કમાઓ ' : 'Earn ',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(
                    text: gu
                        ? '$coins કોઈન્સ'
                        : '$coins coins',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: gu
                        ? ' ડિલિવરી પછી ₹$coinsની કિંમત'
                        : ' worth ₹$coins after delivery',
                  ),
                  if (ruleName != null && ruleName!.isNotEmpty)
                    TextSpan(text: ' · $ruleName'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.empty` — orb icon + title + copy + optional action.
class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String copy;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = 'box',
    required this.title,
    required this.copy,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      ),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.redTint.withValues(alpha: .55),
            ),
            child: Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldPanel,
              boxShadow: AppColors.sh1,
            ),
            child: Center(
              child: AppIcon(icon, size: 34, color: AppColors.red, sw: 1.7),
            ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            gt(title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              gt(copy),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.ink2,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            AppButton(
              gt(actionLabel!),
              onTap: onAction,
              variant: BtnVariant.soft,
              size: BtnSize.sm,
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Small hint line (`.hint`) with leading icon.
class Hint extends StatelessWidget {
  final String text;
  final String icon;
  final Color color;

  const Hint(
    this.text, {
    super.key,
    this.icon = 'info',
    this.color = AppColors.ink3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 13, color: color, sw: 1.8),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 11.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// `.tag` — pill tags on product detail (green/gold/navy/neutral).
class TagPill extends StatelessWidget {
  final String label;
  final String icon;
  final Color bg;
  final Color fg;

  const TagPill({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  factory TagPill.green(String label, String icon) => TagPill(
      label: label, icon: icon, bg: AppColors.greenTint, fg: AppColors.green);
  factory TagPill.gold(String label, String icon) => TagPill(
      label: label, icon: icon, bg: AppColors.goldTint, fg: AppColors.goldInk);
  factory TagPill.navy(String label, String icon) => TagPill(
      label: label, icon: icon, bg: AppColors.navyTint, fg: AppColors.navy);
  factory TagPill.neutral(String label, String icon) => TagPill(
      label: label, icon: icon, bg: AppColors.bg, fg: AppColors.ink2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 11, color: fg, sw: 2),
          const SizedBox(width: 5),
          Text(
            gt(label),
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu row (`.menu-card` rows) — icon tile, title, sub, chevron.
class NavRow extends StatelessWidget {
  final String icon;
  final String title;
  final String? sub;
  final VoidCallback? onTap;
  final Color tileBg;
  final Color tileFg;
  final Widget? trailing;
  final bool danger;

  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.sub,
    this.onTap,
    this.tileBg = AppColors.bg,
    this.tileFg = AppColors.ink,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = danger ? AppColors.red : AppColors.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: AppIcon(icon, size: 19, color: tileFg, sw: 1.9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const AppIcon('right', size: 14, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

/// Icon + value stat tile.
class StatTile extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            AppIcon(icon, size: 17, color: AppColors.navy, sw: 1.9),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              gt(label),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
