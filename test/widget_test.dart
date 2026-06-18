import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:questionapp/app.dart';
import 'package:questionapp/features/account/screens/account_screen.dart';
import 'package:questionapp/features/account/screens/auth_screen.dart';
import 'package:questionapp/features/questions/widgets/go_deeper_button.dart';

void main() {
  testWidgets('App renders the first question', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuestionApp()));

    // Initial frame shows the loading spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the mock repository's simulated delay resolve.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // The settings gear and "go deeper" action should be present.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text(GoDeeperButton.label), findsOneWidget);
  });

  testWidgets('Auth screen renders when Supabase is not configured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Twoje konto'), findsOneWidget);
    expect(
      find.text(
        'Brakuje konfiguracji Supabase. Uruchom aplikację z SUPABASE_URL i SUPABASE_ANON_KEY.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Zaloguj się'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Kontynuuj z Google'),
      findsOneWidget,
    );
  });

  testWidgets('Account screen renders account and subscription settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AccountScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ustawienia konta'), findsOneWidget);
    expect(find.text('Dane konta'), findsOneWidget);
    expect(find.text('Subskrypcja'), findsOneWidget);
    expect(find.text('Wyloguj się'), findsOneWidget);
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
