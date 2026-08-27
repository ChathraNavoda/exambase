import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseService {
  final _firestore = FirebaseFirestore.instance;

  String generateAccessCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> createCourse({
    required String title,
    required String instructorId,
  }) async {
    final doc = await _firestore.collection('courses').add({
      'title': title,
      'instructorId': instructorId,
      'accessCode': generateAccessCode(),
      'studentIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<Map<String, dynamic>>> watchCoursesForInstructor(
    String instructorId,
  ) {
    return _firestore
        .collection('courses')
        .where('instructorId', isEqualTo: instructorId)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> watchCoursesForStudent(String studentId) {
    return _firestore
        .collection('courses')
        .where('studentIds', arrayContains: studentId)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }
}
