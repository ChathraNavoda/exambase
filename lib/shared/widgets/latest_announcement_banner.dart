import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambase/features/courses/screens/announcements_screen.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/announcement_service.dart';

/// Shows the single most recent announcement as a dismissible-feeling
/// banner above the exam list — visible without competing with exams
/// for primary screen space.
class LatestAnnouncementBanner extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final bool isInstructor;

  const LatestAnnouncementBanner({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.isInstructor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AnnouncementService().watchAnnouncementsForCourse(courseId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        final latest = items.first;
        final createdAt = (latest['createdAt'] as Timestamp?)?.toDate();

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AnnouncementsScreen(
                  courseId: courseId,
                  courseTitle: courseTitle,
                  isInstructor: isInstructor,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.primarySurface,
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest['title'] ?? '',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt),
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                ),
                if (items.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusPill,
                      ),
                    ),
                    child: Text(
                      '+${items.length - 1} more',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
