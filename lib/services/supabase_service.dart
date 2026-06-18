import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

/// Thin wrapper around the Supabase client lifecycle.
///
/// Initialised once from `main()` before `runApp`. If no credentials are
/// supplied (see [AppConfig]) initialisation is skipped so the app still runs
/// against mock data during early development.
class SupabaseService {
  SupabaseService._();

  static bool _initialised = false;
  static bool get isInitialised => _initialised;

  static Future<void> initialise() async {
    if (!AppConfig.hasSupabaseCredentials) {
      debugPrint(
        'SupabaseService: no credentials provided — skipping init. '
        'Pass --dart-define=SUPABASE_URL/SUPABASE_ANON_KEY to enable.',
      );
      return;
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Supabase renamed the anon key to "publishable key"; the env var keeps
      // the familiar SUPABASE_ANON_KEY name.
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _initialised = true;
  }

  /// Convenience accessor; throws if used before [initialise] succeeded.
  static SupabaseClient get client => Supabase.instance.client;

  // ---- Auth ------------------------------------------------------------------

  /// Ensures there is a signed-in user, creating an anonymous one on first
  /// launch. Returns the user's UUID, or `null` when Supabase is not configured
  /// (development / mock mode).
  ///
  /// Every user — even guests — gets a stable UUID so their progress can be
  /// tracked server-side without ever asking for an email or password.
  static Future<String?> ensureSignedIn() async {
    if (!_initialised) return null;

    final existing = client.auth.currentUser;
    if (existing != null) return existing.id;

    try {
      final response = await client.auth.signInAnonymously();
      return response.user?.id;
    } catch (e) {
      debugPrint('SupabaseService.ensureSignedIn failed: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    if (!_initialised) return;
    await client.auth.signOut();
  }

  static Future<void> sendEmailLink(String email) async {
    if (!_initialised) {
      throw StateError('Supabase is not configured.');
    }

    await client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: false,
    );
  }

  static Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!_initialised) {
      throw StateError('Supabase is not configured.');
    }

    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates a permanent email/password account.
  ///
  /// When the current user is anonymous we update that same Supabase user
  /// instead of creating a separate account, preserving any progress attached to
  /// their anonymous UUID.
  static Future<User?> registerWithPassword({
    required String email,
    required String password,
  }) async {
    if (!_initialised) {
      throw StateError('Supabase is not configured.');
    }

    final current = client.auth.currentUser;
    if (current?.isAnonymous == true) {
      final response = await client.auth.updateUser(
        UserAttributes(email: email.trim(), password: password),
      );
      return response.user;
    }

    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return response.user;
  }

  static User? get currentUser => _initialised ? client.auth.currentUser : null;

  static bool get currentUserHasAccount {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }
}
