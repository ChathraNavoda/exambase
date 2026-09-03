import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Handles course announcements. Firestore collection stays named 'notices'
/// intentionally — renaming live data has no user-facing benefit, only the
/// app-facing naming changed to "Announcement".
class AnnouncementService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> postAnnouncement({
    required String courseId,
    required String title,
    required String message,
    required String createdBy,
    bool pinned = false,
  }) async {
    await _firestore.collection('notices').add({
      'courseId': courseId,
      'title': title,
      'message': message,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'pinned': pinned,
    });
    await NotificationService().notifyAnnouncement(
      courseId: courseId,
      announcementTitle: title,
    );
  }

  Future<void> deleteAnnouncement(String id) async {
    await _firestore.collection('notices').doc(id).delete();
  }

  Future<void> togglePinned(String id, bool pinned) async {
    await _firestore.collection('notices').doc(id).update({'pinned': pinned});
  }

  Future<void> markCourseViewed(String studentId, String courseId) async {
    await _firestore.collection('users').doc(studentId).update({
      'courseAnnouncementViews.$courseId': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchAnnouncementsForCourse(
    String courseId,
  ) {
    return _firestore
        .collection('notices')
        .where('courseId', isEqualTo: courseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final items = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          items.sort((a, b) {
            final aPinned = a['pinned'] == true;
            final bPinned = b['pinned'] == true;
            if (aPinned != bPinned) return aPinned ? -1 : 1;
            return 0;
          });
          return items;
        });
  }
}
