import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/services/auth_service.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final eventService = EventService();
  final authService = AuthService();

  late Future<List<EventModel>> eventsFuture;

  @override
  void initState() {
    super.initState();
    eventsFuture = eventService.getEvents();
  }

  Future<void> refreshEvents() async {
    setState(() {
      eventsFuture = eventService.getEvents();
    });
  }

  Future<void> logout() async {
    await authService.logout();

    if (!mounted) return;

    context.go('/login');
  }

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String formatDate(DateTime date) {
    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChronoPlan'),
        actions: [
          IconButton(
            onPressed: () async {
              await context.push('/invitations');

              if (!mounted) return;

              refreshEvents();
            },
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Moje zaproszenia',
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>('/events/create');

          if (created == true) {
            refreshEvents();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: refreshEvents,
        child: FutureBuilder<List<EventModel>>(
          future: eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Błąd pobierania wydarzeń',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: refreshEvents,
                          child: const Text('Spróbuj ponownie'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final events = snapshot.data ?? [];

            if (events.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 56,
                          color: Colors.blue,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Brak wydarzeń',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Utwórz pierwsze wydarzenie w ChronoPlan.',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final isPast = event.date.isBefore(DateTime.now());

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPast ? Colors.grey : Colors.blue,
                      foregroundColor: Colors.white,
                      child: Icon(
                        isPast ? Icons.event_busy : Icons.event,
                      ),
                    ),
                    title: Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPast ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      '${event.description?.isNotEmpty == true ? event.description! : 'Brak opisu'}\n'
                      '${formatDate(event.date)}',
                    ),
                    isThreeLine: true,
                    trailing: isPast
                        ? const Chip(
                            label: Text('Zakończone'),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/events/${event.id}');
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}