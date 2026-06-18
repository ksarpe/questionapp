/// Centralised configuration / secrets.
///
/// Values are read from `--dart-define` at build time so keys never get
/// committed. Run with, e.g.:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=... \
///   --dart-define=REVENUECAT_API_KEY=... \
///   --dart-define=ADMOB_BANNER_ID=...
/// ```
class AppConfig {
  AppConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Google "Web" OAuth client id. Passed as serverClientId for native Google
  /// sign-in so Google returns an ID token Supabase can verify.
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  static const String revenueCatApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');

  /// Google's public test banner unit id is used as a safe default so the app
  /// shows test ads until real ids are supplied.
  static const String admobBannerId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  /// Rewarded ad unit shown by the "Unlock next question" sheet.
  ///
  /// Defaults to Google's public Android *test* rewarded unit so real ads only
  /// appear once a real id is supplied. The iOS test unit is
  /// `ca-app-pub-3940256099942544/1712485313` — pass it via ADMOB_REWARDED_ID
  /// for iOS builds, and use your real ids before release.
  static const String admobRewardedId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasGoogleSignIn => googleServerClientId.isNotEmpty;
}
