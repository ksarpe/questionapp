import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/app_locale.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/app_entry.dart';
import 'l10n/gen/app_localizations.dart';

/// Root widget. Riverpod's `ProviderScope` is mounted in `main()`.
class QuestionApp extends ConsumerWidget {
  const QuestionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The chosen app language drives the whole UI: setting `locale` explicitly
    // makes `Localizations.localeOf(context)` return it, so every widget that
    // branches on the locale follows the same source of truth as the question
    // content (see `questionRepositoryProvider`). Changing it rebuilds the app
    // into the new language.
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp(
      title: 'Spark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: kSupportedLocales,
      // The launch flow: brand splash → first-run tutorial → the live daily.
      // After onboarding has run once, this drops straight through to the
      // question screen (see AppEntry).
      home: const AppEntry(),
    );
  }
}
