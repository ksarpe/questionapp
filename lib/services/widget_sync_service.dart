import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes today's daily question to the native home-screen widgets.
///
/// The widgets (Android AppWidget + iOS WidgetKit) are deliberately "dumb": they
/// only render strings this service writes into shared storage, so localization
/// stays in one place (the ARB files) and the native side has no business logic.
/// The daily question is always free to read, so nothing premium ever leaks onto
/// a lock screen.
///
/// Every call is best-effort and swallowed on failure — a home-screen widget is
/// a nice-to-have surface, never a reason to crash or block the app.
class WidgetSyncService {
  WidgetSyncService._();

  /// iOS App Group shared between the Runner app and the widget extension. Must
  /// match the group configured on both targets in Xcode (see
  /// `ios/DailyQuestionWidget/SETUP.md`). No-op on Android.
  static const String _appGroupId = 'group.com.aknsoftware.questionapp';

  /// The Android `AppWidgetProvider` subclass name (see
  /// `DailyQuestionWidgetProvider.kt`).
  static const String _androidProvider = 'DailyQuestionWidgetProvider';

  /// The iOS WidgetKit widget kind (the `Widget`'s struct name).
  static const String _iOSWidgetKind = 'DailyQuestionWidget';

  // Shared-storage keys the native widgets read. Keep in sync with the Android
  // provider and the SwiftUI timeline provider.
  static const String keyLabel = 'widget_label';
  static const String keyQuestion = 'widget_question';
  static const String keyDate = 'widget_date';
  static const String keyQuestionId = 'widget_question_id';

  /// Wires up the App Group so the iOS widget can read what the app writes.
  /// Call once during startup, before the first [pushDaily].
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('WidgetSyncService.init failed: $e');
    }
  }

  /// Writes today's daily question into shared storage and asks the OS to redraw
  /// the widgets. [date] is the local `yyyy-MM-dd` the question is scheduled for,
  /// so the native side can tell whether it is still showing today's.
  static Future<void> pushDaily({
    required String label,
    required String questionText,
    required String date,
    required String questionId,
  }) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(keyLabel, label),
        HomeWidget.saveWidgetData<String>(keyQuestion, questionText),
        HomeWidget.saveWidgetData<String>(keyDate, date),
        HomeWidget.saveWidgetData<String>(keyQuestionId, questionId),
      ]);
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        iOSName: _iOSWidgetKind,
      );
    } catch (e) {
      // Widget surfaces are optional; never let a sync failure surface to the UI.
      debugPrint('WidgetSyncService.pushDaily failed: $e');
    }
  }

  /// Formats a [DateTime] as the local `yyyy-MM-dd` used for [pushDaily]'s
  /// `date`, mirroring the repository's `_dateOnly`.
  static String dateOnly(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
