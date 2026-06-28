import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../models/participant_model.dart';
import '../services/participant_service.dart';
import '../../../core/utils/status_helpers.dart';

enum ParticipantFilter {
  all,
  invited,
  accepted,
  declined,
}

class ParticipantsScreenData {
  final List<ParticipantModel> participants;
  final bool canInvite;

  ParticipantsScreenData({
    required this.participants,
    required this.canInvite,
  });
}

class ParticipantsScreen extends StatefulWidget {
  final int eventId;

  const ParticipantsScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final participantService = ParticipantService();
  final authService = AuthService();

  final searchController = TextEditingController();

  String searchQuery = '';
  ParticipantFilter selectedFilter = ParticipantFilter.all;

  late Future<ParticipantsScreenData> participantsFuture;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    participantsFuture = loadParticipantsData();
  }

  List<ParticipantModel> filterParticipants(List<ParticipantModel> participants) {
    final searchFilteredParticipants = participants.where((participant) {
      final name = participant.user?.name.toLowerCase() ?? '';
      final email = participant.user?.email.toLowerCase() ?? '';
      final role = AppEventRole.label(participant.role).toLowerCase();
      final status = AppParticipantStatus.label(participant.status).toLowerCase();

      return name.contains(searchQuery) ||
          email.contains(searchQuery) ||
          role.contains(searchQuery) ||
          status.contains(searchQuery);
    }).toList();

    switch (selectedFilter) {
      case ParticipantFilter.all:
        return searchFilteredParticipants;
      case ParticipantFilter.invited:
        return searchFilteredParticipants
            .where((participant) => participant.status == 'INVITED')
            .toList();
      case ParticipantFilter.accepted:
        return searchFilteredParticipants
            .where((participant) => participant.status == 'ACCEPTED')
            .toList();
      case ParticipantFilter.declined:
        return searchFilteredParticipants
            .where((participant) => participant.status == 'DECLINED')
            .toList();
    }
  }

  Future<ParticipantsScreenData> loadParticipantsData() async {
    final currentUser = await authService.getCurrentUser();
    final participants =
        await participantService.getParticipantsByEvent(widget.eventId);

    final canInvite = participants.any(
      (participant) =>
          participant.userId == currentUser.id &&
          participant.role == 'ORGANIZER',
    );

    return ParticipantsScreenData(
      participants: participants,
      canInvite: canInvite,
    );
  }

  Future<void> refreshParticipants() async {
    setState(() {
      participantsFuture = loadParticipantsData();
    });

    await participantsFuture;
  }

  Future<void> showInviteDialog() async {
    final emailController = TextEditingController();

    bool isLoading = false;

    final invited = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> invite() async {
              final email = emailController.text.trim();

              if (email.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Podaj email użytkownika'),
                  ),
                );
                return;
              }

              setDialogState(() {
                isLoading = true;
              });

              try {
                await participantService.inviteParticipant(
                  eventId: widget.eventId,
                  email: email,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } on DioException catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                final message = error.response?.data['message'] ??
                    'Błąd zapraszania uczestnika';

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(message),
                  ),
                );
              } catch (_) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Nieoczekiwany błąd'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Zaproś uczestnika'),
              content: SizedBox(
                width: 420,
                child: TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email użytkownika',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: isLoading ? null : invite,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zaproś'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (!mounted) return;

    if (invited == true) {
      await refreshParticipants();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uczestnik został zaproszony'),
        ),
      );
    }
  }

  Future<void> deleteParticipant(ParticipantModel participant) async {
    final userName = participant.user?.name ?? participant.user?.email ?? 'uczestnika';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Usuń uczestnika'),
          content: Text('Czy na pewno chcesz usunąć "$userName" z wydarzenia?'),
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
      await participantService.deleteParticipant(participant.id);

      await refreshParticipants();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uczestnik został usunięty'),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;

      final message =
          error.response?.data['message'] ?? 'Błąd usuwania uczestnika';

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

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Szukaj uczestnika...',
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Wszyscy'),
          selected: selectedFilter == ParticipantFilter.all,
          onSelected: (_) {
            setState(() {
              selectedFilter = ParticipantFilter.all;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Zaproszeni'),
          selected: selectedFilter == ParticipantFilter.invited,
          onSelected: (_) {
            setState(() {
              selectedFilter = ParticipantFilter.invited;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Zaakceptowani'),
          selected: selectedFilter == ParticipantFilter.accepted,
          onSelected: (_) {
            setState(() {
              selectedFilter = ParticipantFilter.accepted;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Odrzuceni'),
          selected: selectedFilter == ParticipantFilter.declined,
          onSelected: (_) {
            setState(() {
              selectedFilter = ParticipantFilter.declined;
            });
          },
        ),
      ],
    );
  }

  Widget buildParticipantCard(ParticipantModel participant, bool canManageParticipants) {
    final user = participant.user;
    final canDeleteParticipant =
        canManageParticipants && participant.role != 'ORGANIZER';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          child: Icon(Icons.person),
        ),
        title: Text(
          user?.name ?? 'Nieznany użytkownik',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${user?.email ?? 'Brak emaila'}\n${AppEventRole.label(participant.role)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                AppParticipantStatus.label(participant.status),
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppParticipantStatus.color(participant.status),
            ),
            if (canDeleteParticipant) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  deleteParticipant(participant);
                },
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Usuń uczestnika',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildErrorBody(Object error) {
    return RefreshIndicator(
      onRefresh: refreshParticipants,
      child: ListView(
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
            'Nie udało się pobrać uczestników',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: refreshParticipants,
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }

  Widget buildParticipantsBody(
    List<ParticipantModel> participants,
    bool canManageParticipants,
  ) {
    if (participants.isEmpty) {
      return RefreshIndicator(
        onRefresh: refreshParticipants,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 100),
            Icon(
              Icons.group,
              size: 56,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              'Brak uczestników',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Zaproś pierwszą osobę do wydarzenia.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filteredParticipants = filterParticipants(participants);

    return RefreshIndicator(
      onRefresh: refreshParticipants,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildSearchField(),
          const SizedBox(height: 16),
          buildFilterSelector(),
          const SizedBox(height: 16),

          if (filteredParticipants.isEmpty) ...[
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
              'Nie znaleziono uczestników pasujących do wybranych filtrów.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            ...filteredParticipants.map(
              (participant) => buildParticipantCard(
                participant,
                canManageParticipants,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParticipantsScreenData>(
      future: participantsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Uczestnicy'),
          ),
          floatingActionButton: data?.canInvite == true
              ? FloatingActionButton(
                  onPressed: showInviteDialog,
                  child: const Icon(Icons.person_add),
                )
              : null,
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return buildErrorBody(snapshot.error!);
              }

              final participants = data?.participants ?? [];

              return buildParticipantsBody(participants, data?.canInvite == true);
            },
          ),
        );
      },
    );
  }
}