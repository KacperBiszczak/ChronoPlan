import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_client.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final _dio = ApiClient.dio;
  final _storage = const FlutterSecureStorage();

  Future<String> _getToken() async {
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Brak tokenu użytkownika');
    }

    return token;
  }

  Future<List<ExpenseModel>> getExpensesByEvent(int eventId) async {
    final token = await _getToken();

    final response = await _dio.get(
      '/expenses/event/$eventId',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as List;

    return data.map((item) => ExpenseModel.fromJson(item)).toList();
  }

  Future<double> getExpenseSummary(int eventId) async {
    final token = await _getToken();

    final response = await _dio.get(
      '/expenses/event/$eventId/summary',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return (response.data['totalExpenses'] as num).toDouble();
  }

  Future<ExpenseModel> createExpense({
    required String title,
    required double amount,
    required int eventId,
  }) async {
    final token = await _getToken();

    final response = await _dio.post(
      '/expenses',
      data: {
        'title': title,
        'amount': amount,
        'eventId': eventId,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return ExpenseModel.fromJson(response.data);
  }

  Future<void> deleteExpense(int id) async {
    final token = await _getToken();

    await _dio.delete(
      '/expenses/$id',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  Future<ExpenseModel> updateExpense({
    required int id,
    required String title,
    required double amount,
  }) async {
    final token = await _getToken();

    final response = await _dio.patch(
      '/expenses/$id',
      data: {
        'title': title,
        'amount': amount,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return ExpenseModel.fromJson(response.data);
  }
}