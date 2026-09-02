import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/services/report_service.dart';
import '../../../core/theme/app_spacing.dart';

class StudentReportScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;

  const StudentReportScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Students: $courseTitle')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final studentIds = List<String>.from(data?['studentIds'] ?? []);

          if (studentIds.isEmpty) {
            return const Center(child: Text('No students enrolled yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: studentIds.length,
            itemBuilder: (context, i) {
              final studentId = studentIds[i];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(studentId)
                    .get(),
                builder: (context, userSnap) {
                  final userData =
                      userSnap.data?.data() as Map<String, dynamic>?;
                  final name = userData?['name'] ?? 'Unknown';
                  final email = userData?['email'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: 'Export Report',
                        onPressed: () async {
                          final reportService = ReportService();
                          final csv = await reportService.buildStudentReportCsv(
                            courseId: courseId,
                            studentId: studentId,
                            studentName: name,
                          );
                          reportService.downloadCsv(
                            csv,
                            '${name.replaceAll(' ', '_')}_report.csv',
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
