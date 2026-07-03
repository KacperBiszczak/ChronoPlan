import 'package:flutter/material.dart';

import '../../../core/utils/app_snack_bar.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

import '../../../core/services/google_calendar_service.dart';
import '../../../core/utils/app_confirm_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final authService = AuthService();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final avatarUrlController = TextEditingController();
  final phoneController = TextEditingController();
  final bioController = TextEditingController();

  final googleCalendarService = GoogleCalendarService();

  late Future<bool> googleCalendarStatusFuture;

  bool isGoogleCalendarLoading = false;

  late Future<UserModel> userFuture;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    googleCalendarStatusFuture = googleCalendarService.getStatus();

    userFuture = loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nameController.dispose();
    emailController.dispose();
    avatarUrlController.dispose();
    phoneController.dispose();
    bioController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      refreshGoogleCalendarStatus();
    }
  }

  Future<UserModel> loadProfile() async {
    final user = await authService.getCurrentUser();

    nameController.text = user.name;
    emailController.text = user.email;
    avatarUrlController.text = user.avatarUrl ?? '';
    phoneController.text = user.phone ?? '';
    bioController.text = user.bio ?? '';

    return user;
  }

  String? emptyToNull(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  Future<void> saveProfile() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty) {
      AppSnackBar.info(context, 'Podaj nazwę użytkownika');
      return;
    }

    if (email.isEmpty) {
      AppSnackBar.info(context, 'Podaj email');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final updatedUser = await authService.updateProfile(
        name: name,
        email: email,
        avatarUrl: emptyToNull(avatarUrlController.text),
        phone: emptyToNull(phoneController.text),
        bio: emptyToNull(bioController.text),
      );

      if (!mounted) return;

      setState(() {
        userFuture = Future.value(updatedUser);
      });

      AppSnackBar.success(context, 'Profil został zaktualizowany');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się zaktualizować profilu',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildAvatarPreview() {
    final avatarUrl = avatarUrlController.text.trim();

    if (avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: Text(
          nameController.text.trim().isNotEmpty
              ? nameController.text.trim()[0].toUpperCase()
              : '?',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
      );
    }

    return CircleAvatar(
      radius: 48,
      backgroundColor: Colors.blue.shade100,
      backgroundImage: NetworkImage(avatarUrl),
    );
  }

  Widget buildProfileForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: buildAvatarPreview()),
        const SizedBox(height: 24),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nazwa użytkownika',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          onChanged: (_) {
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: avatarUrlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'URL avatara',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.image_outlined),
          ),
          onChanged: (_) {
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefon',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: bioController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Opis',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description_outlined),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isSaving ? null : saveProfile,
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(isSaving ? 'Zapisywanie...' : 'Zapisz profil'),
        ),
        const SizedBox(height: 16),
        buildGoogleCalendarSection(),
      ],
    );
  }

  Widget buildErrorBody(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Nie udało się pobrać profilu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  userFuture = loadProfile();
                });
              },
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mój profil')),
      body: FutureBuilder<UserModel>(
        future: userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return buildErrorBody(snapshot.error!);
          }

          return buildProfileForm();
        },
      ),
    );
  }

  Future<void> refreshGoogleCalendarStatus() async {
    final future = googleCalendarService.getStatus();

    setState(() {
      googleCalendarStatusFuture = future;
    });

    await future;
  }

  Future<void> connectGoogleCalendar() async {
    if (isGoogleCalendarLoading) return;

    setState(() {
      isGoogleCalendarLoading = true;
    });

    try {
      await googleCalendarService.connectGoogleCalendar(returnPath: '/#/home');

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Otworzono autoryzację Google Calendar. Po powrocie do aplikacji status odświeży się automatycznie.',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się połączyć Google Calendar',
      );
    } finally {
      if (mounted) {
        setState(() {
          isGoogleCalendarLoading = false;
        });
      }
    }
  }

  Future<void> disconnectGoogleCalendar() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Odłącz Google Calendar',
      message:
          'Czy na pewno chcesz odłączyć Google Calendar? Aplikacja usunie lokalne powiązania wydarzeń i spróbuje cofnąć dostęp do Twojego konta Google.',
      confirmText: 'Odłącz',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    if (isGoogleCalendarLoading) return;

    setState(() {
      isGoogleCalendarLoading = true;
    });

    try {
      await googleCalendarService.disconnectGoogleCalendar();

      if (!mounted) return;

      AppSnackBar.success(context, 'Google Calendar został odłączony');

      await refreshGoogleCalendarStatus();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się odłączyć Google Calendar',
      );
    } finally {
      if (mounted) {
        setState(() {
          isGoogleCalendarLoading = false;
        });
      }
    }
  }

  Widget buildGoogleCalendarSection() {
    return FutureBuilder<bool>(
      future: googleCalendarStatusFuture,
      builder: (context, snapshot) {
        final isConnected = snapshot.data == true;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Google Calendar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Odśwież status',
                      onPressed: isGoogleCalendarLoading
                          ? null
                          : refreshGoogleCalendarStatus,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isLoading
                      ? 'Sprawdzanie połączenia...'
                      : isConnected
                      ? 'Google Calendar jest połączony z Twoim kontem.'
                      : 'Google Calendar nie jest jeszcze połączony.',
                  style: TextStyle(
                    color: isConnected
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isGoogleCalendarLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: isConnected
                      ? OutlinedButton.icon(
                          onPressed: isGoogleCalendarLoading
                              ? null
                              : disconnectGoogleCalendar,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Odłącz Google Calendar'),
                        )
                      : FilledButton.icon(
                          onPressed: isGoogleCalendarLoading
                              ? null
                              : connectGoogleCalendar,
                          icon: const Icon(Icons.link),
                          label: const Text('Połącz Google Calendar'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
