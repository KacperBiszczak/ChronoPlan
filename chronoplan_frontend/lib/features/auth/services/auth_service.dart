import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_client.dart';

class AuthService {
  final _dio = ApiClient.dio;
  final _storage = const FlutterSecureStorage();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final token = response.data['token'];

    if (token == null) {
      throw Exception('Brak tokenu w odpowiedzi serwera');
    }

    await _storage.write(
      key: 'token',
      value: token,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _dio.post(
      '/users',
      data: {
        'name': name,
        'email': email,
        'password': password,
      },
    );
  }

  Future<String?> getToken() async {
    return _storage.read(key: 'token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
  }
}