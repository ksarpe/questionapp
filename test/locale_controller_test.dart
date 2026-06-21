import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:questionapp/core/locale/app_locale.dart';

/// The language is the one source of truth feeding both the UI chrome and the
/// content `p_locale`, persisted so a guest's choice survives a restart. These
/// pin the resolution order — saved choice > supported device language >
/// English fallback — and the `setLocale` no-op guards, so a bad saved value or
/// an unsupported pick can never strand the app on a locale it can't render.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a valid saved choice wins over the device locale', () async {
    final c = await containerWith({kLocalePrefKey: 'en'});
    expect(c.read(localeControllerProvider), const Locale('en'));
  });

  test('with no saved choice it resolves to a supported locale (never junk)',
      () async {
    final c = await containerWith({});
    // The test host's device language is unspecified, so we only assert the
    // contract: the resolved locale is always one the app actually ships.
    expect(kSupportedLocales, contains(c.read(localeControllerProvider)));
  });

  test('an invalid saved code is ignored in favour of the device fallback',
      () async {
    final c = await containerWith({kLocalePrefKey: 'zz'});
    expect(kSupportedLocales, contains(c.read(localeControllerProvider)));
  });

  test('setLocale updates state and persists the choice', () async {
    final c = await containerWith({});
    await c
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));

    expect(c.read(localeControllerProvider), const Locale('en'));
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString(kLocalePrefKey), 'en',
        reason: 'the choice must survive a restart');
  });

  test('setLocale ignores an unsupported locale (stays put)', () async {
    final c = await containerWith({kLocalePrefKey: 'pl'});
    await c
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('de'));
    expect(c.read(localeControllerProvider), const Locale('pl'));
  });
}
