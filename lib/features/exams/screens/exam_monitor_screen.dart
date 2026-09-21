import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/status_chip.dart';

class ExamMonitorScreen extends StatelessWidget {
  final String examId;
  final String examTitle;
  final String courseId;

  const ExamMonitorScreen({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Monitor · $examTitle')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .snapshots(),
        builder: (context, courseSnap) {
          if (!courseSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final courseData = courseSnap.data!.data() as Map<String, dynamic>?;
          final studentIds = List<String>.from(courseData?['studentIds'] ?? []);

          if (studentIds.isEmpty) {
            return const Center(
              child: Text('No students enrolled in this course yet.'),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('submissions')
                .where('activityId', isEqualTo: examId)
                .snapshots(),
            builder: (context, subSnap) {
              if (!subSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Map studentId -> their submission data, if any
              final submissionByStudent = <String, Map<String, dynamic>>{};
              for (final doc in subSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                submissionByStudent[data['studentId']] = data;
              }

              final notStarted = <String>[];
              final inProgress = <String>[];
              final submitted = <String>[];

              for (final sid in studentIds) {
                final sub = submissionByStudent[sid];
                if (sub == null) {
                  notStarted.add(sid);
                } else if (sub['status'] == 'submitted') {
                  submitted.add(sid);
                } else {
                  inProgress.add(sid);
                }
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    color: AppColors.surface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatColumn(
                          label: 'Enrolled',
                          value: '${studentIds.length}',
                          color: AppColors.textPrimary,
                        ),
                        _StatColumn(
                          label: 'Not Started',
                          value: '${notStarted.length}',
                          color: AppColors.textSecondary,
                        ),
                        _StatColumn(
                          label: 'In Progress',
                          value: '${inProgress.length}',
                          color: AppColors.warning,
                        ),
                        _StatColumn(
                          label: 'Submitted',
                          value: '${submitted.length}',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (inProgress.isNotEmpty) ...[
                          _SectionLabel(
                            label: 'In Progress',
                            color: AppColors.warning,
                          ),
                          ...inProgress.map(
                            (sid) => _StudentRow(
                              studentId: sid,
                              submission: submissionByStudent[sid],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (notStarted.isNotEmpty) ...[
                          _SectionLabel(
                            label: 'Not Started',
                            color: AppColors.textSecondary,
                          ),
                          ...notStarted.map(
                            (sid) =>
                                _StudentRow(studentId: sid, submission: null),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (submitted.isNotEmpty) ...[
                          _SectionLabel(
                            label: 'Submitted',
                            color: AppColors.success,
                          ),
                          ...submitted.map(
                            (sid) => _StudentRow(
                              studentId: sid,
                              submission: submissionByStudent[sid],
                            ),
                          ),
                        ],
                      ],
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
  final Color color;
  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.heading2.copyWith(color: color)),
        Text(label, style: AppTypography.bodySecondary),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: AppTypography.heading3.copyWith(color: color)),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic>? submission;

  const _StudentRow({required this.studentId, required this.submission});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final name = userData?['name'] ?? 'Unknown student';
        final email = userData?['email'] ?? '';

        final flags = (submission?['flags'] as List?) ?? [];
        final startedAt = (submission?['startedAt'] as Timestamp?)?.toDate();
        final submittedAt = (submission?['submittedAt'] as Timestamp?)
            ?.toDate();

        String subtitle;
        if (submission == null) {
          subtitle = email;
        } else if (submission!['status'] == 'submitted' &&
            submittedAt != null) {
          subtitle = '$email · submitted ${_timeAgo(submittedAt)}';
        } else if (startedAt != null) {
          subtitle = '$email · started ${_timeAgo(startedAt)}';
        } else {
          subtitle = email;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            title: Text(name),
            subtitle: Text(subtitle, style: AppTypography.bodySecondary),
            trailing: flags.isNotEmpty
                ? StatusChip(
                    label:
                        '${flags.length} flag${flags.length == 1 ? '' : 's'}',
                    tone: StatusTone.error,
                    icon: Icons.warning_amber,
                  )
                : null,
          ),
        );
      },
    );
  }
}
