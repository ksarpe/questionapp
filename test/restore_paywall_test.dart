import 'package:debatly/core/locale/app_locale.dart';
import 'package:debatly/data/models/question.dart';
import 'package:debatly/data/repositories/question_repository.dart';
import 'package:debatly/features/account/providers/session_providers.dart';
import 'package:debatly/features/account/providers/stats_providers.dart';
import 'package:debatly/features/questions/providers/question_providers.dart';
import 'package:debatly/features/questions/widgets/wind_question_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_test_app.dart';
import 'support/test_prefs.dart';

/// The "Przywróć zakup" affordance on the reveal-slot paywall. It exists there
/// precisely because a guest can't reach Settings (the gear is account-only), so
/// the paywall is a guest's only restore path. For a guest the tap first opens a
/// chooser (confirmGuestRestore): a store restore would TRANSFER the receipt onto
/// this fresh anonymous identity, so someone who bought PRO on a real account is
/// steered to sign back in instead — while "restore on this device" keeps the
/// store path available (Apple requires it). RevenueCat is unconfigured in
/// tests, so restorePurchases() reports "no purchase found" without any network
/// call.
void main() {
  Question q(String id) => Question(
    id: id,
    category: id.toUpperCase(),
    questionText: 'Question $id?',
  );

  Future<void> pumpGuestPaywall(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockSharedPreferences(),
        ),
        questionsProvider.overrideWith((ref) async => const <Question>[]),
        todaysDailyQuestionProvider.overrideWith((ref) async => q('daily')),
        isPremiumProvider.overrideWithValue(false),
        freeUnlockCreditsProvider.overrideWithValue(0),
        deckShuffleSeedProvider.overrideWithValue(1),
        questionRepositoryProvider.overrideWithValue(_RevealRepo()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedTestApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 600,
                child: WindQuestionView(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Swipe a free user with no credit onto the reveal slot → the paywall.
    await tester.fling(
      find.byType(WindQuestionView),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('a guest sees the restore affordance on the paywall', (
    tester,
  ) async {
    await pumpGuestPaywall(tester);

    // Sanity: we're on the paywall (the ad CTA is the anchor) ...
    expect(find.text('Odblokuj reklamą'.toUpperCase()), findsOneWidget);
    // ... and the store-restore path is offered right there.
    expect(find.text('Przywróć zakup'), findsOneWidget);
  });

  testWidgets('a guest tapping restore gets the sign-in-or-restore chooser', (
    tester,
  ) async {
    await pumpGuestPaywall(tester);

    await tester.tap(find.text('Przywróć zakup'));
    await tester.pumpAndSettle();

    // The chooser is up, offering both paths; nothing has run yet.
    expect(find.text('Przywrócić zakup?'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Przywróć na tym urządzeniu'), findsOneWidget);
  });

  testWidgets('choosing "restore on this device" runs the store flow', (
    tester,
  ) async {
    await pumpGuestPaywall(tester);

    await tester.tap(find.text('Przywróć zakup'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Przywróć na tym urządzeniu'));
    await tester.pump(); // pop the dialog + start the async restore
    await tester.pump(); // resolve restorePurchases() (false, unconfigured)
    await tester.pump(const Duration(milliseconds: 750)); // animate the toast

    // Store path ran and reported no purchase — no auth sheet was opened
    // (the sheet's social button is its telltale; tests report as Android).
    expect(find.text('Nie znaleziono wcześniejszego zakupu.'), findsOneWidget);
    expect(
      find.text('Kontynuuj z Google'),
      findsNothing,
      reason: 'the explicit store path must not become a login',
    );
  });

  testWidgets('choosing "sign in" opens the auth sheet, not the store flow', (
    tester,
  ) async {
    await pumpGuestPaywall(tester);

    await tester.tap(find.text('Przywróć zakup'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zaloguj się'));
    await tester.pumpAndSettle();

    // The auth sheet is up (its social button is the telltale) and the store
    // flow never ran.
    expect(find.text('Kontynuuj z Google'), findsOneWidget);
    expect(
      find.text('Nie znaleziono wcześniejszego zakupu.'),
      findsNothing,
      reason: 'no store restore may run when the user chose to sign in',
    );
  });
}

/// Minimal repo: a teaser to peek, no reveals expected on this path.
class _RevealRepo extends MockQuestionRepository {
  @override
  Future<({String id, String teaser})?> peekNextQuestion({
    List<String> excludeIds = const [],
  }) async => (id: 'peek', teaser: 'Czy coś');
}
