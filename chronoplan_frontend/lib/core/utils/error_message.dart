import 'package:dio/dio.dart';

class AppErrorMessage {
  static String from(
    Object error, {
    String fallback = 'Wystąpił błąd',
  }) {
    if (error is DioException) {
      final responseData = error.response?.data;

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];

        if (message is String && message.trim().isNotEmpty) {
          return message;
        }

        final errorText = responseData['error'];

        if (errorText is String && errorText.trim().isNotEmpty) {
          return errorText;
        }
      }

      if (responseData is String && responseData.trim().isNotEmpty) {
        return responseData;
      }

      final dioMessage = error.message;

      if (dioMessage != null && dioMessage.trim().isNotEmpty) {
        return dioMessage;
      }
    }

    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '');

      if (message.trim().isNotEmpty) {
        return message;
      }
    }

    final message = error.toString();

    if (message.trim().isNotEmpty && message != 'null') {
      return message;
    }

    return fallback;
  }
}