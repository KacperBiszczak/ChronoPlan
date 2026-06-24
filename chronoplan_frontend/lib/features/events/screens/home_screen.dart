import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/services/auth_service.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

enum EventFilter {
  all,
  upcoming,
  past,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final eventService = EventService();
  final authService = AuthService();
  
  final searchController = TextEditingController();

  String searchQuery = '';
  EventFilter selectedFilter = EventFilter.all;

  late Future<List<EventModel>> eventsFuture;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

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

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Szukaj wydarzenia...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  searchController.clear();

                  setState(() {
                    searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          searchQuery = value.trim().toLowerCase();
        });
      },
    );
  }

  Widget buildFilterSelector() {
    return SegmentedButton<EventFilter>(
      segments: const [
        ButtonSegment(
          value: EventFilter.all,
          label: Text('Wszystkie'),
          icon: Icon(Icons.list),
        ),
        ButtonSegment(
          value: EventFilter.upcoming,
          label: Text('Nadchodzące'),
          icon: Icon(Icons.event),
        ),
        ButtonSegment(
          value: EventFilter.past,
          label: Text('Zakończone'),
          icon: Icon(Icons.event_busy),
        ),
      ],
      selected: {selectedFilter},
      onSelectionChanged: (selection) {
        setState(() {
          selectedFilter = selection.first;
        });
      },
    );
  }

  Widget buildEventCard(EventModel event) {
    final isPast = event.date.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChronoPlan'),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/my-tasks');
            },
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Moje zadania',
          ),
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
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(
                    Icons.event,
                    size: 56,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Brak wydarzeń',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Utwórz pierwsze wydarzenie.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final now = DateTime.now();

            final searchFilteredEvents = events.where((event) {
              final title = event.title.toLowerCase();
              final description = event.description?.toLowerCase() ?? '';

              return title.contains(searchQuery) || description.contains(searchQuery);
            }).toList();

            final filteredEvents = searchFilteredEvents.where((event) {
              final isPast = event.date.isBefore(now);

              switch (selectedFilter) {
                case EventFilter.all:
                  return true;
                case EventFilter.upcoming:
                  return !isPast;
                case EventFilter.past:
                  return isPast;
              }
            }).toList();

            final upcomingEvents = filteredEvents
                .where((event) => !event.date.isBefore(now))
                .toList();

            final pastEvents = filteredEvents
                .where((event) => event.date.isBefore(now))
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                buildSearchField(),
                const SizedBox(height: 16),
                buildFilterSelector(),
                const SizedBox(height: 16),

                if (filteredEvents.isEmpty) ...[
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.search_off,
                    size: 56,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Brak wyników',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nie znaleziono wydarzeń pasujących do wybranych filtrów.',
                    textAlign: TextAlign.center,
                  ),
                ],

                if (upcomingEvents.isNotEmpty) ...[
                  buildSectionTitle('Nadchodzące'),
                  ...upcomingEvents.map(buildEventCard),
                ],

                if (pastEvents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  buildSectionTitle('Zakończone'),
                  ...pastEvents.map(buildEventCard),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}