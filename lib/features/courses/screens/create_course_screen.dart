import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/course_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_text_field.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _courseService = CourseService();
  final _titleController = TextEditingController();
  bool _isLoading = false;

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _courseService.createCourse(
      title: _titleController.text.trim(),
      instructorId: uid,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Course')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Course Details', style: AppTypography.heading2),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: _titleController, label: 'Course Title'),
              const SizedBox(height: AppSpacing.md),
              Text(
                'An enrollment code will be generated automatically. '
                'Share it with students so they can join via Sign Up.',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _isLoading ? null : _create,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Course'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
