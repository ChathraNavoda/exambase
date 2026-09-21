import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamQuestion {
  final String? id;
  final int order;
  final String type; // 'mcq' | 'short_answer'
  final String questionText;
  final List<String> options; // empty for short_answer
  final int correctOptionIndex; // -1 for short_answer
  final num marks;

  ExamQuestion({
    this.id,
    required this.order,
    this.type = 'mcq',
    required this.questionText,
    this.options = const [],
    this.correctOptionIndex = -1,
    required this.marks,
  });

  bool get isShortAnswer => type == 'short_answer';

  Map<String, dynamic> toMap() => {
    'order': order,
    'type': type,
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
      type: data['type'] ?? 'mcq', // old questions default to mcq
      questionText: data['questionText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctOptionIndex: data['correctOptionIndex'] ?? -1,
      marks: (data['marks'] ?? 1) as num,
    );
  }
}

class ExamService {
  final _firestore = FirebaseFirestore.instance;

  static const List<Map<String, dynamic>> defaultGradeBands = [
    {'label': 'A', 'minPercent': 75},
    {'label': 'B', 'minPercent': 65},
    {'label': 'C', 'minPercent': 55},
    {'label': 'S', 'minPercent': 40},
    {'label': 'F', 'minPercent': 0},
  ];

  /// Returns the label of the highest band the given percentage qualifies
  /// for. Bands are sorted defensively, so order in Firestore doesn't matter.
  static String gradeForPercent(List<dynamic> bands, double percent) {
    final sorted = [...bands]
      ..sort(
        (a, b) => (b['minPercent'] as num).compareTo(a['minPercent'] as num),
      );
    for (final band in sorted) {
      if (percent >= (band['minPercent'] as num))
        return band['label'] as String;
    }
    return sorted.isNotEmpty ? sorted.last['label'] as String : '-';
  }

  Future<Map<String, dynamic>> createExam({
    required String courseId,
    required String title,
    required String instructions,
    required int durationMinutes,
    required DateTime openAt,
    required DateTime closeAt,
    required String examCode,
    required String createdBy,
    bool negativeMarkingEnabled = false,
    double negativeMarkingFraction = 0.25,
    List<Map<String, dynamic>>? gradeBands,
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
      'totalMarks': 0,
      'openAt': Timestamp.fromDate(openAt),
      'closeAt': Timestamp.fromDate(closeAt),
      'examCode': examCode,
      'isPublished': false,
      'resultsPublished': false,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'negativeMarkingEnabled': negativeMarkingEnabled,
      'negativeMarkingFraction': negativeMarkingFraction,
      'gradeBands': gradeBands ?? defaultGradeBands,
    });

    return {'id': doc.id};
  }

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

    final questionsSnap = await _firestore
        .collection('activities')
        .doc(activityId)
        .collection('questions')
        .get();
    final total = questionsSnap.docs.fold<num>(
      0,
      (sum, d) => sum + ((d.data()['marks'] as num?) ?? 0),
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

  Future<void> togglePublishResults(
    String activityId,
    bool published,
    DateTime closeAt,
  ) async {
    if (published && DateTime.now().isBefore(closeAt)) {
      throw Exception(
        'You can only release results after the exam window closes.',
      );
    }
    await _firestore.collection('activities').doc(activityId).update({
      'resultsPublished': published,
    });
  }

  Future<void> deleteExam(String activityId) async {
    final questionsSnap = await _firestore
        .collection('activities')
        .doc(activityId)
        .collection('questions')
        .get();
    for (final doc in questionsSnap.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('activities').doc(activityId).delete();
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

  Stream<List<Map<String, dynamic>>> watchExamsForCourse(String courseId) {
    return _firestore
        .collection('activities')
        .where('courseId', isEqualTo: courseId)
        .where('type', isEqualTo: 'mcq_exam')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }
}
