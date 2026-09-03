import 'package:flutter/material.dart';
import '../../core/services/announcement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/courses/screens/announcements_screen.dart';

/// App bar action: campaign icon with a small count badge, opening the
/// full announcements list.
class AnnouncementsIconButton extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final bool isInstructor;

  const AnnouncementsIconButton({
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
        final count = snapshot.data?.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Announcements',
              onPressed: () {
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
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
