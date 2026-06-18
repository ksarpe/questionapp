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
    await MobileAds.instance.initialize();
    _initialised = true;
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
