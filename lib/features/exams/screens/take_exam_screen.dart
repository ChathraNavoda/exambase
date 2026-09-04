import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/exam_shuffle.dart';

class TakeExamScreen extends StatefulWidget {
  final String examId;
  final String submissionId;
  final int shuffleSeed;
  final Map<String, dynamic> exam;
  final DateTime? startedAt; // null = fresh start, non-null = resuming

  const TakeExamScreen({
    super.key,
    required this.examId,
    required this.submissionId,
    required this.shuffleSeed,
    required this.exam,
    this.startedAt,
  });

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen>
    with WidgetsBindingObserver {
  final _examService = ExamService();
  final _submissionService = SubmissionService();

  List<ShuffledQuestion> _shuffled = [];
  int _currentIndex = 0;
  final Map<String, int> _answers = {}; // questionId -> ORIGINAL option index
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _tabSwitchCount = 0;

  late Timer _timer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final totalSeconds = (widget.exam['durationMinutes'] as int) * 60;
    if (widget.startedAt != null) {
      final elapsed = DateTime.now().difference(widget.startedAt!).inSeconds;
      _secondsRemaining = (totalSeconds - elapsed).clamp(0, totalSeconds);
    } else {
      _secondsRemaining = totalSeconds;
    }

    _loadQuestions();
    _startTimer();

    // If time already ran out while they were away, submit immediately.
    if (_secondsRemaining <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit(auto: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _tabSwitchCount++;
      _submissionService.logFlag(
        submissionId: widget.submissionId,
        flagType: 'tab_switch',
      );
    } else if (state == AppLifecycleState.resumed && _tabSwitchCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTabSwitchWarning();
      });
    }
  }

  void _showTabSwitchWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Warning'),
        content: Text(
          'You left the exam screen ($_tabSwitchCount time${_tabSwitchCount == 1 ? '' : 's'}). '
          'This has been recorded and may be reviewed by your instructor.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Exam'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadQuestions() async {
    final stream = _examService.watchQuestions(widget.examId);
    final questions = await stream.first;
    setState(() {
      _shuffled = shuffleExam(questions, widget.shuffleSeed);
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

  void _selectAnswer(int displayedPosition) {
    final sq = _shuffled[_currentIndex];
    final originalIndex = sq.originalIndexFor(displayedPosition);
    setState(() => _answers[sq.original.id!] = originalIndex);
  }

  void _next() {
    if (_currentIndex < _shuffled.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submit(auto: false);
    }
  }

  Future<void> _submit({required bool auto}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _timer.cancel();

    await _submissionService.submitExam(
      submissionId: widget.submissionId,
      questions: _shuffled.map((s) => s.original).toList(),
      answers: _answers,
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ExamResultScreen(autoSubmitted: auto)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_shuffled.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('This exam has no questions yet.')),
      );
    }

    final sq = _shuffled[_currentIndex];
    final selectedOriginal = _answers[sq.original.id];
    final selectedDisplayedPosition = selectedOriginal == null
        ? null
        : sq.optionOrder.indexOf(selectedOriginal);
    final isLast = _currentIndex == _shuffled.length - 1;
    final displayedOptions = sq.displayedOptions;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_currentIndex + 1} of ${_shuffled.length}'),
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
                value: (_currentIndex + 1) / _shuffled.length,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(sq.original.questionText, style: AppTypography.heading2),
              const SizedBox(height: AppSpacing.lg),
              ...List.generate(displayedOptions.length, (i) {
                final isSelected = selectedDisplayedPosition == i;
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
                    child: Text(displayedOptions[i]),
                  ),
                );
              }),
              const Spacer(),
              ElevatedButton(
                onPressed: (_isSubmitting || selectedDisplayedPosition == null)
                    ? null
                    : _next,
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
  final bool autoSubmitted;
  const ExamResultScreen({super.key, required this.autoSubmitted});

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
            const Text(
              'Your response has been recorded.\nResults will be released by your instructor.',
            ),
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
