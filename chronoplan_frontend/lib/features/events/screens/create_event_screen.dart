import 'package:chronoplan_frontend/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/app_snack_bar.dart';
import 'location_picker_screen.dart';


import '../services/event_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationNameController = TextEditingController();
  final locationAddressController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  final eventService = EventService();

  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay selectedTime = TimeOfDay.now();

  String selectedBudgetMode = 'SHARED';

  bool isLoading = false;

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

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
    });
  }

  Future<void> pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
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
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  String formatTime(TimeOfDay time) {
    return '${AppFormatters.twoDigits(time.hour)}:${AppFormatters.twoDigits(time.minute)}';
  }

  Future<void> createEvent() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      AppSnackBar.info(
        context,
        'Podaj tytuł wydarzenia',
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
      isLoading = true;
    });

    try {
      await eventService.createEvent(
        title: title,
        description: description.isEmpty ? null : description,
        date: selectedDateTime,
        budgetMode: selectedBudgetMode,
        locationName: emptyToNull(locationNameController.text),
        locationAddress: emptyToNull(locationAddressController.text),
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydarzenie zostało utworzone',
      );

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Błąd tworzenia wydarzenia',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowe wydarzenie'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Utwórz wydarzenie',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tytuł wydarzenia',
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Data'),
                      subtitle: Text(AppFormatters.date(selectedDate)),
                      trailing: TextButton(
                        onPressed: pickDate,
                        child: const Text('Zmień'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Godzina'),
                      subtitle: Text(formatTime(selectedTime)),
                      trailing: TextButton(
                        onPressed: pickTime,
                        child: const Text('Zmień'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBudgetMode,
                      decoration: const InputDecoration(
                        labelText: 'Tryb budżetu',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'SHARED',
                          child: Text('Wspólny'),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE',
                          child: Text('Prywatny'),
                        ),
                        DropdownMenuItem(
                          value: 'MIXED',
                          child: Text('Mieszany'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          selectedBudgetMode = value;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    Text(
                      getBudgetModeDescription(selectedBudgetMode),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isLoading ? null : createEvent,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Utwórz wydarzenie'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String getBudgetModeDescription(String mode) {
    switch (mode) {
      case 'PRIVATE':
        return 'Koszty widzi tylko organizator. Dobre np. dla wesela.';
      case 'MIXED':
        return 'Część kosztów może być prywatna, a część wspólna.';
      case 'SHARED':
      default:
        return 'Uczestnicy widzą koszty i można ich rozliczać.';
    }
  }
}