import 'package:cloud_firestore/cloud_firestore.dart';
import 'exam_service.dart';

class SubmissionService {
  final _firestore = FirebaseFirestore.instance;

  /// Returns the existing submission for this student+exam, or null if none.
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

  /// Verifies the exam code, checks the time window, and creates a new
  /// in-progress submission. Throws Exception with a user-facing message
  /// if anything is invalid.
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

    final shuffleSeed =
        DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF; // positive int seed

    final doc = await _firestore.collection('submissions').add({
      'activityId': activityId,
      'studentId': studentId,
      'courseId': courseId,
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
      'answers': [],
      'autoScore': 0,
      'totalMarks': exam['totalMarks'] ?? 0,
      'flags': [],
      'shuffleSeed': shuffleSeed,
    });

    return {'submissionId': doc.id, 'shuffleSeed': shuffleSeed};
  }

  /// Grades and finalizes the submission based on the given answers.
  Future<int> submitExam({
    required String submissionId,
    required List<ExamQuestion> questions,
    required Map<String, int> answers, // questionId -> selectedOptionIndex
  }) async {
    int score = 0;
    final answerList = <Map<String, dynamic>>[];

    for (final q in questions) {
      final selected = answers[q.id];
      answerList.add({'questionId': q.id, 'selectedOptionIndex': selected});
      if (selected != null && selected == q.correctOptionIndex) {
        score += q.marks;
      }
    }

    await _firestore.collection('submissions').doc(submissionId).update({
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
      'answers': answerList,
      'autoScore': score,
    });

    return score;
  }

  /// Logs an anti-cheat flag (e.g. tab switch / app backgrounded) onto the
  /// submission. This is a deterrent/audit signal, not a hard block — see
  /// app discussion on limitations of client-side detection.
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
