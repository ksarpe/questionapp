import 'package:flutter_test/flutter_test.dart';
import 'package:questionapp/features/account/providers/streak_celebration_providers.dart';

void main() {
  group('shouldCelebrateStreak', () {
    test('first observation only seeds — never celebrates', () {
      // A fresh install / a user who already had a long streak before this
      // shipped must not get a retroactive flourish; the null baseline is just
      // recorded.
      expect(
        shouldCelebrateStreak(currentStreak: 0, lastCelebratedStreak: null),
        isFalse,
      );
      expect(
        shouldCelebrateStreak(currentStreak: 12, lastCelebratedStreak: null),
        isFalse,
      );
    });

    test('no streak (0) is never celebrated', () {
      expect(
        shouldCelebrateStreak(currentStreak: 0, lastCelebratedStreak: 0),
        isFalse,
      );
    });

    test('the streak growing celebrates', () {
      // The everyday case: a vote pushed the streak from 4 to 5 days.
      expect(
        shouldCelebrateStreak(currentStreak: 1, lastCelebratedStreak: 0),
        isTrue,
      );
      expect(
        shouldCelebrateStreak(currentStreak: 5, lastCelebratedStreak: 4),
        isTrue,
      );
    });

    test('the same streak does not re-celebrate', () {
      // Every invalidate(userStatsProvider) re-fetch lands here; only a genuine
      // increase should fire.
      expect(
        shouldCelebrateStreak(currentStreak: 5, lastCelebratedStreak: 5),
        isFalse,
      );
    });

    test('a freeze-driven drop does not celebrate', () {
      // The caller lowers the baseline to the dropped value; growing back (below)
      // is what re-fires.
      expect(
        shouldCelebrateStreak(currentStreak: 3, lastCelebratedStreak: 6),
        isFalse,
      );
    });

    test('growing back after a freeze drop celebrates again', () {
      // Baseline was lowered to 3 by the drop; climbing to 4 is a fresh day.
      expect(
        shouldCelebrateStreak(currentStreak: 4, lastCelebratedStreak: 3),
        isTrue,
      );
    });
  });
}
