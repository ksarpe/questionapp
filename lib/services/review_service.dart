import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// Thin, fully-guarded wrapper around the OS in-app review flow.
///
/// On iOS this is `SKStoreReviewController`, on Android the Play In-App Review
/// API — both show a NATIVE rating sheet *inside* the app (no app-supplied copy,
/// no jump out to the store). The OS decides whether the sheet actually appears
/// and throttles it hard (iOS allows roughly three a year), so a request is a
/// hint, not a guarantee — there is deliberately no "did it show?" callback. We
/// add our OWN cooldown on top (see `ReviewPromptController`) so the ask is only
/// ever spent at a genuinely good moment.
///
/// Heads-up for testing: the native sheet does NOT appear in local debug builds.
/// Android only shows it for an app installed via Play (internal-testing track or
/// later); iOS shows it in production (not reliably in TestFlight). So "nothing
/// happened" on your dev device is expected, not a bug.
///
/// Every call is guarded so the app still runs where the native plugin isn't
/// available (desktop/web dev, tests): it simply no-ops.
class ReviewService {
  ReviewService._();

  static final InAppReview _inAppReview = InAppReview.instance;

  /// Asks the OS to present its in-app rating sheet, if it's available and the
  /// system chooses to show it. Best-effort: any failure is swallowed so a
  /// review prompt can never break the flow that triggered it.
  static Future<void> requestReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      }
    } catch (e) {
      debugPrint('ReviewService: requestReview failed — $e');
    }
  }
}
