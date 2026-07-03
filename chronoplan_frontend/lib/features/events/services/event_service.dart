import '../../../core/services/api_client.dart';
import '../models/event_model.dart';

class EventService {
  final _dio = ApiClient.dio;

  Future<List<EventModel>> getEvents() async {
    final response = await _dio.get('/events');

    final data = response.data as List;

    return data.map((item) => EventModel.fromJson(item)).toList();
  }

  Future<EventModel> getEventById(int id) async {
    final response = await _dio.get('/events/$id');

    return EventModel.fromJson(response.data);
  }

  Future<EventModel> createEvent({
    required String title,
    required String? description,
    required DateTime date,
    String budgetMode = 'SHARED',
    String? locationName,
    String? locationAddress,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.post(
      '/events',
      data: {
        'title': title,
        'description': description,
        'date': date.toUtc().toIso8601String(),
        'budgetMode': budgetMode,
        'locationName': locationName,
        'locationAddress': locationAddress,
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    return EventModel.fromJson(response.data);
  }

  Future<EventModel> updateEvent({
    required int id,
    required String title,
    required String? description,
    required DateTime date,
    String? budgetMode,
    String? locationName,
    String? locationAddress,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.put(
      '/events/$id',
      data: {
        'title': title,
        'description': description,
        'date': date.toUtc().toIso8601String(),
        'budgetMode': ?budgetMode,
        'locationName': locationName,
        'locationAddress': locationAddress,
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    return EventModel.fromJson(response.data);
  }

  Future<void> deleteEvent(int id) async {
    await _dio.delete('/events/$id');
  }
}