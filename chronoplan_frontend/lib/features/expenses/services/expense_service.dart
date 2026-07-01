import '../../../core/services/api_client.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final _dio = ApiClient.dio;

  Future<List<ExpenseModel>> getExpensesByEvent(int eventId) async {
    final response = await _dio.get('/expenses/event/$eventId');

    final data = response.data as List;

    return data.map((item) => ExpenseModel.fromJson(item)).toList();
  }

  Future<double> getExpenseSummary(int eventId) async {
    final summary = await getExpenseSummaryDetails(eventId);

    return summary.totalExpenses;
  }

  Future<ExpenseSummaryModel> getExpenseSummaryDetails(int eventId) async {
    final response = await _dio.get('/expenses/event/$eventId/summary');

    return ExpenseSummaryModel.fromJson(response.data);
  }

  Future<ExpenseModel> createExpense({
    required String title,
    required double amount,
    required int eventId,
    int? paidById,
  }) async {
    final response = await _dio.post(
      '/expenses',
      data: {
        'title': title,
        'amount': amount,
        'eventId': eventId,
        'paidById': paidById,
      },
    );

    return ExpenseModel.fromJson(response.data);
  }

  Future<ExpenseModel> updateExpense({
    required int id,
    required String title,
    required double amount,
    int? paidById,
  }) async {
    final response = await _dio.patch(
      '/expenses/$id',
      data: {
        'title': title,
        'amount': amount,
        'paidById': paidById,
      },
    );

    return ExpenseModel.fromJson(response.data);
  }

  Future<void> deleteExpense(int id) async {
    await _dio.delete('/expenses/$id');
  }
}