import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

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

  /// Purchases the first package of the current offering and reports whether the
  /// premium entitlement is active afterwards.
  ///
  /// This is a pragmatic stand-in for a full paywall: it buys the default
  /// package so the unlock flow works end-to-end. A user-cancelled purchase is
  /// treated as a quiet `false`, not an error.
  static Future<bool> purchasePremium() async {
    if (!_configured) {
      debugPrint('PurchasesService: not configured — cannot purchase.');
      return false;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const [];
      if (packages.isEmpty) {
        debugPrint('PurchasesService.purchasePremium: no packages available.');
        return false;
      }

      final result =
          await Purchases.purchase(PurchaseParams.package(packages.first));
      return result.customerInfo.entitlements.active
          .containsKey(_premiumEntitlementId);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('PurchasesService.purchasePremium failed: $e');
      }
      return false;
    }
  }
}
