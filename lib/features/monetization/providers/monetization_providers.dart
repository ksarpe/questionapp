import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/rewarded_ad_service.dart';

/// The single shared rewarded-ad service. Begins pre-loading on creation and is
/// disposed with the app.
///
/// Revealing a question after an ad is server-mediated and client-driven (the
/// `reveal_ad_question` RPC, see [WindQuestionView]); there is no client-side
/// "unlock credit" bookkeeping. The old `SwipeGate` / `unlockCreditsProvider`
/// model (a per-session counter reconciled against the dropped `question_unlocks`
/// table) was removed when the reveal feed landed.
final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService()..preload();
  ref.onDispose(service.dispose);
  return service;
});
