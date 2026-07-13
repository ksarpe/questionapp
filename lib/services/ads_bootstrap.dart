import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../core/startup/guarded_init.dart';
import 'ads_service.dart';
import 'consent_service.dart';

/// Deferred bring-up of the whole ad stack: consent first (UMP GDPR form +
/// iOS ATT), then the AdMob SDK, in that order so the first ad request already
/// carries a consent decision.
///
/// This deliberately does NOT run at app launch. The UMP form and the ATT
/// prompt are the app's only interrupting legal dialogs, and firing them from
/// `main()` meant they could drop on top of the onboarding funnel at a random
/// moment. Instead [AppEntry] calls [ensureStarted] when the home screen comes
/// on screen — after onboarding on a first run, right after the splash for a
/// returning user (who has usually already answered, so no form re-appears;
/// UMP just silently refreshes its consent info, as Google recommends per
/// launch).
///
/// Safe ordering is preserved by construction: until this runs,
/// `AdsService.isInitialised` is false and `RewardedAdService.preload` no-ops,
/// so nothing can request an ad before consent has been gathered.
class AdsBootstrap {
  AdsBootstrap._();

  static Future<void>? _started;

  /// Gathers consent and initialises AdMob, once per app run. Subsequent calls
  /// return the same future, so callers can await it freely (e.g. to warm the
  /// first rewarded ad afterwards). Each step is guarded + bounded like the
  /// `main()` startup inits — a hung native channel degrades ads, never the UI.
  static Future<void> ensureStarted() {
    // Skip entirely under `flutter test`: the UMP platform channel has no host
    // there, its callbacks never answer, and guardedInit's bounding timer then
    // trips the framework's pending-timer check. Widget tests pump AppEntry
    // (which calls this on home entry), and ads are inert in tests anyway.
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future.value();
    }
    return _started ??= _run();
  }

  static Future<void> _run() async {
    await guardedInit('consent', ConsentService.gather);
    await guardedInit('ads', AdsService.initialise);
  }
}
