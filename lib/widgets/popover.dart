import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nav/nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../state/gu_strings.dart';
import 'app_icon.dart';

/// Width from which top-bar panels open as a dropdown under their button;
/// below it they open as a bottom sheet (phone layout).
const double kPopoverBreakpoint = 900;

RawDialogRoute<void>? _activePopover;
Object? _activeTag;

/// Closes the dropdown panel that is currently open, if any. Safe to call
/// when nothing is open.
void closeActivePopover() {
  final r = _activePopover;
  _activePopover = null;
  _activeTag = null;
  if (r != null && r.isActive) r.navigator?.removeRoute(r);
}

/// True while a dropdown panel is open.
bool get popoverIsOpen => _activePopover?.isActive == true;

/// Opens a top-bar panel anchored to [anchor]'s widget.
///
/// * width >= 900: a dropdown under the button — [width] wide, at most
///   [maxHeightFactor] of the window tall, kept inside the window edges,
///   closed by an outside click, Esc, or tapping the same button again.
/// * narrower: a bottom sheet capped to the space below the top bar, with the
///   bottom safe area applied.
///
/// [builder] returns the panel body (usually a [PanelShell]); it must size
/// itself with `mainAxisSize.min` and scroll inside a `Flexible`.
Future<void> showTopBarPanel({
  required BuildContext anchor,
  required Object tag,
  required Widget Function(BuildContext context) builder,
  double width = 400,
  double maxHeightFactor = .7,
}) async {
  final nav = rootNavKey.currentState;
  if (nav == null) return;
  final winW = MediaQuery.sizeOf(anchor).width;
  if (winW >= kPopoverBreakpoint) {
    if (_activeTag == tag && popoverIsOpen) {
      closeActivePopover();
      return;
    }
    closeActivePopover();
    Rect? rect;
    final box = anchor.findRenderObject();
    final overlayBox = nav.overlay?.context.findRenderObject();
    if (box is RenderBox &&
        box.attached &&
        overlayBox is RenderBox &&
        overlayBox.attached) {
      rect = overlayBox.globalToLocal(box.localToGlobal(Offset.zero)) &
          box.size;
    }
    final route = RawDialogRoute<void>(
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: gt('Close'),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (ctx, a, b) => _PopoverPage(
        anchorRect: rect,
        width: width,
        maxHeightFactor: maxHeightFactor,
        child: builder(ctx),
      ),
      transitionBuilder: (ctx, a, b, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: child,
      ),
    );
    _activePopover = route;
    _activeTag = tag;
    await nav.push(route);
    if (identical(_activePopover, route)) {
      _activePopover = null;
      _activeTag = null;
    }
    return;
  }

  closeActivePopover();
  final ctx = rootSheetContext;
  if (ctx == null) return;
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x6614162B),
    builder: (c) => LayoutBuilder(
      builder: (c, cons) {
        final safeBottom = MediaQuery.of(c).padding.bottom;
        final maxH = cons.maxHeight.isFinite
            ? cons.maxHeight - 8
            : MediaQuery.sizeOf(c).height * .8;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(160.0, maxH)),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.ink3.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: safeBottom),
                    child: Material(
                      color: Colors.transparent,
                      child: builder(c),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PopoverPage extends StatelessWidget {
  final Rect? anchorRect;
  final double width;
  final double maxHeightFactor;
  final Widget child;

  const _PopoverPage({
    required this.anchorRect,
    required this.width,
    required this.maxHeightFactor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final maxH = c.maxHeight;
        final w = math.max(240.0, math.min(width, maxW - 16));
        final rect = anchorRect;
        var left = rect != null ? rect.right - w : maxW - w - 8;
        left = left.clamp(8.0, math.max(8.0, maxW - w - 8)).toDouble();
        final top = rect != null ? math.max(8.0, rect.bottom + 8) : 8.0;
        final avail = maxH - top - 8;
        final cap = MediaQuery.sizeOf(context).height * maxHeightFactor;
        final mh = math.max(140.0, math.min(avail, cap));
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: w,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: mh),
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () =>
                        Navigator.of(context).maybePop(),
                  },
                  child: Focus(
                    autofocus: true,
                    child: Material(
                      color: AppColors.white,
                      elevation: 14,
                      shadowColor: const Color(0x4014162B),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shared frame for top-bar panels: a pinned header (title, sub, optional
/// trailing action, close), a scrolling body and an optional pinned footer.
/// Works inside a dropdown and inside a bottom sheet; never unbounded.
class PanelShell extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  final Widget child;
  final Widget? footer;
  final EdgeInsets bodyPadding;

  const PanelShell({
    super.key,
    required this.title,
    this.sub,
    this.trailing,
    required this.child,
    this.footer,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gt(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (sub != null && sub!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          gt(sub!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: gt('Close'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: AppIcon('close', size: 16, color: AppColors.ink2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.line),
        Flexible(
          child: SingleChildScrollView(
            padding: bodyPadding,
            child: child,
          ),
        ),
        if (footer != null) ...[
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: footer,
          ),
        ],
      ],
    );
  }
}
