import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/status_helpers.dart';
import '../../../core/utils/app_snack_bar.dart';

enum MyTaskFilter { all, todo, inProgress, done }

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final taskService = TaskService();

  final searchController = TextEditingController();

  String searchQuery = '';
  MyTaskFilter selectedFilter = MyTaskFilter.all;

  late Future<List<TaskModel>> tasksFuture;

  int getStatusPriority(String status) {
    switch (status) {
      case 'TODO':
        return 0;
      case 'IN_PROGRESS':
        return 1;
      case 'DONE':
        return 2;
      default:
        return 3;
    }
  }

  List<TaskModel> filterTasks(List<TaskModel> tasks) {
    final searchFilteredTasks = tasks.where((task) {
      final title = task.title.toLowerCase();
      final description = task.description?.toLowerCase() ?? '';
      final eventTitle = task.event?.title.toLowerCase() ?? '';
      final eventDescription = task.event?.description?.toLowerCase() ?? '';

      return title.contains(searchQuery) ||
          description.contains(searchQuery) ||
          eventTitle.contains(searchQuery) ||
          eventDescription.contains(searchQuery);
    }).toList();

    final statusFilteredTasks = switch (selectedFilter) {
      MyTaskFilter.all => searchFilteredTasks,
      MyTaskFilter.todo =>
        searchFilteredTasks.where((task) => task.status == 'TODO').toList(),
      MyTaskFilter.inProgress =>
        searchFilteredTasks
            .where((task) => task.status == 'IN_PROGRESS')
            .toList(),
      MyTaskFilter.done =>
        searchFilteredTasks.where((task) => task.status == 'DONE').toList(),
    };

    statusFilteredTasks.sort((a, b) {
      final statusCompare = getStatusPriority(
        a.status,
      ).compareTo(getStatusPriority(b.status));

      if (statusCompare != 0) {
        return statusCompare;
      }

      final aDate = a.event?.date;
      final bDate = b.event?.date;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    return statusFilteredTasks;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    tasksFuture = taskService.getMyTasks();
  }

  Future<void> refreshTasks() async {
    final future = taskService.getMyTasks();

    setState(() {
      tasksFuture = future;
    });

    await future;
  }

  Future<void> changeStatus(TaskModel task, String status) async {
    try {
      await taskService.updateTaskStatus(taskId: task.id, status: status);

      await refreshTasks();

      if (!mounted) return;

      AppSnackBar.success(context, 'Status zadania został zmieniony');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(context, e, fallback: 'Błąd zmiany statusu zadania');
    }
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Szukaj zadania...',
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Wszystkie'),
          selected: selectedFilter == MyTaskFilter.all,
          onSelected: (_) {
            setState(() {
              selectedFilter = MyTaskFilter.all;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Do zrobienia'),
          selected: selectedFilter == MyTaskFilter.todo,
          onSelected: (_) {
            setState(() {
              selectedFilter = MyTaskFilter.todo;
            });
          },
        ),
        ChoiceChip(
          label: const Text('W trakcie'),
          selected: selectedFilter == MyTaskFilter.inProgress,
          onSelected: (_) {
            setState(() {
              selectedFilter = MyTaskFilter.inProgress;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Zrobione'),
          selected: selectedFilter == MyTaskFilter.done,
          onSelected: (_) {
            setState(() {
              selectedFilter = MyTaskFilter.done;
            });
          },
        ),
      ],
    );
  }

  Widget buildTaskCard(TaskModel task) {
    final event = task.event;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTaskStatus.color(task.status),
          foregroundColor: Colors.white,
          child: Icon(AppTaskStatus.icon(task.status)),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${task.description?.isNotEmpty == true ? task.description! : 'Brak opisu'}\n'
          'Wydarzenie: ${event?.title ?? '-'}\n'
          'Data: ${event != null ? AppFormatters.dateTime(event.date) : '-'}',
        ),
        isThreeLine: true,
        trailing: SizedBox(
          width: 132,
          child: DropdownButton<String>(
            value: task.status,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: 'TODO',
                child: Text(AppTaskStatus.label('TODO')),
              ),
              DropdownMenuItem(
                value: 'IN_PROGRESS',
                child: Text(AppTaskStatus.label('IN_PROGRESS')),
              ),
              DropdownMenuItem(
                value: 'DONE',
                child: Text(AppTaskStatus.label('DONE')),
              ),
            ],
            onChanged: (value) {
              if (value == null || value == task.status) return;

              changeStatus(task, value);
            },
          ),
        ),
        onTap: event == null
            ? null
            : () {
                context.push('/events/${event.id}');
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moje zadania')),
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
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Nie udało się pobrać Twoich zadań',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
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
                  Icon(Icons.assignment_outlined, size: 56, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    'Brak przypisanych zadań',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tutaj pojawią się zadania przypisane bezpośrednio do Ciebie.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final filteredTasks = filterTasks(tasks);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                buildSearchField(),
                const SizedBox(height: 16),
                buildFilterSelector(),
                const SizedBox(height: 16),

                if (filteredTasks.isEmpty) ...[
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.filter_alt_off,
                    size: 56,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Brak wyników',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nie znaleziono zadań pasujących do wyszukiwania lub filtra.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  ...filteredTasks.map(buildTaskCard),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
