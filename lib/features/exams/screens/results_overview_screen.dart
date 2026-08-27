import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
      appBar: AppBar(title: Text('Results: $examTitle')),
      body: StreamBuilder<QuerySnapshot>(
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
              final aScore = aData['autoScore'] ?? 0;
              final bScore = bData['autoScore'] ?? 0;
              return (bScore as int).compareTo(aScore as int);
            });

          final submittedCount = submissions
              .where(
                (d) =>
                    (d.data() as Map<String, dynamic>)['status'] == 'submitted',
              )
              .length;
          final scores = submissions
              .where(
                (d) =>
                    (d.data() as Map<String, dynamic>)['status'] == 'submitted',
              )
              .map(
                (d) =>
                    (d.data() as Map<String, dynamic>)['autoScore'] as int? ??
                    0,
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

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: AppColors.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(label: 'Submitted', value: '$submittedCount'),
                    _StatColumn(
                      label: 'Average',
                      value: '${average.toStringAsFixed(1)} / $totalMarks',
                    ),
                    _StatColumn(
                      label: 'Highest',
                      value: scores.isEmpty
                          ? '—'
                          : '${scores.reduce((a, b) => a > b ? a : b)} / $totalMarks',
                    ),
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

                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(
                              flags.isNotEmpty
                                  ? '$email  ·  ⚠️ ${flags.length} flag${flags.length == 1 ? '' : 's'}'
                                  : email,
                              style: flags.isNotEmpty
                                  ? const TextStyle(color: AppColors.warning)
                                  : null,
                            ),
                            trailing: isSubmitted
                                ? Text(
                                    '${data['autoScore']} / ${data['totalMarks']}',
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
