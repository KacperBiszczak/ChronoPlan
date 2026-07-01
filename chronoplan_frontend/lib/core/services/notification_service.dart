import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../router/root_navigator_key.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
      
  static void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    final context = rootNavigatorKey.currentContext;

    if (context == null) {
      return;
    }

    context.go(payload);
  }

  static Future<void> init() async {
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    await requestPermissions();
  }

  static Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) {
      return;
    }

    tz.initializeTimeZones();

    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(
        tz.getLocation(timeZoneInfo.identifier),
      );
    } catch (_) {
      // Jeśli nie uda się pobrać strefy, timezone zostanie z domyślną konfiguracją.
    }
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static int eventReminderId(int eventId) {
    return 500000 + eventId;
  }

  static Future<void> scheduleEventReminder({
    required int eventId,
    required String eventTitle,
    required DateTime eventDate,
  }) async {
    if (kIsWeb) {
      return;
    }

    final reminderDate = eventDate.subtract(
      const Duration(hours: 1),
    );

    if (reminderDate.isBefore(DateTime.now())) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(
      reminderDate,
      tz.local,
    );

    await _plugin.zonedSchedule(
      id: eventReminderId(eventId),
      title: 'ChronoPlan',
      body: 'Wydarzenie "$eventTitle" rozpoczyna się za godzinę.',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_reminders',
          'Przypomnienia wydarzeń',
          channelDescription: 'Powiadomienia przypominające o wydarzeniach',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/events/$eventId',
    );
  }

  static Future<void> cancelEventReminder(int eventId) async {
    await _plugin.cancel(
      id: eventReminderId(eventId),
    );
  }
}