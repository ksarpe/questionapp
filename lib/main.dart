import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/locale/app_locale.dart';
import 'features/settings/providers/reminder_providers.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/ads_service.dart';
import 'services/consent_service.dart';
import 'services/notification_service.dart';
import 'services/purchases_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise external SDKs before the UI starts. Each call no-ops gracefully
  // when its credentials are absent, so the app runs against mock data out of
  // the box (see AppConfig for the --dart-define keys).
  await SupabaseService.initialise();
  await PurchasesService.initialise();

  // Gather ad consent (GDPR via UMP + iOS App Tracking Transparency) BEFORE the
  // AdMob SDK initialises, so the first ad request already carries a consent
  // decision. Required for store compliance; no-ops where it doesn't apply.
  await ConsentService.gather();
  await AdsService.initialise();
  await NotificationService.initialise();

  // Resolve persisted preferences before the first frame so the chosen language
  // (or the device-detected one) is available synchronously to MaterialApp and
  // the question repository — no loading flash, no wrong-language first paint.
  final prefs = await SharedPreferences.getInstance();

  // Re-arm the daily reminder on every launch: schedules survive app restarts
  // but not necessarily a device reboot, and re-scheduling also refreshes the
  // notification text to the user's current language. No UI exists yet, so we
  // read the persisted prefs directly.
  await _rescheduleReminderIfEnabled(prefs);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const QuestionApp(),
    ),
  );
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
  await NotificationService.scheduleDailyReminder(
    hour: reminder.hour,
    minute: reminder.minute,
    title: l10n.notificationDailyTitle,
    body: l10n.notificationDailyBody,
    // Don't re-arm today's nudge if they already voted before this relaunch.
    skipToday: hasVotedTodayLocal(prefs),
  );
}
