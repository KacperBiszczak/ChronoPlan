import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../constants/api_constants.dart';
import '../router/root_navigator_key.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();

  static final Dio dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;

          final isUnauthorized = statusCode == 401;

          final isAuthRequest =
              path == '/auth/login' || path == '/users';

          if (isUnauthorized && !isAuthRequest) {
            await _storage.delete(key: 'token');

            final navigatorContext = rootNavigatorKey.currentContext;

            if (navigatorContext != null && navigatorContext.mounted) {
              navigatorContext.go('/login');
            }
          }

          handler.next(error);
        },
      ),
    );

    return dio;
  }
}