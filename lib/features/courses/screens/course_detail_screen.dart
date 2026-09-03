import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambase/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/announcements_icon_button.dart';
import '../../../shared/widgets/latest_announcement_banner.dart';
import '../../../shared/widgets/copyable_code.dart';
import '../../../shared/widgets/status_chip.dart';
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
      appBar: AppBar(
        title: Text(courseTitle),
        actions: [
          AnnouncementsIconButton(
            courseId: courseId,
            courseTitle: courseTitle,
            isInstructor: true,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enrollment code — tap to copy
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: AppColors.surface,
            child: Row(
              children: [
                const Icon(
                  Icons.key_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Enrollment Code', style: AppTypography.bodySecondary),
                const Spacer(),
                CopyableCode(code: accessCode, label: 'Enrollment code'),
              ],
            ),
          ),

          LatestAnnouncementBanner(
            courseId: courseId,
            courseTitle: courseTitle,
            isInstructor: true,
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text('Exams', style: AppTypography.heading2),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: examService.watchExamsForCourse(courseId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load exams.'));
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exam['title'] ?? 'Untitled Exam',
                                          style: AppTypography.heading3,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: AppSpacing.xs,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              '${exam['durationMinutes']} min · ${exam['totalMarks']} marks · ',
                                              style:
                                                  AppTypography.bodySecondary,
                                            ),
                                            CopyableCode(
                                              code: exam['examCode'] ?? '—',
                                              label: 'Exam code',
                                              compact: true,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  StatusChip(
                                    label: isPublished ? 'Published' : 'Draft',
                                    tone: isPublished
                                        ? StatusTone.success
                                        : StatusTone.warning,
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Divider(height: 1),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  _ActionIcon(
                                    icon: Icons.edit_outlined,
                                    tooltip: 'Questions',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ManageQuestionsScreen(
                                            examId: exam['id'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  _ActionIcon(
                                    icon: Icons.bar_chart_outlined,
                                    tooltip: 'Results',
                                    onTap: () {
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
                                  _ActionIcon(
                                    icon: resultsPublished
                                        ? Icons.check_circle
                                        : Icons.publish_outlined,
                                    tooltip: resultsPublished
                                        ? 'Results Published'
                                        : 'Release Results',
                                    color: resultsPublished
                                        ? AppColors.success
                                        : AppColors.primary,
                                    onTap: () async {
                                      final closeAt =
                                          (exam['closeAt'] as Timestamp)
                                              .toDate();
                                      try {
                                        await examService.togglePublishResults(
                                          exam['id'],
                                          !resultsPublished,
                                          closeAt,
                                        );
                                        if (!resultsPublished) {
                                          // Only notify when actually releasing (not when un-publishing)
                                          await NotificationService()
                                              .notifyResultsReleased(
                                                examId: exam['id'],
                                              );
                                        }
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
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  _ActionIcon(
                                    icon: Icons.delete_outline,
                                    tooltip: 'Delete',
                                    color: AppColors.error,
                                    onTap: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Delete Exam?'),
                                          content: Text(
                                            'This will permanently delete "${exam['title']}" and all its '
                                            'questions. This cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.error,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
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

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Icon(icon, size: 22, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}
