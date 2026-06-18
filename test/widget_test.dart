import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:questionapp/app.dart';
import 'package:questionapp/features/account/screens/auth_screen.dart';

void main() {
  testWidgets('App renders the first question', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuestionApp()));

    // Initial frame shows the loading spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the mock repository's simulated delay resolve.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // The settings gear and drawer handle should be present.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.back_hand), findsOneWidget);
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
    expect(find.widgetWithText(FilledButton, 'Wyślij link'), findsOneWidget);
  });
}
