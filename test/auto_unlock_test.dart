import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/data/models/question.dart';
import 'package:questionapp/data/repositories/question_repository.dart';
import 'package:questionapp/features/account/providers/session_providers.dart';
import 'package:questionapp/features/account/providers/stats_providers.dart';
import 'package:questionapp/features/questions/providers/question_providers.dart';
import 'package:questionapp/features/questions/widgets/wind_question_view.dart';

/// Reveal-feed credit behaviour: a free user swiping forward off the daily lands
/// on the "reveal slot". With a daily credit it auto-reveals the next question
/// (no button); with no credit it lands on the paywall instead. The rule lives
/// in [WindQuestionView._advance].
void main() {
  Question q(String id) => Question(
        id: id,
        category: id.toUpperCase(),
        questionText: 'Question $id?',
      );

  Future<ProviderContainer> pumpFeed(
    WidgetTester tester, {
    required Question daily,
    required int credits,
    required _RevealRepo repo,
  }) async {
    final container = ProviderContainer(
      overrides: [
        todaysDailyQuestionProvider.overrideWith((ref) async => daily),
        isPremiumProvider.overrideWithValue(false),
        freeUnlockCreditsProvider.overrideWithValue(credits),
        questionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 300, height: 600, child: WindQuestionView()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // Drives the wind transition + the reveal microtask, then drains the
  // falling-words animation that plays once a revealed question lands.
  Future<void> swipeLeft(WidgetTester tester) async {
    await tester.fling(find.byType(WindQuestionView), const Offset(-300, 0), 1000);
    await tester.pump(); // dispatch the fling, start the OUT animation
    await tester.pump(const Duration(milliseconds: 260)); // finish the animation
    await tester.pump(const Duration(milliseconds: 120)); // fire the 80ms beat
    await tester.pump(); // forwardLinear + reveal microtask
    await tester.pump(); // append + setState
    await tester.pumpAndSettle(); // drain the falling-words / paywall frame
  }

  testWidgets('a credit auto-reveals the next question on swipe', (tester) async {
    final daily = q('daily');
    final repo = _RevealRepo();
    final container = await pumpFeed(tester, daily: daily, credits: 1, repo: repo);

    expect(container.read(questionIndexProvider), 0); // on the daily

    await swipeLeft(tester);

    // The credit was spent (free reveal) and the feed now carries the revealed
    // question, which the user has landed on at index 1.
    expect(repo.freeReveals, 1);
    expect(repo.adReveals, 0);
    expect(container.read(revealedFeedProvider).length, 1);
    expect(container.read(questionIndexProvider), 1);
    expect(container.read(isAtRevealSlotProvider), isFalse);
  });

  testWidgets('with no credit the swipe lands on the paywall, no reveal',
      (tester) async {
    final daily = q('daily');
    final repo = _RevealRepo();
    final container = await pumpFeed(tester, daily: daily, credits: 0, repo: repo);

    await swipeLeft(tester);

    // No credit: nothing is revealed and the user sits on the reveal slot, where
    // the ad / PRO paywall is shown — with the next question peeked for its teaser.
    expect(repo.freeReveals, 0);
    expect(repo.adReveals, 0);
    expect(repo.peeks, greaterThanOrEqualTo(1));
    expect(container.read(revealedFeedProvider), isEmpty);
    expect(container.read(isAtRevealSlotProvider), isTrue);
    expect(find.text('Odblokuj reklamą'.toUpperCase()), findsOneWidget);
  });
}

/// Mock repo that records reveals (credit vs ad) and peeks, handing back a fresh
/// question each time.
class _RevealRepo extends MockQuestionRepository {
  int freeReveals = 0;
  int adReveals = 0;
  int peeks = 0;
  int _n = 0;

  @override
  Future<({String id, String teaser})?> peekNextQuestion() async {
    peeks++;
    return (id: 'peek$peeks', teaser: 'Czy coś');
  }

  @override
  Future<Question?> revealFreeQuestion() async {
    freeReveals++;
    _n++;
    return Question(id: 'free$_n', category: 'C', questionText: 'Free $_n?');
  }

  @override
  Future<Question?> revealAdQuestion({String? questionId}) async {
    adReveals++;
    _n++;
    return Question(
      id: questionId ?? 'ad$_n',
      category: 'C',
      questionText: 'Ad $_n?',
    );
  }
}
