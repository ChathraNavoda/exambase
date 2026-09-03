import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../courses/screens/announcements_screen.dart';
import '../../exams/screens/exam_list_screen.dart';
import '../../exams/screens/my_results_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser!.uid;
    final service = NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => service.markAllAsRead(studentId),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.watchNotificationsForStudent(studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SelectableText(
                  'Could not load notifications: ${snapshot.error}',
                  style: AppTypography.bodySecondary.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No notifications yet.',
                      style: AppTypography.bodySecondary,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              final isRead = n['read'] == true;
              final createdAt = (n['createdAt'] as Timestamp?)?.toDate();
              final icon = switch (n['type']) {
                'exam' => Icons.assignment_outlined,
                'results' => Icons.bar_chart_outlined,
                'announcement' => Icons.campaign_outlined,
                _ => Icons.notifications_outlined,
              };

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                color: isRead ? AppColors.surface : AppColors.primarySurface,
                child: ListTile(
                  leading: Icon(
                    icon,
                    color: isRead ? AppColors.textSecondary : AppColors.primary,
                  ),
                  title: Text(
                    n['title'] ?? '',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${n['courseTitle'] ?? ''}\n${n['message'] ?? ''}',
                    style: AppTypography.bodySecondary,
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    createdAt != null ? _formatDate(createdAt) : '',
                    style: AppTypography.caption,
                  ),
                  onTap: () async {
                    await service.markAsRead(n['id']);
                    if (!context.mounted) return;
                    _navigateForType(context, n);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateForType(BuildContext context, Map<String, dynamic> n) {
    switch (n['type']) {
      case 'exam':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamListScreen(courseId: n['courseId']),
          ),
        );
        break;
      case 'announcement':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnnouncementsScreen(
              courseId: n['courseId'],
              courseTitle: n['courseTitle'] ?? '',
              isInstructor: false,
            ),
          ),
        );
        break;
      case 'results':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyResultsScreen()));
        break;
    }
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
