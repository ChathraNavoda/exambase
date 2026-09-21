import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class ManualGradingScreen extends StatelessWidget {
  final String examId;
  final String examTitle;

  const ManualGradingScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  Widget build(BuildContext context) {
    final examService = ExamService();
    final submissionService = SubmissionService();

    return Scaffold(
      appBar: AppBar(title: Text('Grade · $examTitle')),
      body: StreamBuilder<List<ExamQuestion>>(
        stream: examService.watchQuestions(examId),
        builder: (context, questionsSnap) {
          final questions = questionsSnap.data ?? [];
          final shortAnswerQuestions = questions
              .where((q) => q.isShortAnswer)
              .toList();

          if (shortAnswerQuestions.isEmpty) {
            return const Center(
              child: Text('This exam has no short-answer questions to grade.'),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('submissions')
                .where('activityId', isEqualTo: examId)
                .where('status', isEqualTo: 'submitted')
                .snapshots(),
            builder: (context, subSnap) {
              if (!subSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final submissions = subSnap.data!.docs;
              if (submissions.isEmpty) {
                return const Center(child: Text('No submissions yet.'));
              }

              final sorted = [...submissions]
                ..sort((a, b) {
                  final aGraded =
                      (a.data() as Map)['manualGradingComplete'] == true;
                  final bGraded =
                      (b.data() as Map)['manualGradingComplete'] == true;
                  if (aGraded != bGraded) return aGraded ? 1 : -1;
                  return 0;
                });

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: sorted.length,
                itemBuilder: (context, i) {
                  final subDoc = sorted[i];
                  final subData = subDoc.data() as Map<String, dynamic>;
                  final answers = List<Map<String, dynamic>>.from(
                    subData['answers'] ?? [],
                  );
                  final manualScores = Map<String, dynamic>.from(
                    subData['manualScores'] ?? {},
                  );
                  final graded = subData['manualGradingComplete'] == true;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(subData['studentId'])
                        .get(),
                    builder: (context, userSnap) {
                      final userData =
                          userSnap.data?.data() as Map<String, dynamic>?;
                      final name = userData?['name'] ?? 'Unknown student';

                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ExpansionTile(
                          title: Text(name, style: AppTypography.bodyMedium),
                          trailing: Icon(
                            graded
                                ? Icons.check_circle
                                : Icons.pending_outlined,
                            color: graded
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          children: shortAnswerQuestions.map((q) {
                            final answerEntry = answers.firstWhere(
                              (a) => a['questionId'] == q.id,
                              orElse: () => {'answerText': ''},
                            );
                            final existingMark = manualScores[q.id];
                            final marksController = TextEditingController(
                              text: existingMark != null ? '$existingMark' : '',
                            );

                            return Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.questionText,
                                    style: AppTypography.bodyMedium,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSm,
                                      ),
                                    ),
                                    child: Text(
                                      answerEntry['answerText']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? answerEntry['answerText']
                                          : '(no answer given)',
                                      style: AppTypography.bodySecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: marksController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Marks (max ${q.marks})',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final awarded = num.tryParse(
                                            marksController.text,
                                          );
                                          if (awarded == null ||
                                              awarded < 0 ||
                                              awarded > q.marks) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Enter a value between 0 and ${q.marks}.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          await submissionService
                                              .saveManualGrade(
                                                submissionId: subDoc.id,
                                                questionId: q.id!,
                                                marksAwarded: awarded,
                                                allQuestions: questions,
                                              );
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
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
