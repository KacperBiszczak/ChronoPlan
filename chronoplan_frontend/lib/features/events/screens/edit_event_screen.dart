import 'package:chronoplan_frontend/core/utils/formatters.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/event_service.dart';

class EditEventScreen extends StatefulWidget {
  final int eventId;

  const EditEventScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final eventService = EventService();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadEvent();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadEvent() async {
    try {
      final event = await eventService.getEventById(widget.eventId);

      titleController.text = event.title;
      descriptionController.text = event.description ?? '';
      selectedDate = event.date;
      selectedTime = TimeOfDay.fromDateTime(event.date);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się pobrać wydarzenia'),
        ),
      );
    }
  }

  DateTime get selectedDateTime {
    final date = selectedDate ?? DateTime.now();
    final time = selectedTime ?? TimeOfDay.now();

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> pickDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
    });
  }

  Future<void> pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      selectedTime = pickedTime;
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Wybierz datę';

    return AppFormatters.date(date);
  }

  String formatTime(TimeOfDay? time) {
    if (time == null) return 'Wybierz godzinę';

    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> updateEvent() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podaj nazwę wydarzenia'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await eventService.updateEvent(
        id: widget.eventId,
        title: title,
        description: description.isEmpty ? null : description,
        date: selectedDateTime,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wydarzenie zostało zaktualizowane'),
        ),
      );

      context.pop(true);
    } on DioException catch (error) {
      if (!mounted) return;

      final message =
          error.response?.data['message'] ?? 'Błąd aktualizacji wydarzenia';

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
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edytuj wydarzenie'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edytuj wydarzenie'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Nazwa wydarzenia',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Opis',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text('Data'),
              subtitle: Text(formatDate(selectedDate)),
              onTap: pickDate,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.access_time, color: Colors.blue),
              title: const Text('Godzina'),
              subtitle: Text(formatTime(selectedTime)),
              onTap: pickTime,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isSaving ? null : updateEvent,
            child: isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Zapisz zmiany'),
          ),
        ],
      ),
    );
  }
}