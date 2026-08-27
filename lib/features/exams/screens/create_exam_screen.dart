import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_colors.dart';
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
  final _examCodeController = TextEditingController();

  DateTime? _openAt;
  DateTime? _closeAt;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _examCodeController.text = _examService.generateExamCode();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createExam() async {
    setState(() => _errorMessage = null);

    // Client-side validation before hitting the service
    if (_titleController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter an exam title.');
      return;
    }
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      setState(
        () => _errorMessage = 'Please enter a valid duration in minutes.',
      );
      return;
    }
    if (_openAt == null || _closeAt == null) {
      setState(() => _errorMessage = 'Please set both open and close times.');
      return;
    }
    if (_closeAt!.isBefore(_openAt!) || _closeAt!.isAtSameMomentAs(_openAt!)) {
      setState(() => _errorMessage = 'Close time must be after open time.');
      return;
    }
    if (_examCodeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please set an exam code.');
      return;
    }
    if (_titleController.text.trim().length < 3) {
      setState(
        () => _errorMessage = 'Exam title must be at least 3 characters.',
      );
      return;
    }
    if (duration > 300) {
      setState(
        () => _errorMessage =
            'Duration seems unusually long (max 300 minutes). Please check.',
      );
      return;
    }
    if (_examCodeController.text.trim().length < 4) {
      setState(
        () => _errorMessage = 'Exam code must be at least 4 characters.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final result = await _examService.createExam(
        courseId: widget.courseId,
        title: _titleController.text.trim(),
        instructions: _instructionsController.text.trim(),
        durationMinutes: duration,
        openAt: _openAt!,
        closeAt: _closeAt!,
        examCode: _examCodeController.text.trim().toUpperCase(),
        createdBy: uid,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ManageQuestionsScreen(examId: result['id']),
          ),
        );
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Live-computed "last start time" preview so the instructor sees the fairness math
  String get _lastStartTimePreview {
    final duration = int.tryParse(_durationController.text);
    if (_closeAt == null || duration == null) return '';
    final lastStart = _closeAt!.subtract(Duration(minutes: duration));
    return 'Last possible start time: ${_formatDateTime(lastStart)} (everyone who starts gets the full $duration min)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Exam')),
      body: Center(
        child: SingleChildScrollView(
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

                Text('Schedule', style: AppTypography.heading2),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Opens at'),
                  subtitle: Text(_formatDateTime(_openAt)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await _pickDateTime(_openAt);
                    if (picked != null) setState(() => _openAt = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Closes at'),
                  subtitle: Text(_formatDateTime(_closeAt)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await _pickDateTime(_closeAt);
                    if (picked != null) setState(() => _closeAt = picked);
                  },
                ),
                if (_closeAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      _lastStartTimePreview,
                      style: AppTypography.bodySecondary,
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),
                Text('Enrollment', style: AppTypography.heading2),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _examCodeController,
                        label: 'Exam Code',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Generate new code',
                      onPressed: () {
                        setState(
                          () => _examCodeController.text = _examService
                              .generateExamCode(),
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  'Share this code with students right before the exam starts.',
                  style: AppTypography.bodySecondary,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],

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
      ),
    );
  }
}
