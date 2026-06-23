import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/settings/providers/reminder_providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'notification_service.dart';
import 'question_cache.dart';
import 'reminder_messages.dart';

/// How many days ahead the reminder loop is pre-scheduled. A week gives the
/// "loop" real day-to-day variety even for a user who doesn't open the app for a
/// few days; it's recomputed on every launch / vote anyway, so the far days
/// rarely fire as baked.
const int kReminderLoopDays = 7;

/// Rebuilds the whole reminder loop from local state, in [l10n]'s language.
/// No-ops when reminders are off.
///
/// Reads the inputs that drive the message choice straight from [prefs] — the
/// last cached [UserStats] sync (streak / grace window) and whether today's
/// daily is already voted (with the split the user landed on) — so it works
/// without the provider graph and is safe to call from `main()`. Call it anywhere
/// that state may have changed: launch, after a daily vote, on enable, on a time
/// change, and on a language switch.
Future<void> rescheduleReminderLoop({
  required SharedPreferences prefs,
  required AppLocalizations l10n,
}) async {
  final reminder = ReminderPrefs.fromPrefs(prefs);
  if (!reminder.enabled) return;

  final stats = QuestionCache(prefs).readStats();
  final votedToday = hasVotedTodayLocal(prefs);
  final disagreePct = lastDisagreePctToday(prefs);
  final random = Random();

  await NotificationService.scheduleReminderLoop(
    hour: reminder.hour,
    minute: reminder.minute,
    days: kReminderLoopDays,
    build: (dayOffset, isToday) => buildReminderMessage(
      l10n: l10n,
      stats: stats,
      // The vote state / split are only known for today; future days assume an
      // unvoted day and fall back to the "come and vote" pool.
      votedToday: isToday && votedToday,
      isToday: isToday,
      disagreePct: isToday ? disagreePct : null,
      random: random,
    ),
  );
}
