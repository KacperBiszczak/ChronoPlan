import '../../../core/services/api_client.dart';
import '../models/date_option_model.dart';

class DateVoteService {
  final _dio = ApiClient.dio;

  Future<List<DateOptionModel>> getOptionsByEvent(int eventId) async {
    final response = await _dio.get('/date-votes/event/$eventId');

    final data = response.data as List;

    return data.map((item) => DateOptionModel.fromJson(item)).toList();
  }

  Future<DateOptionModel> createOption({
    required int eventId,
    required DateTime proposedDate,
  }) async {
    final response = await _dio.post(
      '/date-votes/options',
      data: {
        'eventId': eventId,
        'proposedDate': proposedDate.toUtc().toIso8601String(),
      },
    );

    return DateOptionModel.fromJson(response.data);
  }

  Future<void> vote({
    required int optionId,
    required String status,
  }) async {
    await _dio.patch(
      '/date-votes/options/$optionId/vote',
      data: {
        'status': status,
      },
    );
  }

  Future<void> deleteOption(int optionId) async {
    await _dio.delete('/date-votes/options/$optionId');
  }
}