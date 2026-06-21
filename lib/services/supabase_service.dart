import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Signs in with Google via the native account picker, then exchanges the
  /// Google ID token for a Supabase session. Returns null if the user cancels.
  ///
  /// First sign-in creates the account, so this covers both login and
  /// registration.
  static Future<User?> signInWithGoogle() async {
    if (!_initialised) {
      throw StateError('Supabase is not configured.');
    }
    if (AppConfig.googleServerClientId.isEmpty) {
      throw StateError(
        'Missing GOOGLE_SERVER_CLIENT_ID (the Google "Web" OAuth client id).',
      );
    }

    final googleSignIn = GoogleSignIn(
      serverClientId: AppConfig.googleServerClientId,
    );
    final account = await googleSignIn.signIn();
    if (account == null) return null; // user cancelled

    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;
    if (accessToken == null) {
      throw const AuthException('Google did not return an access token.');
    }
    if (idToken == null) {
      throw const AuthException('Google did not return an ID token.');
    }

    final response = await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return response.user;
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

  /// Reconciles the backend's premium flag with RevenueCat's REST truth for the
  /// current identity, returning the authoritative `is_premium` (or null when it
  /// couldn't run — no backend, no session, or the function isn't configured).
  ///
  /// This is the PULL counterpart to the inbound `revenue-cat-webhook`: the app
  /// calls it right after a purchase/restore and on launch so the server-side
  /// gate (`profiles.is_premium`, read by every question/smaczki RPC) matches
  /// what the device already knows, without waiting on — or depending on — the
  /// async webhook ever landing. Best-effort: a failure leaves the flag as-is.
  static Future<bool?> syncEntitlement() async {
    if (!_initialised || client.auth.currentUser == null) return null;
    try {
      final res = await client.functions.invoke('sync-entitlement');
      final data = res.data;
      if (data is Map && data['is_premium'] is bool) {
        return data['is_premium'] as bool;
      }
      return null;
    } catch (e) {
      debugPrint('SupabaseService.syncEntitlement failed: $e');
      return null;
    }
  }

  static User? get currentUser => _initialised ? client.auth.currentUser : null;

  static bool get currentUserHasAccount {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }
}
