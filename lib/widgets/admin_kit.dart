import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../nav/nav.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'buttons.dart';

/// Shared presentation helpers for the admin / staff screens: KPI cards,
/// native (CustomPainter) charts, table headers, skeleton loaders and
/// error / empty states. Presentation only - no state, no data fetching.

const TextStyle _kLabel = TextStyle(
  fontFamily: AppTheme.uiFont,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: AppColors.ink2,
);

/// Compact currency-less number: 1250 -> 1.3k, 120000 -> 1.2L.
String compactNum(num v) {
  final a = v.abs();
  if (a >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (a >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (a >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.round().toString();
}

/// Percent change from [prev] to [cur]; null when there is no baseline.
double? pctDelta(num cur, num prev) {
  if (prev <= 0) return null;
  return (cur - prev) / prev * 100;
}

// --------------------------------------------------------------------------
// Delta chip  (+12.5% / -3%)
// --------------------------------------------------------------------------

class DeltaChip extends StatelessWidget {
  final double? pct;
  final String? hint;

  const DeltaChip(this.pct, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    if (pct == null) {
      return Text(hint ?? '', style: _kLabel.copyWith(color: AppColors.ink3));
    }
    final up = pct! >= 0;
    final fg = up ? AppColors.green : AppColors.red3;
    final bg = up ? AppColors.greenTint : AppColors.redTint;
    return Semantics(
      label: '${up ? 'up' : 'down'} ${pct!.abs().toStringAsFixed(0)} percent',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 11, color: fg),
            const SizedBox(width: 2),
            Text(
              '${pct!.abs().toStringAsFixed(pct!.abs() < 10 ? 1 : 0)}%',
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// KPI card with optional sparkline
// --------------------------------------------------------------------------

class KpiCard extends StatelessWidget {
  final String icon;
  final Color tint;
  final Color bg;
  final String label;
  final String value;
  final double? deltaPct;
  final String? deltaHint;
  final List<double>? spark;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.icon,
    required this.tint,
    required this.bg,
    required this.label,
    required this.value,
    this.deltaPct,
    this.deltaHint,
    this.spark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg.withValues(alpha: .85), AppColors.white],
          stops: const [0.0, 0.7],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: tint.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
              color: tint.withValues(alpha: .12),
              offset: const Offset(0, 8),
              blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(11)),
                child: Center(
                    child: AppIcon(icon, size: 16, color: tint, sw: 1.8)),
              ),
              const Spacer(),
              if (deltaPct != null || deltaHint != null)
                Flexible(child: DeltaChip(deltaPct, hint: deltaHint)),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _kLabel,
          ),
          if (spark != null && spark!.length >= 2) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(painter: SparklinePainter(spark!, tint)),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: '$label $value',
      child: GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: onTap, child: card),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = (hi - lo) == 0 ? 1.0 : (hi - lo);
    const pad = 3.0;
    final h = size.height - pad * 2;
    Offset pt(int i) => Offset(
          i * size.width / (values.length - 1),
          pad + h - ((values[i] - lo) / span) * h,
        );
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = pt(i - 1), b = pt(i);
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    final end = pt(values.length - 1);
    canvas.drawCircle(end, 3, Paint()..color = AppColors.white);
    canvas.drawCircle(end, 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.color != color || old.values != values;
}

// --------------------------------------------------------------------------
// Bar chart (revenue by day) with gridlines and value axis
// --------------------------------------------------------------------------

class BarChartData {
  final String label;
  final double value;
  const BarChartData(this.label, this.value);
}

class RevenueBarChart extends StatelessWidget {
  final List<BarChartData> data;
  final double height;
  final String semanticsLabel;

  const RevenueBarChart({
    super.key,
    required this.data,
    this.height = 170,
    this.semanticsLabel = 'Sales by day chart',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _BarChartPainter(data)),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<BarChartData> data;

  _BarChartPainter(this.data);

  void _text(Canvas c, String s, Offset at,
      {TextAlign align = TextAlign.center,
      double w = 60,
      Color color = AppColors.ink3,
      FontWeight fw = FontWeight.w700,
      double fs = 10}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: fs,
              fontWeight: fw,
              color: color)),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: 0, maxWidth: w);
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width < 80 || size.height < 60) return;
    const leftGutter = 38.0;
    const bottomGutter = 22.0;
    const topPad = 14.0;
    final plotW = size.width - leftGutter;
    final plotH = size.height - bottomGutter - topPad;
    var maxV = 1.0;
    for (final d in data) {
      if (d.value > maxV) maxV = d.value;
    }
    // Round the axis ceiling up to a tidy number.
    final mag = math.pow(10, (math.log(maxV) / math.ln10).floor()).toDouble();
    final nice = [1, 2, 2.5, 5, 10].firstWhere((m) => m * mag >= maxV) * mag;
    const ticks = 4;
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= ticks; i++) {
      final y = topPad + plotH - plotH * i / ticks;
      canvas.drawLine(Offset(leftGutter, y), Offset(size.width, y), grid);
      _text(canvas, compactNum(nice * i / ticks), Offset(leftGutter - 6, y),
          align: TextAlign.right, w: leftGutter - 6, fs: 9.5);
    }
    final slot = plotW / data.length;
    final barW = math.min(34.0, slot * .56);
    var peak = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i].value > data[peak].value) peak = i;
    }
    for (var i = 0; i < data.length; i++) {
      final cx = leftGutter + slot * i + slot / 2;
      final isToday = i == data.length - 1;
      final h = data[i].value <= 0
          ? 2.0
          : math.max(3.0, data[i].value / nice * plotH);
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, topPad + plotH - h, barW, h),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
      );
      final colors = isToday
          ? const [AppColors.red2, AppColors.red]
          : const [Color(0xFF8FA0F0), AppColors.navy2];
      canvas.drawRRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(r.outerRect),
      );
      if (i == peak && data[i].value > 0 && slot >= 44) {
        _text(canvas, compactNum(data[i].value),
            Offset(cx, topPad + plotH - h - 8),
            color: AppColors.ink, fw: FontWeight.w800, fs: 10);
      }
      _text(canvas, data[i].label, Offset(cx, size.height - 8),
          w: slot,
          color: isToday ? AppColors.red : AppColors.ink3,
          fw: isToday ? FontWeight.w800 : FontWeight.w700);
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.data != data;
}

// --------------------------------------------------------------------------
// Horizontal proportional bar (top products etc.)
// --------------------------------------------------------------------------

class MeterBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const MeterBar(this.fraction,
      {super.key, this.color = AppColors.navy2, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.bg),
          FractionallySizedBox(
            widthFactor: f,
            child: Container(height: height, color: color),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Data-table style header (wide screens)
// --------------------------------------------------------------------------

class TableCol {
  final String label;
  final int flex;
  final TextAlign align;
  const TableCol(this.label, this.flex, {this.align = TextAlign.left});
}

class TableHeadRow extends StatelessWidget {
  final List<TableCol> cols;
  final double leading;
  final double trailing;

  const TableHeadRow(this.cols, {super.key, this.leading = 0, this.trailing = 0});

  @override
  Widget build(BuildContext context) {
    final pal = SectionPalette.forRoute(Nav.instance.route);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pal.tint,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: pal.accent.withValues(alpha: .25))),
      ),
      child: Row(
        children: [
          if (leading > 0) SizedBox(width: leading),
          for (final c in cols)
            Expanded(
              flex: c.flex,
              child: Text(
                gt(c.label).toUpperCase(),
                textAlign: c.align,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                  color: AppColors.ink2,
                ),
              ),
            ),
          if (trailing > 0) SizedBox(width: trailing),
        ],
      ),
    );
  }
}

/// Hover-aware table row shell: zebra-free, bottom divider, 44px min height.
class TableRowShell extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool last;
  final String? semanticLabel;

  const TableRowShell({
    super.key,
    required this.child,
    this.onTap,
    this.last = false,
    this.semanticLabel,
  });

  @override
  State<TableRowShell> createState() => _TableRowShellState();
}

class _TableRowShellState extends State<TableRowShell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _hover ? AppColors.navyTint.withValues(alpha: .55) : null,
        border: Border(
          bottom: BorderSide(
              color: widget.last ? Colors.transparent : AppColors.line),
        ),
      ),
      child: widget.child,
    );
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: widget.onTap != null,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Count / summary line above lists
// --------------------------------------------------------------------------

class ResultSummary extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const ResultSummary(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: _kLabel),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Skeleton loaders
// --------------------------------------------------------------------------

class SkeletonBlock extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBlock({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
              AppColors.line, const Color(0xFFF0F1F8), _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A few skeleton list rows (avatar + two text lines + trailing value).
class SkeletonRows extends StatelessWidget {
  final int rows;

  const SkeletonRows({super.key, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SkeletonBlock(width: 40, height: 40, radius: 12),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(width: 130, height: 12),
                        SizedBox(height: 7),
                        SkeletonBlock(width: 190, height: 10),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SkeletonBlock(width: 54, height: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Error state with retry
// --------------------------------------------------------------------------

class ErrorRetry extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorRetry({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: AppColors.redTint, shape: BoxShape.circle),
            child: const Center(
                child: Icon(Icons.error_outline_rounded,
                    size: 28, color: AppColors.red)),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.ink2)),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            AppButton(retryLabel,
                onTap: onRetry, variant: BtnVariant.soft, size: BtnSize.sm),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Small alert row ("3 orders waiting", "5 items low")
// --------------------------------------------------------------------------

class AlertBanner extends StatelessWidget {
  final String icon;
  final Color tint;
  final Color bg;
  final String title;
  final String sub;
  final VoidCallback? onTap;

  const AlertBanner({
    super.key,
    required this.icon,
    required this.tint,
    required this.bg,
    required this.title,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title. $sub',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tint.withValues(alpha: .22)),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 20, color: tint, sw: 1.9),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: tint)),
                    const SizedBox(height: 1),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink2)),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 20, color: tint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keyboard-shortcut hint chip, e.g. `KeyHint('F2')`.
class KeyHint extends StatelessWidget {
  final String keys;

  const KeyHint(this.keys, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(keys,
          style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.ink2,
              height: 1.2)),
    );
  }
}

// --------------------------------------------------------------------------
// Second-pass additions (additive only)
// --------------------------------------------------------------------------

/// Responsive grid of KPI cards: 2 columns on phones, up to 4 on wide screens.
class KpiGrid extends StatelessWidget {
  final List<Widget> children;
  const KpiGrid(this.children, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final avail = c.maxWidth.isFinite ? c.maxWidth : 360.0;
      final cols = avail >= 860 ? math.min(4, math.max(1, children.length)) : 2;
      final w = (avail - 10 * (cols - 1)) / cols;
      // Rows of equal-height tiles: a card with a delta chip / sparkline is
      // taller than a plain one, and a ragged Wrap looked distorted.
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        final slice = children.skip(i).take(cols).toList();
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < slice.length; j++) ...[
                if (j > 0) const SizedBox(width: 10),
                SizedBox(width: w, child: slice[j]),
              ],
            ],
          ),
        ));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    });
  }
}

/// Rounded card shell for a wide-screen table: [header] on top, [rows] below.
class TableCard extends StatelessWidget {
  final Widget header;
  final List<Widget> rows;
  const TableCard({super.key, required this.header, required this.rows});

  @override
  Widget build(BuildContext context) {
    final pal = SectionPalette.forRoute(Nav.instance.route);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.accent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
              color: pal.accent.withValues(alpha: .10),
              offset: const Offset(0, 8),
              blurRadius: 22),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [pal.accent, pal.glow]),
            ),
          ),
          header,
          ...rows,
        ],
      ),
    );
  }
}

/// Small coloured status chip (text only) for table cells.
class StatusChip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const StatusChip(this.label,
      {super.key, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bg, bg.withValues(alpha: .55)]),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: .22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.2)),
        ),
      ]),
    );
  }
}

/// Shimmering list placeholder for admin screens that wait on the backend,
/// falling back to [fallback] (empty / error state) after [seconds].
class AdminLoadingOrElse extends StatefulWidget {
  final Widget fallback;
  final int rows;
  final int seconds;
  const AdminLoadingOrElse(
      {super.key, required this.fallback, this.rows = 4, this.seconds = 5});

  @override
  State<AdminLoadingOrElse> createState() => _AdminLoadingOrElseState();
}

class _AdminLoadingOrElseState extends State<AdminLoadingOrElse> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: widget.seconds), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.fallback;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: SkeletonRows(rows: widget.rows),
    );
  }
}

/// Sticky bottom action bar for admin edit screens. Sits at the bottom of the
/// screen Column, leaving room for the floating admin nav on phones.
class AdminSaveBar extends StatelessWidget {
  final Widget child;
  const AdminSaveBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= 900;
    final inset = mq.size.width <= 360 ? 9.0 : 11.0;
    final navClear = wide ? 0.0 : 72 + inset + mq.padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + navClear),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: child,
    );
  }
}
