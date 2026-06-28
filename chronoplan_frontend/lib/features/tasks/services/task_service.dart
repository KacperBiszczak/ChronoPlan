import '../../../core/services/api_client.dart';
import '../models/task_model.dart';

class TaskService {
  final _dio = ApiClient.dio;

  Future<List<TaskModel>> getTasksByEvent(int eventId) async {
    final response = await _dio.get('/tasks/event/$eventId');

    final data = response.data as List;

    return data.map((item) => TaskModel.fromJson(item)).toList();
  }

  Future<List<TaskModel>> getMyTasks() async {
    final response = await _dio.get('/tasks/my');

    final data = response.data as List;

    return data.map((item) => TaskModel.fromJson(item)).toList();
  }

  Future<TaskModel> createTask({
    required String title,
    required String? description,
    required int eventId,
    required int? assigneeId,
  }) async {
    final response = await _dio.post(
      '/tasks',
      data: {
        'title': title,
        'description': description,
        'eventId': eventId,
        'assigneeId': assigneeId,
      },
    );

    return TaskModel.fromJson(response.data);
  }

  Future<TaskModel> updateTask({
    required int taskId,
    required String title,
    required String? description,
    required int? assigneeId,
  }) async {
    final response = await _dio.patch(
      '/tasks/$taskId',
      data: {
        'title': title,
        'description': description,
        'assigneeId': assigneeId,
      },
    );

    return TaskModel.fromJson(response.data);
  }

  Future<TaskModel> updateTaskStatus({
    required int taskId,
    required String status,
  }) async {
    final response = await _dio.patch(
      '/tasks/$taskId/status',
      data: {
        'status': status,
      },
    );

    return TaskModel.fromJson(response.data);
  }

  Future<void> deleteTask(int taskId) async {
    await _dio.delete('/tasks/$taskId');
  }
}