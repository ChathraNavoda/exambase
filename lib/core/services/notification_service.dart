import 'package:cloud_firestore/cloud_firestore.dart';

/// Universal, cross-course notifications. Unlike announcements (scoped to
/// one course, browsed from inside it), notifications land in a student's
/// own feed regardless of which course triggered them. There is no Cloud
/// Functions backend in this project, so fan-out happens client-side at
/// the moment the instructor performs the triggering action.
class NotificationService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _notifyCourseStudents({
    required String courseId,
    required String courseTitle,
    required List<String> studentIds,
    required String type, // 'exam' | 'announcement' | 'results' | 'assignment'
    required String title,
    required String message,
  }) async {
    if (studentIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final studentId in studentIds) {
      final doc = _firestore.collection('notifications').doc();
      batch.set(doc, {
        'studentId': studentId,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'type': type,
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
    await batch.commit();
  }

  Future<void> notifyExamPublished({required String examId}) async {
    final examDoc = await _firestore.collection('activities').doc(examId).get();
    final exam = examDoc.data();
    if (exam == null) return;
    final courseDoc = await _firestore
        .collection('courses')
        .doc(exam['courseId'])
        .get();
    final course = courseDoc.data();
    if (course == null) return;
    await _notifyCourseStudents(
      courseId: exam['courseId'],
      courseTitle: course['title'] ?? '',
      studentIds: List<String>.from(course['studentIds'] ?? []),
      type: 'exam',
      title: exam['title'] ?? 'New Exam',
      message:
          'A new exam is available in ${course['title'] ?? 'your course'}.',
    );
  }

  Future<void> notifyResultsReleased({required String examId}) async {
    final examDoc = await _firestore.collection('activities').doc(examId).get();
    final exam = examDoc.data();
    if (exam == null) return;
    final courseDoc = await _firestore
        .collection('courses')
        .doc(exam['courseId'])
        .get();
    final course = courseDoc.data();
    if (course == null) return;
    await _notifyCourseStudents(
      courseId: exam['courseId'],
      courseTitle: course['title'] ?? '',
      studentIds: List<String>.from(course['studentIds'] ?? []),
      type: 'results',
      title: exam['title'] ?? '',
      message: 'Results have been released for ${exam['title'] ?? 'an exam'}.',
    );
  }

  Future<void> notifyAnnouncement({
    required String courseId,
    required String announcementTitle,
  }) async {
    final courseDoc = await _firestore
        .collection('courses')
        .doc(courseId)
        .get();
    final course = courseDoc.data();
    if (course == null) return;
    await _notifyCourseStudents(
      courseId: courseId,
      courseTitle: course['title'] ?? '',
      studentIds: List<String>.from(course['studentIds'] ?? []),
      type: 'announcement',
      title: announcementTitle,
      message: 'New announcement in ${course['title'] ?? 'your course'}.',
    );
  }

  Stream<List<Map<String, dynamic>>> watchNotificationsForStudent(
    String studentId,
  ) {
    return _firestore
        .collection('notifications')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<void> markAsRead(String id) async {
    await _firestore.collection('notifications').doc(id).update({'read': true});
  }

  Future<void> markAllAsRead(String studentId) async {
    final snap = await _firestore
        .collection('notifications')
        .where('studentId', isEqualTo: studentId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> markCourseAnnouncementsRead(
    String studentId,
    String courseId,
  ) async {
    final snap = await _firestore
        .collection('notifications')
        .where('studentId', isEqualTo: studentId)
        .where('courseId', isEqualTo: courseId)
        .where('type', isEqualTo: 'announcement')
        .where('read', isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
