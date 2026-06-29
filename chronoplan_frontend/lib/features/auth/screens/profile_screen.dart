import 'package:flutter/material.dart';

import '../../../core/utils/app_snack_bar.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final authService = AuthService();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final avatarUrlController = TextEditingController();
  final phoneController = TextEditingController();
  final bioController = TextEditingController();

  late Future<UserModel> userFuture;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    userFuture = loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    avatarUrlController.dispose();
    phoneController.dispose();
    bioController.dispose();

    super.dispose();
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
      AppSnackBar.info(
        context,
        'Podaj nazwę użytkownika',
      );
      return;
    }

    if (email.isEmpty) {
      AppSnackBar.info(
        context,
        'Podaj email',
      );
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

      AppSnackBar.success(
        context,
        'Profil został zaktualizowany',
      );
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
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
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
        Center(
          child: buildAvatarPreview(),
        ),
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
            const Icon(
              Icons.error_outline,
              size: 56,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nie udało się pobrać profilu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
      appBar: AppBar(
        title: const Text('Mój profil'),
      ),
      body: FutureBuilder<UserModel>(
        future: userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return buildErrorBody(snapshot.error!);
          }

          return buildProfileForm();
        },
      ),
    );
  }
}