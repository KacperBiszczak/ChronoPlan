import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../models/event_model.dart';
import '../services/event_service.dart';
import 'package:go_router/go_router.dart';
import '../../auth/services/auth_service.dart';

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

  int? currentUserId;

  late Future<EventModel> eventFuture;

  @override
  void initState() {
    super.initState();
    eventFuture = eventService.getEventById(widget.eventId);
    loadCurrentUser();
  }

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String formatDate(DateTime date) {
    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year}';
  }

  String formatTime(DateTime date) {
    return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  Future<void> refreshEvent() async {
    setState(() {
      eventFuture = eventService.getEventById(widget.eventId);
    });
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

  Future<void> deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Usuń wydarzenie'),
          content: const Text(
            'Czy na pewno chcesz usunąć to wydarzenie? Tej operacji nie można cofnąć.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Usuń'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmed != true) return;

    try {
      await eventService.deleteEvent(widget.eventId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wydarzenie zostało usunięte'),
        ),
      );

      context.go('/home');
    } on DioException catch (error) {
      if (!mounted) return;

      final message =
          error.response?.data['message'] ?? 'Błąd usuwania wydarzenia';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nieoczekiwany błąd'),
        ),
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
                      value: formatDate(event.date),
                    ),
                    buildInfoCard(
                      icon: Icons.access_time,
                      title: 'Godzina',
                      value: formatTime(event.date),
                    ),
                    const SizedBox(height: 16),
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
                        subtitle: const Text('Lista zadań wydarzenia'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.push('/events/${widget.eventId}/tasks');
                        },
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.payments, color: Colors.blue),
                        title: const Text('Budżet'),
                        subtitle: const Text('Wydatki i podsumowanie kosztów'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.push('/events/${widget.eventId}/expenses');
                        },
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.group, color: Colors.blue),
                        title: const Text('Uczestnicy'),
                        subtitle: const Text('Zaproszenia i lista osób'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.push('/events/${widget.eventId}/participants');
                        },
                      ),
                    ),
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