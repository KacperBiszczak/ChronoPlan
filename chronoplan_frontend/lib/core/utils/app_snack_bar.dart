import 'package:flutter/material.dart';

import 'error_message.dart';

class AppSnackBar {
  static void success(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  static void error(
    BuildContext context,
    Object error, {
    String fallback = 'Wystąpił błąd',
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppErrorMessage.from(
            error,
            fallback: fallback,
          ),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  static void info(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}