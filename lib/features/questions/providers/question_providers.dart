import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/question.dart';
import '../../../data/models/smaczek.dart';
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

/// Loads the discussion prompts ("smaczki") for a given question id.
///
/// The repository calls the `get_question_smaczki` RPC, which applies the
/// premium gate server-side: a free user gets the first smaczek plus the others
/// as locked placeholders, premium users get them all. Keyed by question id so
/// each question caches its own set; invalidate it after a purchase to re-fetch
/// the now-unlocked text.
final smaczkiProvider = FutureProvider.family<List<Smaczek>, String>((
  ref,
  questionId,
) async {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.fetchSmaczki(questionId);
});

/// Tracks which question in the loaded list is currently shown.
///
/// The "wind" swipe simply advances this index; the view animates the text
/// transition in response to the change. Wraps around at both ends.
class QuestionDeckNotifier extends Notifier<int> {
  @override
  int build() => 0;

  int get _length => ref.watch(questionDeckProvider).length;

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

/// Today's scheduled daily question (resolved for the user's local date).
///
/// Captures "now" once when first read, so it does not refetch on every rebuild
/// the way `dailyQuestionProvider(DateTime.now())` would (a fresh DateTime is a
/// fresh family key). This is the free, no-paywall question every user opens to.
final todaysDailyQuestionProvider = FutureProvider<Question?>((ref) async {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.fetchDailyQuestion(DateTime.now());
});

/// The ordered deck the home screen walks through.
///
/// Position 0 is always today's daily — the same free question for everyone,
/// shown alone when the app opens. The tail is the rest of the pool in a random
/// order, revealed one at a time as the user swipes (each swipe gated by the
/// monetization rules in [SwipeGate]). The daily is filtered out of the tail so
/// it is not repeated right after it is shown.
///
/// While the daily is still loading the deck stays empty on purpose, so the
/// screen shows its spinner rather than flashing a non-daily question first.
final questionDeckProvider = Provider<List<Question>>((ref) {
  final pool = ref.watch(questionsProvider).asData?.value ?? const <Question>[];
  final dailyAsync = ref.watch(todaysDailyQuestionProvider);

  if (dailyAsync.isLoading) return const [];

  final daily = dailyAsync.asData?.value;
  if (daily == null) {
    // No daily scheduled (or the fetch failed) — degrade to the plain pool so
    // the screen still has something to show; no badge is shown in this case.
    return pool;
  }

  final rest = pool.where((q) => q.id != daily.id).toList()..shuffle();
  return [daily, ...rest];
});

/// The single question to render, or null while the deck is not yet ready.
final currentQuestionProvider = Provider<Question?>((ref) {
  final deck = ref.watch(questionDeckProvider);
  if (deck.isEmpty) return null;
  final index = ref.watch(questionIndexProvider);
  return deck[index % deck.length];
});

/// Whether the question currently on screen is today's free daily question.
///
/// Drives the "Daily" badge: true only when the visible question's id matches
/// today's scheduled daily. The daily shares its id with its deck entry (both
/// the mock list and the `get_daily_question` RPC return the same id), so an id
/// comparison is enough and stays correct even if the deck wraps around.
final isShowingDailyProvider = Provider<bool>((ref) {
  final current = ref.watch(currentQuestionProvider);
  final daily = ref.watch(todaysDailyQuestionProvider).asData?.value;
  if (current == null || daily == null) return false;
  return current.id == daily.id;
});
