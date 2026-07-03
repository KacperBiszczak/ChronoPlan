import 'package:flutter/material.dart';

import '../../expenses/services/expense_service.dart';
import '../../participants/services/participant_service.dart';
import '../../tasks/services/task_service.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'package:go_router/go_router.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/app_confirm_dialog.dart';
import '../../../core/utils/app_snack_bar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/calendar_integration_service.dart';
import '../../../core/services/google_calendar_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final int eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final eventService = EventService();
  final authService = AuthService();
  final taskService = TaskService();
  final expenseService = ExpenseService();
  final participantService = ParticipantService();
  final googleCalendarService = GoogleCalendarService();

  late Future<GoogleCalendarEventStatus> googleCalendarStatusFuture;
  late Future<bool> reminderStatusFuture;

  bool isGoogleCalendarActionLoading = false;

  int? currentUserId;

  late Future<EventModel> eventFuture;
  late Future<EventSummaryData> summaryFuture;

  @override
  void initState() {
    super.initState();

    eventFuture = loadEvent();
    summaryFuture = loadSummary();

    loadCurrentUser();

    googleCalendarStatusFuture = googleCalendarService.getEventStatus(
      widget.eventId,
    );
    reminderStatusFuture = NotificationService.isEventReminderScheduled(
      widget.eventId,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refreshEvent() async {
    setState(() {
      eventFuture = loadEvent();
      summaryFuture = loadSummary();
    });
  }

  Future<EventModel> loadEvent() async {
    final event = await eventService.getEventById(widget.eventId);

    await rescheduleReminderIfNeeded(event);

    return event;
  }

  Future<EventSummaryData> loadSummary() async {
    final tasks = await taskService.getTasksByEvent(widget.eventId);
    final totalExpenses = await expenseService.getExpenseSummary(
      widget.eventId,
    );
    final participants = await participantService.getParticipantsByEvent(
      widget.eventId,
    );

    final todoTasks = tasks.where((task) => task.status == 'TODO').length;

    final inProgressTasks = tasks
        .where((task) => task.status == 'IN_PROGRESS')
        .length;

    final doneTasks = tasks.where((task) => task.status == 'DONE').length;

    return EventSummaryData(
      todoTasks: todoTasks,
      inProgressTasks: inProgressTasks,
      doneTasks: doneTasks,
      totalExpenses: totalExpenses,
      participantsCount: participants.length,
    );
  }

  Future<void> loadCurrentUser() async {
    try {
      final user = await authService.getCurrentUser();

      if (!mounted) return;

      setState(() {
        currentUserId = user.id;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        currentUserId = null;
      });
    }
  }

  bool isOrganizer(EventModel event) {
    return currentUserId != null && event.creatorId == currentUserId;
  }

  Future<void> leaveEvent() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Opuścić wydarzenie?',
      message:
          'Czy na pewno chcesz opuścić to wydarzenie? Nie będziesz mieć już do niego dostępu.',
      confirmText: 'Opuść',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    try {
      await participantService.leaveEvent(widget.eventId);

      if (!mounted) return;

      AppSnackBar.success(context, 'Opuszczono wydarzenie');

      context.go('/home');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się opuścić wydarzenia',
      );
    }
  }

  Future<void> deleteEvent(EventModel event) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Usuń wydarzenie',
      message:
          'Czy na pewno chcesz usunąć to wydarzenie? Usunięte zostaną też zadania, wydatki i uczestnicy.',
      confirmText: 'Usuń',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    try {
      await eventService.deleteEvent(event.id);

      try {
        await NotificationService.cancelEventReminder(event.id);
      } catch (_) {}

      if (!mounted) return;

      AppSnackBar.success(context, 'Wydarzenie zostało usunięte');

      context.go('/home');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się usunąć wydarzenia',
      );
    }
  }

  Widget buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Future<void> openLocationInMaps(EventModel event) async {
    if (event.latitude == null || event.longitude == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${event.latitude},${event.longitude}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget buildEventMap(EventModel event) {
    if (event.latitude == null || event.longitude == null) {
      return const SizedBox.shrink();
    }

    final point = LatLng(event.latitude!, event.longitude!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.chronoplan_frontend',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () {
                openLocationInMaps(event);
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Otwórz w mapach'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLocationSection(EventModel event) {
    final hasLocationName =
        event.locationName != null && event.locationName!.trim().isNotEmpty;

    final hasLocationAddress =
        event.locationAddress != null &&
        event.locationAddress!.trim().isNotEmpty;

    final hasCoordinates = event.latitude != null && event.longitude != null;

    if (!hasLocationName && !hasLocationAddress && !hasCoordinates) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Lokalizacja',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (hasLocationName) ...[
              Text(
                event.locationName!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
            ],

            if (hasLocationAddress) ...[
              Text(event.locationAddress!),
              const SizedBox(height: 6),
            ],

            if (hasCoordinates)
              Text(
                'Współrzędne: ${event.latitude!.toStringAsFixed(6)}, ${event.longitude!.toStringAsFixed(6)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildModulesSection() {
    return FutureBuilder<EventSummaryData>(
      future: summaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data;

        final tasksText = summary == null
            ? 'Ładowanie...'
            : '${summary.todoTasks} do zrobienia, '
                  '${summary.inProgressTasks} w trakcie, '
                  '${summary.doneTasks} zrobione';

        final expensesText = summary == null
            ? 'Ładowanie...'
            : 'Suma: ${AppFormatters.amount(summary.totalExpenses)}';

        final participantsText = summary == null
            ? 'Ładowanie...'
            : '${summary.participantsCount} ${summary.participantsCount == 1 ? "osoba" : (summary.participantsCount <= 4 ? "osoby" : "osób")} w wydarzeniu';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Moduły wydarzenia',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist, color: Colors.blue),
                title: const Text('Zadania'),
                subtitle: Text(tasksText),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/events/${widget.eventId}/tasks');

                  if (!mounted) return;

                  refreshEvent();
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments, color: Colors.blue),
                title: const Text('Budżet'),
                subtitle: Text(expensesText),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/events/${widget.eventId}/expenses');

                  if (!mounted) return;

                  refreshEvent();
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.group, color: Colors.blue),
                title: const Text('Uczestnicy'),
                subtitle: Text(participantsText),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/events/${widget.eventId}/participants');

                  if (!mounted) return;

                  await refreshEvent();
                  await refreshGoogleCalendarStatus();
                  await refreshReminderStatus();
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.how_to_vote_outlined,
                  color: Colors.blue,
                ),
                title: const Text('Głosowanie nad terminem'),
                subtitle: const Text('Propozycje terminów i głosy uczestników'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/events/${widget.eventId}/date-votes');

                  if (!mounted) return;

                  refreshEvent();
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.blue,
                ),
                title: const Text('Czat'),
                subtitle: const Text('Wiadomości uczestników wydarzenia'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/events/${widget.eventId}/chat');

                  if (!mounted) return;

                  refreshEvent();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventModel>(
      future: eventFuture,
      builder: (context, snapshot) {
        final event = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(event?.title ?? 'Szczegóły wydarzenia'),
            actions: [
              if (event != null && isOrganizer(event)) ...[
                IconButton(
                  onPressed: () async {
                    final updated = await context.push<bool>(
                      '/events/${widget.eventId}/edit',
                    );

                    if (!mounted) return;

                    if (updated == true) {
                      refreshEvent();
                    }
                  },
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edytuj wydarzenie',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Usuń wydarzenie',
                  onPressed: () {
                    deleteEvent(event);
                  },
                ),
              ],
              if (event != null && !isOrganizer(event))
                IconButton(
                  onPressed: leaveEvent,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Opuść wydarzenie',
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: refreshEvent,
            child: Builder(
              builder: (context) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      const Icon(
                        Icons.error_outline,
                        size: 56,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nie udało się pobrać wydarzenia',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: refreshEvent,
                        child: const Text('Spróbuj ponownie'),
                      ),
                    ],
                  );
                }

                if (event == null) {
                  return const Center(child: Text('Brak danych wydarzenia'));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              event.description?.isNotEmpty == true
                                  ? event.description!
                                  : 'Brak opisu wydarzenia',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildInfoCard(
                      icon: Icons.calendar_today,
                      title: 'Data',
                      value: AppFormatters.date(event.date),
                    ),
                    buildInfoCard(
                      icon: Icons.access_time,
                      title: 'Godzina',
                      value: AppFormatters.time(event.date),
                    ),
                    buildModulesSection(),
                    const SizedBox(height: 16),
                    buildLocationSection(event),
                    const SizedBox(height: 16),
                    buildEventMap(event),
                    const SizedBox(height: 16),
                    buildNotificationSection(event),
                    const SizedBox(height: 16),
                    buildCalendarSection(event),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> scheduleReminder(EventModel event) async {
    try {
      await NotificationService.scheduleEventReminder(
        eventId: event.id,
        eventTitle: event.title,
        eventDate: event.date,
      );

      if (!mounted) return;

      AppSnackBar.success(context, 'Przypomnienie zostało ustawione');

      await refreshReminderStatus();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się ustawić przypomnienia',
      );
    }
  }

  Future<void> refreshReminderStatus() async {
    final future = NotificationService.isEventReminderScheduled(widget.eventId);

    setState(() {
      reminderStatusFuture = future;
    });

    await future;
  }

  Future<void> cancelReminder(EventModel event) async {
    try {
      await NotificationService.cancelEventReminder(event.id);

      if (!mounted) return;

      AppSnackBar.success(context, 'Przypomnienie zostało anulowane');

      await refreshReminderStatus();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się anulować przypomnienia',
      );
    }
  }

  Widget buildNotificationSection(EventModel event) {
    return FutureBuilder<bool>(
      future: reminderStatusFuture,
      builder: (context, snapshot) {
        final isScheduled = snapshot.data == true;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final canSchedule = event.date.isAfter(
          DateTime.now().add(const Duration(hours: 1)),
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Przypomnienie',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Odśwież status',
                      onPressed: refreshReminderStatus,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isLoading
                      ? 'Sprawdzanie przypomnienia...'
                      : isScheduled
                      ? 'Przypomnienie jest ustawione godzinę przed wydarzeniem.'
                      : canSchedule
                      ? 'Możesz ustawić lokalne przypomnienie godzinę przed wydarzeniem.'
                      : 'Nie można ustawić przypomnienia, bo wydarzenie zaczyna się za mniej niż godzinę lub już minęło.',
                  style: TextStyle(
                    color: isScheduled
                        ? Colors.green.shade700
                        : canSchedule
                        ? Colors.blue.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: isScheduled
                      ? OutlinedButton.icon(
                          onPressed: () {
                            cancelReminder(event);
                          },
                          icon: const Icon(Icons.notifications_off_outlined),
                          label: const Text('Anuluj przypomnienie'),
                        )
                      : FilledButton.icon(
                          onPressed: canSchedule
                              ? () {
                                  scheduleReminder(event);
                                }
                              : null,
                          icon: const Icon(Icons.notifications_outlined),
                          label: const Text('Ustaw przypomnienie'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> addToGoogleCalendar(EventModel event) async {
    try {
      await CalendarIntegrationService.openGoogleCalendar(event);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się otworzyć Google Calendar',
      );
    }
  }

  Widget buildCalendarSection(EventModel event) {
    return FutureBuilder<GoogleCalendarEventStatus>(
      future: googleCalendarStatusFuture,
      builder: (context, snapshot) {
        final status = snapshot.data;

        final isConnected = status?.connected == true;
        final isSynced = status?.synced == true;
        final syncedAt = status?.syncedAt;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Google Calendar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Odśwież status',
                      onPressed: refreshGoogleCalendarStatus,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isLoading
                      ? 'Sprawdzanie połączenia...'
                      : isConnected
                      ? isSynced
                            ? 'To wydarzenie jest dodane do Twojego Google Calendar.'
                            : 'Możesz dodać to wydarzenie do swojego Google Calendar.'
                      : 'Najpierw połącz Google Calendar w profilu.',
                  style: TextStyle(
                    color: isConnected
                        ? isSynced
                              ? Colors.green.shade700
                              : Colors.blue.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (syncedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ostatnia synchronizacja: ${AppFormatters.dateTime(syncedAt)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],

                if (isGoogleCalendarActionLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],

                const SizedBox(height: 16),

                if (!isConnected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: openProfileForGoogleCalendar,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Przejdź do profilu'),
                    ),
                  ),
                ],

                if (isConnected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isGoogleCalendarActionLoading
                          ? null
                          : () {
                              runGoogleCalendarAction(() {
                                return syncEventWithGoogleCalendar(event);
                              });
                            },
                      icon: const Icon(Icons.sync),
                      label: Text(
                        isSynced
                            ? 'Aktualizuj w Google Calendar'
                            : 'Dodaj do Google Calendar',
                      ),
                    ),
                  ),
                ],

                if (isConnected && isSynced) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isGoogleCalendarActionLoading
                          ? null
                          : () {
                              runGoogleCalendarAction(() {
                                return deleteEventFromGoogleCalendar(event);
                              });
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Usuń z mojego Google Calendar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: isGoogleCalendarActionLoading
                          ? null
                          : () {
                              runGoogleCalendarAction(() {
                                return clearGoogleCalendarEventLink(event);
                              });
                            },
                      icon: const Icon(Icons.link_off),
                      label: const Text('Usuń tylko powiązanie'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openProfileForGoogleCalendar() async {
    await context.push('/profile');

    if (!mounted) return;

    await refreshGoogleCalendarStatus();
  }

  Future<void> syncEventWithGoogleCalendar(EventModel event) async {
    try {
      final status = await googleCalendarService.getEventStatus(event.id);

      if (!status.connected) {
        if (!mounted) return;

        AppSnackBar.info(context, 'Najpierw połącz Google Calendar w profilu.');

        await openProfileForGoogleCalendar();
        return;
      }

      await googleCalendarService.syncEvent(event.id);

      if (!mounted) return;

      AppSnackBar.success(context, 'Google Calendar został zaktualizowany');

      await refreshEvent();
      await refreshGoogleCalendarStatus();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się zsynchronizować wydarzenia',
      );
    }
  }

  Future<void> refreshGoogleCalendarStatus() async {
    final future = googleCalendarService.getEventStatus(widget.eventId);

    setState(() {
      googleCalendarStatusFuture = future;
    });

    await future;
  }

  Future<void> clearGoogleCalendarEventLink(EventModel event) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Usuń powiązanie',
      message:
          'Czy na pewno chcesz usunąć samo powiązanie z Google Calendar? Wydarzenie w ChronoPlan zostanie bez zmian.',
      confirmText: 'Usuń powiązanie',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    try {
      await googleCalendarService.clearEventLink(event.id);

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Powiązanie z Twoim Google Calendar zostało usunięte',
      );

      await refreshEvent();
      await refreshGoogleCalendarStatus();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się usunąć powiązania Google Calendar',
      );
    }
  }

  Future<void> deleteEventFromGoogleCalendar(EventModel event) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Usuń z Google Calendar',
      message:
          'Czy na pewno chcesz usunąć to wydarzenie z Google Calendar? Wydarzenie w ChronoPlan zostanie zachowane.',
      confirmText: 'Usuń z Google',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    try {
      await googleCalendarService.deleteSyncedEvent(event.id);

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydarzenie zostało usunięte z Google Calendar',
      );

      await refreshEvent();
      await refreshGoogleCalendarStatus();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się usunąć wydarzenia z Google Calendar',
      );
    }
  }

  Future<void> runGoogleCalendarAction(Future<void> Function() action) async {
    if (isGoogleCalendarActionLoading) return;

    setState(() {
      isGoogleCalendarActionLoading = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          isGoogleCalendarActionLoading = false;
        });
      }
    }
  }

  Future<void> rescheduleReminderIfNeeded(EventModel event) async {
    try {
      final wasRescheduled =
          await NotificationService.rescheduleEventReminderIfNeeded(
            eventId: event.id,
            eventTitle: event.title,
            eventDate: event.date,
          );

      if (!mounted || !wasRescheduled) return;

      AppSnackBar.info(
        context,
        'Przypomnienie zostało zaktualizowane do nowej daty wydarzenia',
      );

      await refreshReminderStatus();
    } catch (_) {
      // Nie blokujemy ładowania szczegółów wydarzenia.
    }
  }
}

class EventSummaryData {
  final int todoTasks;
  final int inProgressTasks;
  final int doneTasks;
  final double totalExpenses;
  final int participantsCount;

  EventSummaryData({
    required this.todoTasks,
    required this.inProgressTasks,
    required this.doneTasks,
    required this.totalExpenses,
    required this.participantsCount,
  });
}
