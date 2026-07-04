import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
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
  static const defaultProfileColor = '#2563EB';
  static const profileColorOptions = [
    '#2563EB',
    '#1E3A8A',
    '#16A34A',
    '#7C3AED',
    '#F97316',
    '#DC2626',
    '#64748B',
  ];

  final authService = AuthService();
  final imagePicker = ImagePicker();

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
  bool isAvatarSaving = false;
  String selectedProfileColor = defaultProfileColor;

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
    selectedProfileColor = user.profileColor ?? defaultProfileColor;

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
        profileColor: selectedProfileColor,
        phone: emptyToNull(phoneController.text),
        bio: emptyToNull(bioController.text),
      );

      if (!mounted) return;

      setState(() {
        selectedProfileColor = updatedUser.profileColor ?? selectedProfileColor;
        avatarUrlController.text = updatedUser.avatarUrl ?? '';
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

  String? resolvedAvatarUrl() {
    final avatarUrl = avatarUrlController.text.trim();

    if (avatarUrl.isEmpty) {
      return null;
    }

    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl;
    }

    if (avatarUrl.startsWith('/')) {
      return '${ApiConstants.baseUrl}$avatarUrl';
    }

    return avatarUrl;
  }

  Color colorFromHex(String? value) {
    final normalized = (value ?? defaultProfileColor).replaceFirst('#', '');

    if (normalized.length != 6) {
      return Theme.of(context).colorScheme.primary;
    }

    try {
      return Color(int.parse('FF$normalized', radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String initialsForName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  void applyUpdatedUser(UserModel user, {bool syncTextFields = false}) {
    selectedProfileColor = user.profileColor ?? selectedProfileColor;
    avatarUrlController.text = user.avatarUrl ?? '';

    if (syncTextFields) {
      nameController.text = user.name;
      emailController.text = user.email;
      phoneController.text = user.phone ?? '';
      bioController.text = user.bio ?? '';
    }

    userFuture = Future.value(user);
  }

  Future<void> showAvatarOptions() async {
    if (isAvatarSaving) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final hasAvatar = avatarUrlController.text.trim().isNotEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Zmień zdjęcie'),
                  onTap: () {
                    Navigator.of(context).pop();
                    pickAvatarImage();
                  },
                ),
                if (hasAvatar)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Usuń zdjęcie'),
                    onTap: () {
                      Navigator.of(context).pop();
                      deleteAvatar();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Zmień kolor profilu'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showColorPickerSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> pickAvatarImage() async {
    final pickedImage = await imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      isAvatarSaving = true;
    });

    try {
      final updatedUser = await authService.uploadAvatar(
        bytes: await pickedImage.readAsBytes(),
        fileName: pickedImage.name,
      );

      if (!mounted) return;

      setState(() {
        applyUpdatedUser(updatedUser);
      });

      AppSnackBar.success(context, 'Avatar został zaktualizowany');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(context, e, fallback: 'Nie udało się przesłać avatara');
    } finally {
      if (mounted) {
        setState(() {
          isAvatarSaving = false;
        });
      }
    }
  }

  Future<void> deleteAvatar() async {
    setState(() {
      isAvatarSaving = true;
    });

    try {
      final updatedUser = await authService.deleteAvatar();

      if (!mounted) return;

      setState(() {
        applyUpdatedUser(updatedUser);
      });

      AppSnackBar.success(context, 'Avatar został usunięty');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(context, e, fallback: 'Nie udało się usunąć avatara');
    } finally {
      if (mounted) {
        setState(() {
          isAvatarSaving = false;
        });
      }
    }
  }

  Future<void> showColorPickerSheet() async {
    final selectedColor = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kolor profilu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: profileColorOptions.map((colorValue) {
                    final color = colorFromHex(colorValue);
                    final isSelected = selectedProfileColor == colorValue;

                    return InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.of(context).pop(colorValue);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.white,
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.24),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedColor == null || selectedColor == selectedProfileColor) {
      return;
    }

    await updateProfileColor(selectedColor);
  }

  Future<void> updateProfileColor(String profileColor) async {
    setState(() {
      isAvatarSaving = true;
    });

    try {
      final updatedUser = await authService.updateProfileColor(profileColor);

      if (!mounted) return;

      setState(() {
        applyUpdatedUser(updatedUser);
      });

      AppSnackBar.success(context, 'Kolor profilu został zapisany');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się zapisać koloru profilu',
      );
    } finally {
      if (mounted) {
        setState(() {
          isAvatarSaving = false;
        });
      }
    }
  }

  Widget buildAvatarPreview() {
    final avatarUrl = resolvedAvatarUrl();
    final profileColor = colorFromHex(selectedProfileColor);
    final initials = initialsForName(nameController.text);

    return Semantics(
      button: true,
      label: 'Zmień avatar',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isAvatarSaving ? null : showAvatarOptions,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 62,
              backgroundColor: profileColor,
              foregroundColor: Colors.white,
              backgroundImage: avatarUrl == null
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            if (isAvatarSaving)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
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
          onPressed: isSaving || isAvatarSaving ? null : saveProfile,
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
