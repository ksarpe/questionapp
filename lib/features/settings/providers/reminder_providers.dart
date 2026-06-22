import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/locale/app_locale.dart' show sharedPreferencesProvider;

const String _kEnabledKey = 'reminders_enabled';
const String _kHourKey = 'reminder_hour';
const String _kMinuteKey = 'reminder_minute';

/// Default daily-reminder time: 20:00 — a quiet evening slot with good open
/// rates, used until the user picks their own.
const int kDefaultReminderHour = 20;
const int kDefaultReminderMinute = 0;

/// The user's daily-reminder preference: whether it's on and at what local time.
/// Persisted in SharedPreferences so it survives restarts; the actual OS-level
/// scheduling is done by [NotificationService], orchestrated from the Settings
/// screen (which has the localized strings) and refreshed on launch in `main()`.
class ReminderPrefs {
  const ReminderPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  /// Reads the persisted preference straight from [prefs] — used in `main()` to
  /// re-arm the reminder on launch before the provider graph exists.
  factory ReminderPrefs.fromPrefs(SharedPreferences prefs) => ReminderPrefs(
    enabled: prefs.getBool(_kEnabledKey) ?? false,
    hour: prefs.getInt(_kHourKey) ?? kDefaultReminderHour,
    minute: prefs.getInt(_kMinuteKey) ?? kDefaultReminderMinute,
  );

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  ReminderPrefs copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderPrefs(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

/// Reads and persists [ReminderPrefs]. Mutating it does NOT touch the OS
/// schedule — the caller pairs a state change with [NotificationService] calls,
/// keeping this provider free of platform/l10n concerns.
class ReminderController extends Notifier<ReminderPrefs> {
  @override
  ReminderPrefs build() =>
      ReminderPrefs.fromPrefs(ref.watch(sharedPreferencesProvider));

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await ref.read(sharedPreferencesProvider).setBool(_kEnabledKey, enabled);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = state.copyWith(hour: time.hour, minute: time.minute);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kHourKey, time.hour);
    await prefs.setInt(_kMinuteKey, time.minute);
  }
}

final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderPrefs>(ReminderController.new);
