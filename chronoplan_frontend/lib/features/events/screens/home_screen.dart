import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/services/auth_service.dart';
import '../../auth/models/user_model.dart';
import '../../participants/services/participant_service.dart';
import '../../tasks/services/task_service.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/app_confirm_dialog.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/widgets/app_state_widgets.dart';

enum EventFilter { all, upcoming, past }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final eventService = EventService();
  final authService = AuthService();
  final taskService = TaskService();
  final participantService = ParticipantService();

  int myActiveTasksCount = 0;
  int invitationsCount = 0;
  int? currentUserId;
  UserModel? currentUser;

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
    loadCounters();
    loadCurrentUser();
  }

  Future<void> refreshEvents() async {
    final future = eventService.getEvents();

    setState(() {
      eventsFuture = future;
    });

    await Future.wait([future, loadCounters(), loadCurrentUser()]);
  }

  Future<void> logout() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Wylogować się?',
      message: 'Czy na pewno chcesz się wylogować z aplikacji?',
      confirmText: 'Wyloguj',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    try {
      await authService.logout();

      if (!mounted) return;

      AppSnackBar.success(context, 'Wylogowano');

      context.go('/login');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(context, e, fallback: 'Nie udało się wylogować');
    }
  }

  Widget buildSectionTitle(String title) {
    return AppSectionTitle(title: title);
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget buildEventBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEventCard(EventModel event) {
    final isPast = event.date.isBefore(DateTime.now());
    final isOrganizer =
        currentUserId != null && event.creatorId == currentUserId;

    final roleColor = isOrganizer ? Colors.blue : Colors.green;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await context.push('/events/${event.id}');

          if (!mounted) return;

          refreshEvents();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                child: Icon(isPast ? Icons.event_busy : Icons.event),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isPast ? Colors.grey[700] : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description?.isNotEmpty == true
                          ? event.description!
                          : 'Brak opisu',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isPast ? Colors.grey[600] : null),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: isPast ? Colors.grey : Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppFormatters.dateTime(event.date),
                              style: TextStyle(
                                color: isPast
                                    ? Colors.grey[700]
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (event.locationName != null &&
                            event.locationName!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  event.locationName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildEventBadge(
                          label: isOrganizer ? 'Organizator' : 'Uczestnik',
                          color: roleColor,
                          icon: isOrganizer
                              ? Icons.admin_panel_settings
                              : Icons.person,
                        ),
                        if (isPast)
                          buildEventBadge(
                            label: 'Zakończone',
                            color: Colors.grey,
                            icon: Icons.event_busy,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildProfileButton() {
    final user = currentUser;
    final avatarUrl = user?.avatarUrl;
    final name = user?.name ?? '';

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: 'Mój profil',
        onPressed: () async {
          await context.push('/profile');

          if (!mounted) return;

          await refreshEvents();
        },
        icon: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blue.shade700,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> loadCurrentUser() async {
    try {
      final user = await authService.getCurrentUser();

      if (!mounted) return;

      setState(() {
        currentUserId = user.id;
        currentUser = user;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        currentUserId = null;
        currentUser = null;
      });
    }
  }

  Future<void> loadCounters() async {
    try {
      final myTasks = await taskService.getMyTasks();
      final invitations = await participantService.getMyInvitations();

      if (!mounted) return;

      setState(() {
        myActiveTasksCount = myTasks
            .where((task) => task.status != 'DONE')
            .length;
        invitationsCount = invitations.length;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        myActiveTasksCount = 0;
        invitationsCount = 0;
      });
    }
  }

  Widget buildIconWithBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 99 ? '+99' : count.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> openCreateEvent() async {
    final created = await context.push<bool>('/events/create');

    if (!mounted) return;

    if (created == true) {
      await refreshEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChronoPlan'),
        actions: [
          IconButton(
            onPressed: () async {
              await context.push('/my-tasks');

              if (!mounted) return;

              await refreshEvents();
            },
            icon: buildIconWithBadge(
              icon: Icons.assignment_outlined,
              count: myActiveTasksCount,
            ),
            tooltip: 'Moje zadania',
          ),
          IconButton(
            onPressed: () async {
              await context.push('/invitations');

              if (!mounted) return;

              await refreshEvents();
            },
            icon: buildIconWithBadge(
              icon: Icons.mail_outline,
              count: invitationsCount,
            ),
            tooltip: 'Moje zaproszenia',
          ),
          buildProfileButton(),

          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj',
            onPressed: logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openCreateEvent,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: refreshEvents,
        child: FutureBuilder<List<EventModel>>(
          future: eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState();
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
                  Icon(Icons.event, size: 56, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    'Brak wydarzeń',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

              return title.contains(searchQuery) ||
                  description.contains(searchQuery);
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
                  const Icon(Icons.search_off, size: 56, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Brak wyników',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
