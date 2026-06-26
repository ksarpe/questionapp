import 'package:debatly/core/locale/app_locale.dart';
import 'package:debatly/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// A [MaterialApp] pre-wired with the app's localization delegates and pinned to
/// a fixed [locale] (Polish by default).
///
/// Widgets read their copy through `context.l10n` (`AppLocalizations.of`), which
/// asserts the delegate is present — so any test that pumps such a widget must
/// register [AppLocalizations.delegate]. Pinning the locale also makes string
/// assertions deterministic regardless of the host machine's device language
/// (otherwise the UI would render in whatever locale the test runner reports).
class LocalizedTestApp extends StatelessWidget {
  const LocalizedTestApp({
    super.key,
    required this.home,
    this.locale = const Locale('pl'),
  });

  final Widget home;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: kSupportedLocales,
      home: home,
    );
  }
}
