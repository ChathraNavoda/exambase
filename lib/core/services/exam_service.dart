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
  Future<String> createExam({
    required String courseId,
    required String title,
    required String instructions,
    required int durationMinutes,
    required String createdBy,
  }) async {
    final doc = await _firestore.collection('activities').add({
      'courseId': courseId,
      'type': 'mcq_exam',
      'title': title,
      'instructions': instructions,
      'durationMinutes': durationMinutes,
      'attemptsAllowed': 1,
      'totalMarks': 0, // updated as questions are added
      'isPublished': false,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
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
