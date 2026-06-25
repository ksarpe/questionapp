import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/app_config.dart';

/// Wrapper around Google AdMob (`google_mobile_ads`).
///
/// Call [initialise] once at startup. [createBannerAd] hands back a configured
/// (but not yet loaded) [BannerAd]; the caller is responsible for `load()` and
/// `dispose()` — typically a small banner widget.
class AdsService {
  AdsService._();

  static bool _initialised = false;

  /// Whether the AdMob SDK has been initialised. Ad-loading code (e.g.
  /// [RewardedAdService]) checks this so it cleanly no-ops in development and
  /// tests where [initialise] was never called.
  static bool get isInitialised => _initialised;

  static Future<void> initialise() async {
    // Degrade gracefully like SupabaseService / PurchasesService: if the AdMob
    // SDK fails to initialise we leave [_initialised] false so ad-loading code
    // cleanly no-ops, rather than letting the exception abort app launch.
    try {
      // Register test devices BEFORE requesting any ad: AdMob then serves test
      // ads to them even on the real ad unit id, so we can exercise the live
      // rewarded unit + SSV loop in development without risking an invalid-
      // traffic ban. Empty (the default) leaves real ads on for everyone else.
      final testDeviceIds = AppConfig.admobTestDeviceIds;
      if (testDeviceIds.isNotEmpty) {
        MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: testDeviceIds),
        );
      }
      await MobileAds.instance.initialize();
      _initialised = true;
    } catch (e) {
      debugPrint('AdsService: initialisation failed — ads disabled. $e');
    }
  }

  static BannerAd createBannerAd({
    void Function(Ad)? onLoaded,
    void Function(Ad, LoadAdError)? onFailed,
  }) {
    return BannerAd(
      adUnitId: AppConfig.admobBannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onLoaded?.call(ad),
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdsService: banner failed to load — $error');
          ad.dispose();
          onFailed?.call(ad, error);
        },
      ),
    );
  }
}
