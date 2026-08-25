import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import 'student_dashboard.dart';
import 'instructor_dashboard.dart';

class RoleRouter extends StatelessWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService().getUserRole(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data;

        if (role == 'instructor') {
          return const InstructorDashboard();
        }
        if (role == 'student') {
          return const StudentDashboard();
        }

        // Role missing or unrecognized — shouldn't normally happen,
        // but fail safely instead of crashing.
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Something went wrong loading your account.'),
                TextButton(
                  onPressed: () => AuthService().signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
