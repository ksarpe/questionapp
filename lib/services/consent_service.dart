import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gathers the user's ad-consent BEFORE any ad loads, covering the two regimes
/// the app stores require:
///
///   1. **GDPR / EEA** via Google's User Messaging Platform (UMP — bundled in
///      `google_mobile_ads`, no extra plugin). We refresh consent info and, when
///      a form is required (EEA / UK), present it. Elsewhere UMP reports
///      "not required" and we move on.
///   2. **iOS App Tracking Transparency.** Apple requires the ATT prompt before
///      an app touches the IDFA, which AdMob uses — so we request it on iOS only,
///      and only when the user hasn't already answered.
///
/// Call [gather] once at startup, BEFORE [AdsService.initialise], so the AdMob
/// SDK already has a consent decision when it initialises and loads ads.
///
/// Best-effort throughout: every call is guarded so a consent hiccup (or running
/// on a platform without the native SDKs, e.g. desktop dev) never blocks launch.
/// [canRequestAds] stays permissive by default so the free tier's ads still work
/// when UMP isn't applicable; the AdMob SDK independently honours the stored
/// consent for personalization.
class ConsentService {
  ConsentService._();

  static bool _canRequestAds = true;

  /// Whether ads may be requested per the UMP decision. Defaults to `true` so
  /// ads work where UMP doesn't apply or can't be reached; flips to `false` only
  /// when UMP explicitly says consent is still outstanding.
  static bool get canRequestAds => _canRequestAds;

  /// Runs the consent flow: UMP (GDPR) first, then iOS ATT. Safe to call when
  /// ads aren't configured — UMP simply finds nothing required.
  static Future<void> gather() async {
    await _requestUmpConsent();
    await _requestIosTracking();
  }

  /// Refreshes UMP consent info and shows the consent form if the SDK says one
  /// is required, then records whether ads may now be requested. The callback
  /// API is bridged to a [Completer] so the caller can `await` the whole flow.
  static Future<void> _requestUmpConsent() async {
    try {
      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint(
                  'ConsentService: consent form error — ${formError.message}',
                );
              }
            });
            _canRequestAds = await ConsentInformation.instance.canRequestAds();
          } catch (e) {
            debugPrint('ConsentService: consent form failed — $e');
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        },
        (error) {
          debugPrint(
            'ConsentService: consent info update failed — ${error.message}',
          );
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
    } catch (e) {
      // MissingPluginException on desktop/web dev, or any UMP failure: leave ads
      // permitted (non-personalized) rather than blocking the free tier.
      debugPrint('ConsentService: UMP unavailable — $e');
    }
  }

  /// On iOS, prompts for App Tracking Transparency the first time only. No-op on
  /// Android / web / desktop, where ATT doesn't exist.
  static Future<void> _requestIosTracking() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ConsentService: ATT request failed — $e');
    }
  }
}
