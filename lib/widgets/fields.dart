import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nav/nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import '../state/gu_strings.dart';

/// `.field` — label + input + error line (`.error`).
class AppField extends StatefulWidget {
  final String? label;
  final String value;
  final ValueChanged<String>? onChanged;
  final String? placeholder;
  final String? error;
  final TextInputType keyboardType;
  final bool readOnly;
  final bool uppercase;
  final int? maxLength;
  final Widget? suffix;
  final Widget? prefix;
  final bool numeric;
  final bool autofocus;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final VoidCallback? onEditingComplete;
  final TextInputAction? textInputAction;
  final bool obscure;

  const AppField({
    super.key,
    this.label,
    this.value = '',
    this.onChanged,
    this.placeholder,
    this.error,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.uppercase = false,
    this.maxLength,
    this.suffix,
    this.prefix,
    this.numeric = false,
    this.autofocus = false,
    this.controller,
    this.focusNode,
    this.onEditingComplete,
    this.textInputAction,
    this.obscure = false,
  });

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  bool _focused = false;

  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant AppField old) {
    super.didUpdateWidget(old);
    // Only push the incoming value when it genuinely differs from what the
    // field already shows. `TextEditingController.text = x` resets the
    // selection to `collapsed(-1)`, so calling it on every keystroke (the
    // old `old.value != widget.value` check) threw the cursor away and made
    // the browser drop the previously typed character — you could never get
    // more than one letter into a field.
    // Only push the incoming value when it genuinely differs from what the
    // field already shows. `TextEditingController.text = x` re-writes the
    // whole editing value and marks the selection invalid (`collapsed(-1)`),
    // which is pushed to the platform input connection — on web that makes
    // the browser drop the previously typed character, so a field would only
    // ever keep the last letter typed.
    if (widget.controller == null && widget.value != _ctrl.text) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invalid = widget.error != null && widget.error!.isNotEmpty;
    final pal = SectionPalette.forRoute(Nav.instance.route);
    final accent = pal.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            gt(widget.label!),
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: invalid
                  ? AppColors.red
                  : (_focused ? accent : AppColors.ink),
            ),
          ),
          const SizedBox(height: 7),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.white,
                _focused
                    ? pal.tint.withValues(alpha: .55)
                    : const Color(0xFFF8F9FE)
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
            border: Border.all(
                color: invalid
                    ? AppColors.red
                    : (_focused ? accent : const Color(0xFFD9DDF0)),
                width: _focused || invalid ? 1.6 : 1),
            boxShadow: _focused
                ? [
                    BoxShadow(
                        color: accent.withValues(alpha: .22),
                        blurRadius: 14,
                        spreadRadius: 1)
                  ]
                : AppColors.sh1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (f) => setState(() => _focused = f),
            child: Row(
            children: [
              if (widget.prefix != null) ...[
                widget.prefix!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  readOnly: widget.readOnly,
                  obscureText: widget.obscure,
                  maxLength: widget.maxLength,
                  keyboardType: widget.numeric
                      ? TextInputType.number
                      : widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  inputFormatters: [
                    if (widget.uppercase)
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    if (widget.numeric)
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    if (widget.numeric)
                      LengthLimitingTextInputFormatter(widget.maxLength),
                  ],
                  onChanged: widget.onChanged,
                  onEditingComplete: widget.onEditingComplete,
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: widget.uppercase ? .6 : 0,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.placeholder == null ? null : gt(widget.placeholder!),
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 8),
                widget.suffix!,
              ],
            ],
          ),
          ),
        ),
        if (invalid) ...[
          const SizedBox(height: 6),
          Text(
            widget.error!,
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.red,
            ),
          ),
        ],
      ],
    );
  }
}

/// Select-style field (`.field--select`) — shows value + chevron, tap opens.
class SelectField extends StatelessWidget {
  final String? label;
  final String value;
  final VoidCallback? onTap;
  final String? placeholder;

  const SelectField({
    super.key,
    this.label,
    required this.value,
    this.onTap,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            gt(label!),
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.white, Color(0xFFF8F9FE)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
              border: Border.all(color: const Color(0xFFD9DDF0)),
              boxShadow: AppColors.sh1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? (placeholder ?? '') : value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          value.isEmpty ? AppColors.ink3 : AppColors.ink,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: SectionPalette.forRoute(Nav.instance.route).tint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AppIcon('down',
                        size: 14,
                        color: SectionPalette.forRoute(Nav.instance.route)
                            .accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// `+91` phone input from the sign-in screen.
class PhoneField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;

  const PhoneField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '98765 43210',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.sh1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            '+91',
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink2,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.line,
          ),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                border: InputBorder.none,
                hintText: placeholder == null ? null : gt(placeholder!),
                hintStyle: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink3,
                  letterSpacing: 0,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'\d')),
              ],
              onChanged: (v) => onChanged(v),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4-box OTP row (`.otp-row`).
class OtpRow extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final List<TextEditingController> controllers;

  /// Highlights every box red (e.g. wrong / rejected code).
  final bool error;

  const OtpRow({
    super.key,
    required this.controllers,
    required this.onCompleted,
    this.error = false,
  });

  @override
  State<OtpRow> createState() => _OtpRowState();
}

class _OtpRowState extends State<OtpRow> {
  // One focus node per box; the box count follows the controllers list so the
  // same row serves the 4-digit email OTP and the 5-digit mobile (SMS) OTP.
  late List<FocusNode> _nodes =
      List.generate(widget.controllers.length, (_) => FocusNode());

  @override
  void didUpdateWidget(covariant OtpRow old) {
    super.didUpdateWidget(old);
    if (old.controllers.length != widget.controllers.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes = List.generate(widget.controllers.length, (_) => FocusNode());
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.controllers.length;
    if (len == 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(len, (i) {
        return Expanded(
          child: AnimatedBuilder(
            animation:
                Listenable.merge([_nodes[i], widget.controllers[i]]),
            builder: (context, child) {
              final focused = _nodes[i].hasFocus;
              final filled = widget.controllers[i].text.isNotEmpty;
              final Color border = widget.error
                  ? AppColors.red
                  : focused
                      ? AppColors.navy2
                      : filled
                          ? AppColors.ink3
                          : AppColors.line;
              return Container(
            margin: EdgeInsets.only(right: i == len - 1 ? 0 : 10),
            height: 56,
            decoration: BoxDecoration(
              color: widget.error
                  ? AppColors.redTint
                  : (filled ? AppColors.navyTint : AppColors.white),
              borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
              border: Border.all(
                  color: border, width: (focused || widget.error) ? 2 : 1.2),
              boxShadow: focused ? AppColors.sh2 : AppColors.sh1,
            ),
            child: child,
              );
            },
            child: Center(
              child: SizedBox(
                width: 28,
                child: TextField(
                  controller: widget.controllers[i],
                  focusNode: _nodes[i],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
                  onChanged: (v) {
                    if (v.isEmpty && i > 0) {
                      _nodes[i - 1].requestFocus();
                    } else if (v.isNotEmpty && i < len - 1) {
                      _nodes[i + 1].requestFocus();
                    } else if (v.isNotEmpty && i == len - 1) {
                      _nodes[i].unfocus();
                    }
                    final code = widget.controllers.map((c) => c.text).join();
                    if (code.length == len) widget.onCompleted(code);
                  },
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}


/// Short fields side by side on one line (2 or 3), so forms stay compact.
/// Each child keeps its own label and error line. [flex] gives uneven widths
/// (for example `[2, 1]`). When the available width is under [minWidth] the
/// children stack vertically again so nothing gets cramped on small phones.
class FieldRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double gap;
  final double minWidth;

  const FieldRow({
    super.key,
    required this.children,
    this.flex,
    this.gap = 10,
    this.minWidth = 300,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth.isFinite && c.maxWidth < minWidth;
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
                flex: (flex != null && i < flex!.length) ? flex![i] : 1,
                child: children[i]),
          ],
        ],
      );
    });
  }
}
