import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

TextStyle labelText(double size, FontWeight w, [Color c = AppColors.ink]) =>
    TextStyle(
        fontFamily: AppTheme.uiFont, fontSize: size, fontWeight: w, color: c);

/// Error text for a failed call (server message, plus reference on 5xx).
String labelError(Object e) {
  if (e is ApiException) return e.messageWithRef;
  return gt('Could not reach the server. Please try again.');
}

const labelModes = ['PDF', 'TSPL', 'ZPL', 'ESCPOS', 'JSON'];

String labelModeName(String m) {
  switch (m) {
    case 'PDF':
      return 'PDF';
    case 'TSPL':
      return 'TSPL';
    case 'ZPL':
      return 'ZPL';
    case 'ESCPOS':
      return 'ESC/POS';
    case 'JSON':
      return gt('Draw in app (JSON)');
  }
  return m;
}

/// Small bold section label above a control.
class LabelCaption extends StatelessWidget {
  final String text;
  const LabelCaption(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(gt(text), style: labelText(13, FontWeight.w800)),
      );
}

/// `2026-11-09` for the wire.
String labelDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
