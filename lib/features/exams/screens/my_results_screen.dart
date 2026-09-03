import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/course_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'course_results_screen.dart';

class MyResultsScreen extends StatelessWidget {
  const MyResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final courseService = CourseService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Results')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: courseService.watchCoursesForStudent(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(
              child: Text('You are not enrolled in any courses yet.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: courses.length,
            itemBuilder: (context, i) {
              final course = courses[i];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: Text(
                    course['title'] ?? 'Untitled Course',
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: const Text('Tap to view your results'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseResultsScreen(
                          courseId: course['id'],
                          courseTitle: course['title'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
