import 'package:exambase/core/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/announcement_service.dart';
import '../../../shared/widgets/announcements_feed.dart';

class AnnouncementsScreen extends StatefulWidget {
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
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.isInstructor) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      AnnouncementService().markCourseViewed(uid, widget.courseId);
      NotificationService().markCourseAnnouncementsRead(uid, widget.courseId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Announcements · ${widget.courseTitle}')),
      body: AnnouncementsFeed(
        courseId: widget.courseId,
        isInstructor: widget.isInstructor,
      ),
      floatingActionButton: widget.isInstructor
          ? FloatingActionButton.extended(
              onPressed: () =>
                  AnnouncementsFeed.showComposeSheet(context, widget.courseId),
              icon: const Icon(Icons.add),
              label: const Text('New Announcement'),
            )
          : null,
    );
  }
}
