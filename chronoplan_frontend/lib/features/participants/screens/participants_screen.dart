import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/participant_model.dart';
import '../services/participant_service.dart';

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

  late Future<List<ParticipantModel>> participantsFuture;

  @override
  void initState() {
    super.initState();
    participantsFuture =
        participantService.getParticipantsByEvent(widget.eventId);
  }

  Future<void> refreshParticipants() async {
    setState(() {
      participantsFuture =
          participantService.getParticipantsByEvent(widget.eventId);
    });
  }

  String getRoleLabel(String role) {
    switch (role) {
      case 'ORGANIZER':
        return 'Organizator';
      case 'PARTICIPANT':
        return 'Uczestnik';
      default:
        return role;
    }
  }

  String getStatusLabel(String status) {
    switch (status) {
      case 'INVITED':
        return 'Zaproszony';
      case 'ACCEPTED':
        return 'Zaakceptował';
      case 'DECLINED':
        return 'Odrzucił';
      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return Colors.green;
      case 'DECLINED':
        return Colors.red;
      case 'INVITED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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

  Widget buildParticipantCard(ParticipantModel participant) {
    final user = participant.user;

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
          '${user?.email ?? 'Brak emaila'}\n${getRoleLabel(participant.role)}',
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(
            getStatusLabel(participant.status),
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: getStatusColor(participant.status),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uczestnicy'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showInviteDialog,
        child: const Icon(Icons.person_add),
      ),
      body: RefreshIndicator(
        onRefresh: refreshParticipants,
        child: FutureBuilder<List<ParticipantModel>>(
          future: participantsFuture,
          builder: (context, snapshot) {
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
                    'Nie udało się pobrać uczestników',
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
                    onPressed: refreshParticipants,
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              );
            }

            final participants = snapshot.data ?? [];

            if (participants.isEmpty) {
              return ListView(
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
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                return buildParticipantCard(participants[index]);
              },
            );
          },
        ),
      ),
    );
  }
}