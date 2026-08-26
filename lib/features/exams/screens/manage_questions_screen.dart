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
  int _correctIndex = 0;
  bool _isAdding = false;

  Future<void> _addQuestion(int currentCount) async {
    if (_questionController.text.trim().isEmpty ||
        _optionControllers.any((c) => c.text.trim().isEmpty)) {
      return;
    }
    setState(() => _isAdding = true);

    await _examService.addQuestion(
      widget.examId,
      ExamQuestion(
        order: currentCount,
        questionText: _questionController.text.trim(),
        options: _optionControllers.map((c) => c.text.trim()).toList(),
        correctOptionIndex: _correctIndex,
        marks: 1,
      ),
    );

    _questionController.clear();
    for (final c in _optionControllers) {
      c.clear();
    }
    setState(() {
      _correctIndex = 0;
      _isAdding = false;
    });
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
                          q.options
                              .asMap()
                              .entries
                              .map((e) {
                                final marker = e.key == q.correctOptionIndex
                                    ? '✓'
                                    : ' ';
                                return '$marker ${e.value}';
                              })
                              .join('   '),
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
                  AppTextField(
                    controller: _questionController,
                    label: 'Question',
                  ),
                  const SizedBox(height: AppSpacing.md),
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
