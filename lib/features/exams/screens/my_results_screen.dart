import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';

class MyResultsScreen extends StatelessWidget {
  const MyResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Results')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .where('status', isEqualTo: 'submitted')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final submissions = snapshot.data!.docs;
          if (submissions.isEmpty) {
            return const Center(child: Text('No submitted exams yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: submissions.length,
            itemBuilder: (context, i) {
              final sub = submissions[i].data() as Map<String, dynamic>;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('activities')
                    .doc(sub['activityId'])
                    .get(),
                builder: (context, examSnap) {
                  if (!examSnap.hasData) return const SizedBox.shrink();
                  final exam = examSnap.data!.data() as Map<String, dynamic>?;
                  if (exam == null) return const SizedBox.shrink();

                  final published = exam['resultsPublished'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text(exam['title'] ?? ''),
                      trailing: published
                          ? Text(
                              '${sub['autoScore']} / ${sub['totalMarks']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : const Text(
                              'Pending',
                              style: TextStyle(color: Colors.grey),
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
