import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../core/config/app_config.dart';

/// Wrapper around RevenueCat (`purchases_flutter`).
///
/// Handles SDK configuration and exposes a single [isPremium] check the rest of
/// the app can use to gate premium questions. Skips configuration when no API
/// key is supplied so the app runs without RevenueCat during development.
class PurchasesService {
  PurchasesService._();

  /// Entitlement identifier configured in the RevenueCat dashboard. Adjust here
  /// (one place) if the dashboard uses a different name.
  static const String _premiumEntitlementId = 'premium';

  static bool _configured = false;

  static Future<void> initialise() async {
    if (AppConfig.revenueCatApiKey.isEmpty) {
      debugPrint(
        'PurchasesService: no API key — skipping RevenueCat configure. '
        'Pass --dart-define=REVENUECAT_API_KEY to enable.',
      );
      return;
    }

    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatApiKey),
    );
    _configured = true;
  }

  /// Links the RevenueCat customer to a stable app user id (the Supabase
  /// anonymous UUID), so entitlements follow the same identity the backend uses.
  /// No-ops when RevenueCat is not configured.
  static Future<void> identify(String appUserId) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(appUserId);
    } catch (e) {
      debugPrint('PurchasesService.identify failed: $e');
    }
  }

  /// Whether the current user has the active premium entitlement.
  static Future<bool> isPremium() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_premiumEntitlementId);
    } catch (e) {
      debugPrint('PurchasesService.isPremium failed: $e');
      return false;
    }
  }

  /// Presents the RevenueCat-hosted paywall — the one designed in the dashboard
  /// and attached to the current offering — and reports whether the user ended
  /// up with the premium entitlement (bought or restored).
  ///
  /// A cancelled / dismissed paywall is a quiet `false`, not an error.
  static Future<bool> presentPaywall() async {
    if (!_configured) {
      debugPrint('PurchasesService: not configured — cannot show paywall.');
      return false;
    }
    try {
      final result = await RevenueCatUI.presentPaywall();
      switch (result) {
        case PaywallResult.purchased:
        case PaywallResult.restored:
          // The entitlement is the source of truth — re-check it rather than
          // trusting the result alone.
          return await isPremium();
        case PaywallResult.cancelled:
        case PaywallResult.error:
        case PaywallResult.notPresented:
          return false;
      }
    } catch (e) {
      debugPrint('PurchasesService.presentPaywall failed: $e');
      return false;
    }
  }

  /// Restores a previous purchase (e.g. after reinstalling or switching device)
  /// and reports whether premium is active afterwards. Required by the App
  /// Store review guidelines for any app that sells a non-consumable.
  static Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      await Purchases.restorePurchases();
      return await isPremium();
    } catch (e) {
      debugPrint('PurchasesService.restorePurchases failed: $e');
      return false;
    }
  }
}
