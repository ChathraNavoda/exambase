import 'package:cloud_firestore/cloud_firestore.dart';
import 'exam_service.dart';

class SubmissionService {
  final _firestore = FirebaseFirestore.instance;

  Future<DocumentSnapshot?> getExistingSubmission({
    required String activityId,
    required String studentId,
  }) async {
    final query = await _firestore
        .collection('submissions')
        .where('activityId', isEqualTo: activityId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    return query.docs.isEmpty ? null : query.docs.first;
  }

  Future<Map<String, dynamic>> startExam({
    required Map<String, dynamic> exam,
    required String activityId,
    required String studentId,
    required String courseId,
    required String enteredCode,
  }) async {
    final now = DateTime.now();
    final openAt = (exam['openAt'] as Timestamp).toDate();
    final closeAt = (exam['closeAt'] as Timestamp).toDate();
    final duration = exam['durationMinutes'] as int;
    final lastStart = closeAt.subtract(Duration(minutes: duration));

    if (now.isBefore(openAt)) {
      throw Exception('This exam has not opened yet.');
    }
    if (now.isAfter(lastStart)) {
      throw Exception('The window to start this exam has closed.');
    }
    if (enteredCode.trim().toUpperCase() !=
        (exam['examCode'] as String).toUpperCase()) {
      throw Exception('Incorrect exam code.');
    }

    final existing = await getExistingSubmission(
      activityId: activityId,
      studentId: studentId,
    );
    if (existing != null) {
      throw Exception('You have already attempted this exam.');
    }

    final shuffleSeed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

    final doc = await _firestore.collection('submissions').add({
      'activityId': activityId,
      'studentId': studentId,
      'courseId': courseId,
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
      'answers': [],
      'autoScore': 0,
      'manualScore': 0,
      'finalScore': 0,
      'totalMarks': exam['totalMarks'] ?? 0,
      'flags': [],
      'shuffleSeed': shuffleSeed,
      'hasShortAnswer': false,
      'manualGradingComplete': true,
    });

    return {'submissionId': doc.id, 'shuffleSeed': shuffleSeed};
  }

  /// Grades MCQ questions immediately (with optional negative marking, and
  /// the total floored at 0 — no exam finishes negative). Short-answer
  /// questions are recorded but contribute 0 until an instructor grades
  /// them via [saveManualGrade].
  Future<Map<String, dynamic>> submitExam({
    required String submissionId,
    required Map<String, dynamic> exam,
    required List<ExamQuestion> questions,
    required Map<String, int> answers,
    required Map<String, String> shortAnswers,
  }) async {
    final negEnabled = exam['negativeMarkingEnabled'] == true;
    final negFraction =
        (exam['negativeMarkingFraction'] as num?)?.toDouble() ?? 0.25;

    num autoScore = 0;
    bool hasShortAnswer = false;
    final answerList = <Map<String, dynamic>>[];

    for (final q in questions) {
      if (q.isShortAnswer) {
        hasShortAnswer = true;
        answerList.add({
          'questionId': q.id,
          'answerText': shortAnswers[q.id] ?? '',
        });
        continue;
      }

      final selected = answers[q.id];
      answerList.add({'questionId': q.id, 'selectedOptionIndex': selected});

      if (selected == null) continue; // unanswered — no penalty either way
      if (selected == q.correctOptionIndex) {
        autoScore += q.marks;
      } else if (negEnabled) {
        autoScore -= q.marks * negFraction;
      }
    }

    if (autoScore < 0) autoScore = 0;

    await _firestore.collection('submissions').doc(submissionId).update({
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
      'answers': answerList,
      'autoScore': autoScore,
      'manualScore': 0,
      'finalScore': autoScore,
      'hasShortAnswer': hasShortAnswer,
      'manualGradingComplete': !hasShortAnswer,
    });

    return {'autoScore': autoScore, 'hasShortAnswer': hasShortAnswer};
  }

  /// Records marks for one short-answer question on one submission, and
  /// recomputes the running total. Safe to call repeatedly (e.g. correcting
  /// a mark) — it always recalculates from the full manualScores map.
  Future<void> saveManualGrade({
    required String submissionId,
    required String questionId,
    required num marksAwarded,
    required List<ExamQuestion> allQuestions,
  }) async {
    final doc = await _firestore
        .collection('submissions')
        .doc(submissionId)
        .get();
    final data = doc.data();
    if (data == null) return;

    final manualScores = Map<String, dynamic>.from(data['manualScores'] ?? {});
    manualScores[questionId] = marksAwarded;

    final shortAnswerIds = allQuestions
        .where((q) => q.isShortAnswer)
        .map((q) => q.id)
        .toSet();
    final allGraded = shortAnswerIds.every(
      (id) => manualScores.containsKey(id),
    );

    final manualTotal = manualScores.values.fold<num>(
      0,
      (sum, v) => sum + (v as num),
    );
    final autoScore = (data['autoScore'] as num?) ?? 0;

    await _firestore.collection('submissions').doc(submissionId).update({
      'manualScores': manualScores,
      'manualScore': manualTotal,
      'finalScore': autoScore + manualTotal,
      'manualGradingComplete': allGraded,
    });
  }

  Future<void> logFlag({
    required String submissionId,
    required String flagType,
  }) async {
    await _firestore.collection('submissions').doc(submissionId).update({
      'flags': FieldValue.arrayUnion([
        {'type': flagType, 'timestamp': Timestamp.now()},
      ]),
    });
  }
}
