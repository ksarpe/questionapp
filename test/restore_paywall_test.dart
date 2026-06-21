import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/data/models/question.dart';
import 'package:questionapp/data/repositories/question_repository.dart';
import 'package:questionapp/features/account/providers/session_providers.dart';
import 'package:questionapp/features/account/providers/stats_providers.dart';
import 'package:questionapp/features/account/screens/auth_screen.dart';
import 'package:questionapp/features/questions/providers/question_providers.dart';
import 'package:questionapp/features/questions/widgets/wind_question_view.dart';

import 'support/localized_test_app.dart';

/// The "Przywróć zakup" affordance on the reveal-slot paywall. It exists there
/// precisely because a guest can't reach Settings (the gear is account-only), so
/// the paywall is a guest's only restore path. Restore is a STORE operation, not
/// a login — tapping it must run the store-restore flow, never open the auth
/// sheet. RevenueCat is unconfigured in tests, so restorePurchases() reports "no
/// purchase found" without any network call.
void main() {
  Question q(String id) => Question(
        id: id,
        category: id.toUpperCase(),
        questionText: 'Question $id?',
      );

  Future<void> pumpGuestPaywall(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
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
              child: SizedBox(width: 300, height: 600, child: WindQuestionView()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Swipe a free user with no credit onto the reveal slot → the paywall.
    await tester.fling(find.byType(WindQuestionView), const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('a guest sees the restore affordance on the paywall',
      (tester) async {
    await pumpGuestPaywall(tester);

    // Sanity: we're on the paywall (the ad CTA is the anchor) ...
    expect(find.text('Odblokuj reklamą'.toUpperCase()), findsOneWidget);
    // ... and the store-restore path is offered right there.
    expect(find.text('Przywróć zakup'), findsOneWidget);
  });

  testWidgets('tapping restore runs the store flow, not a login', (tester) async {
    await pumpGuestPaywall(tester);

    await tester.tap(find.text('Przywróć zakup'));
    await tester.pump(); // start the async restore
    await tester.pump(); // resolve restorePurchases() (false, unconfigured)
    await tester.pump(const Duration(milliseconds: 750)); // animate the SnackBar

    // Store path ran and reported no purchase — no auth sheet was opened.
    expect(find.text('Nie znaleziono wcześniejszego zakupu.'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing,
        reason: 'restore must not be a login affordance');
  });
}

/// Minimal repo: a teaser to peek, no reveals expected on this path.
class _RevealRepo extends MockQuestionRepository {
  @override
  Future<({String id, String teaser})?> peekNextQuestion() async =>
      (id: 'peek', teaser: 'Czy coś');
}
