import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';

import '../nav/nav.dart';
import '../theme/app_colors.dart';

/// Soft multi-colour page background: a pastel gradient, two blurred colour
/// blobs that follow the section colour, and a very light dot pattern.
/// Colour only; it never changes layout.
class RichBackdrop extends StatelessWidget {
  final Widget child;
  const RichBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final pal = SectionPalette.forRoute(Nav.instance.route);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFECF0FF), Color(0xFFF7F4FC), Color(0xFFFFF4E8)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, -0.9),
              radius: 0.9,
              colors: [
                pal.accent.withValues(alpha: .16),
                pal.accent.withValues(alpha: 0)
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.0, 1.0),
              radius: 0.9,
              colors: [
                pal.glow.withValues(alpha: .20),
                pal.glow.withValues(alpha: 0)
              ],
            ),
          ),
        ),
        const IgnorePointer(child: CustomPaint(painter: DotPatternPainter())),
        child,
      ],
    );
  }
}

/// Light dotted grid (or [lines] for a diagonal weave) used on dark chrome too.
class DotPatternPainter extends CustomPainter {
  final Color color;
  final double step;
  final bool lines;
  const DotPatternPainter(
      {this.color = const Color(0x0F1F2A6B), this.step = 22, this.lines = false});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = lines ? 1 : 2.2
      ..strokeCap = StrokeCap.round;
    if (lines) {
      for (double x = -size.height; x < size.width; x += step) {
        canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
      }
      return;
    }
    final pts = <Offset>[];
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        pts.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, pts, p);
  }

  @override
  bool shouldRepaint(covariant DotPatternPainter old) =>
      old.color != color || old.step != step || old.lines != lines;
}
