import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_client.dart';
import '../models/user_model.dart';

class AuthService {
  final _dio = ApiClient.dio;
  final _storage = const FlutterSecureStorage();
  final String baseUrl = 'http://127.0.0.1:5000';

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

  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get('/auth/me');

    return UserModel.fromJson(response.data);
  }

  Future<UserModel> updateProfile({
    required String name,
    required String email,
    required String? avatarUrl,
    required String? phone,
    required String? bio,
  }) async {
    final response = await _dio.patch(
      '/auth/me',
      data: {
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'phone': phone,
        'bio': bio,
      },
    );

    return UserModel.fromJson(response.data);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      await getCurrentUser();

      return true;
    } catch (_) {
      await logout();

      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
  }
}