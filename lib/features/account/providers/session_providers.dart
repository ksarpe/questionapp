import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/monitoring/monitoring.dart';
import '../../../services/purchases_service.dart';
import '../../../services/supabase_service.dart';

/// Immutable snapshot of who the current user is and what they're entitled to.
///
/// [userId] is the Supabase anonymous UUID (null until silent sign-in resolves,
/// or in mock mode). [isPremium] reflects the active RevenueCat entitlement.
class SessionState {
  const SessionState({
    this.userId,
    this.email,
    this.displayName,
    this.createdAt,
    this.isAnonymous,
    this.isPremium = false,
  });

  final String? userId;
  final String? email;

  /// Human name from the auth provider (e.g. Google `full_name`), when present.
  /// Email/password accounts have none — the UI falls back to the email handle.
  final String? displayName;

  /// When the account was created — drives the "member since" badge.
  final DateTime? createdAt;

  final bool? isAnonymous;
  final bool isPremium;

  bool get isSignedIn => userId != null;
  bool get hasAccount => isSignedIn && isAnonymous != true;

  SessionState copyWith({
    String? userId,
    String? email,
    String? displayName,
    DateTime? createdAt,
    bool? isAnonymous,
    bool? isPremium,
  }) => SessionState(
    userId: userId ?? this.userId,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    createdAt: createdAt ?? this.createdAt,
    isAnonymous: isAnonymous ?? this.isAnonymous,
    isPremium: isPremium ?? this.isPremium,
  );
}

/// Owns the user session: silent anonymous auth on launch plus the premium
/// entitlement that gates the swipe.
///
/// Built lazily the first time something reads [sessionProvider]; the app reads
/// it at launch (see `QuestionScreen`) so anonymous sign-in happens up front.
class SessionNotifier extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() {
    _subscribeToAuthChanges();
    _subscribeToEntitlementChanges();
    return _load();
  }

  /// Keep `isPremium` live when the entitlement changes OUTSIDE the in-app
  /// paywall — a renewal, an expiry, or a restore on another device. Without
  /// this the session reads premium once at launch and only `refresh()` (called
  /// after an in-app purchase) updates it, so an entitlement that lapses or is
  /// restored elsewhere is invisible until the app is killed and relaunched.
  /// Guarded on a real change so RevenueCat's immediate replay (and repeat
  /// pushes of identical info) don't trigger redundant reloads.
  void _subscribeToEntitlementChanges() {
    final listener = PurchasesService.addPremiumListener((isPremium) {
      if (state.hasValue && state.value!.isPremium != isPremium) refresh();
    });
    ref.onDispose(() => PurchasesService.removePremiumListener(listener));
  }

  /// Converge the app on the real identity whenever Supabase changes it OUTSIDE
  /// an in-app action — a refresh-token failure / server-side revocation fires
  /// `signedOut`, and an anonymous→email upgrade fires `userUpdated`. Without
  /// this the session is loaded once and a silent sign-out leaves a zombie UI
  /// (stale userId, every RPC 401-ing) recoverable only by an app restart.
  ///
  /// We reload via [refresh] (no loading flash) rather than `invalidateSelf` so
  /// the QuestionScreen identity listener isn't tripped by a transient null. A
  /// `signedOut` reload re-runs `ensureSignedIn`, minting a fresh guest so the
  /// app is never left sign-in-less. The initial-session / signedIn / token
  /// refresh events are ignored (no identity change to act on).
  void _subscribeToAuthChanges() {
    if (!SupabaseService.isInitialised) return;
    final sub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userUpdated:
          refresh();
        default:
          break;
      }
    });
    ref.onDispose(sub.cancel);
  }

  Future<SessionState> _load() async {
    // 1. Make sure every user — even a brand-new guest — has a stable UUID.
    final userId = await SupabaseService.ensureSignedIn();
    final user = SupabaseService.currentUser;

    // 2. Tie the RevenueCat customer to that same identity.
    if (userId != null) {
      await PurchasesService.identify(userId);
    }

    // 3. Resolve the EFFECTIVE premium entitlement. The DATABASE is the source
    // of truth — it merges store subscriptions with promotional/admin grants and
    // the server-side question/smaczki gate enforces that same flag. We first
    // reconcile the STORE side against RevenueCat (sync-entitlement pulls this
    // identity's store entitlement and folds it in) and use the effective flag it
    // returns; this also closes the "bought PRO but see nothing" race before any
    // RPC fetches catalog text. If that call can't run we read the flag straight
    // from the profile, so a promotional grant with no purchase behind it still
    // unlocks the app. Only with no backend at all do we fall back to the
    // on-device RevenueCat cache.
    final isPremium =
        await SupabaseService.syncEntitlement() ??
        await SupabaseService.fetchIsPremium() ??
        await PurchasesService.isPremium();

    // 4. Pull the display name (social logins only) and the account's creation
    // date for the profile header.
    final metadata = user?.userMetadata;
    final displayName =
        (metadata?['full_name'] ?? metadata?['name']) as String?;
    final createdAt = user != null ? DateTime.tryParse(user.createdAt) : null;

    // Tag every Sentry event with the (pseudonymous) identity + tier, so a crash
    // report says WHO hit it and whether they were premium — without ever sending
    // an email/name. Re-runs on each reload, so a sign-out/switch keeps it fresh.
    await Monitoring.setUser(
      id: userId,
      isPremium: isPremium,
      isAnonymous: user?.isAnonymous ?? false,
    );

    return SessionState(
      userId: userId,
      email: user?.email,
      displayName: displayName,
      createdAt: createdAt,
      isAnonymous: user?.isAnonymous ?? false,
      isPremium: isPremium,
    );
  }

  /// Re-reads the premium entitlement, e.g. immediately after a purchase so the
  /// swipe gate sees the upgrade.
  ///
  /// Deliberately does NOT flip to `AsyncValue.loading()` first. Doing so nulls
  /// out `value` mid-reload, so `userId` momentarily reads null and the
  /// QuestionScreen identity listener fires on the guest→null→guest flicker —
  /// wiping the revealed feed, snapping back to the daily and flashing a
  /// full-screen spinner. That's the "freeze" a guest sees after buying PRO from
  /// the reveal-slot paywall (a logged-in user buys from Settings, so the flicker
  /// hides under that pushed route). Keeping the previous SessionState visible
  /// while `_load` runs means only `isPremium` changes, exactly once.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

/// Convenience: `true` only once the session has resolved to a premium user.
/// Treats the still-loading / errored states as non-premium (free tier).
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider).value?.isPremium ?? false,
);

/// Details of the active premium subscription (renewal date, billing store,
/// management deep link) for the Manage-subscription screen. Re-fetched whenever
/// the premium entitlement flips, and only resolves to non-null while premium is
/// active; otherwise the SDK has nothing to report.
final premiumStatusProvider = FutureProvider.autoDispose<PremiumStatus?>((
  ref,
) async {
  if (!ref.watch(isPremiumProvider)) return null;
  return PurchasesService.premiumStatus();
});
