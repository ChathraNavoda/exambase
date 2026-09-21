import 'package:exambase/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_text_field.dart';

class ManageQuestionsScreen extends StatefulWidget {
  final String examId;
  const ManageQuestionsScreen({super.key, required this.examId});

  @override
  State<ManageQuestionsScreen> createState() => _ManageQuestionsScreenState();
}

class _ManageQuestionsScreenState extends State<ManageQuestionsScreen> {
  final _examService = ExamService();
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  final _marksController = TextEditingController(text: '1');
  String _selectedType = 'mcq'; // 'mcq' | 'short_answer'
  int _correctIndex = 0;
  bool _isAdding = false;

  Future<void> _addQuestion(int currentCount) async {
    final marks = num.tryParse(_marksController.text) ?? 1;

    if (_questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the question text.')),
      );
      return;
    }
    if (marks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marks must be greater than 0.')),
      );
      return;
    }
    if (_selectedType == 'mcq') {
      final emptyIndex = _optionControllers.indexWhere(
        (c) => c.text.trim().isEmpty,
      );
      if (emptyIndex != -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Option ${emptyIndex + 1} is empty. Fill in all 4 options.',
            ),
          ),
        );
        return;
      }
      final options = _optionControllers.map((c) => c.text.trim()).toList();
      if (options.toSet().length != options.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Options must be unique — you have a duplicate.'),
          ),
        );
        return;
      }
    }

    setState(() => _isAdding = true);

    try {
      await _examService.addQuestion(
        widget.examId,
        ExamQuestion(
          order: currentCount,
          type: _selectedType,
          questionText: _questionController.text.trim(),
          options: _selectedType == 'mcq'
              ? _optionControllers.map((c) => c.text.trim()).toList()
              : const [],
          correctOptionIndex: _selectedType == 'mcq' ? _correctIndex : -1,
          marks: marks,
        ),
      );

      _questionController.clear();
      for (final c in _optionControllers) {
        c.clear();
      }
      _marksController.text = '1';
      if (mounted) setState(() => _correctIndex = 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add question: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Questions')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question list
          Expanded(
            child: StreamBuilder<List<ExamQuestion>>(
              stream: _examService.watchQuestions(widget.examId),
              builder: (context, snapshot) {
                final questions = snapshot.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: questions.length,
                  itemBuilder: (context, i) {
                    final q = questions[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text('${i + 1}. ${q.questionText}'),
                        subtitle: Text(
                          q.isShortAnswer
                              ? 'Short answer · ${q.marks} marks'
                              : '${q.options.asMap().entries.map((e) {
                                  final marker = e.key == q.correctOptionIndex ? '✓' : ' ';
                                  return '$marker ${e.value}';
                                }).join('   ')}  ·  ${q.marks} marks',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          // Add question form
          SizedBox(
            width: 400,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New Question', style: AppTypography.heading2),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'mcq', label: Text('MCQ')),
                      ButtonSegment(
                        value: 'short_answer',
                        label: Text('Short Answer'),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (selection) =>
                        setState(() => _selectedType = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _questionController,
                    label: 'Question',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _marksController,
                    label: 'Marks',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_selectedType == 'mcq') ...[
                    ...List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: i,
                              groupValue: _correctIndex,
                              onChanged: (val) =>
                                  setState(() => _correctIndex = val!),
                            ),
                            Expanded(
                              child: AppTextField(
                                controller: _optionControllers[i],
                                label: 'Option ${i + 1}',
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Text(
                      'Select the radio button next to the correct answer.',
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  StreamBuilder<List<ExamQuestion>>(
                    stream: _examService.watchQuestions(widget.examId),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return ElevatedButton(
                        onPressed: _isAdding ? null : () => _addQuestion(count),
                        child: _isAdding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Add Question'),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: () async {
                      await _examService.togglePublish(widget.examId, true);
                      await NotificationService().notifyExamPublished(
                        examId: widget.examId,
                      );
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Publish Exam'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
