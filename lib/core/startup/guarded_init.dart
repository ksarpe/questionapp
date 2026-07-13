import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../monitoring/monitoring.dart';

/// How long any single startup SDK gets before we give up on it and let the app
/// come up anyway. Comfortably longer than a healthy init on a cold device, yet
/// bounded so a broken/hanging one can't wall the launch. See [guardedInit].
const kInitTimeout = Duration(seconds: 8);

/// Runs a startup SDK init defensively so it can never wall the launch.
///
/// Bounds the call with [kInitTimeout] (a stripped/hung platform channel never
/// returns on its own) and swallows any error, reporting both to Sentry tagged
/// with [name] so a stuck launch is diagnosable from the dashboard even when we
/// can't pull a logcat. The SDK's own code already degrades when uninitialised.
Future<void> guardedInit(String name, Future<void> Function() init) async {
  try {
    await init().timeout(kInitTimeout);
  } on TimeoutException {
    // Report as a distinct [StartupInitException], NOT the raw TimeoutException:
    // Monitoring's offline filter drops timeouts as expected connectivity blips,
    // but a walled init is a real bug we must see (these SDKs don't need the
    // network to initialise, so a timeout means a broken channel, not offline).
    debugPrint(
      'startup: "$name" did not initialise within '
      '${kInitTimeout.inSeconds}s — continuing without it',
    );
    await Monitoring.captureException(
      StartupInitException(name, kInitTimeout),
      stackTrace: StackTrace.current,
      feature: 'startup',
      extra: {'sdk': name, 'timeout_s': kInitTimeout.inSeconds},
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

/// A startup SDK that didn't finish initialising inside [kInitTimeout].
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
