import 'package:debatly/services/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The analytics facade must be bullet-proof plumbing: a stable pseudonymous
/// install id, and never an exception out of `log` — analytics may lose events,
/// but must never lose the user's flow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'init mints a well-formed v4 install id and keeps it across restarts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      Analytics.init(prefs);
      final minted = prefs.getString(kInstallIdPrefKey);
      expect(
        minted,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );

      // A relaunch re-reads the same id instead of minting a fresh one — the
      // funnel would fall apart if every session looked like a new install.
      Analytics.init(prefs);
      expect(prefs.getString(kInstallIdPrefKey), minted);
    },
  );

  test('log is a safe no-op when Supabase is not configured', () async {
    SharedPreferences.setMockInitialValues({});
    Analytics.init(await SharedPreferences.getInstance());

    expect(
      () => Analytics.log('onboarding_started', {'from': 'test'}),
      returnsNormally,
    );
  });
}
