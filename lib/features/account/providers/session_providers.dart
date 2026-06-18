import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.isAnonymous,
    this.isPremium = false,
  });

  final String? userId;
  final String? email;
  final bool? isAnonymous;
  final bool isPremium;

  bool get isSignedIn => userId != null;
  bool get hasAccount => isSignedIn && isAnonymous != true;

  SessionState copyWith({
    String? userId,
    String? email,
    bool? isAnonymous,
    bool? isPremium,
  }) => SessionState(
    userId: userId ?? this.userId,
    email: email ?? this.email,
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
  Future<SessionState> build() => _load();

  Future<SessionState> _load() async {
    // 1. Make sure every user — even a brand-new guest — has a stable UUID.
    final userId = await SupabaseService.ensureSignedIn();
    final user = SupabaseService.currentUser;

    // 2. Tie the RevenueCat customer to that same identity.
    if (userId != null) {
      await PurchasesService.identify(userId);
    }

    // 3. Resolve the current premium entitlement.
    final isPremium = await PurchasesService.isPremium();

    return SessionState(
      userId: userId,
      email: user?.email,
      isAnonymous: user?.isAnonymous ?? false,
      isPremium: isPremium,
    );
  }

  /// Re-reads the premium entitlement, e.g. immediately after a purchase so the
  /// swipe gate sees the upgrade.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
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
