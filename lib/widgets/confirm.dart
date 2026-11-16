import 'package:flutter/material.dart';

import '../state/gu_strings.dart';
import '../theme/app_colors.dart';

/// Yes/no dialog (the caller passes [body] already translated) for actions that are hard to undo. Resolves to true only when
/// the confirm button is pressed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(gt(title)),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(gt('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(gt(confirmLabel),
              style: const TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
  return ok == true;
}
