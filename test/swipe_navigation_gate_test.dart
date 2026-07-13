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

/// Navigation rules of the reveal feed ([WindQuestionView._advance]):
///   * PREMIUM walks the full catalog, wrapping around — never walled.
///   * a FREE user goes forward onto the reveal slot; with a credit it reveals,
///     and they can swipe back through what they've revealed this session.
///   * with no credit the slot is a wall: swiping forward again does nothing.
void main() {
  Question q(String id) => Question(
    id: id,
    category: id.toUpperCase(),
    questionText: 'Question $id?',
  );

  Future<ProviderContainer> pumpFeed(
    WidgetTester tester, {
    required Question daily,
    List<Question> pool = const [],
    required bool premium,
    int credits = 0,
    _RevealRepo? repo,
  }) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockSharedPreferences(),
        ),
        questionsProvider.overrideWith((ref) async => pool),
        todaysDailyQuestionProvider.overrideWith((ref) async => daily),
        isPremiumProvider.overrideWithValue(premium),
        freeUnlockCreditsProvider.overrideWithValue(credits),
        deckShuffleSeedProvider.overrideWithValue(1),
        if (repo != null) questionRepositoryProvider.overrideWithValue(repo),
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
    return container;
  }

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.fling(find.byType(WindQuestionView), Offset(dx, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> swipeLeft(WidgetTester tester) => swipe(tester, -300);
  Future<void> swipeRight(WidgetTester tester) => swipe(tester, 300);

  testWidgets('premium swipes forward through the catalog', (tester) async {
    final daily = q('daily');
    final container = await pumpFeed(
      tester,
      daily: daily,
      pool: [daily, q('a'), q('b')],
      premium: true,
    );

    await swipeLeft(tester);
    expect(container.read(questionIndexProvider), 1);
    await swipeLeft(tester);
    expect(container.read(questionIndexProvider), 2);
  });

  testWidgets('free user with no credit is walled on the reveal slot', (
    tester,
  ) async {
    final daily = q('daily');
    final repo = _RevealRepo();
    final container = await pumpFeed(
      tester,
      daily: daily,
      premium: false,
      credits: 0,
      repo: repo,
    );

    // One swipe off the daily lands on the slot...
    await swipeLeft(tester);
    expect(container.read(questionIndexProvider), 1);
    expect(container.read(isAtRevealSlotProvider), isTrue);

    // ...and swiping forward again does nothing (no credit → the paywall stands).
    await swipeLeft(tester);
    expect(container.read(questionIndexProvider), 1);
    expect(repo.freeReveals, 0);
  });

  testWidgets('free user can swipe back through the session feed', (
    tester,
  ) async {
    final daily = q('daily');
    final repo = _RevealRepo();
    final container = await pumpFeed(
      tester,
      daily: daily,
      premium: false,
      credits: 1,
      repo: repo,
    );

    // Credit reveals a question; the user lands on it at index 1.
    await swipeLeft(tester);
    expect(container.read(questionIndexProvider), 1);
    expect(container.read(revealedFeedProvider).length, 1);

    // Swiping right steps back to the daily (within-session back-navigation).
    await swipeRight(tester);
    expect(container.read(questionIndexProvider), 0);

    // The revealed question is still in the feed — going back didn't drop it.
    expect(container.read(revealedFeedProvider).length, 1);
  });
}

/// Mock repo that hands back a fresh question per reveal and counts reveals/peeks.
class _RevealRepo extends MockQuestionRepository {
  int freeReveals = 0;
  int adReveals = 0;
  int peeks = 0;
  int _n = 0;

  @override
  Future<({String id, String teaser})?> peekNextQuestion({
    List<String> excludeIds = const [],
  }) async {
    peeks++;
    return (id: 'peek$peeks', teaser: 'Czy coś');
  }

  @override
  Future<Question?> revealFreeQuestion({
    List<String> excludeIds = const [],
  }) async {
    freeReveals++;
    _n++;
    return Question(id: 'free$_n', category: 'C', questionText: 'Free $_n?');
  }

  @override
  Future<Question?> revealAdQuestion({
    String? questionId,
    List<String> excludeIds = const [],
  }) async {
    adReveals++;
    _n++;
    return Question(
      id: questionId ?? 'ad$_n',
      category: 'C',
      questionText: 'Ad $_n?',
    );
  }
}
