import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

class GoogleCalendarService {
  final _dio = ApiClient.dio;

  Future<bool> getStatus() async {
    final response = await _dio.get('/google-calendar/status');

    return response.data['connected'] == true;
  }

  Future<void> connectGoogleCalendar({
    String returnPath = '/home',
  }) async {
    final response = await _dio.get(
      '/google-calendar/auth-url',
      queryParameters: {
        'returnPath': returnPath,
      },
    );

    final url = response.data['url'];

    if (url == null || url is! String || url.isEmpty) {
      throw Exception('Brak linku autoryzacji Google Calendar');
    }

    final uri = Uri.parse(url);

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception('Nie udało się otworzyć autoryzacji Google Calendar');
    }
  }

  Future<void> syncEvent(int eventId) async {
    await _dio.post('/google-calendar/sync-event/$eventId');
  }
  
  Future<void> deleteSyncedEvent(int eventId) async {
    await _dio.delete('/google-calendar/delete-event/$eventId');
  }

  Future<void> disconnectGoogleCalendar() async {
    await _dio.delete('/google-calendar/disconnect');
  }
}