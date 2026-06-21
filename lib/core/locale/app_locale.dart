import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The single source of truth for the app's language.
///
/// Before this provider existed the app had TWO disconnected notions of
/// "language": the UI chrome followed the device locale (via Flutter's
/// `supportedLocales` auto-pick) while the question content was hardwired to
/// `'pl'` in the repository. They could disagree and nothing let the user
/// choose. [localeControllerProvider] unifies both: it is read by `MaterialApp`
/// (so `Localizations.localeOf(context)` follows it) AND by
/// `questionRepositoryProvider` (so the Supabase `p_locale` follows it), and the
/// settings screen mutates it. Persisted locally, so the choice survives
/// restarts — and works for guests too (no account required).

/// The languages the app ships UI + content for.
///
/// `pl` first because the app is Polish-first; the order also drives Flutter's
/// own `supportedLocales` fallback (though we set `locale` explicitly, so our
/// own resolution in [_resolveDeviceLocale] is what actually decides the start
/// language).
const List<Locale> kSupportedLocales = [Locale('pl'), Locale('en')];

/// Where a non-Polish device lands by default — English is the international
/// fallback. Content exists in both `pl` and `en`, and the localized UI branches
/// fall back to English, so this is the safe default for "everyone else".
const Locale kFallbackLocale = Locale('en');

/// SharedPreferences key holding the user's explicit language override
/// (a language code like `pl`/`en`). Absent until the user picks one.
const String kLocalePrefKey = 'app_locale';

/// Holds the [SharedPreferences] instance, injected once at startup.
///
/// Overridden in `main()` after `SharedPreferences.getInstance()` resolves, so
/// every consumer (this controller, future preferences) reads the same handle
/// synchronously. Throwing here makes a missing override a loud, immediate bug
/// rather than a silent default.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with the resolved '
    'SharedPreferences instance.',
  ),
);

/// Picks the start language from the device when the user has never chosen one:
/// the device language if we support it, otherwise [kFallbackLocale] (English).
Locale _resolveDeviceLocale() {
  final deviceCode = PlatformDispatcher.instance.locale.languageCode;
  for (final locale in kSupportedLocales) {
    if (locale.languageCode == deviceCode) return locale;
  }
  return kFallbackLocale;
}

/// The active app language. Read it; mutate it with [LocaleController.setLocale].
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(kLocalePrefKey);
    if (saved != null) {
      for (final locale in kSupportedLocales) {
        if (locale.languageCode == saved) return locale;
      }
    }
    // No (valid) saved choice yet — detect from the device.
    return _resolveDeviceLocale();
  }

  /// Switches the app language and persists the choice.
  ///
  /// A no-op for an unsupported locale or the one already active, so callers can
  /// fire it without guarding. Updating [state] rebuilds every dependent
  /// provider — crucially `questionRepositoryProvider`, which re-fetches the
  /// questions/smaczki in the new language — and `MaterialApp` re-resolves the
  /// UI locale.
  Future<void> setLocale(Locale locale) async {
    if (!kSupportedLocales.contains(locale) || locale == state) return;
    state = locale;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kLocalePrefKey, locale.languageCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
