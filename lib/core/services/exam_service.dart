import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamQuestion {
  final String? id;
  final int order;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final int marks;

  ExamQuestion({
    this.id,
    required this.order,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.marks,
  });

  Map<String, dynamic> toMap() => {
    'order': order,
    'questionText': questionText,
    'options': options,
    'correctOptionIndex': correctOptionIndex,
    'marks': marks,
  };

  factory ExamQuestion.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamQuestion(
      id: doc.id,
      order: data['order'] ?? 0,
      questionText: data['questionText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctOptionIndex: data['correctOptionIndex'] ?? 0,
      marks: data['marks'] ?? 1,
    );
  }
}

class ExamService {
  final _firestore = FirebaseFirestore.instance;

  /// Creates a new exam (activity doc) and returns its ID.
  ///
  /// Validates that the [openAt]–[closeAt] window is at least as long as
  /// [durationMinutes], so every student who starts can finish. See app
  /// discussion: the last fair start time is `closeAt - durationMinutes`.
  Future<Map<String, dynamic>> createExam({
    required String courseId,
    required String title,
    required String instructions,
    required int durationMinutes,
    required DateTime openAt,
    required DateTime closeAt,
    required String examCode,
    required String createdBy,
  }) async {
    final windowMinutes = closeAt.difference(openAt).inMinutes;
    if (windowMinutes < durationMinutes) {
      throw Exception(
        'Exam window (${windowMinutes}min) is shorter than the exam duration '
        '(${durationMinutes}min). No student could ever finish in time.',
      );
    }
    if (windowMinutes == durationMinutes) {
      throw Exception(
        'Exam window exactly matches the duration, leaving no time for '
        'students to actually start. Add a few extra minutes as buffer.',
      );
    }

    if (closeAt.isBefore(DateTime.now())) {
      throw Exception('Close time must be in the future.');
    }

    final doc = await _firestore.collection('activities').add({
      'courseId': courseId,
      'type': 'mcq_exam',
      'title': title,
      'instructions': instructions,
      'durationMinutes': durationMinutes,
      'attemptsAllowed': 1,
      'totalMarks': 0, // updated as questions are added
      'openAt': Timestamp.fromDate(openAt),
      'closeAt': Timestamp.fromDate(closeAt),
      'examCode': examCode,
      'isPublished': false,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {'id': doc.id};
  }

  /// Generates a short, readable random code like "A7X2K9".
  /// Excludes visually confusing characters (0/O, 1/I).
  String generateExamCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> addQuestion(String activityId, ExamQuestion question) async {
    await _firestore
        .collection('activities')
        .doc(activityId)
        .collection('questions')
        .add(question.toMap());

    // Keep totalMarks in sync
    final questionsSnap = await _firestore
        .collection('activities')
        .doc(activityId)
        .collection('questions')
        .get();
    final total = questionsSnap.docs.fold<int>(
      0,
      (sum, d) => sum + (d.data()['marks'] as int? ?? 0),
    );
    await _firestore.collection('activities').doc(activityId).update({
      'totalMarks': total,
    });
  }

  Stream<List<ExamQuestion>> watchQuestions(String activityId) {
    return _firestore
        .collection('activities')
        .doc(activityId)
        .collection('questions')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map((d) => ExamQuestion.fromDoc(d)).toList());
  }

  Future<void> togglePublish(String activityId, bool isPublished) async {
    await _firestore.collection('activities').doc(activityId).update({
      'isPublished': isPublished,
    });
  }

  Stream<List<Map<String, dynamic>>> watchExamsForInstructor(String uid) {
    return _firestore
        .collection('activities')
        .where('createdBy', isEqualTo: uid)
        .where('type', isEqualTo: 'mcq_exam')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }
}
