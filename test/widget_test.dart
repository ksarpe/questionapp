import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:questionapp/app.dart';
import 'package:questionapp/features/account/screens/auth_screen.dart';
import 'package:questionapp/features/questions/widgets/go_deeper_button.dart';
import 'package:questionapp/features/settings/screens/settings_screen.dart';

void main() {
  testWidgets('App renders the first question', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuestionApp()));

    // Initial frame shows the loading spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the mock repository's simulated delay resolve.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Mock mode resolves to a guest: the quiet "Zaloguj" button replaces the
    // person/settings icon, and the streak chip is hidden. The "go deeper"
    // action is still present.
    expect(find.text('Zaloguj'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    expect(find.text(GoDeeperButton.label), findsOneWidget);
  });

  testWidgets('Auth screen renders when Supabase is not configured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Brakuje konfiguracji Supabase. Uruchom aplikację z SUPABASE_URL i SUPABASE_ANON_KEY.',
      ),
      findsOneWidget,
    );
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
  });

  testWidgets('Settings screen renders the profile hub', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('USTAWIENIA APLIKACJI'), findsOneWidget);
    expect(find.text('KONTO'), findsOneWidget);
    expect(find.text('Przypomnienia'), findsOneWidget);
    // Mock mode resolves to a guest, free session.
    expect(find.text('Sesja gościa'), findsOneWidget);
    expect(find.text('Przejdź na Premium'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
  });

  testWidgets('GoDeeperButton uses the requested label and tappable glow', (
    WidgetTester tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: GoDeeperButton(onTap: () => taps++)),
        ),
      ),
    );

    expect(find.text(GoDeeperButton.label), findsOneWidget);

    final buttonTopLeft = tester.getTopLeft(find.byType(GoDeeperButton));
    await tester.tapAt(buttonTopLeft + const Offset(2, 2));

    expect(taps, 1);
  });
}
