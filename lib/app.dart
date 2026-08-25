import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'features/auth/screens/login_screen.dart';

class ExamBaseApp extends StatelessWidget {
  const ExamBaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamBase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Logged in — placeholder until we build the dashboards
            return const Scaffold(
              body: Center(child: Text('Logged in! Dashboard coming next.')),
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
