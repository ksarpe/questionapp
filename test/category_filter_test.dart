import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/data/models/question.dart';
import 'package:questionapp/features/account/providers/session_providers.dart';
import 'package:questionapp/features/questions/providers/question_providers.dart';
import 'package:questionapp/features/questions/widgets/category_filter_button.dart';

import 'support/localized_test_app.dart';

/// The premium category filter (bottom-sheet picker):
///   * picking a category narrows the deck and lands on its first question;
///   * picking "All" clears the filter and returns to the daily;
///   * the displayed current question actually changes (the bug report).
void main() {
  Question cat(String id, String category) =>
      Question(id: id, category: category, questionText: 'Q $id?');

  Future<ProviderContainer> pumpButton(WidgetTester tester) async {
    final daily = cat('daily', 'Society');
    final pool = [
      daily,
      cat('e1', 'Ethics'),
      cat('e2', 'Ethics'),
      cat('m1', 'Money'),
    ];

    final container = ProviderContainer(
      overrides: [
        questionsProvider.overrideWith((ref) async => pool),
        todaysDailyQuestionProvider.overrideWith((ref) async => daily),
        isPremiumProvider.overrideWithValue(true),
        deckShuffleSeedProvider.overrideWithValue(1),
      ],
    );
    addTearDown(container.dispose);
    await container.read(questionsProvider.future);
    await container.read(todaysDailyQuestionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedTestApp(
          home: Scaffold(body: Center(child: CategoryFilterButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('picking a category narrows the deck and changes the current '
      'question', (tester) async {
    final container = await pumpButton(tester);

    // Starts unfiltered, on the daily.
    expect(container.read(selectedCategoryProvider), isNull);
    expect(container.read(currentQuestionProvider)?.id, 'daily');

    // Open the sheet and pick "Etyka" (Ethics, localized in the test's PL locale).
    await tester.tap(find.byType(CategoryFilterButton));
    await tester.pumpAndSettle();
    expect(find.text('Etyka'), findsOneWidget);
    await tester.tap(find.text('Etyka'));
    await tester.pumpAndSettle();

    // Filter applied; the deck is the daily + the two Ethics questions, and the
    // current question is now an Ethics one (not the daily) — the bug fix.
    expect(container.read(selectedCategoryProvider), 'Ethics');
    expect(container.read(questionIndexProvider), 1);
    final current = container.read(currentQuestionProvider);
    expect(current?.category, 'Ethics');
    expect(current?.id, isNot('daily'));
    final deck = container.read(questionDeckProvider).map((e) => e.id).toList();
    expect(deck.first, 'daily'); // daily exempt, always index 0
    expect(deck.sublist(1).toSet(), {'e1', 'e2'}); // only the Ethics questions
    expect(deck, hasLength(3));
  });

  testWidgets('the "All" chip clears the filter and returns to the daily',
      (tester) async {
    final container = await pumpButton(tester);

    // Apply a filter first.
    container.read(selectedCategoryProvider.notifier).select('Ethics');
    container.read(questionIndexProvider.notifier).jumpTo(1);
    await tester.pump();

    // Open the sheet and tap "Wszystkie" (All) — this is the case the old
    // PopupMenu silently dropped (null value never fired onSelected).
    await tester.tap(find.byType(CategoryFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wszystkie'));
    await tester.pumpAndSettle();

    expect(container.read(selectedCategoryProvider), isNull);
    expect(container.read(questionIndexProvider), 0);
    expect(container.read(currentQuestionProvider)?.id, 'daily');
  });
}
