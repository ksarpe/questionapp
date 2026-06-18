import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/features/account/providers/session_providers.dart';
import 'package:questionapp/features/monetization/providers/monetization_providers.dart';

void main() {
  group('SwipeGate', () {
    test('free user with no credits is gated', () {
      final container = ProviderContainer(
        overrides: [isPremiumProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      final gate = container.read(swipeGateProvider);
      expect(gate.requestAdvance(), SwipeDecision.gated);
    });

    test('one rewarded ad unlocks exactly kUnlocksPerAd swipes', () {
      final container = ProviderContainer(
        overrides: [isPremiumProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      final gate = container.read(swipeGateProvider);
      gate.grantAdReward();

      // The granted batch is spendable on the next kUnlocksPerAd swipes...
      for (var i = 0; i < kUnlocksPerAd; i++) {
        expect(gate.requestAdvance(), SwipeDecision.allowed, reason: 'swipe $i');
      }
      // ...and then the gate closes again.
      expect(gate.requestAdvance(), SwipeDecision.gated);
    });

    test('premium user always passes without spending credits', () {
      final container = ProviderContainer(
        overrides: [isPremiumProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);

      final gate = container.read(swipeGateProvider);
      for (var i = 0; i < 5; i++) {
        expect(gate.requestAdvance(), SwipeDecision.allowed);
      }
      // No credits were touched, so the counter is untouched.
      expect(container.read(unlockCreditsProvider), 0);
    });
  });
}
