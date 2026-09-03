import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/course_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data!.data() as Map<String, dynamic>?;
          final name = user?['name'] ?? 'Student';
          final email = user?['email'] ?? '';
          final initials = name.isNotEmpty
              ? name
                    .trim()
                    .split(' ')
                    .map((w) => w.isNotEmpty ? w[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase()
              : '?';

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        initials,
                        style: AppTypography.heading1.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(name, style: AppTypography.heading2),
                    const SizedBox(height: 4),
                    Text(email, style: AppTypography.bodySecondary),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text('Enrolled Courses', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: CourseService().watchCoursesForStudent(uid),
                builder: (context, courseSnap) {
                  final courses = courseSnap.data ?? [];
                  if (courses.isEmpty) {
                    return Text(
                      'Not enrolled in any courses yet.',
                      style: AppTypography.bodySecondary,
                    );
                  }
                  return Column(
                    children: courses.map((c) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: const Icon(Icons.school_outlined),
                          title: Text(c['title'] ?? ''),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
