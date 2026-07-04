import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_client.dart';
import '../models/user_model.dart';

class AuthService {
  final _dio = ApiClient.dio;
  final _storage = const FlutterSecureStorage();
  final String baseUrl = 'http://127.0.0.1:5000';

  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final token = response.data['token'];

    if (token == null) {
      throw Exception('Brak tokenu w odpowiedzi serwera');
    }

    await _storage.write(key: 'token', value: token);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _dio.post(
      '/users',
      data: {'name': name, 'email': email, 'password': password},
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
    required String? profileColor,
    required String? phone,
    required String? bio,
  }) async {
    final response = await _dio.patch(
      '/auth/me',
      data: {
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'profileColor': profileColor,
        'phone': phone,
        'bio': bio,
      },
    );

    return UserModel.fromJson(response.data);
  }

  Future<UserModel> updateProfileColor(String profileColor) async {
    final response = await _dio.patch(
      '/auth/me',
      data: {'profileColor': profileColor},
    );

    return UserModel.fromJson(response.data);
  }

  Future<UserModel> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final response = await _dio.post(
      '/auth/me/avatar',
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );

    return UserModel.fromJson(response.data);
  }

  Future<UserModel> deleteAvatar() async {
    final response = await _dio.delete('/auth/me/avatar');

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
