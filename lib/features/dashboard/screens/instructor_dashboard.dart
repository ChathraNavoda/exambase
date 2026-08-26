import 'package:exambase/features/exams/screens/create_exam_screen.dart';
import 'package:exambase/features/exams/screens/results_overview_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../exams/screens/manage_questions_screen.dart';

class InstructorDashboard extends StatelessWidget {
  const InstructorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final examService = ExamService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Exams', style: AppTypography.heading2),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: examService.watchExamsForInstructor(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final exams = snapshot.data ?? [];

                  if (exams.isEmpty) {
                    return const Text(
                      'No exams yet. Tap "New Exam" to create one.',
                    );
                  }

                  return ListView.builder(
                    itemCount: exams.length,
                    itemBuilder: (context, i) {
                      final exam = exams[i];
                      final isPublished = exam['isPublished'] == true;
                      final resultsPublished = exam['resultsPublished'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: ListTile(
                            title: Text(exam['title'] ?? 'Untitled Exam'),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${exam['durationMinutes']} min · ${exam['totalMarks']} marks · Code: ${exam['examCode'] ?? '—'}',
                              ),
                            ),
                            // Using OverflowBar or Row wrapped in IntrinsicWidth to prevent vertical tight constraints collision
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.bar_chart),
                                  tooltip: 'View Results',
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ResultsOverviewScreen(
                                          examId: exam['id'],
                                          examTitle: exam['title'] ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Chip(
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      label: Text(
                                        isPublished ? 'Published' : 'Draft',
                                      ),
                                      backgroundColor: isPublished
                                          ? AppColors.success.withOpacity(0.15)
                                          : AppColors.warning.withOpacity(0.15),
                                      labelStyle: TextStyle(
                                        color: isPublished
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: () async {
                                        final newValue = !resultsPublished;

                                        await examService.togglePublishResults(
                                          exam['id'],
                                          newValue,
                                        );
                                      },
                                      child: Text(
                                        resultsPublished
                                            ? 'Results Published'
                                            : 'Release Results',
                                        style: TextStyle(
                                          color: resultsPublished
                                              ? AppColors.success
                                              : AppColors.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ManageQuestionsScreen(examId: exam['id']),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const CreateExamScreen(courseId: 'iJ9fCIOHNbtjOnlGaQ1o'),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Exam'),
      ),
    );
  }
}
