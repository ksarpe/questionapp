import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/question.dart';
import '../../../data/repositories/question_repository.dart';
import '../../../services/supabase_service.dart';

/// The active question source.
///
/// In production builds, providing SUPABASE_URL and SUPABASE_ANON_KEY makes the
/// app read questions from Supabase. Without credentials, local mock data keeps
/// development and tests simple.
final questionRepositoryProvider = Provider<QuestionRepository>(
  (ref) => SupabaseService.isInitialised
      ? const SupabaseQuestionRepository()
      : const MockQuestionRepository(),
);

/// Loads the full list of questions once.
final questionsProvider = FutureProvider<List<Question>>((ref) async {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.fetchQuestions();
});

/// Loads the scheduled daily question for a concrete local date.
final dailyQuestionProvider = FutureProvider.family<Question?, DateTime>((
  ref,
  date,
) async {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.fetchDailyQuestion(date);
});

/// Tracks which question in the loaded list is currently shown.
///
/// The "wind" swipe simply advances this index; the view animates the text
/// transition in response to the change. Wraps around at both ends.
class QuestionDeckNotifier extends Notifier<int> {
  @override
  int build() => 0;

  int get _length => ref
      .watch(questionsProvider)
      .maybeWhen(data: (list) => list.length, orElse: () => 0);

  void next() {
    final length = _length;
    if (length == 0) return;
    state = (state + 1) % length;
  }

  void previous() {
    final length = _length;
    if (length == 0) return;
    state = (state - 1 + length) % length;
  }
}

/// Index of the currently displayed question.
final questionIndexProvider = NotifierProvider<QuestionDeckNotifier, int>(
  QuestionDeckNotifier.new,
);

/// The single question to render, or null while loading / on error.
final currentQuestionProvider = Provider<Question?>((ref) {
  final questions = ref.watch(questionsProvider).asData?.value;
  if (questions == null || questions.isEmpty) return null;
  final index = ref.watch(questionIndexProvider);
  return questions[index % questions.length];
});
