import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';
import '../network/network_error.dart';

/// Centralised crash- and error-reporting facade over Sentry.
///
/// Every Sentry touchpoint in the app goes through here so that:
///
///   * the rest of the code never imports `sentry_flutter` directly — swapping
///     or removing the provider later is a one-file change;
///   * every call is a safe no-op when no `SENTRY_DSN` is configured (dev / mock
///     mode). `SentryFlutter.init` with an empty DSN initialises a *disabled*
///     hub: events are dropped but the static API stays callable, and the same
///     is true of the no-op hub used in tests that never call `init` at all;
///   * connectivity blips are filtered out in ONE place ([_isReportable] +
///     [configureOptions]'s `beforeSend`), so a user on a flaky network never
///     burns the Sentry quota with errors the app already handles gracefully.
///
/// Wiring lives in `main()` ([configureOptions] + `appRunner`); user identity is
/// attached from the session layer ([setUser]); the service layer reports its
/// otherwise-swallowed failures via [captureException] / [addBreadcrumb].
class Monitoring {
  Monitoring._();

  /// Whether a DSN was supplied, i.e. events will actually be sent. Handy for
  /// surfacing the wiring state in dev logs; the report methods below stay safe
  /// to call regardless.
  static bool get isEnabled => AppConfig.hasSentry;

  /// Builds the Sentry options. Passed as the first argument to
  /// `SentryFlutter.init` in `main()`.
  static FutureOr<void> configureOptions(SentryFlutterOptions options) {
    options.dsn = AppConfig.sentryDsn;

    // Tag every event with a deployment name so you can split dev/staging noise
    // from production crashes. Falls back to the build mode when unset.
    options.environment = AppConfig.sentryEnvironment.isNotEmpty
        ? AppConfig.sentryEnvironment
        : (kReleaseMode ? 'production' : 'development');

    // Performance tracing (transactions for navigation + slow operations). The
    // Developer plan meters performance units, so sample instead of tracing 100%.
    options.tracesSampleRate = AppConfig.sentryTracesSampleRate;

    // Surface SDK diagnostics in the console only in debug, and only when a DSN
    // is set, so an unconfigured dev build stays quiet.
    options.debug = kDebugMode && AppConfig.hasSentry;

    // We attach a stable, pseudonymous Supabase UUID as the user id ourselves
    // (see [setUser]); never let the SDK harvest IPs/emails on top of that.
    options.sendDefaultPii = false;

    // Tells Sentry which frames are ours vs. package/SDK code, so issues group
    // on the app's own stack and the "In App" filter works.
    options.addInAppInclude('questionapp');

    // Last line of defence against quota noise: drop anything that is really a
    // loss of connectivity (the app falls back to cache and shows an offline
    // banner for these — they are not bugs). Manual reports are already filtered
    // in [captureException]; this also covers framework/zone-caught errors.
    options.beforeSend = (event, hint) {
      final Object? thrown = event.throwable;
      if (thrown != null && isOfflineError(thrown)) return null;
      return event;
    };
  }

  /// Attaches (or clears) the current identity on the global scope so every
  /// subsequent event is tagged with who hit it. We send only the pseudonymous
  /// Supabase UUID — never email/name — plus coarse tags for fast filtering.
  ///
  /// Call with [id] = null to detach on sign-out. Safe to call before/without
  /// `SentryFlutter.init`.
  static Future<void> setUser({
    required String? id,
    bool? isPremium,
    bool? isAnonymous,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(id == null ? null : SentryUser(id: id));
      if (isPremium != null) scope.setTag('premium', '$isPremium');
      if (isAnonymous != null) scope.setTag('guest', '$isAnonymous');
    });
  }

  /// Reports a handled exception that the app caught and recovered from — the
  /// failures that would otherwise be swallowed by a `debugPrint` and never seen
  /// in production.
  ///
  /// Connectivity errors are dropped (the app handles those as "offline", not as
  /// bugs). [feature] becomes a searchable tag (e.g. `auth`, `purchases`);
  /// [extra] is attached as a context block.
  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? feature,
    Map<String, dynamic>? extra,
    SentryLevel level = SentryLevel.error,
  }) async {
    if (!_isReportable(error)) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = level;
        if (feature != null) scope.setTag('feature', feature);
        if (extra != null && extra.isNotEmpty) {
          scope.setContexts('details', extra);
        }
      },
    );
  }

  /// Records a breadcrumb: a low-cost trail entry that rides along with the next
  /// captured event so you can see what the user did just before it. Use for
  /// frequent/expected events (ad no-fill, vote cast, paywall shown) that aren't
  /// worth an issue of their own but give an error its context.
  static void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
      ),
    );
  }

  /// An error is worth reporting unless it's just a dropped connection — those
  /// are an expected, gracefully-handled state, not a bug, and reporting them
  /// would flood the quota for users on poor networks.
  static bool _isReportable(Object error) => !isOfflineError(error);
}
