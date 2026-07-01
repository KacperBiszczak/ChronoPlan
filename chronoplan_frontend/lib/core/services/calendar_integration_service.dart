import 'package:url_launcher/url_launcher.dart';

import '../../features/events/models/event_model.dart';

class CalendarIntegrationService {
  static String _googleDate(DateTime date) {
    final utc = date.toUtc();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${utc.year}'
        '${twoDigits(utc.month)}'
        '${twoDigits(utc.day)}'
        'T'
        '${twoDigits(utc.hour)}'
        '${twoDigits(utc.minute)}'
        '${twoDigits(utc.second)}'
        'Z';
  }

  static Future<void> openGoogleCalendar(EventModel event) async {
    final startDate = event.date;
    final endDate = event.date.add(const Duration(hours: 1));

    final locationParts = [
      event.locationName,
      event.locationAddress,
    ].where((value) => value != null && value.trim().isNotEmpty).join(', ');

    final details = event.description?.trim().isNotEmpty == true
        ? event.description!
        : 'Wydarzenie utworzone w ChronoPlan';

    final uri = Uri.https(
      'calendar.google.com',
      '/calendar/render',
      {
        'action': 'TEMPLATE',
        'text': event.title,
        'dates': '${_googleDate(startDate)}/${_googleDate(endDate)}',
        'details': details,
        if (locationParts.isNotEmpty) 'location': locationParts,
      },
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Nie udało się otworzyć Google Calendar');
    }
  }
}