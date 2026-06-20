import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/rewarded_ad_service.dart';

/// How many questions a single rewarded ad unlocks. Surfaced in the unlock
/// sheet's copy; the actual reveal is reconciled server-side. Tune freely.
const int kUnlocksPerAd = 3;

/// Count of free-tier unlocks earned from watching rewarded ads this session.
///
/// Recorded when a rewarded ad completes. Actually revealing a locked
/// question's text is server-mediated (premium, or an AdMob SSV-verified row in
/// `question_unlocks`), so this is bookkeeping for that reconciliation rather
/// than something the UI gates on directly. In-memory by design — a fresh
/// session starts at zero.
class UnlockCreditsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Grants a fresh batch of unlocks after a rewarded ad completes.
  void grantFromAd() => state += kUnlocksPerAd;
}

final unlockCreditsProvider =
    NotifierProvider<UnlockCreditsNotifier, int>(UnlockCreditsNotifier.new);

/// The single shared rewarded-ad service. Begins pre-loading on creation and is
/// disposed with the app.
final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService()..preload();
  ref.onDispose(service.dispose);
  return service;
});

/// Records the monetization side effects of the unlock sheet.
///
/// The text gate itself lives server-side (RLS on `question_translations`):
/// browsing the deck is free, and a locked question is revealed only by going
/// premium or by an SSV-verified ad unlock. This just records the ad reward;
/// keeping it here (not in the widget) keeps the side effect explicit.
class SwipeGate {
  SwipeGate(this._ref);

  final Ref _ref;

  /// Adds the unlocks earned from a completed rewarded ad.
  void grantAdReward() =>
      _ref.read(unlockCreditsProvider.notifier).grantFromAd();
}

final swipeGateProvider = Provider<SwipeGate>((ref) => SwipeGate(ref));
