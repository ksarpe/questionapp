import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// On-device daily reminder for the question of the day.
///
/// Deliberately **local** notifications — no Firebase, no APNs key, no server
/// cron. The daily nudge is scheduled on the device with a repeating wall-clock
/// trigger, so there is nothing to configure in any console and nothing to keep
/// running server-side. It works offline and survives reboots (the schedule is
/// also refreshed on every launch, see `main()`).
///
/// Every call is guarded so the app still runs where the native plugin isn't
/// available (desktop/web dev, tests): it simply no-ops.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;
  static bool get isInitialised => _initialised;

  /// Stable id for the single daily reminder, so re-scheduling replaces it
  /// rather than stacking duplicates.
  static const int _dailyReminderId = 1001;

  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily question';
  static const String _channelDescription =
      'A daily nudge to answer the question of the day.';

  /// Initialises the plugin and the timezone database. Safe to call once at
  /// startup; subsequent calls no-op.
  static Future<void> initialise() async {
    if (_initialised) return;
    try {
      // Timezone DB + the device's local zone, so a daily wall-clock time fires
      // at the right local moment regardless of where the user is.
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        // Falls back to UTC (the timezone package default) — the reminder still
        // fires daily, just anchored to UTC rather than the device zone.
        debugPrint('NotificationService: timezone detect failed — $e');
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Don't ask for permission at init — we request it contextually when the
      // user turns the reminder on (see [requestPermission]).
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _initialised = true;
    } catch (e) {
      debugPrint('NotificationService: init failed — $e');
    }
  }

  /// Requests OS permission to post notifications, returning whether it's
  /// granted. On Android < 13 no runtime permission exists, so this resolves
  /// true. Call right before enabling the reminder.
  static Future<bool> requestPermission() async {
    if (!_initialised) return false;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        // Null = pre-Android-13, where notifications need no runtime grant.
        return granted ?? true;
      }
      return false;
    } catch (e) {
      debugPrint('NotificationService: permission request failed — $e');
      return false;
    }
  }

  /// Schedules (replacing any existing) a daily reminder at [hour]:[minute]
  /// local time. [title]/[body] are baked in at schedule time, so callers pass
  /// the localized strings for the current language.
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_initialised) return;
    try {
      await _plugin.cancel(id: _dailyReminderId);
      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        // Inexact alarms avoid the SCHEDULE_EXACT_ALARM permission and its Play
        // Store declaration — a daily reminder doesn't need to-the-second timing.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repeat every day at the same time.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('NotificationService: schedule failed — $e');
    }
  }

  /// Cancels the daily reminder, e.g. when the user turns it off.
  static Future<void> cancelDailyReminder() async {
    if (!_initialised) return;
    try {
      await _plugin.cancel(id: _dailyReminderId);
    } catch (e) {
      debugPrint('NotificationService: cancel failed — $e');
    }
  }

  /// The next [hour]:[minute] in the device's local zone — today if it's still
  /// ahead, otherwise tomorrow.
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
