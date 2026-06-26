import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale.dart' show sharedPreferencesProvider;
import '../../../data/models/user_stats.dart';

/// SharedPreferences key: the highest streak we have already *celebrated* on this
/// device. Absent until the first stats sync seeds it. Kept locally (the server
/// owns the streak itself) so the one-shot "streak grew" flourish fires once per
/// increase instead of every time stats refresh.
const String _kCelebratedStreakKey = 'streak_celebrated_value';

/// Pure decision: should reaching [currentStreak] trigger the streak-up
/// flourish, given the streak we last celebrated ([lastCelebratedStreak], null if
/// we've never recorded one on this device)?
///
/// Kept free of prefs/UI so it can be unit-tested exhaustively. Mirrors the rank
/// celebration's logic so the two moments behave consistently:
///   * streak 0 is "no streak" — nothing to celebrate;
///   * first observation (null) → seed only, never celebrate. This stops a fresh
///     install / a user who already had a long streak before this shipped from
///     getting a retroactive flourish on launch;
///   * any streak *above* the last celebrated one → yes, the streak just grew
///     (in practice always by exactly one — a vote adds a single day);
///   * same streak → no (every `invalidate(userStatsProvider)` re-fetch hits
///     this; only a genuine increase should fire);
///   * a *lower* streak (the "freeze" decay ate days) → no, but the caller lowers
///     the baseline so growing back fires again.
bool shouldCelebrateStreak({
  required int currentStreak,
  required int? lastCelebratedStreak,
}) {
  if (currentStreak <= 0) return false;
  if (lastCelebratedStreak == null) return false;
  return currentStreak > lastCelebratedStreak;
}

/// Decides — and records — the one-shot "your streak grew" flourish off the back
/// of a freshly-synced [UserStats].
///
/// Orchestration only: the *when* lives in the pure [shouldCelebrateStreak], the
/// *how* (the flame flying up into the streak chip) lives in the UI. The single
/// fact it holds — the last celebrated streak — lives in SharedPreferences so an
/// increase is celebrated exactly once across restarts.
class StreakCelebrationController extends Notifier<void> {
  @override
  void build() {}

  /// Returns the new streak value to celebrate for [stats], or null when the
  /// streak didn't just grow. Advances the stored baseline to the current streak
  /// as a side effect FIRST, so the decision is idempotent: a repeat sync of the
  /// same streak (every `invalidate(userStatsProvider)` re-fetch) can't re-fire
  /// the flourish.
  Future<int?> evaluate(UserStats stats) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final last = prefs.getInt(_kCelebratedStreakKey);
    final current = stats.currentStreak;

    final celebrate = shouldCelebrateStreak(
      currentStreak: current,
      lastCelebratedStreak: last,
    );

    // Move the baseline to the current streak regardless of the outcome: seeding
    // on the first observation, advancing on growth, and lowering it after a
    // freeze decay so growing back fires again. Done before returning so the
    // flourish is consumed even if showing it later fails.
    if (last != current) {
      await prefs.setInt(_kCelebratedStreakKey, current);
    }

    if (!celebrate) return null;
    return current;
  }
}

final streakCelebrationControllerProvider =
    NotifierProvider<StreakCelebrationController, void>(
      StreakCelebrationController.new,
    );
