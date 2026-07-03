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

  Future<List<ExpenseSettlementModel>> getSettlementsByEvent(
    int eventId,
  ) async {
    final response = await _dio.get('/expenses/event/$eventId/settlements');

    final data = response.data as List;

    return data.map((item) => ExpenseSettlementModel.fromJson(item)).toList();
  }

  Future<ExpenseModel> createExpense({
    required String title,
    required double amount,
    required int eventId,
    int? paidById,
    String? category,
    String? visibility,
    String? settlementType,
  }) async {
    final response = await _dio.post(
      '/expenses',
      data: {
        'title': title,
        'amount': amount,
        'eventId': eventId,
        'paidById': paidById,
        'category': category,
        'visibility': visibility,
        'settlementType': settlementType,
      },
    );

    return ExpenseModel.fromJson(response.data);
  }

  Future<ExpenseModel> updateExpense({
    required int id,
    required String title,
    required double amount,
    int? paidById,
    String? category,
    String? visibility,
    String? settlementType,
  }) async {
    final response = await _dio.patch(
      '/expenses/$id',
      data: {
        'title': title,
        'amount': amount,
        'paidById': paidById,
        'category': category,
        'visibility': visibility,
        'settlementType': settlementType,
      },
    );

    return ExpenseModel.fromJson(response.data);
  }

  Future<void> deleteExpense(int id) async {
    await _dio.delete('/expenses/$id');
  }

  Future<ExpenseSettlementModel> markSettlementAsPaid(int id) async {
    final response = await _dio.patch('/expenses/settlements/$id/mark-paid');

    return ExpenseSettlementModel.fromJson(response.data);
  }

  Future<ExpenseSettlementModel> confirmSettlement(int id) async {
    final response = await _dio.patch('/expenses/settlements/$id/confirm');

    return ExpenseSettlementModel.fromJson(response.data);
  }

  Future<ExpenseSettlementModel> cancelSettlement(int id) async {
    final response = await _dio.patch('/expenses/settlements/$id/cancel');

    return ExpenseSettlementModel.fromJson(response.data);
  }
}
