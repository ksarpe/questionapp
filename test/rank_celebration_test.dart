import 'package:flutter_test/flutter_test.dart';
import 'package:questionapp/features/account/providers/rank_celebration_providers.dart';

void main() {
  group('shouldCelebrateRank', () {
    test('first observation only seeds — never celebrates', () {
      // A fresh install / a user already past several ranks must not get a
      // retroactive barrage; the null baseline is just recorded.
      expect(
        shouldCelebrateRank(currentTier: 0, lastCelebratedTier: null),
        isFalse,
      );
      expect(
        shouldCelebrateRank(currentTier: 4, lastCelebratedTier: null),
        isFalse,
      );
    });

    test('the free entry rank (tier 0) is never celebrated', () {
      expect(
        shouldCelebrateRank(currentTier: 0, lastCelebratedTier: 0),
        isFalse,
      );
    });

    test('a genuine promotion above the last celebrated tier celebrates', () {
      expect(
        shouldCelebrateRank(currentTier: 1, lastCelebratedTier: 0),
        isTrue,
      );
      expect(
        shouldCelebrateRank(currentTier: 3, lastCelebratedTier: 2),
        isTrue,
      );
    });

    test('staying on the same tier does not re-celebrate', () {
      expect(
        shouldCelebrateRank(currentTier: 3, lastCelebratedTier: 3),
        isFalse,
      );
    });

    test('a freeze-driven drop does not celebrate', () {
      // The caller lowers the baseline to the dropped tier; reaching it again
      // (below) is what re-fires.
      expect(
        shouldCelebrateRank(currentTier: 2, lastCelebratedTier: 3),
        isFalse,
      );
    });

    test('re-climbing a rank after a freeze drop celebrates again', () {
      // Baseline was lowered to 2 by the drop; climbing back to 3 is a fresh win.
      expect(
        shouldCelebrateRank(currentTier: 3, lastCelebratedTier: 2),
        isTrue,
      );
    });
  });
}
