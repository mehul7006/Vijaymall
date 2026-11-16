import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'store_kit.dart';

/// Responsive breakpoints shared by the customer pages.
class StoreBreakpoints {
  StoreBreakpoints._();

  static bool wide(double w) => w >= 1100;
  static bool mid(double w) => w >= 700;

  /// Number of grid columns that fit [contentWidth] with cards of at least
  /// [minCard] wide (never less than 1).
  static int gridCols(double contentWidth, {double minCard = 210}) {
    if (contentWidth <= 0 || minCard <= 0) return 1;
    final n = (contentWidth / minCard).floor();
    return n < 1 ? 1 : n;
  }
}

/// Titled horizontal shelf with round scroll arrows on wide screens.
class StoreShelf extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double itemWidth;
  final double itemGap;
  final double height;

  const StoreShelf({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.itemWidth = 200,
    this.itemGap = 12,
  });

  @override
  State<StoreShelf> createState() => _StoreShelfState();
}

class _StoreShelfState extends State<StoreShelf> {
  final ScrollController _c = ScrollController();
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant StoreShelf old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _c.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted || !_c.hasClients) return;
    final p = _c.position;
    final l = p.pixels > 2;
    final r = p.pixels < p.maxScrollExtent - 2;
    if (l != _canLeft || r != _canRight) {
      setState(() {
        _canLeft = l;
        _canRight = r;
      });
    }
  }

  void _scrollBy(int dir) {
    if (!_c.hasClients) return;
    final step = (widget.itemWidth + widget.itemGap) * 3;
    final target = (_c.offset + dir * step)
        .clamp(0.0, _c.position.maxScrollExtent)
        .toDouble();
    _c.animateTo(target,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();
    final showArrows = MediaQuery.sizeOf(context).width >= 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StoreSectionTitle(widget.title,
            subtitle: widget.subtitle,
            actionLabel: widget.actionLabel,
            onAction: widget.onAction),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                  scrollbars: false,
                ),
                child: ListView.separated(
                  controller: _c,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: widget.itemCount,
                  separatorBuilder: (_, __) => SizedBox(width: widget.itemGap),
                  itemBuilder: (ctx, i) => SizedBox(
                    width: widget.itemWidth,
                    child: widget.itemBuilder(ctx, i),
                  ),
                ),
              ),
              if (showArrows && _canLeft)
                Positioned(
                  left: -6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowBtn(left: true, onTap: () => _scrollBy(-1)),
                  ),
                ),
              if (showArrows && _canRight)
                Positioned(
                  right: -6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowBtn(left: false, onTap: () => _scrollBy(1)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final bool left;
  final VoidCallback onTap;
  const _ArrowBtn({required this.left, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x33121A47),
                  offset: Offset(0, 4),
                  blurRadius: 12),
            ],
          ),
          child: Center(
            child: Icon(
              left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 26,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Main + aside layout: side by side when wide, stacked when narrower.
class StoreTwoPane extends StatelessWidget {
  final Widget main;
  final Widget aside;
  final double asideWidth;
  final double gap;
  final double breakpoint;
  final bool hideAsideWhenNarrow;

  const StoreTwoPane({
    super.key,
    required this.main,
    required this.aside,
    this.asideWidth = 360,
    this.gap = 20,
    this.breakpoint = 1100,
    this.hideAsideWhenNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= breakpoint) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: main),
          SizedBox(width: gap),
          SizedBox(width: asideWidth, child: aside),
        ],
      );
    }
    if (hideAsideWhenNarrow) return main;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [main, SizedBox(height: gap), aside],
    );
  }
}
