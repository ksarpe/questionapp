import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/locale/app_locale.dart';
import 'services/ads_service.dart';
import 'services/purchases_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise external SDKs before the UI starts. Each call no-ops gracefully
  // when its credentials are absent, so the app runs against mock data out of
  // the box (see AppConfig for the --dart-define keys).
  await SupabaseService.initialise();
  await PurchasesService.initialise();
  await AdsService.initialise();

  // Resolve persisted preferences before the first frame so the chosen language
  // (or the device-detected one) is available synchronously to MaterialApp and
  // the question repository — no loading flash, no wrong-language first paint.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const QuestionApp(),
    ),
  );
}
