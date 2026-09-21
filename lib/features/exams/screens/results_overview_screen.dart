import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambase/core/services/report_service.dart';
import 'package:flutter/material.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class ResultsOverviewScreen extends StatelessWidget {
  final String examId;
  final String examTitle;

  const ResultsOverviewScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Results: $examTitle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: () async {
              final reportService = ReportService();
              final csv = await reportService.buildExamReportCsv(
                examId: examId,
                examTitle: examTitle,
              );
              reportService.downloadCsv(
                csv,
                '${examTitle.replaceAll(' ', '_')}_results.csv',
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('activities')
            .doc(examId)
            .get(),
        builder: (context, examSnap) {
          if (!examSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final exam = examSnap.data!.data() as Map<String, dynamic>? ?? {};
          final gradeBands =
              (exam['gradeBands'] as List?) ?? ExamService.defaultGradeBands;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('submissions')
                .where('activityId', isEqualTo: examId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final submissions = snapshot.data!.docs;

              if (submissions.isEmpty) {
                return const Center(child: Text('No submissions yet.'));
              }

              // Sort: submitted first (by score desc), then in-progress
              final sorted = [...submissions]
                ..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aSubmitted = aData['status'] == 'submitted';
                  final bSubmitted = bData['status'] == 'submitted';
                  if (aSubmitted != bSubmitted) return aSubmitted ? -1 : 1;
                  final aScore =
                      (aData['finalScore'] ?? aData['autoScore'] ?? 0) as num;
                  final bScore =
                      (bData['finalScore'] ?? bData['autoScore'] ?? 0) as num;
                  return bScore.compareTo(aScore);
                });

              final submittedDocs = submissions
                  .where(
                    (d) =>
                        (d.data() as Map<String, dynamic>)['status'] ==
                        'submitted',
                  )
                  .toList();
              final scores = submittedDocs
                  .map(
                    (d) =>
                        ((d.data() as Map<String, dynamic>)['finalScore'] ??
                                (d.data()
                                    as Map<String, dynamic>)['autoScore'] ??
                                0)
                            as num,
                  )
                  .toList();
              final average = scores.isEmpty
                  ? 0
                  : scores.reduce((a, b) => a + b) / scores.length;
              final totalMarks = submissions.isNotEmpty
                  ? (submissions.first.data()
                            as Map<String, dynamic>)['totalMarks'] ??
                        0
                  : 0;
              final pendingGradingCount = submittedDocs
                  .where(
                    (d) =>
                        (d.data()
                            as Map<String, dynamic>)['manualGradingComplete'] ==
                        false,
                  )
                  .length;

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatColumn(
                              label: 'Submitted',
                              value: '${submittedDocs.length}',
                            ),
                            _StatColumn(
                              label: 'Average',
                              value:
                                  '${average.toStringAsFixed(1)} / $totalMarks',
                            ),
                            _StatColumn(
                              label: 'Highest',
                              value: scores.isEmpty
                                  ? '—'
                                  : '${scores.reduce((a, b) => a > b ? a : b)} / $totalMarks',
                            ),
                          ],
                        ),
                        if (pendingGradingCount > 0) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningSurface,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusPill,
                              ),
                            ),
                            child: Text(
                              '$pendingGradingCount submission${pendingGradingCount == 1 ? '' : 's'} awaiting manual grading',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: sorted.length,
                      itemBuilder: (context, i) {
                        final data = sorted[i].data() as Map<String, dynamic>;
                        final isSubmitted = data['status'] == 'submitted';
                        final flags = (data['flags'] as List?) ?? [];
                        final finalScore =
                            (data['finalScore'] ?? data['autoScore'] ?? 0)
                                as num;
                        final total = (data['totalMarks'] ?? 0) as num;
                        final percent = total > 0
                            ? (finalScore / total * 100)
                            : 0.0;
                        final grade = ExamService.gradeForPercent(
                          gradeBands,
                          percent.toDouble(),
                        );
                        final gradingPending =
                            data['manualGradingComplete'] == false;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(data['studentId'])
                              .get(),
                          builder: (context, userSnap) {
                            final userData =
                                userSnap.data?.data() as Map<String, dynamic>?;
                            final name = userData?['name'] ?? 'Unknown student';
                            final email = userData?['email'] ?? '';

                            final subtitleParts = <String>[email];
                            if (flags.isNotEmpty) {
                              subtitleParts.add(
                                '⚠️ ${flags.length} flag${flags.length == 1 ? '' : 's'}',
                              );
                            }
                            if (gradingPending) {
                              subtitleParts.add('grading pending');
                            }

                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  subtitleParts.join('  ·  '),
                                  style: (flags.isNotEmpty || gradingPending)
                                      ? const TextStyle(
                                          color: AppColors.warning,
                                        )
                                      : null,
                                ),
                                trailing: isSubmitted
                                    ? Text(
                                        '$finalScore / $total  ($grade)',
                                        style: AppTypography.score,
                                      )
                                    : const Chip(label: Text('In Progress')),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.heading2),
        Text(label, style: AppTypography.bodySecondary),
      ],
    );
  }
}
