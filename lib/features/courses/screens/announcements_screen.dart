import 'package:exambase/shared/widgets/announcements_feed.dart';
import 'package:flutter/material.dart';

class AnnouncementsScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final bool isInstructor;

  const AnnouncementsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.isInstructor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Announcements · $courseTitle')),
      body: AnnouncementsFeed(courseId: courseId, isInstructor: isInstructor),
      floatingActionButton: isInstructor
          ? FloatingActionButton.extended(
              onPressed: () =>
                  AnnouncementsFeed.showComposeSheet(context, courseId),
              icon: const Icon(Icons.add),
              label: const Text('New Announcement'),
            )
          : null,
    );
  }
}
