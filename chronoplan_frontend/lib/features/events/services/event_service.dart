import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_client.dart';
import '../models/event_model.dart';

class EventService {
  final _dio = ApiClient.dio;
  final _storage = const FlutterSecureStorage();

  Future<String> _getToken() async {
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Brak tokenu użytkownika');
    }

    return token;
  }

  Future<List<EventModel>> getEvents() async {
    final token = await _getToken();

    final response = await _dio.get(
      '/events',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as List;

    return data.map((item) => EventModel.fromJson(item)).toList();
  }

  Future<EventModel> createEvent({
    required String title,
    required String? description,
    required DateTime date,
  }) async {
    final token = await _getToken();

    final response = await _dio.post(
      '/events',
      data: {
        'title': title,
        'description': description,
        'date': date.toUtc().toIso8601String(),
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return EventModel.fromJson(response.data);
  }
}