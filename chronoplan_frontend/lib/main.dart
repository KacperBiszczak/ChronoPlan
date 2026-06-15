import 'package:flutter/material.dart';

void main() {
  runApp(const ChronoPlanApp());
}

class ChronoPlanApp extends StatelessWidget {
  const ChronoPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChronoPlan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Ekran logowania ChronoPlan',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}