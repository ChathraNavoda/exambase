import 'dart:math';
import '../services/exam_service.dart';

class ShuffledQuestion {
  final ExamQuestion original;
  final List<int> optionOrder; // displayed position -> original option index

  ShuffledQuestion({required this.original, required this.optionOrder});

  List<String> get displayedOptions =>
      optionOrder.map((i) => original.options[i]).toList();

  /// Given the position the student tapped (0-based, in displayed order),
  /// returns the original option index to store/grade against.
  int originalIndexFor(int displayedPosition) => optionOrder[displayedPosition];

  /// The displayed position of the correct answer — used only if you ever
  /// need to show it post-results, not used during the exam itself.
  int get correctDisplayedPosition =>
      optionOrder.indexOf(original.correctOptionIndex);
}

/// Deterministically shuffles question order and each question's options
/// using [seed], so the same student always sees the same arrangement.
List<ShuffledQuestion> shuffleExam(List<ExamQuestion> questions, int seed) {
  final questionOrderRandom = Random(seed);
  final shuffledQuestions = [...questions]..shuffle(questionOrderRandom);

  return shuffledQuestions.map((q) {
    // Vary the option-shuffle per question so it's not identical across all
    // questions, while still being deterministic for this student+question.
    final optionRandom = Random(seed ^ q.order ^ (q.id?.hashCode ?? 0));
    final optionOrder = List.generate(q.options.length, (i) => i)
      ..shuffle(optionRandom);
    return ShuffledQuestion(original: q, optionOrder: optionOrder);
  }).toList();
}
