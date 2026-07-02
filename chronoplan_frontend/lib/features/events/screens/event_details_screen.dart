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

  const EventDetailsScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> with WidgetsBindingObserver {
  final eventService = EventService();
  final authService = AuthService();
  final taskService = TaskService();
  final expenseService = ExpenseService();
  final participantService = ParticipantService();
  final googleCalendarService = GoogleCalendarService();
  
  late Future<bool> googleCalendarStatusFuture;

  int? currentUserId;

  late Future<EventModel> eventFuture;
  late Future<EventSummaryData> summaryFuture;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    eventFuture = eventService.getEventById(widget.eventId);
    summaryFuture = loadSummary();
    
    loadCurrentUser();

    googleCalendarStatusFuture = googleCalendarService.getStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refreshEvent() async {
    setState(() {
      eventFuture = eventService.getEventById(widget.eventId);
      summaryFuture = loadSummary();
    });
  }

  Future<EventSummaryData> loadSummary() async {
    final tasks = await taskService.getTasksByEvent(widget.eventId);
    final totalExpenses = await expenseService.getExpenseSummary(widget.eventId);
    final participants =
        await participantService.getParticipantsByEvent(widget.eventId);

    final todoTasks = tasks.where((task) => task.status == 'TODO').length;

    final inProgressTasks =
        tasks.where((task) => task.status == 'IN_PROGRESS').length;

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

      AppSnackBar.success(
        context,
        'Opuszczono wydarzenie',
      );

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
      if (event.googleCalendarEventId != null) {
        try {
          await googleCalendarService.deleteSyncedEvent(event.id);
        } catch (_) {
          // Jeśli usuwanie z Google Calendar się nie uda,
          // nie blokujemy usunięcia wydarzenia z ChronoPlan.
        }
      }

      await eventService.deleteEvent(event.id);

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydarzenie zostało usunięte',
      );

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
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Widget buildEventMap(EventModel event) {
    if (event.latitude == null || event.longitude == null) {
      return const SizedBox.shrink();
    }

    final point = LatLng(
      event.latitude!,
      event.longitude!,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
              ),
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
        event.locationAddress != null && event.locationAddress!.trim().isNotEmpty;

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
                Icon(
                  Icons.location_on_outlined,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lokalizacja',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (hasLocationName) ...[
              Text(
                event.locationName!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
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
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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

                  refreshEvent();
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.how_to_vote_outlined, color: Colors.blue),
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
                leading: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
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
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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
                  return const Center(
                    child: Text('Brak danych wydarzenia'),
                  );
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
    final reminderDate = event.date.subtract(
      const Duration(hours: 1),
    );

    if (reminderDate.isBefore(DateTime.now())) {
      AppSnackBar.info(
        context,
        'Nie można ustawić przypomnienia — wydarzenie zaczyna się za mniej niż godzinę lub już minęło',
      );
      return;
    }

    try {
      await NotificationService.scheduleEventReminder(
        eventId: event.id,
        eventTitle: event.title,
        eventDate: event.date,
      );

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Przypomnienie zostało ustawione',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się ustawić przypomnienia',
      );
    }
  }

  Future<void> cancelReminder(EventModel event) async {
    try {
      await NotificationService.cancelEventReminder(event.id);

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Przypomnienie zostało anulowane',
      );
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
                  'Powiadomienia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Możesz ustawić lokalne przypomnienie godzinę przed rozpoczęciem wydarzenia.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      scheduleReminder(event);
                    },
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Przypomnij'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      cancelReminder(event);
                    },
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: const Text('Anuluj'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    return FutureBuilder<bool>(
      future: googleCalendarStatusFuture,
      builder: (context, snapshot) {
        final isConnected = snapshot.data == true;
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
                          ? 'Konto Google Calendar jest połączone.'
                          : 'Konto Google Calendar nie jest jeszcze połączone.',
                  style: TextStyle(
                    color: isConnected ? Colors.green.shade700 : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (event.googleCalendarSyncedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ostatnia synchronizacja: ${AppFormatters.dateTime(event.googleCalendarSyncedAt!)}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              connectGoogleCalendar(event);
                            },
                            icon: const Icon(Icons.link),
                            label: Text(isConnected ? 'Połącz ponownie' : 'Połącz'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isConnected
                                ? () {
                                    syncEventWithGoogleCalendar(event);
                                  }
                                : null,
                            icon: const Icon(Icons.sync),
                            label: const Text('Synchronizuj'),
                          ),
                        ),
                      ],
                    ),

                    if (isConnected) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: disconnectGoogleCalendar,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Odłącz Google Calendar'),
                        ),
                      ),
                    ],

                    if (isConnected && event.googleCalendarEventId != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            deleteEventFromGoogleCalendar(event);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Usuń wydarzenie z Google Calendar'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> connectGoogleCalendar(EventModel event) async {
    try {
      await googleCalendarService.connectGoogleCalendar(
        returnPath: '/events/${event.id}',
      );

        if (!mounted) return;

        AppSnackBar.success(
          context,
          'Otworzono autoryzację Google Calendar. Po powrocie do aplikacji status odświeży się automatycznie.',
        );
      } catch (e) {
        if (!mounted) return;

        AppSnackBar.error(
          context,
          e,
          fallback: 'Nie udało się połączyć Google Calendar',
        );
      }
  }

  Future<void> syncEventWithGoogleCalendar(EventModel event) async {
    try {
      await googleCalendarService.syncEvent(event.id);

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydarzenie zsynchronizowane z Google Calendar',
      );

      await refreshEvent();
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
    final future = googleCalendarService.getStatus();

    setState(() {
      googleCalendarStatusFuture = future;
    });

    await future;
  }

  Future<void> disconnectGoogleCalendar() async {
    try {
      await googleCalendarService.disconnectGoogleCalendar();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Google Calendar został odłączony',
      );

      await refreshGoogleCalendarStatus();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się odłączyć Google Calendar',
      );
    }
  }

  Future<void> deleteEventFromGoogleCalendar(EventModel event) async {
    try {
      await googleCalendarService.deleteSyncedEvent(event.id);

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydarzenie zostało usunięte z Google Calendar',
      );

      await refreshEvent();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się usunąć wydarzenia z Google Calendar',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      refreshGoogleCalendarStatus();
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