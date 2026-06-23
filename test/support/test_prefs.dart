import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [SharedPreferences] for tests that pump widgets reading persisted
/// flags (e.g. the swipe-discovered hint via [SwipeDiscoveredController]). Feed
/// it to `sharedPreferencesProvider.overrideWithValue(...)`; without that
/// override the provider throws, because `main()` — which injects the resolved
/// instance — never runs under the test harness.
Future<SharedPreferences> mockSharedPreferences([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}
