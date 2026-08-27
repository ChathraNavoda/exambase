import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../exams/screens/create_exam_screen.dart';
import '../../exams/screens/manage_questions_screen.dart';
import '../../exams/screens/results_overview_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final String accessCode;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.accessCode,
  });

  @override
  Widget build(BuildContext context) {
    final examService = ExamService();

    return Scaffold(
      appBar: AppBar(title: Text(courseTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enrollment code
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: AppColors.surface,
            child: Row(
              children: [
                const Icon(Icons.key, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text('Enrollment Code: ', style: AppTypography.bodySecondary),
                Text(
                  accessCode,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Exams heading
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text('Exams', style: AppTypography.heading2),
          ),

          // Exams list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: examService.watchExamsForCourse(courseId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load exams.',
                      style: AppTypography.body,
                    ),
                  );
                }

                final exams = snapshot.data ?? [];

                if (exams.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('No exams yet. Tap "New Exam" to create one.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: exams.length,
                  itemBuilder: (context, i) {
                    final exam = exams[i];

                    final isPublished = exam['isPublished'] == true;

                    final resultsPublished = exam['resultsPublished'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Exam information
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      exam['title'] ?? 'Untitled Exam',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
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
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${exam['durationMinutes']} min · '
                                  '${exam['totalMarks']} marks · '
                                  'Code: ${exam['examCode'] ?? '—'}',
                                ),
                              ),
                            ),

                            const Divider(height: 1),

                            // Actions
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  // Questions
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ManageQuestionsScreen(
                                                  examId: exam['id'],
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Questions'),
                                    ),
                                  ),

                                  // Results
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ResultsOverviewScreen(
                                                  examId: exam['id'],
                                                  examTitle:
                                                      exam['title'] ?? '',
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.bar_chart),
                                      label: const Text('Results'),
                                    ),
                                  ),

                                  // Release Results
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final closeAt =
                                            (exam['closeAt'] as Timestamp)
                                                .toDate();
                                        try {
                                          await examService
                                              .togglePublishResults(
                                                exam['id'],
                                                !resultsPublished,
                                                closeAt,
                                              );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    AppColors.error,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: Icon(
                                        resultsPublished
                                            ? Icons.check_circle_outline
                                            : Icons.publish_outlined,
                                      ),
                                      label: Text(
                                        resultsPublished
                                            ? 'Published'
                                            : 'Release Results',
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: resultsPublished
                                            ? AppColors.success
                                            : AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Delete Exam?'),
                                            content: Text(
                                              'This will permanently delete "${exam['title']}" and all its questions and submissions data. This cannot be undone.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.error,
                                                ),
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await examService.deleteExam(
                                            exam['id'],
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.error,
                                      ),
                                      label: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

      // Create exam
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateExamScreen(courseId: courseId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Exam'),
      ),
    );
  }
}
