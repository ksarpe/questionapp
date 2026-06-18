import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/rewarded_ad_service.dart';
import '../../account/providers/session_providers.dart';

/// How many question swipes a single rewarded ad unlocks.
///
/// Watching one ad grants this many unlocks; the swipe that triggered the ad
/// spends the first, so a free user isn't prompted again until the batch runs
/// out. Tune freely (1 = an ad per swipe).
const int kUnlocksPerAd = 3;

/// Remaining free-tier unlocks earned from watching rewarded ads.
///
/// Premium users bypass this entirely (see [SwipeGate]). State is in-memory by
/// design — a fresh session starts at zero so the gate is honoured on each run.
class UnlockCreditsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Grants a fresh batch of unlocks after a rewarded ad completes.
  void grantFromAd() => state += kUnlocksPerAd;

  /// Spends one unlock if any remain. Returns whether one was actually spent.
  bool tryConsume() {
    if (state <= 0) return false;
    state -= 1;
    return true;
  }
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

/// Outcome of asking to advance to the next question.
enum SwipeDecision {
  /// The swipe may proceed (premium, or a credit was spent).
  allowed,

  /// Free user out of credits — show the unlock sheet instead of animating.
  gated,
}

/// The free-tier monetization gate.
///
/// Premium users always pass. Free users spend an earned unlock credit; with
/// none left they're gated, which the swipe handler turns into the unlock
/// sheet. Keeping the decision here (not in the widget) keeps it testable and
/// the side effect — spending a credit — explicit.
class SwipeGate {
  SwipeGate(this._ref);

  final Ref _ref;

  /// Evaluates a swipe, consuming one unlock credit when a free user uses one.
  SwipeDecision requestAdvance() {
    if (_ref.read(isPremiumProvider)) return SwipeDecision.allowed;

    final consumed = _ref.read(unlockCreditsProvider.notifier).tryConsume();
    return consumed ? SwipeDecision.allowed : SwipeDecision.gated;
  }

  /// Adds the unlocks earned from a completed rewarded ad.
  void grantAdReward() =>
      _ref.read(unlockCreditsProvider.notifier).grantFromAd();
}

final swipeGateProvider = Provider<SwipeGate>((ref) => SwipeGate(ref));
