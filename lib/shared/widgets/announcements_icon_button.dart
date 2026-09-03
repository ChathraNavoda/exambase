import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/announcement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/courses/screens/announcements_screen.dart';

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
    // Instructors always see plain icon, no unread concept for their own posts.
    if (isInstructor) {
      return IconButton(
        icon: const Icon(Icons.campaign_outlined),
        tooltip: 'Announcements',
        onPressed: () => _open(context),
      );
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final views =
            userData?['courseAnnouncementViews'] as Map<String, dynamic>?;
        final lastVisited = (views?[courseId] as Timestamp?)?.toDate();

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: AnnouncementService().watchAnnouncementsForCourse(courseId),
          builder: (context, annSnap) {
            final items = annSnap.data ?? [];
            final unread = items.where((a) {
              final createdAt = (a['createdAt'] as Timestamp?)?.toDate();
              if (createdAt == null) return false;
              return lastVisited == null || createdAt.isAfter(lastVisited);
            }).length;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.campaign_outlined),
                  tooltip: 'Announcements',
                  onPressed: () => _open(context),
                ),
                if (unread > 0)
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
                        unread > 9 ? '9+' : '$unread',
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
      },
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnnouncementsScreen(
          courseId: courseId,
          courseTitle: courseTitle,
          isInstructor: isInstructor,
        ),
      ),
    );
  }
}
