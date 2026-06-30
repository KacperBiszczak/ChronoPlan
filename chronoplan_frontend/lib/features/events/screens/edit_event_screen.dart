import 'package:chronoplan_frontend/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/app_snack_bar.dart';
import 'location_picker_screen.dart';

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
  final locationNameController = TextEditingController();
  final locationAddressController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

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
    locationNameController.dispose();
    locationAddressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  Future<void> loadEvent() async {
    try {
      final event = await eventService.getEventById(widget.eventId);

      titleController.text = event.title;
      descriptionController.text = event.description ?? '';

      locationNameController.text = event.locationName ?? '';
      locationAddressController.text = event.locationAddress ?? '';
      latitudeController.text = event.latitude?.toString() ?? '';
      longitudeController.text = event.longitude?.toString() ?? '';

      selectedDate = event.date;
      selectedTime = TimeOfDay.fromDateTime(event.date);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się pobrać wydarzenia',
      );
    }
  }

  String? emptyToNull(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  double? parseOptionalDouble(String value) {
    final trimmed = value.trim().replaceAll(',', '.');

    if (trimmed.isEmpty) {
      return null;
    }

    return double.tryParse(trimmed);
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

  Future<void> pickLocationFromMap() async {
    final currentLatitude = parseOptionalDouble(latitudeController.text);
    final currentLongitude = parseOptionalDouble(longitudeController.text);

    final result = await context.push<PickedLocation>(
      '/location-picker',
      extra: {
        'latitude': currentLatitude,
        'longitude': currentLongitude,
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      latitudeController.text = result.latitude.toStringAsFixed(6);
      longitudeController.text = result.longitude.toStringAsFixed(6);
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Wybierz datę';

    return AppFormatters.date(date);
  }

  String formatTime(TimeOfDay? time) {
    if (time == null) return 'Wybierz godzinę';

    return '${AppFormatters.twoDigits(time.hour)}:${AppFormatters.twoDigits(time.minute)}';
  }

  Future<void> updateEvent() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      AppSnackBar.info(
        context,
        'Podaj nazwę wydarzenia',
      );
      return;
    }

    final latitudeText = latitudeController.text.trim();
    final longitudeText = longitudeController.text.trim();

    final latitude = parseOptionalDouble(latitudeText);
    final longitude = parseOptionalDouble(longitudeText);

    if (latitudeText.isNotEmpty && latitude == null) {
      AppSnackBar.info(
        context,
        'Szerokość geograficzna musi być liczbą',
      );
      return;
    }

    if (longitudeText.isNotEmpty && longitude == null) {
      AppSnackBar.info(
        context,
        'Długość geograficzna musi być liczbą',
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
        locationName: emptyToNull(locationNameController.text),
        locationAddress: emptyToNull(locationAddressController.text),
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydarzenie zostało zaktualizowane',
      );

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Błąd aktualizacji wydarzenia',
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
          TextField(
            controller: locationNameController,
            decoration: const InputDecoration(
              labelText: 'Nazwa miejsca',
              hintText: 'Np. Restauracja, sala, park',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: locationAddressController,
            decoration: const InputDecoration(
              labelText: 'Adres',
              hintText: 'Np. ul. Przykładowa 10, Warszawa',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latitudeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Szerokość geograficzna',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: longitudeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Długość geograficzna',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: pickLocationFromMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Wybierz punkt na mapie'),
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