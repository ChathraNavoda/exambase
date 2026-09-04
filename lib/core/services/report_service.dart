import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambase/core/services/csv_downloader_stub.dart';

// keep dart:html import but only use it behind a kIsWeb check via conditional import — see below
class ReportService {
  final _firestore = FirebaseFirestore.instance;

  /// Builds a CSV string of all submissions for a given exam, with student
  /// names/emails resolved. Includes flag counts for anti-cheat visibility.
  Future<String> buildExamReportCsv({
    required String examId,
    required String examTitle,
  }) async {
    final submissionsSnap = await _firestore
        .collection('submissions')
        .where('activityId', isEqualTo: examId)
        .get();

    final rows = <List<String>>[
      [
        'Student Name',
        'Email',
        'Status',
        'Score',
        'Total Marks',
        'Flags',
        'Started At',
        'Submitted At',
      ],
    ];

    for (final doc in submissionsSnap.docs) {
      final data = doc.data();
      final userDoc = await _firestore
          .collection('users')
          .doc(data['studentId'])
          .get();
      final userData = userDoc.data();

      final startedAt = (data['startedAt'] as Timestamp?)?.toDate();
      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
      final flags = (data['flags'] as List?) ?? [];

      rows.add([
        userData?['name'] ?? 'Unknown',
        userData?['email'] ?? '',
        data['status'] ?? '',
        '${data['autoScore'] ?? 0}',
        '${data['totalMarks'] ?? 0}',
        '${flags.length}',
        startedAt?.toString() ?? '',
        submittedAt?.toString() ?? '',
      ]);
    }

    return _toCsv(rows);
  }

  /// Builds a CSV of one student's scores across every exam in a course.
  Future<String> buildStudentReportCsv({
    required String courseId,
    required String studentId,
    required String studentName,
  }) async {
    final examsSnap = await _firestore
        .collection('activities')
        .where('courseId', isEqualTo: courseId)
        .where('type', isEqualTo: 'mcq_exam')
        .get();

    final rows = <List<String>>[
      ['Exam Title', 'Status', 'Score', 'Total Marks', 'Flags', 'Submitted At'],
    ];

    for (final examDoc in examsSnap.docs) {
      final subSnap = await _firestore
          .collection('submissions')
          .where('activityId', isEqualTo: examDoc.id)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      final examData = examDoc.data();

      if (subSnap.docs.isEmpty) {
        rows.add([
          examData['title'] ?? '',
          'Not Attempted',
          '-',
          '${examData['totalMarks'] ?? 0}',
          '0',
          '',
        ]);
        continue;
      }

      final data = subSnap.docs.first.data();
      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
      final flags = (data['flags'] as List?) ?? [];

      rows.add([
        examData['title'] ?? '',
        data['status'] ?? '',
        '${data['autoScore'] ?? 0}',
        '${data['totalMarks'] ?? 0}',
        '${flags.length}',
        submittedAt?.toString() ?? '',
      ]);
    }

    return _toCsv(rows);
  }

  String _toCsv(List<List<String>> rows) {
    return rows.map((row) => row.map(_escapeCsvField).join(',')).join('\n');
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Triggers a browser download of the given CSV content. Web only.
  void downloadCsv(String csvContent, String filename) {
    downloadCsvPlatform(csvContent, filename);
  }
}
