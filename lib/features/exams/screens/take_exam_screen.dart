import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class TakeExamScreen extends StatefulWidget {
  final String examId;
  final String submissionId;
  final Map<String, dynamic> exam;

  const TakeExamScreen({
    super.key,
    required this.examId,
    required this.submissionId,
    required this.exam,
  });

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> {
  final _examService = ExamService();
  final _submissionService = SubmissionService();

  List<ExamQuestion> _questions = [];
  int _currentIndex = 0;
  final Map<String, int> _answers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  late Timer _timer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = (widget.exam['durationMinutes'] as int) * 60;
    _loadQuestions();
    _startTimer();
  }

  Future<void> _loadQuestions() async {
    final stream = _examService.watchQuestions(widget.examId);
    final questions = await stream.first;
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _submit(auto: true);
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  String get _timeDisplay {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _selectAnswer(int optionIndex) {
    final q = _questions[_currentIndex];
    setState(() => _answers[q.id!] = optionIndex);
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submit(auto: false);
    }
  }

  Future<void> _submit({required bool auto}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _timer.cancel();

    final score = await _submissionService.submitExam(
      submissionId: widget.submissionId,
      questions: _questions,
      answers: _answers,
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExamResultScreen(
          score: score,
          totalMarks: widget.exam['totalMarks'] ?? 0,
          autoSubmitted: auto,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('This exam has no questions yet.')),
      );
    }

    final q = _questions[_currentIndex];
    final selected = _answers[q.id];
    final isLast = _currentIndex == _questions.length - 1;

    return PopScope(
      canPop:
          false, // block back navigation entirely — sequential, no going back
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _timeDisplay,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _secondsRemaining < 60
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _questions.length,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(q.questionText, style: AppTypography.heading2),
              const SizedBox(height: AppSpacing.lg),
              ...List.generate(q.options.length, (i) {
                final isSelected = selected == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: OutlinedButton(
                    onPressed: () => _selectAnswer(i),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      backgroundColor: isSelected
                          ? AppColors.primaryBlue.withOpacity(0.08)
                          : null,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(q.options[i]),
                  ),
                );
              }),
              const Spacer(),
              ElevatedButton(
                onPressed: (_isSubmitting || selected == null) ? null : _next,
                child: Text(isLast ? 'Submit Exam' : 'Next Question'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamResultScreen extends StatelessWidget {
  final int score;
  final int totalMarks;
  final bool autoSubmitted;

  const ExamResultScreen({
    super.key,
    required this.score,
    required this.totalMarks,
    required this.autoSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text('Exam Submitted', style: AppTypography.heading1),
            if (autoSubmitted) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Time expired — your exam was submitted automatically.',
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text('$score / $totalMarks', style: AppTypography.heading2),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
