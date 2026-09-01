import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../exams/screens/manage_questions_screen.dart';
import '../../exams/screens/results_overview_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late Timer _tickTimer;

  @override
  void initState() {
    super.initState();
    // Re-render every 30s so countdowns stay roughly live without hammering rebuilds.
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    super.dispose();
  }

  String _countdown(DateTime target, {required bool isFuture}) {
    final diff = isFuture
        ? target.difference(DateTime.now())
        : DateTime.now().difference(target);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'less than a minute';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final examService = ExamService();

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Timeline')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: examService.watchExamsForInstructor(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final exams = snapshot.data ?? [];
          if (exams.isEmpty) {
            return const Center(child: Text('No exams created yet.'));
          }

          final now = DateTime.now();
          final live = <Map<String, dynamic>>[];
          final upcoming = <Map<String, dynamic>>[];
          final closed = <Map<String, dynamic>>[];
          final needsAttention = <Map<String, dynamic>>[];

          for (final exam in exams) {
            if (exam['openAt'] == null || exam['closeAt'] == null) continue;
            final openAt = (exam['openAt'] as Timestamp).toDate();
            final closeAt = (exam['closeAt'] as Timestamp).toDate();
            final duration = exam['durationMinutes'] as int? ?? 0;
            final lastStart = closeAt.subtract(Duration(minutes: duration));

            if (now.isBefore(openAt)) {
              upcoming.add(exam);
            } else if (now.isAfter(lastStart)) {
              closed.add(exam);
              if (exam['resultsPublished'] != true) {
                needsAttention.add(exam);
              }
            } else {
              live.add(exam);
            }
          }

          upcoming.sort(
            (a, b) =>
                (a['openAt'] as Timestamp).compareTo(b['openAt'] as Timestamp),
          );
          closed.sort(
            (a, b) => (b['closeAt'] as Timestamp).compareTo(
              a['closeAt'] as Timestamp,
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (needsAttention.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Needs Attention',
                  color: AppColors.warning,
                  icon: Icons.warning_amber,
                ),
                ...needsAttention.map((e) => _AttentionCard(exam: e)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (live.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Live Now',
                  color: AppColors.success,
                  icon: Icons.circle,
                ),
                ...live.map((e) {
                  final closeAt = (e['closeAt'] as Timestamp).toDate();
                  final duration = e['durationMinutes'] as int? ?? 0;
                  final lastStart = closeAt.subtract(
                    Duration(minutes: duration),
                  );
                  return _TimelineCard(
                    exam: e,
                    accentColor: AppColors.success,
                    countdownLabel:
                        'Closes for new starts in ${_countdown(lastStart, isFuture: true)}',
                  );
                }),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (upcoming.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Upcoming',
                  color: AppColors.primaryBlue,
                  icon: Icons.schedule,
                ),
                ...upcoming.map((e) {
                  final openAt = (e['openAt'] as Timestamp).toDate();
                  return _TimelineCard(
                    exam: e,
                    accentColor: AppColors.primaryBlue,
                    countdownLabel:
                        'Opens in ${_countdown(openAt, isFuture: true)}',
                  );
                }),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (closed.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Closed',
                  color: AppColors.textSecondary,
                  icon: Icons.check_circle_outline,
                ),
                ...closed.map((e) {
                  final closeAt = (e['closeAt'] as Timestamp).toDate();
                  return _TimelineCard(
                    exam: e,
                    accentColor: AppColors.textSecondary,
                    countdownLabel:
                        'Closed ${_countdown(closeAt, isFuture: false)} ago',
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.heading2.copyWith(color: color, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  const _AttentionCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: AppColors.warning),
        title: Text(exam['title'] ?? 'Untitled Exam'),
        subtitle: const Text(
          'Exam has closed but results are not published yet.',
        ),
        trailing: TextButton(
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
          child: const Text('Review'),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  final Color accentColor;
  final String countdownLabel;

  const _TimelineCard({
    required this.exam,
    required this.accentColor,
    required this.countdownLabel,
  });

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final openAt = (exam['openAt'] as Timestamp).toDate();
    final closeAt = (exam['closeAt'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('courses')
            .doc(exam['courseId'])
            .get(),
        builder: (context, courseSnap) {
          final courseData = courseSnap.data?.data() as Map<String, dynamic>?;
          final courseTitle = courseData?['title'] ?? '';

          return ListTile(
            leading: Container(width: 4, color: accentColor),
            title: Text(exam['title'] ?? 'Untitled Exam'),
            subtitle: Text(
              '$courseTitle\n${_fmt(openAt)} – ${_fmt(closeAt)}\n$countdownLabel',
              style: TextStyle(
                color: accentColor == AppColors.textSecondary
                    ? null
                    : accentColor,
              ),
            ),
            isThreeLine: true,
            trailing: IconButton(
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageQuestionsScreen(examId: exam['id']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
