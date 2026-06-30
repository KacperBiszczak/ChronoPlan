import 'package:flutter/material.dart';

import '../../../core/utils/app_confirm_dialog.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/services/auth_service.dart';
import '../../events/services/event_service.dart';
import '../models/date_option_model.dart';
import '../services/date_vote_service.dart';

class DateVotingScreenData {
  final List<DateOptionModel> options;
  final bool isOrganizer;
  final int currentUserId;

  DateVotingScreenData({
    required this.options,
    required this.isOrganizer,
    required this.currentUserId,
  });
}

class DateVotingScreen extends StatefulWidget {
  final int eventId;

  const DateVotingScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<DateVotingScreen> createState() => _DateVotingScreenState();
}

class _DateVotingScreenState extends State<DateVotingScreen> {
  final dateVoteService = DateVoteService();
  final eventService = EventService();
  final authService = AuthService();

  late Future<DateVotingScreenData> votingFuture;

  @override
  void initState() {
    super.initState();

    votingFuture = loadVotingData();
  }

  Future<DateVotingScreenData> loadVotingData() async {
    final user = await authService.getCurrentUser();
    final event = await eventService.getEventById(widget.eventId);
    final options = await dateVoteService.getOptionsByEvent(widget.eventId);

    return DateVotingScreenData(
      options: options,
      isOrganizer: event.creatorId == user.id,
      currentUserId: user.id,
    );
  }

  Future<void> refreshVoting() async {
    final future = loadVotingData();

    setState(() {
      votingFuture = future;
    });

    await future;
  }

  Future<void> showCreateOptionDialog() async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    bool isLoading = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );

              if (picked == null) return;

              setDialogState(() {
                selectedDate = picked;
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: dialogContext,
                initialTime: selectedTime,
              );

              if (picked == null) return;

              setDialogState(() {
                selectedTime = picked;
              });
            }

            Future<void> createOption() async {
              final proposedDate = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );

              setDialogState(() {
                isLoading = true;
              });

              try {
                await dateVoteService.createOption(
                  eventId: widget.eventId,
                  proposedDate: proposedDate,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                AppSnackBar.error(
                  dialogContext,
                  e,
                  fallback: 'Nie udało się dodać terminu',
                );
              }
            }

            return AlertDialog(
              title: const Text('Dodaj propozycję terminu'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Data'),
                      subtitle: Text(AppFormatters.date(selectedDate)),
                      onTap: pickDate,
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Godzina'),
                      subtitle: Text(
                        '${AppFormatters.twoDigits(selectedTime.hour)}:${AppFormatters.twoDigits(selectedTime.minute)}',
                      ),
                      onTap: pickTime,
                    ),
                  ],
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
                  onPressed: isLoading ? null : createOption,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Dodaj'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (created == true) {
      await refreshVoting();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Termin został dodany',
      );
    }
  }

  DateVoteModel? getUserVote(
    DateOptionModel option,
    int currentUserId,
  ) {
    for (final vote in option.votes) {
      if (vote.userId == currentUserId) {
        return vote;
      }
    }

    return null;
  }

  int countVotes(DateOptionModel option, String status) {
    return option.votes.where((vote) => vote.status == status).length;
  }

  Future<void> voteForOption(
    DateOptionModel option,
    String status,
  ) async {
    try {
      await dateVoteService.vote(
        optionId: option.id,
        status: status,
      );

      await refreshVoting();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Głos został zapisany',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się zapisać głosu',
      );
    }
  }

  Future<void> applyOption(DateOptionModel option) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Ustawić termin wydarzenia?',
      message:
          'Czy chcesz ustawić ${AppFormatters.dateTime(option.proposedDate)} jako właściwy termin wydarzenia?',
      confirmText: 'Ustaw',
      cancelText: 'Anuluj',
    );

    if (!mounted || !confirmed) return;

    try {
      await dateVoteService.applyOption(option.id);

      await refreshVoting();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Termin wydarzenia został zaktualizowany',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się ustawić terminu wydarzenia',
      );
    }
  }

  Future<void> deleteOption(DateOptionModel option) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Usunąć termin?',
      message:
          'Czy na pewno chcesz usunąć propozycję ${AppFormatters.dateTime(option.proposedDate)}?',
      confirmText: 'Usuń',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    try {
      await dateVoteService.deleteOption(option.id);

      await refreshVoting();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Termin został usunięty',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się usunąć terminu',
      );
    }
  }

  Widget buildVoteButton({
    required DateOptionModel option,
    required String status,
    required String label,
    required IconData icon,
    required Color color,
    required String? selectedStatus,
  }) {
    final selected = selectedStatus == status;

    return Expanded(
      child: selected
          ? FilledButton.icon(
              onPressed: () {
                voteForOption(option, status);
              },
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: color,
              ),
            )
          : OutlinedButton.icon(
              onPressed: () {
                voteForOption(option, status);
              },
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }

  Widget buildOptionCard(
    DateOptionModel option,
    DateVotingScreenData data,
  ) {
    final userVote = getUserVote(option, data.currentUserId);
    final selectedStatus = userVote?.status;

    final yesCount = countVotes(option, 'YES');
    final maybeCount = countVotes(option, 'MAYBE');
    final noCount = countVotes(option, 'NO');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.event_available),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppFormatters.dateTime(option.proposedDate),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (data.isOrganizer)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Usuń termin',
                    onPressed: () {
                      deleteOption(option);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Tak: $yesCount'),
                const SizedBox(width: 12),
                Text('Może: $maybeCount'),
                const SizedBox(width: 12),
                Text('Nie: $noCount'),
              ],
            ),
            if (data.isOrganizer) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    applyOption(option);
                  },
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Ustaw jako termin wydarzenia'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                buildVoteButton(
                  option: option,
                  status: 'YES',
                  label: 'Tak',
                  icon: Icons.check,
                  color: Colors.green,
                  selectedStatus: selectedStatus,
                ),
                const SizedBox(width: 8),
                buildVoteButton(
                  option: option,
                  status: 'MAYBE',
                  label: 'Może',
                  icon: Icons.help_outline,
                  color: Colors.orange,
                  selectedStatus: selectedStatus,
                ),
                const SizedBox(width: 8),
                buildVoteButton(
                  option: option,
                  status: 'NO',
                  label: 'Nie',
                  icon: Icons.close,
                  color: Colors.red,
                  selectedStatus: selectedStatus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyBody(bool isOrganizer) {
    return RefreshIndicator(
      onRefresh: refreshVoting,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.how_to_vote_outlined,
            size: 56,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          const Text(
            'Brak propozycji terminów',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOrganizer
                ? 'Dodaj pierwszy termin, żeby uczestnicy mogli zagłosować.'
                : 'Organizator nie dodał jeszcze propozycji terminów.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildErrorBody(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nie udało się pobrać głosowania',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: refreshVoting,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBody(DateVotingScreenData data) {
    if (data.options.isEmpty) {
      return buildEmptyBody(data.isOrganizer);
    }

    return RefreshIndicator(
      onRefresh: refreshVoting,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...data.options.map(
            (option) => buildOptionCard(option, data),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DateVotingScreenData>(
      future: votingFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Głosowanie nad terminem'),
          ),
          floatingActionButton: data?.isOrganizer == true
              ? FloatingActionButton(
                  onPressed: showCreateOptionDialog,
                  child: const Icon(Icons.add),
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

              if (data == null) {
                return buildErrorBody('Brak danych');
              }

              return buildBody(data);
            },
          ),
        );
      },
    );
  }
}