import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'manage_questions_screen.dart';

class CreateExamScreen extends StatefulWidget {
  final String courseId;
  const CreateExamScreen({super.key, required this.courseId});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _examService = ExamService();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  bool _isLoading = false;

  Future<void> _createExam() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final examId = await _examService.createExam(
      courseId: widget.courseId,
      title: _titleController.text.trim(),
      instructions: _instructionsController.text.trim(),
      durationMinutes: int.tryParse(_durationController.text) ?? 30,
      createdBy: uid,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ManageQuestionsScreen(examId: examId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Exam')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Exam Details', style: AppTypography.heading2),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: _titleController, label: 'Exam Title'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _instructionsController,
                label: 'Instructions',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _durationController,
                label: 'Duration (minutes)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _isLoading ? null : _createExam,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create & Add Questions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
