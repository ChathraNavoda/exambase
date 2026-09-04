import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/announcements_icon_button.dart';
import '../../../shared/widgets/latest_announcement_banner.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'take_exam_screen.dart';

class ExamListScreen extends StatelessWidget {
  final String courseId;
  const ExamListScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
        actions: [
          AnnouncementsIconButton(
            courseId: courseId,
            courseTitle: '',
            isInstructor: false,
          ),
        ],
      ),
      body: Column(
        children: [
          LatestAnnouncementBanner(
            courseId: courseId,
            courseTitle: '',
            isInstructor: false,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activities')
                  .where('courseId', isEqualTo: courseId)
                  .where('type', isEqualTo: 'mcq_exam')
                  .where('isPublished', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final exams = snapshot.data!.docs;
                if (exams.isEmpty) {
                  return const Center(child: Text('No exams available yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: exams.length,
                  itemBuilder: (context, i) {
                    final doc = exams[i];
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['openAt'] == null ||
                        data['closeAt'] == null ||
                        data['examCode'] == null) {
                      return const SizedBox.shrink();
                    }

                    final openAt = (data['openAt'] as Timestamp).toDate();
                    final closeAt = (data['closeAt'] as Timestamp).toDate();
                    final duration = data['durationMinutes'] as int;
                    final lastStart = closeAt.subtract(
                      Duration(minutes: duration),
                    );
                    final now = DateTime.now();

                    return FutureBuilder<DocumentSnapshot?>(
                      future: SubmissionService().getExistingSubmission(
                        activityId: doc.id,
                        studentId: FirebaseAuth.instance.currentUser!.uid,
                      ),
                      builder: (context, subSnap) {
                        final existingData =
                            subSnap.data?.data() as Map<String, dynamic>?;
                        final status0 = existingData?['status'];

                        String status;
                        Color statusColor;
                        bool tappable;

                        if (status0 == 'submitted') {
                          status = 'Completed';
                          statusColor = AppColors.success;
                          tappable = false;
                        } else if (status0 == 'in_progress') {
                          status = 'Resume';
                          statusColor = AppColors.warning;
                          tappable = true; // tapping resumes
                        } else if (now.isBefore(openAt)) {
                          status = 'Pending';
                          statusColor = AppColors.textSecondary;
                          tappable = false;
                        } else if (now.isAfter(lastStart)) {
                          status = 'Expired';
                          statusColor = AppColors.error;
                          tappable = false;
                        } else {
                          status = 'Open';
                          statusColor = AppColors.primaryBlue;
                          tappable = true;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            title: Text(data['title'] ?? ''),
                            subtitle: Text(
                              '${data['durationMinutes']} min · Open ${_fmt(openAt)} – ${_fmt(closeAt)}',
                            ),
                            trailing: Chip(
                              label: Text(status),
                              backgroundColor: statusColor.withValues(
                                alpha: 0.15,
                              ),
                              labelStyle: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: tappable
                                ? () => _handleTap(context, doc.id, data)
                                : null,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _handleTap(
    BuildContext context,
    String examId,
    Map<String, dynamic> exam,
  ) async {
    final studentId = FirebaseAuth.instance.currentUser!.uid;
    final submissionService = SubmissionService();

    final existing = await submissionService.getExistingSubmission(
      activityId: examId,
      studentId: studentId,
    );

    if (existing != null) {
      final data = existing.data() as Map<String, dynamic>;

      if (data['status'] == 'submitted') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already attempted this exam.'),
            ),
          );
        }
        return;
      }

      // In-progress — resume instead of blocking.
      await submissionService.logFlag(
        submissionId: existing.id,
        flagType: 'resumed_session',
      );
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TakeExamScreen(
              examId: examId,
              submissionId: existing.id,
              shuffleSeed: data['shuffleSeed'] ?? 0,
              exam: exam,
              startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Exam Code'),
        content: AppTextField(controller: codeController, label: 'Exam Code'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, codeController.text),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (code == null || code.trim().isEmpty || !context.mounted) return;

    try {
      final result = await submissionService.startExam(
        exam: exam,
        activityId: examId,
        studentId: studentId,
        courseId: courseId,
        enteredCode: code,
      );

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TakeExamScreen(
              examId: examId,
              submissionId: result['submissionId'],
              shuffleSeed: result['shuffleSeed'],
              exam: exam,
              startedAt: null, // fresh start, TakeExamScreen uses full duration
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
