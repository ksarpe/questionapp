import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/features/onboarding/screens/onboarding_screen.dart';

import 'support/localized_test_app.dart';

/// The onboarding "aha": the last intro page is a real question the user votes
/// on, and the tap flips straight to a community split with a personal
/// majority/minority line — proving the app instead of promising it. Then
/// "Continue" carries them to the account choice.
///
/// The welcome card animates a perpetual glow, so `pumpAndSettle` never returns —
/// every step uses explicit `pump`s past the page/switcher transitions instead
/// (the same pattern as widget_test's onboarding flow).
void main() {
  // The page transition is 320ms; pump comfortably past it.
  Future<void> settlePage(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: OnboardingScreen(onFinish: () {}),
      ),
    );
    await settlePage(tester);
  }

  // Walks welcome → daily → the taste-vote page via the bottom "Next" CTA.
  Future<void> reachVotePage(WidgetTester tester) async {
    await tester.tap(find.text('Dalej')); // welcome → daily
    await settlePage(tester);
    await tester.tap(find.text('Dalej')); // daily → taste vote
    await settlePage(tester);
  }

  testWidgets('voting TAK reveals the split, the majority line and Continue',
      (tester) async {
    await pumpOnboarding(tester);
    await reachVotePage(tester);

    // The taste page: kicker + the TAK/NIE buttons, and crucially NO split yet.
    expect(find.text('TWÓJ RUCH'), findsOneWidget);
    expect(find.text('TAK'), findsOneWidget);
    expect(find.text('NIE'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    await tester.tap(find.text('TAK'));
    await settlePage(tester); // AnimatedSwitcher to the results

    // The aha: a believable split appears with the "VS" seam, and — TAK being the
    // majority side — the personal "you're with the majority" line.
    expect(find.text('63%'), findsOneWidget);
    expect(find.text('37%'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Jesteś z większością. 🙌'), findsOneWidget);
  });

  testWidgets('voting NIE lands the user in the minority', (tester) async {
    await pumpOnboarding(tester);
    await reachVotePage(tester);

    await tester.tap(find.text('NIE'));
    await settlePage(tester);

    expect(find.text('Jesteś w mniejszości. 👀'), findsOneWidget);
  });

  testWidgets('Continue after voting advances to the notifications ask, then '
      'the account choice', (tester) async {
    await pumpOnboarding(tester);
    await reachVotePage(tester);

    await tester.tap(find.text('TAK'));
    await settlePage(tester);

    // The card's own "Continue" (the bottom Next is suppressed on this page)
    // lands on the reminder opt-in, not yet the account choice.
    await tester.tap(find.text('Dalej'));
    await settlePage(tester);

    expect(find.text('Nie przegap pytania dnia'), findsOneWidget);
    expect(find.text('Włącz przypomnienia'), findsOneWidget);
    expect(find.text('Zacznij anonimowo'), findsNothing);

    // "Not now" carries the user on to the account choice without enabling.
    await tester.tap(find.text('Nie teraz'));
    await settlePage(tester);

    expect(find.text('Zacznij anonimowo'), findsOneWidget);
    expect(find.text('Zaloguj / Załóż konto'), findsOneWidget);
  });

  testWidgets('the reminder ask never traps the user — "Enable" advances even '
      'when the notification plugin is unavailable', (tester) async {
    // The native plugin no-ops in the test host, so the permission request
    // resolves false; the card must still carry the user to the account choice
    // rather than stalling on its busy spinner.
    await pumpOnboarding(tester);
    await reachVotePage(tester);

    await tester.tap(find.text('TAK'));
    await settlePage(tester);
    await tester.tap(find.text('Dalej')); // taste vote → reminder ask
    await settlePage(tester);

    await tester.tap(find.text('Włącz przypomnienia'));
    await settlePage(tester);

    expect(find.text('Zacznij anonimowo'), findsOneWidget);
  });
}
