import 'package:exambase/features/dashboard/screens/timeline_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/course_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../courses/screens/create_course_screen.dart';
import '../../courses/screens/course_detail_screen.dart';

class InstructorDashboard extends StatelessWidget {
  const InstructorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final courseService = CourseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'Timeline',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TimelineScreen()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: courseService.watchCoursesForInstructor(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final courses = snapshot.data ?? [];
            if (courses.isEmpty) {
              return const Text(
                'No courses yet. Tap "New Course" to create one.',
              );
            }
            return ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, i) {
                final course = courses[i];
                final studentCount =
                    (course['studentIds'] as List?)?.length ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Text(course['title'] ?? 'Untitled Course'),
                    subtitle: Text(
                      '$studentCount student${studentCount == 1 ? '' : 's'} enrolled',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(
                            courseId: course['id'],
                            courseTitle: course['title'] ?? '',
                            accessCode: course['accessCode'] ?? '',
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreateCourseScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('New Course'),
      ),
    );
  }
}
