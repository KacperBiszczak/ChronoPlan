import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

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

class EventDetailsScreen extends StatefulWidget {
  final int eventId;

  const EventDetailsScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final eventService = EventService();
  final authService = AuthService();
  final taskService = TaskService();
  final expenseService = ExpenseService();
  final participantService = ParticipantService();

  int? currentUserId;

  late Future<EventModel> eventFuture;
  late Future<EventSummaryData> summaryFuture;

  @override
  void initState() {
    super.initState();
    eventFuture = eventService.getEventById(widget.eventId);
    summaryFuture = loadSummary();
    loadCurrentUser();
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

  Future<void> deleteEvent() async {
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
      await eventService.deleteEvent(widget.eventId);

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
                  onPressed: deleteEvent,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Usuń wydarzenie',
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
                    const SizedBox(height: 16),
                    buildModulesSection(),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
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