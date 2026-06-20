import 'package:flutter_test/flutter_test.dart';
import 'package:questionapp/data/models/question.dart';

/// The unlock flow swaps a locked question for its unlocked twin (same id, text
/// now present). Value equality must reflect that, or Riverpod's
/// currentQuestionProvider treats the unlocked value as unchanged and never
/// notifies the view — the reveal never reaches the screen.
void main() {
  test('a question and its unlocked twin (same id) are NOT equal', () {
    const locked = Question(
      id: 'q1',
      category: 'general',
      questionText: '',
      isLocked: true,
      teaser: 'Czy miliarderzy',
    );
    final unlocked = locked.copyWith(
      isLocked: false,
      questionText: 'Czy miliarderzy zasłużyli na swoje fortuny?',
    );

    expect(unlocked == locked, isFalse);
    expect(unlocked.hashCode == locked.hashCode, isFalse);
  });

  test('two identical questions remain equal', () {
    const a = Question(id: 'q1', category: 'general', questionText: 'Hej?');
    const b = Question(id: 'q1', category: 'general', questionText: 'Hej?');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
