import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale/app_locale.dart';

/// The single source of truth for the app's appearance (light / dark / follow
/// the system).
///
/// Mirrors [localeControllerProvider]: read by `MaterialApp` (drives
/// `themeMode`), mutated by the settings screen, and persisted locally so the
/// choice survives restarts and works for guests too (no account required).
/// Defaults to [ThemeMode.system], so a first-run user matches their device's
/// light/dark setting — the accessibility-correct default.

/// SharedPreferences key holding the user's explicit appearance override
/// (`system` / `light` / `dark`). Absent until the user picks one, in which
/// case we follow the system.
const String kThemeModePrefKey = 'app_theme_mode';

/// Serialises a [ThemeMode] to the short token stored in SharedPreferences.
String _themeModeToKey(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'system',
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
};

/// Parses a stored token back to a [ThemeMode], defaulting to following the
/// system for anything unrecognised (or absent).
ThemeMode _themeModeFromKey(String? key) => switch (key) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// The active appearance. Read it; mutate it with [ThemeController.setMode].
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _themeModeFromKey(prefs.getString(kThemeModePrefKey));
  }

  /// Switches the appearance and persists the choice. A no-op when [mode] is
  /// already active, so callers can fire it without guarding. Updating [state]
  /// rebuilds `MaterialApp`, which re-resolves `themeMode`.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kThemeModePrefKey, _themeModeToKey(mode));
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
