import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'buttons.dart';

/// Shared shimmer driver: one gradient sweep that every [SkeletonBox] below
/// it paints from, so a whole skeleton screen pulses in sync.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final t = _c.value;
            return LinearGradient(
              begin: Alignment(-1.6 + 3.2 * t, -0.3),
              end: Alignment(-0.6 + 3.2 * t, 0.3),
              colors: const [
                Color(0xFFE9EBF4),
                Color(0xFFF7F8FC),
                Color(0xFFE9EBF4),
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}

/// A flat placeholder block (painted by the ancestor [Shimmer]).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EBF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder shaped like a [ProductCard].
class ProductCardSkeleton extends StatelessWidget {
  final double width;
  const ProductCardSkeleton({super.key, this.width = 172});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 116, radius: 0),
          Padding(
            padding: EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 13, width: 110),
                SizedBox(height: 8),
                SkeletonBox(height: 10, width: 70),
                SizedBox(height: 12),
                SkeletonBox(height: 14, width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A wrap of product skeletons (matches the Wrap layout used by Home/Shop).
class ProductGridSkeleton extends StatelessWidget {
  final int count;
  final double width;
  const ProductGridSkeleton({super.key, this.count = 6, this.width = 160});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: LayoutBuilder(builder: (context, c) {
        final avail = c.maxWidth.isFinite ? c.maxWidth : 2 * width + 12;
        final cols = avail >= 900 ? 4 : (avail >= 560 ? 3 : 2);
        final w = (avail - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < count; i++) ProductCardSkeleton(width: w),
          ],
        );
      }),
    );
  }
}

/// Placeholder rows for order / ledger lists.
class ListSkeleton extends StatelessWidget {
  final int count;
  final double rowHeight;
  const ListSkeleton({super.key, this.count = 4, this.rowHeight = 92});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              height: rowHeight,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 48, height: 48, radius: 14),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 13, width: 140),
                        SizedBox(height: 9),
                        SkeletonBox(height: 10),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SkeletonBox(width: 44, height: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Press-feedback wrapper: scales down slightly while held. Keeps a minimum
/// 44x44 hit area. Pure presentation around the supplied [onTap].
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double minSize;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .96,
    this.minSize = 0,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget body = AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (widget.minSize > 0) {
      body = ConstrainedBox(
        constraints: BoxConstraints(
            minWidth: widget.minSize, minHeight: widget.minSize),
        child: Center(widthFactor: 1, heightFactor: 1, child: body),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: body,
    );
  }
}

/// Fades + slides its child up on first build; [delayMs] staggers lists.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    final total = 320 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

/// Friendly failure state with a retry action.
class ErrorState extends StatelessWidget {
  final String title;
  final String copy;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    super.key,
    this.title = "Couldn't load right now",
    this.copy = 'Check your connection and try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.redTint,
            ),
            child: const Center(
              child: AppIcon('info', size: 32, color: AppColors.red, sw: 1.8),
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
            constraints: const BoxConstraints(maxWidth: 260),
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
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            AppButton(
              gt(retryLabel),
              onTap: onRetry,
              icon: 'refresh',
              variant: BtnVariant.soft,
              size: BtnSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows [skeleton] for a few seconds (data still loading), then [fallback]
/// (empty / error state). Avoids a skeleton that never resolves.
class LoadingOrElse extends StatefulWidget {
  final Widget skeleton;
  final Widget fallback;
  final int seconds;

  const LoadingOrElse({
    super.key,
    required this.skeleton,
    required this.fallback,
    this.seconds = 6,
  });

  @override
  State<LoadingOrElse> createState() => _LoadingOrElseState();
}

class _LoadingOrElseState extends State<LoadingOrElse> {
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _done
          ? KeyedSubtree(key: const ValueKey('fb'), child: widget.fallback)
          : KeyedSubtree(key: const ValueKey('sk'), child: widget.skeleton),
    );
  }
}

/// Pull-to-refresh action for storefront screens (no-op in offline demo mode).
Future<void> refreshStorefront(AppState s) async {
  try {
    if (s.backendMode && !s.isBackendAdmin) await s.bootstrapCustomer();
  } catch (_) {}
}

/// True while a signed-in/backed storefront has not received its catalog yet.
bool storefrontLoading(AppState s) =>
    s.backendMode && s.products.isEmpty && s.apiLastError == null;
