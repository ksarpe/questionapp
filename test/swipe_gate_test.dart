import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/features/monetization/providers/monetization_providers.dart';

void main() {
  group('SwipeGate', () {
    test('a rewarded ad records kUnlocksPerAd credits', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final gate = container.read(swipeGateProvider);
      expect(container.read(unlockCreditsProvider), 0);

      gate.grantAdReward();
      expect(container.read(unlockCreditsProvider), kUnlocksPerAd);
    });
  });
}
