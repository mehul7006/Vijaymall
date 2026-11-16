import 'package:flutter/material.dart';

/// Layout helpers for the customer pages on a computer screen (>= 1000px).
class CustomerWide {
  CustomerWide._();

  static const double breakpoint = 1000;

  static bool on(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpoint;

  /// 1 column below 1000, 2 up to 1500, 3 beyond (for card lists).
  static int listCols(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1500) return 3;
    return 2;
  }
}

/// Lays [items] out in [cols] equal columns, filling row by row so the order
/// reads left to right. Each column is as tall as its content.
class WideColumns extends StatelessWidget {
  final List<Widget> items;
  final int cols;
  final double gap;

  const WideColumns({
    super.key,
    required this.items,
    this.cols = 2,
    this.gap = 14,
  });

  @override
  Widget build(BuildContext context) {
    final n = cols < 1 ? 1 : cols;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < n; c++) ...[
          if (c > 0) SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = c; i < items.length; i += n) ...[
                  if (i >= n) SizedBox(height: gap),
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Main area + fixed-width side column (side column is top aligned).
class CustomerSplit extends StatelessWidget {
  final Widget main;
  final Widget side;
  final double sideWidth;
  final double gap;
  final bool sideFirst;

  const CustomerSplit({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 380,
    this.gap = 22,
    this.sideFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final mainW = Expanded(child: main);
    final sideW = SizedBox(width: sideWidth, child: side);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sideFirst
          ? [sideW, SizedBox(width: gap), mainW]
          : [mainW, SizedBox(width: gap), sideW],
    );
  }
}
