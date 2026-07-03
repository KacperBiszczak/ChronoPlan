import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'error_message.dart';

class AppSnackBar {
  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline,
      backgroundColor: AppTheme.success,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.info_outline,
      backgroundColor: AppTheme.primaryDark,
    );
  }

  static void error(
    BuildContext context,
    Object error, {
    String fallback = 'Wystąpił błąd',
  }) {
    _show(
      context,
      AppErrorMessage.from(error, fallback: fallback),
      icon: Icons.error_outline,
      backgroundColor: AppTheme.danger,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          showCloseIcon: true,
          closeIconColor: Colors.white,
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
