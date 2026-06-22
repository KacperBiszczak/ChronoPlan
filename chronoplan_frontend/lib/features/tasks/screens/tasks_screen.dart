import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../events/services/event_service.dart';
import '../../participants/models/participant_model.dart';
import '../../participants/services/participant_service.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';

class TasksScreen extends StatefulWidget {
  final int eventId;

  const TasksScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final taskService = TaskService();
  final eventService = EventService();
  final authService = AuthService();
  final participantService = ParticipantService();

  bool canManageTasks = false;

  late Future<List<TaskModel>> tasksFuture;

  @override
  void initState() {
    super.initState();
    tasksFuture = taskService.getTasksByEvent(widget.eventId);
    loadPermissions();
  }

  Future<void> refreshTasks() async {
    final future = taskService.getTasksByEvent(widget.eventId);
    
    setState(() {
      tasksFuture = taskService.getTasksByEvent(widget.eventId);
    });

    await loadPermissions();
    await future;
  }

  String getStatusLabel(String status) {
    switch (status) {
      case 'TODO':
        return 'Do zrobienia';
      case 'IN_PROGRESS':
        return 'W trakcie';
      case 'DONE':
        return 'Zrobione';
      default:
        return status;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'TODO':
        return Icons.radio_button_unchecked;
      case 'IN_PROGRESS':
        return Icons.timelapse;
      case 'DONE':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> showEditTaskDialog(TaskModel task) async {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(
      text: task.description ?? '',
    );

    bool isLoading = false;
    int? selectedAssigneeId = task.assigneeId;

    final participantsFuture =
        participantService.getParticipantsByEvent(widget.eventId);

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> updateTask() async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Podaj tytuł zadania'),
                  ),
                );
                return;
              }

              setDialogState(() {
                isLoading = true;
              });

              try {
                await taskService.updateTask(
                  taskId: task.id,
                  title: title,
                  description: description.isEmpty ? null : description,
                  assigneeId: selectedAssigneeId,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } on DioException catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                final message =
                    error.response?.data['message'] ?? 'Błąd edycji zadania';

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
              title: const Text('Edytuj zadanie'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tytuł zadania',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<ParticipantModel>>(
                      future: participantsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }

                        if (snapshot.hasError) {
                          return const Text(
                            'Nie udało się pobrać uczestników',
                            style: TextStyle(color: Colors.red),
                          );
                        }

                        final participants = (snapshot.data ?? [])
                            .where(
                              (participant) =>
                                  participant.status == 'ACCEPTED' &&
                                  participant.user != null,
                            )
                            .toList();

                        return DropdownButtonFormField<int?>(
                          value: selectedAssigneeId,
                          decoration: const InputDecoration(
                            labelText: 'Osoba odpowiedzialna',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Nie przypisuj'),
                            ),
                            ...participants.map(
                              (participant) => DropdownMenuItem<int?>(
                                value: participant.userId,
                                child: Text(
                                  '${participant.user!.name} (${participant.user!.email})',
                                ),
                              ),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedAssigneeId = value;
                                  });
                                },
                        );
                      },
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
                  onPressed: isLoading ? null : updateTask,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (!mounted) return;

    if (updated == true) {
      await refreshTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadanie zostało zaktualizowane'),
        ),
      );
    }
  }

  Future<void> changeStatus(TaskModel task, String status) async {
    try {
      await taskService.updateTaskStatus(
        taskId: task.id,
        status: status,
      );

      await refreshTasks();
    } on DioException catch (error) {
      if (!mounted) return;

      final message =
          error.response?.data['message'] ?? 'Błąd zmiany statusu zadania';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieoczekiwany błąd')),
      );
    }
  }

  Future<void> deleteTask(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Usuń zadanie'),
          content: Text('Czy na pewno chcesz usunąć zadanie "${task.title}"?'),
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
      await taskService.deleteTask(task.id);

      await refreshTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadanie zostało usunięte'),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;

      final message = error.response?.data['message'] ?? 'Błąd usuwania zadania';

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

  Future<void> showCreateTaskDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    bool isLoading = false;
    int? selectedAssigneeId;

    final participantsFuture =
        participantService.getParticipantsByEvent(widget.eventId);

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> createTask() async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Podaj tytuł zadania'),
                  ),
                );
                return;
              }

              setDialogState(() {
                isLoading = true;
              });

              try {
                await taskService.createTask(
                  title: title,
                  description: description.isEmpty ? null : description,
                  eventId: widget.eventId,
                  assigneeId: selectedAssigneeId,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } on DioException catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                final message =
                    error.response?.data['message'] ?? 'Błąd dodawania zadania';

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
              title: const Text('Nowe zadanie'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tytuł zadania',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<ParticipantModel>>(
                      future: participantsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }

                        if (snapshot.hasError) {
                          return const Text(
                            'Nie udało się pobrać uczestników',
                            style: TextStyle(color: Colors.red),
                          );
                        }

                        final participants = (snapshot.data ?? [])
                            .where((participant) =>
                                participant.status == 'ACCEPTED' &&
                                participant.user != null)
                            .toList();

                        return DropdownButtonFormField<int?>(
                          initialValue: selectedAssigneeId,
                          decoration: const InputDecoration(
                            labelText: 'Osoba odpowiedzialna',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Nie przypisuj'),
                            ),
                            ...participants.map(
                              (participant) => DropdownMenuItem<int?>(
                                value: participant.userId,
                                child: Text(
                                  '${participant.user!.name} (${participant.user!.email})',
                                ),
                              ),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedAssigneeId = value;
                                  });
                                },
                        );
                      },
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
                  onPressed: isLoading ? null : createTask,
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

    titleController.dispose();
    descriptionController.dispose();

    if (!mounted) return;

    if (created == true) {
      await refreshTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadanie zostało dodane'),
        ),
      );
    }
  }

  Widget buildTaskCard(TaskModel task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              child: Icon(getStatusIcon(task.status)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (task.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(task.description!),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    task.assignee != null
                        ? 'Odpowiedzialny: ${task.assignee!.name}'
                        : 'Nie przypisano osoby',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: task.status,
              items: const [
                DropdownMenuItem(
                  value: 'TODO',
                  child: Text('Do zrobienia'),
                ),
                DropdownMenuItem(
                  value: 'IN_PROGRESS',
                  child: Text('W trakcie'),
                ),
                DropdownMenuItem(
                  value: 'DONE',
                  child: Text('Zrobione'),
                ),
              ],
              onChanged: (value) {
                if (value == null || value == task.status) return;

                changeStatus(task, value);
              },
            ),
            if (canManageTasks)
              IconButton(
                onPressed: () {
                  showEditTaskDialog(task);
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edytuj zadanie',
              ),
            if (canManageTasks)
              IconButton(
                onPressed: () {
                  deleteTask(task);
                },
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Usuń zadanie',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> loadPermissions() async {
    try {
      final currentUser = await authService.getCurrentUser();
      final event = await eventService.getEventById(widget.eventId);

      if (!mounted) return;

      setState(() {
        canManageTasks = event.creatorId == currentUser.id;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        canManageTasks = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zadania'),
      ),
      floatingActionButton: canManageTasks
          ? FloatingActionButton(
              onPressed: showCreateTaskDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: refreshTasks,
        child: FutureBuilder<List<TaskModel>>(
          future: tasksFuture,
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
                    'Nie udało się pobrać zadań',
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
                    onPressed: refreshTasks,
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              );
            }

            final tasks = snapshot.data ?? [];

            if (tasks.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(
                    Icons.checklist,
                    size: 56,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Brak zadań',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Dodaj pierwsze zadanie do tego wydarzenia.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return buildTaskCard(tasks[index]);
              },
            );
          },
        ),
      ),
    );
  }
}