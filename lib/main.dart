import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
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

  runApp(const ProviderScope(child: QuestionApp()));
}
