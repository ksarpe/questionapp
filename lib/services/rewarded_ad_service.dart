import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/app_config.dart';
import 'ads_service.dart';

/// Manages the lifecycle of a single Google AdMob *rewarded* ad: pre-loading one
/// in the background, showing it on demand, surfacing the
/// `onUserEarnedReward` callback, and immediately pre-loading the next.
///
/// Kept framework-agnostic (no Riverpod here) like the other services; a
/// provider owns the single shared instance and disposes it (see
/// `monetization_providers.dart`).
class RewardedAdService {
  RewardedAdService();

  RewardedAd? _ad;
  bool _isLoading = false;

  /// Whether an ad is loaded and ready to [showRewardedAd] right now.
  bool get isReady => _ad != null;

  /// Starts loading a rewarded ad if one isn't already loaded or in flight.
  ///
  /// No-ops when the AdMob SDK hasn't been initialised (development / tests), so
  /// callers can preload freely without guarding.
  void preload() {
    if (!AdsService.isInitialised) return;
    if (_ad != null || _isLoading) return;

    _isLoading = true;
    RewardedAd.load(
      adUnitId: AppConfig.admobRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAdService: failed to load — $error');
          _ad = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// Shows the loaded ad, invoking [onReward] if (and only if) the user earns
  /// the reward. Completes once the ad is dismissed — or immediately if no ad
  /// was ready (in which case a fresh load is kicked off). A replacement ad is
  /// always pre-loaded for next time.
  Future<void> showRewardedAd({required VoidCallback onReward}) async {
    final ad = _ad;
    if (ad == null) {
      preload();
      return;
    }

    // Consume the reference up front so the same ad can't be shown twice.
    _ad = null;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('RewardedAdService: failed to show — $error');
        ad.dispose();
        preload();
        if (!completer.isCompleted) completer.complete();
      },
    );

    await ad.show(onUserEarnedReward: (_, _) => onReward());
    return completer.future;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
