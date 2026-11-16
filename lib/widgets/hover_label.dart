import 'dart:async';

import 'package:flutter/material.dart';

import '../nav/nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Hover label for controls that live in the site header.
///
/// The header is built in `MaterialApp.builder`, i.e. *above* the Navigator,
/// so it has no `Overlay` ancestor: a plain [Tooltip] throws there on hover and
/// takes the whole header row down with it. This label is drawn in the root
/// navigator's overlay instead, so it can never throw and is never clipped by
/// the 56-64 px bar or covered by the page content below it.
///
/// It appears after a short delay, sits under the control (above it when there
/// is no room), stays inside the window and disappears on exit, press or
/// dispose. If the overlay is not available it silently shows nothing.
class HoverLabel extends StatefulWidget {
  final String message;
  final Widget child;

  const HoverLabel({super.key, required this.message, required this.child});

  @override
  State<HoverLabel> createState() => _HoverLabelState();
}

class _HoverLabelState extends State<HoverLabel> {
  OverlayEntry? _entry;
  Timer? _delay;

  void _arm() {
    _delay?.cancel();
    _delay = Timer(const Duration(milliseconds: 350), _insert);
  }

  void _insert() {
    if (!mounted || _entry != null || widget.message.trim().isEmpty) return;
    final overlay = rootNavKey.currentState?.overlay;
    final box = context.findRenderObject();
    final overlayBox = overlay?.context.findRenderObject();
    if (overlay == null ||
        box is! RenderBox ||
        !box.attached ||
        overlayBox is! RenderBox ||
        !overlayBox.attached) {
      return;
    }
    final target =
        overlayBox.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
    final message = widget.message;
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _LabelLayout(target),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                message,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    _entry = entry;
  }

  void _hide() {
    _delay?.cancel();
    _delay = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _arm(),
      onExit: (_) => _hide(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _hide(),
        child: widget.child,
      ),
    );
  }
}

/// Places the label centred under [target]; flips above when there is no room
/// below; keeps 8 px from every window edge; never wider than the window.
class _LabelLayout extends SingleChildLayoutDelegate {
  final Rect target;

  _LabelLayout(this.target);

  static const double _gap = 6;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = (constraints.maxWidth - _margin * 2).clamp(40.0, 280.0);
    return BoxConstraints(maxWidth: maxW);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = target.center.dx - childSize.width / 2;
    final maxX = size.width - childSize.width - _margin;
    if (x > maxX) x = maxX;
    if (x < _margin) x = _margin;
    var y = target.bottom + _gap;
    if (y + childSize.height > size.height - _margin) {
      y = target.top - _gap - childSize.height;
    }
    if (y < _margin) y = _margin;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _LabelLayout old) => old.target != target;
}
