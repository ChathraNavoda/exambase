import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class CourseResultsScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;

  const CourseResultsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Results · $courseTitle')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .where('courseId', isEqualTo: courseId)
            .where('status', isEqualTo: 'submitted')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SelectableText(
                  'Could not load results: ${snapshot.error}',
                  style: AppTypography.bodySecondary.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final submissions = snapshot.data!.docs;
          if (submissions.isEmpty) {
            return const Center(
              child: Text('No submitted exams in this course yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: submissions.length,
            itemBuilder: (context, i) {
              final sub = submissions[i].data() as Map<String, dynamic>;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('activities')
                    .doc(sub['activityId'])
                    .get(),
                builder: (context, examSnap) {
                  if (!examSnap.hasData) return const SizedBox.shrink();
                  final exam = examSnap.data!.data() as Map<String, dynamic>?;
                  if (exam == null) return const SizedBox.shrink();

                  final published = exam['resultsPublished'] == true;
                  final gradingPending = sub['manualGradingComplete'] == false;

                  final finalScore =
                      (sub['finalScore'] ?? sub['autoScore'] ?? 0) as num;
                  final total = (sub['totalMarks'] ?? 0) as num;
                  final percent = total > 0 ? (finalScore / total * 100) : 0.0;
                  final gradeBands =
                      (exam['gradeBands'] as List?) ??
                      ExamService.defaultGradeBands;
                  final grade = ExamService.gradeForPercent(
                    gradeBands,
                    percent.toDouble(),
                  );

                  Widget trailing;
                  if (!published) {
                    trailing = Text(
                      'Pending',
                      style: AppTypography.bodySecondary,
                    );
                  } else if (gradingPending) {
                    trailing = Text(
                      'Grading pending',
                      style: AppTypography.bodySecondary.copyWith(
                        color: AppColors.warning,
                      ),
                    );
                  } else {
                    trailing = Text(
                      '$finalScore / $total  ($grade)',
                      style: AppTypography.score,
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text(exam['title'] ?? ''),
                      trailing: trailing,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
