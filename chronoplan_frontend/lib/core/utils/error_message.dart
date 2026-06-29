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
      }

      if (responseData is String && responseData.trim().isNotEmpty) {
        return responseData;
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Przekroczono czas połączenia z serwerem';

        case DioExceptionType.connectionError:
          return 'Nie można połączyć się z serwerem';

        case DioExceptionType.badResponse:
          return fallback;

        case DioExceptionType.cancel:
          return 'Żądanie zostało anulowane';

        case DioExceptionType.badCertificate:
          return 'Problem z certyfikatem serwera';

        case DioExceptionType.unknown:
          return fallback;
      }
    }

    return fallback;
  }
}