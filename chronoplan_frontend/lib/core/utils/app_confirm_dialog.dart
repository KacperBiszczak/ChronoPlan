import 'package:flutter/material.dart';

class AppConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Potwierdź',
    String cancelText = 'Anuluj',
    bool isDanger = false,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.help_outline,
            color: isDanger ? colorScheme.error : colorScheme.primary,
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(cancelText),
            ),
            FilledButton(
              style: isDanger
                  ? FilledButton.styleFrom(backgroundColor: colorScheme.error)
                  : null,
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
