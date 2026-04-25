import 'package:flutter/material.dart';
import 'features/auth/presentation/pages/login_page.dart';

class PianoMissPassApp extends StatelessWidget {
  const PianoMissPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Practice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F7A8C)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
