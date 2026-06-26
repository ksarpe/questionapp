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

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Google "Web" OAuth client id. Passed as serverClientId for native Google
  /// sign-in so Google returns an ID token Supabase can verify.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

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

  /// Comma-separated AdMob **test-device** ids. When set, AdMob serves *test*
  /// ads to these devices even on the real ad unit id — so you can exercise the
  /// real rewarded unit (and its SSV callback) during development WITHOUT
  /// generating invalid traffic on live ads, which risks an AdMob ban.
  ///
  /// Grab the id from the device log the first time an ad loads, e.g.:
  /// `Use RequestConfiguration.Builder.setTestDeviceIds(["33BE2250…"])`.
  /// Leave empty for store builds. Wired in [AdsService.initialise].
  static const String _admobTestDeviceIdsRaw = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS',
    defaultValue: '',
  );

  static List<String> get admobTestDeviceIds => _admobTestDeviceIdsRaw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Public URL of the privacy policy, opened from the Privacy & data screen.
  /// Defaults to the live page on the marketing site (a public, non-secret URL,
  /// so it's baked in to guarantee the legal link works in every build); still
  /// overridable via `--dart-define=PRIVACY_POLICY_URL=...`.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://debatly.app/privacy',
  );

  /// Public URL of the terms of service, opened from the Privacy & data screen.
  /// See [privacyPolicyUrl] for the baked-in/overridable rationale.
  static const String termsOfServiceUrl = String.fromEnvironment(
    'TERMS_OF_SERVICE_URL',
    defaultValue: 'https://debatly.app/terms',
  );

  /// Public URL where users can request account + data deletion from the web,
  /// without the app. Required by the Google Play Data safety form (the in-app
  /// deletion in Settings covers the on-device path). Surfaced on the Privacy &
  /// data screen as a fallback to the in-app flow.
  static const String deleteAccountUrl = String.fromEnvironment(
    'DELETE_ACCOUNT_URL',
    defaultValue: 'https://debatly.app/delete-account',
  );

  /// Sentry DSN (the project's ingest URL, found in Sentry under
  /// `Settings → Projects → your project → Client Keys (DSN)`). When empty, Sentry is
  /// initialised in a disabled state so the app still runs against mock data with
  /// no error reporting — see [Monitoring]. Not a secret in the password sense
  /// (it only allows sending events), but kept out of git like the other keys.
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Logical deployment name shown on every Sentry event, so you can filter
  /// dev/staging noise away from real user crashes. Defaults are resolved in
  /// [Monitoring] from the build mode when this is left blank.
  static const String sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: '',
  );

  /// Fraction of transactions sampled for performance tracing (0.0–1.0). The
  /// Developer plan has a monthly performance-unit budget, so we sample rather
  /// than trace every navigation. Passed as a string so it fits the dart-define
  /// model; falls back to a conservative 20%.
  static const String _sentryTracesSampleRateRaw = String.fromEnvironment(
    'SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0.2',
  );

  static double get sentryTracesSampleRate =>
      double.tryParse(_sentryTracesSampleRateRaw)?.clamp(0.0, 1.0) ?? 0.2;

  static bool get hasSentry => sentryDsn.isNotEmpty;

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasGoogleSignIn => googleServerClientId.isNotEmpty;

  static bool get hasPrivacyPolicy => privacyPolicyUrl.isNotEmpty;

  static bool get hasTermsOfService => termsOfServiceUrl.isNotEmpty;

  static bool get hasDeleteAccountUrl => deleteAccountUrl.isNotEmpty;
}
