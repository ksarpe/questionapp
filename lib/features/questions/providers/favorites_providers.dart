import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/question.dart';
import '../../account/providers/session_providers.dart';
import 'question_providers.dart';

/// The set of question ids the current user has favorited.
///
/// Loaded once per identity (the build re-runs when the signed-in user changes,
/// so a new account never inherits the previous one's stars) and updated
/// optimistically on [FavoriteIdsNotifier.toggle] so the star fills instantly
/// without waiting on the round-trip. Free users can't add favorites, so theirs
/// stays empty — but a LAPSED-premium user keeps the set they built, since the
/// server still serves their favorites (readable forever).
class FavoriteIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    // Re-run when the identity changes so stars reset across accounts. Read the
    // id only (not the whole session) to avoid reloading on unrelated changes
    // like a premium flip.
    ref.watch(sessionProvider.select((s) => s.value?.userId));
    final repo = ref.watch(questionRepositoryProvider);
    try {
      return await repo.fetchFavoriteIds();
    } catch (_) {
      // No session / backend error: an empty set just means "no stars yet" —
      // never a blocking error on the home screen.
      return <String>{};
    }
  }

  bool isFavorite(String questionId) =>
      state.value?.contains(questionId) ?? false;

  /// Toggles [questionId] and returns the NEW state (true = now favorited).
  ///
  /// Optimistic: flips the local set immediately so the star animates without a
  /// wait, then reconciles with the server's authoritative result. On failure it
  /// rolls back and rethrows, so the caller can surface the paywall (a non-premium
  /// add throws 'premium required' server-side) or an error message.
  Future<bool> toggle(String questionId) async {
    final current = state.value ?? const <String>{};
    final wasFavorite = current.contains(questionId);
    final optimistic = {...current};
    if (wasFavorite) {
      optimistic.remove(questionId);
    } else {
      optimistic.add(questionId);
    }
    state = AsyncData(optimistic);

    try {
      final repo = ref.read(questionRepositoryProvider);
      final nowFavorite = await repo.toggleFavorite(questionId);
      // Reconcile with the truth the server returned (covers a races / no-op).
      final reconciled = {...current};
      if (nowFavorite) {
        reconciled.add(questionId);
      } else {
        reconciled.remove(questionId);
      }
      state = AsyncData(reconciled);
      return nowFavorite;
    } catch (e) {
      state = AsyncData(current); // roll back the optimistic flip
      rethrow;
    }
  }
}

final favoriteIdsProvider =
    AsyncNotifierProvider<FavoriteIdsNotifier, Set<String>>(
      FavoriteIdsNotifier.new,
    );

/// The current user's favorited questions WITH text, newest first — for the
/// favorites screen in Settings.
///
/// Re-fetched when the identity or the locale changes (the text follows the UI
/// language). The screen also watches [favoriteIdsProvider] so an un-favorite
/// drops the card instantly without re-hitting the server.
final favoriteQuestionsProvider = FutureProvider.autoDispose<List<Question>>((
  ref,
) async {
  ref.watch(sessionProvider.select((s) => s.value?.userId));
  final repo = ref.watch(questionRepositoryProvider);
  return repo.fetchFavoriteQuestions();
});
