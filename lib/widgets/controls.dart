import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import '../state/gu_strings.dart';

/// `.chip` — pill filter chip.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool small;

  const AppChip(
    this.label, {
    super.key,
    required this.selected,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 11 : 14,
          vertical: small ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.redTint : AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(
            color: selected ? AppColors.red : AppColors.line,
          ),
        ),
        child: Text(
          gt(label),
          style: TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: small ? 12 : 13,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.red : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable chip rail (`.chips`, `.status-tabs`).
class ChipRail extends StatelessWidget {
  final List<Widget> children;

  const ChipRail({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: children),
    );
  }
}

String statusKey(String status) =>
    status.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

const Map<String, String> statusPillClass = {
  'placed': 'placed',
  'confirmed': 'confirmed',
  'packed': 'packed',
  'ready_for_pickup': 'ready',
  'out_for_delivery': 'out',
  'delivered': 'done',
  'picked_up': 'done',
  'cancelled': 'cancelled',
};

/// `customerStatusPill(status)` — tinted status pill.
class StatusPill extends StatelessWidget {
  final String status;
  final String label;

  const StatusPill(this.status, {super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final kind = statusPillClass[statusKey(status)] ?? 'grey';
    final (bg, fg) = switch (kind) {
      'placed' => (AppColors.navyTint, AppColors.navy2),
      'confirmed' => (const Color(0xFFE8EBF8), AppColors.navy),
      'packed' => (AppColors.goldTint, AppColors.goldInk),
      'ready' => (AppColors.goldTint, AppColors.goldInk),
      'out' => (const Color(0xFFFFE9DC), AppColors.orange),
      'done' => (AppColors.greenTint, AppColors.green),
      'cancelled' => (AppColors.redTint, AppColors.red3),
      _ => (AppColors.bg, AppColors.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Text(
        gt(label),
        style: TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}

/// `customerPayPill(state)` — Paid / Pending / Refunded.
class PayPill extends StatelessWidget {
  final String state;
  final String label;

  const PayPill(this.state, {super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final done = state == 'Paid';
    final cancelled = state == 'Refunded';
    final bg = done
        ? AppColors.greenTint
        : cancelled
            ? AppColors.redTint
            : AppColors.goldTint;
    final fg = done
        ? AppColors.green
        : cancelled
            ? AppColors.red3
            : AppColors.goldInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Text(
        gt(label),
        style: TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Generic pill (`pill--active`, `pill--low`, `pill--cancelled` …).
class Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final String? icon;

  const Pill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  factory Pill.active(String label) => Pill(
        label: label,
        bg: AppColors.greenTint,
        fg: AppColors.green,
      );

  factory Pill.low(String label) => Pill(
        label: label,
        bg: AppColors.goldTint,
        fg: AppColors.goldInk,
      );

  factory Pill.out(String label) => Pill(
        label: label,
        bg: AppColors.redTint,
        fg: AppColors.red,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 12, color: fg, sw: 2),
            const SizedBox(width: 4),
          ],
          Text(
            gt(label),
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.switch` — iOS-style toggle.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;

  const AppSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final off = disabled || onChanged == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: off ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.red : AppColors.knobOff,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.radio` circle.
class AppRadio extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;

  const AppRadio({super.key, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.white,
          border: Border.all(
            color: selected ? AppColors.red : AppColors.knobOff,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: selected
            ? Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// `stepper-pill` — minus / value / plus.
class Stepper extends StatelessWidget {
  final int value;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  final String? ariaDec;
  final String? ariaInc;
  final bool compact;

  const Stepper({
    super.key,
    required this.value,
    this.onDec,
    this.onInc,
    this.ariaDec,
    this.ariaInc,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = compact ? 30.0 : 38.0;
    final btn = compact ? 30.0 : 32.0;
    return Container(
      height: h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundBtn(
            icon: 'minus',
            enabled: onDec != null,
            size: btn,
            aria: ariaDec ?? 'Decrease',
            onTap: onDec,
          ),
          SizedBox(
            width: compact ? 24 : 30,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          _roundBtn(
            icon: 'plus',
            enabled: onInc != null,
            size: btn,
            aria: ariaInc ?? 'Increase',
            onTap: onInc,
          ),
        ],
      ),
    );
  }

  Widget _roundBtn({
    required String icon,
    required bool enabled,
    required double size,
    required String aria,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .35,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AppIcon(icon, size: 13, color: AppColors.ink, sw: 2.2),
          ),
        ),
      ),
    );
  }
}

/// `.segmented` — 2-up pill switcher (delivery/pickup etc.).
class Segmented extends StatelessWidget {
  final List<SegmentOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: options.map((o) {
          final selected = o.key == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(o.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected ? AppColors.sh1 : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (o.icon != null) ...[
                      AppIcon(
                        o.icon!,
                        size: 16,
                        color: selected ? AppColors.red : AppColors.ink3,
                        sw: 1.9,
                      ),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Text(
                        gt(o.label),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: selected ? AppColors.ink : AppColors.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SegmentOption {
  final String key;
  final String label;
  final String? icon;

  const SegmentOption(this.key, this.label, {this.icon});
}
