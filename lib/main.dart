import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/locale/app_locale.dart';
import 'core/monitoring/monitoring.dart';
import 'features/settings/providers/reminder_providers.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/ads_service.dart';
import 'services/consent_service.dart';
import 'services/notification_service.dart';
import 'services/purchases_service.dart';
import 'services/reminder_scheduler.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  // Initialise Sentry FIRST and run the whole app inside its `appRunner`. That
  // installs the Flutter + zone error handlers and the native crash handler
  // before anything else runs, so failures during the SDK init sequence below —
  // not just runtime UI errors — are captured too. With no SENTRY_DSN the SDK
  // initialises disabled and still runs `appRunner`, so dev/mock builds are
  // unaffected. See Monitoring + SENTRY_SETUP.md.
  await SentryFlutter.init(Monitoring.configureOptions, appRunner: _startApp);
}

/// How long any single startup SDK gets before we give up on it and let the app
/// come up anyway. Comfortably longer than a healthy init on a cold device, yet
/// bounded so a broken/hanging one can't wall the launch. See [_guardedInit].
const _kInitTimeout = Duration(seconds: 8);

/// Boots the app: persisted prefs, then external SDKs, then the widget tree.
/// Runs inside Sentry's guarded zone (see [main]).
///
/// The contract here is: **`runApp` MUST be reached.** A third-party SDK init
/// must never be able to keep the app stuck on the native splash. Two failure
/// modes have bitten release/R8 builds specifically — an unguarded exception
/// (which aborts the async chain before `runApp`) and, worse, a platform-channel
/// call whose native handler R8 stripped, so the `await` never returns at all.
/// A plain `try/catch` catches the first but NOT the second. So every init runs
/// through [_guardedInit] (timeout + guard + Sentry report), and everything not
/// needed for the first frame is kicked off in the background after `runApp`.
Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve persisted preferences before the first frame so the chosen language
  // (or the device-detected one) is available synchronously to MaterialApp and
  // the question repository — no loading flash, no wrong-language first paint.
  // This is the one genuinely-required await: the ProviderScope override below
  // needs the instance. It's a first-party Flutter plugin (unlikely to be the
  // R8 casualty), so we let it run unguarded rather than fabricate a fake store.
  final prefs = await SharedPreferences.getInstance();

  // Initialise the SDKs the first screens actually read: Supabase backs the
  // question repository, RevenueCat gates premium. Guarded + bounded so a hang
  // or throw in either degrades that feature instead of walling the splash.
  await _guardedInit('supabase', SupabaseService.initialise);
  await _guardedInit('purchases', PurchasesService.initialise);

  // SentryWidget enables view-hierarchy/screenshot context and binds the app to
  // the SDK; it's a transparent passthrough when Sentry is disabled.
  runApp(
    SentryWidget(
      child: ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const DebatlyApp(),
      ),
    ),
  );

  // Everything below is irrelevant to the first frame, so it runs AFTER the UI
  // is on screen — the splash can never wait on it. Ads/consent are the heaviest
  // native stack (play-services + UMP) and the likeliest to hang under R8; the
  // reminder just refreshes an on-device schedule. Order is preserved where it
  // matters: consent must be gathered before AdMob so the first ad request
  // carries a decision, and notifications must init before the reminder re-arms.
  unawaited(_initBackgroundServices(prefs));
}

/// Non-blocking startup: SDKs and housekeeping that the UI doesn't need to
/// paint its first frame. Fired from [_startApp] after `runApp`.
Future<void> _initBackgroundServices(SharedPreferences prefs) async {
  // Gather ad consent (GDPR via UMP + iOS App Tracking Transparency) BEFORE the
  // AdMob SDK initialises, so the first ad request already carries a consent
  // decision. Required for store compliance; no-ops where it doesn't apply.
  await _guardedInit('consent', ConsentService.gather);
  await _guardedInit('ads', AdsService.initialise);
  await _guardedInit('notifications', NotificationService.initialise);

  // Re-arm the daily reminder on every launch: schedules survive app restarts
  // but not necessarily a device reboot, and re-scheduling also refreshes the
  // notification text to the user's current language. Runs after the
  // notification plugin is up (it no-ops otherwise).
  await _guardedInit(
    'reminder',
    () => _rescheduleReminderIfEnabled(prefs),
  );
}

/// Runs a startup SDK init defensively so it can never wall the launch.
///
/// Bounds the call with [_kInitTimeout] (a stripped/hung platform channel never
/// returns on its own) and swallows any error, reporting both to Sentry tagged
/// with [name] so a stuck launch is diagnosable from the dashboard even when we
/// can't pull a logcat. The SDK's own code already degrades when uninitialised.
Future<void> _guardedInit(String name, Future<void> Function() init) async {
  try {
    await init().timeout(_kInitTimeout);
  } on TimeoutException {
    // Report as a distinct [StartupInitException], NOT the raw TimeoutException:
    // Monitoring's offline filter drops timeouts as expected connectivity blips,
    // but a walled init is a real bug we must see (these SDKs don't need the
    // network to initialise, so a timeout means a broken channel, not offline).
    debugPrint('startup: "$name" did not initialise within '
        '${_kInitTimeout.inSeconds}s — continuing without it');
    await Monitoring.captureException(
      StartupInitException(name, _kInitTimeout),
      stackTrace: StackTrace.current,
      feature: 'startup',
      extra: {'sdk': name, 'timeout_s': _kInitTimeout.inSeconds},
      level: SentryLevel.warning,
    );
  } catch (e, st) {
    // A genuine offline error here (e.g. Supabase can't reach the network) is
    // filtered out by Monitoring on purpose — the app degrades to cache and we
    // don't burn quota on it. Everything else gets reported.
    debugPrint('startup: "$name" failed — $e');
    await Monitoring.captureException(
      e,
      stackTrace: st,
      feature: 'startup',
      extra: {'sdk': name},
    );
  }
}

/// A startup SDK that didn't finish initialising inside [_kInitTimeout].
///
/// Deliberately a bespoke type (not [TimeoutException]) and worded to avoid the
/// transport keywords in `isOfflineError`, so Monitoring's offline filter lets
/// it through: a launch that hangs on an SDK is a bug worth an alert, unlike the
/// flaky-network timeouts that filter is there to suppress.
class StartupInitException implements Exception {
  StartupInitException(this.sdk, this.after);

  final String sdk;
  final Duration after;

  @override
  String toString() =>
      'StartupInitException: "$sdk" did not initialise within '
      '${after.inSeconds}s';
}

/// Re-schedules the daily reminder from persisted prefs, in the user's current
/// language. No-ops when the user hasn't enabled reminders. Mirrors the locale
/// resolution in [LocaleController] (saved choice → device language → fallback)
/// so the notification text matches what the UI will show.
Future<void> _rescheduleReminderIfEnabled(SharedPreferences prefs) async {
  final reminder = ReminderPrefs.fromPrefs(prefs);
  if (!reminder.enabled) return;

  final savedCode = prefs.getString(kLocalePrefKey);
  final deviceCode =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final locale = kSupportedLocales.firstWhere(
    (l) => l.languageCode == savedCode,
    orElse: () => kSupportedLocales.firstWhere(
      (l) => l.languageCode == deviceCode,
      orElse: () => kFallbackLocale,
    ),
  );

  final l10n = await AppLocalizations.delegate.load(locale);
  await rescheduleReminderLoop(prefs: prefs, l10n: l10n);
}
