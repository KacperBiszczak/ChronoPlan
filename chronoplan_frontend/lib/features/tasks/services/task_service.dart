import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_client.dart';
import '../models/task_model.dart';

class TaskService {
  final _dio = ApiClient.dio;
  final _storage = const FlutterSecureStorage();

  Future<String> _getToken() async {
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Brak tokenu użytkownika');
    }

    return token;
  }

  Future<List<TaskModel>> getTasksByEvent(int eventId) async {
    final token = await _getToken();

    final response = await _dio.get(
      '/tasks/event/$eventId',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as List;

    return data.map((item) => TaskModel.fromJson(item)).toList();
  }

  Future<TaskModel> createTask({
    required String title,
    required String? description,
    required int eventId,
    required int? assigneeId,
  }) async {
    final token = await _getToken();

    final response = await _dio.post(
      '/tasks',
      data: {
        'title': title,
        'description': description,
        'eventId': eventId,
        'assigneeId': assigneeId,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return TaskModel.fromJson(response.data);
  }

  Future<TaskModel> updateTaskStatus({
    required int taskId,
    required String status,
  }) async {
    final token = await _getToken();

    final response = await _dio.patch(
      '/tasks/$taskId/status',
      data: {
        'status': status,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return TaskModel.fromJson(response.data);
  }
  
  Future<void> deleteTask(int taskId) async {
    final token = await _getToken();

    await _dio.delete(
      '/tasks/$taskId',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
}