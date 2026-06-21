import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';

/// Where the active subscription is billed — drives the wording and the
/// "manage" deep link, since cancellation lives in a different place on each
/// platform (Apple and Google both forbid cancelling from inside the app).
enum PremiumStore {
  appStore,
  playStore,

  /// Web / third-party billing (Stripe, RevenueCat Billing, an external store).
  web,

  /// Promotional grants, Amazon, or anything we don't surface a deep link for.
  other,
}

/// A read-only snapshot of the user's premium subscription, distilled from the
/// RevenueCat `EntitlementInfo` into just what the Manage-subscription UI needs.
///
/// [willRenew] is the cancellation signal: `false` means the user has already
/// turned off auto-renew (in the store) but keeps premium until [expirationDate].
@immutable
class PremiumStatus {
  const PremiumStatus({
    required this.isActive,
    required this.willRenew,
    required this.store,
    this.expirationDate,
    this.managementUrl,
  });

  final bool isActive;
  final bool willRenew;
  final PremiumStore store;

  /// End of the current paid period. Null for lifetime/promotional grants.
  final DateTime? expirationDate;

  /// Store-specific deep link to the subscription-management page (the
  /// App Store / Google Play subscriptions screen). Null when RevenueCat can't
  /// build one (e.g. promotional entitlements).
  final String? managementUrl;

  /// The user has cancelled but is still inside their paid period.
  bool get isCancelled => isActive && !willRenew;
}

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

  /// Registers [onChanged] to fire whenever RevenueCat pushes a customer-info
  /// update — a renewal, an expiry, a restore on another device, or a purchase
  /// completing outside the in-app paywall. The bool is whether premium is now
  /// active. Returns the underlying listener (pass it to [removePremiumListener]
  /// to detach) or null when RevenueCat isn't configured.
  ///
  /// Note RevenueCat fires this immediately on registration with the cached
  /// info; callers should ignore a no-op change.
  static CustomerInfoUpdateListener? addPremiumListener(
    void Function(bool isPremium) onChanged,
  ) {
    if (!_configured) return null;
    void listener(CustomerInfo info) =>
        onChanged(info.entitlements.active.containsKey(_premiumEntitlementId));
    Purchases.addCustomerInfoUpdateListener(listener);
    return listener;
  }

  static void removePremiumListener(CustomerInfoUpdateListener? listener) {
    if (!_configured || listener == null) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
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

  /// Reads the active premium subscription's details (renewal date, whether it
  /// will renew, the billing store and its management deep link) for the
  /// Manage-subscription screen. Returns null when RevenueCat isn't configured
  /// or premium isn't active — the caller falls back to a generic state.
  static Future<PremiumStatus?> premiumStatus() async {
    if (!_configured) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.active[_premiumEntitlementId];
      if (entitlement == null) return null;
      final expiry = entitlement.expirationDate;
      return PremiumStatus(
        isActive: entitlement.isActive,
        willRenew: entitlement.willRenew,
        store: _mapStore(entitlement.store),
        expirationDate: expiry == null ? null : DateTime.tryParse(expiry),
        managementUrl: info.managementURL,
      );
    } catch (e) {
      debugPrint('PurchasesService.premiumStatus failed: $e');
      return null;
    }
  }

  /// Opens the native subscription-management page (App Store / Google Play
  /// subscriptions) for the current customer. Neither store lets an app cancel
  /// a subscription itself, so "manage / cancel" always means deep-linking out
  /// to [PremiumStatus.managementUrl]. Returns whether the page could be opened.
  static Future<bool> openManagement(String? managementUrl) async {
    if (managementUrl == null || managementUrl.isEmpty) return false;
    final uri = Uri.tryParse(managementUrl);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('PurchasesService.openManagement failed: $e');
      return false;
    }
  }

  static PremiumStore _mapStore(Store store) {
    switch (store) {
      case Store.appStore:
      case Store.macAppStore:
        return PremiumStore.appStore;
      case Store.playStore:
        return PremiumStore.playStore;
      case Store.stripe:
      case Store.rcBilling:
      case Store.paddle:
      case Store.externalStore:
        return PremiumStore.web;
      case Store.amazon:
      case Store.galaxy:
      case Store.promotional:
      case Store.testStore:
      case Store.unknownStore:
        return PremiumStore.other;
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
