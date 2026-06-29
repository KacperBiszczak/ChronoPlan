import 'package:chronoplan_frontend/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/app_snack_bar.dart';

import '../models/participant_model.dart';
import '../services/participant_service.dart';

class MyInvitationsScreen extends StatefulWidget {
  const MyInvitationsScreen({super.key});

  @override
  State<MyInvitationsScreen> createState() => _MyInvitationsScreenState();
}

class _MyInvitationsScreenState extends State<MyInvitationsScreen> {
  final participantService = ParticipantService();

  late Future<List<ParticipantModel>> invitationsFuture;

  @override
  void initState() {
    super.initState();
    invitationsFuture = participantService.getMyInvitations();
  }

  Future<void> refreshInvitations() async {
    final future = participantService.getMyInvitations();

    setState(() {
      invitationsFuture = future;
    });

    await future;
  }
  
  Future<void> updateStatus({
    required ParticipantModel invitation,
    required String status,
  }) async {
    try {
      await participantService.updateInvitationStatus(
        participantId: invitation.id,
        status: status,
      );

      await refreshInvitations();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        status == 'ACCEPTED'
            ? 'Zaproszenie zaakceptowane'
            : 'Zaproszenie odrzucone',
      );

      if (status == 'ACCEPTED') {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Błąd zmiany statusu zaproszenia',
      );
    }
  }

  Widget buildInvitationCard(ParticipantModel invitation) {
    final event = invitation.event;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                child: Icon(Icons.mail_outline),
              ),
              title: Text(
                event?.title ?? 'Nieznane wydarzenie',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${event?.description ?? 'Brak opisu'}\n'
                'Data: ${event != null ? AppFormatters.date(event.date) : '-'}\n'
                'Organizator: ${event?.creator?.name ?? '-'}',
              ),
              isThreeLine: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      updateStatus(
                        invitation: invitation,
                        status: 'DECLINED',
                      );
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Odrzuć'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      updateStatus(
                        invitation: invitation,
                        status: 'ACCEPTED',
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Akceptuj'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje zaproszenia'),
      ),
      body: RefreshIndicator(
        onRefresh: refreshInvitations,
        child: FutureBuilder<List<ParticipantModel>>(
          future: invitationsFuture,
          builder: (context, snapshot) {
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
                    'Nie udało się pobrać zaproszeń',
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
                    onPressed: refreshInvitations,
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              );
            }

            final invitations = snapshot.data ?? [];

            if (invitations.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 56,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Brak zaproszeń',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tutaj pojawią się zaproszenia do wydarzeń.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              itemBuilder: (context, index) {
                return buildInvitationCard(invitations[index]);
              },
            );
          },
        ),
      ),
    );
  }
}