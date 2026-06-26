import 'package:debatly/data/models/question.dart';
import 'package:debatly/features/account/providers/session_providers.dart';
import 'package:debatly/features/questions/providers/question_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deck composition under the reveal-feed model:
///   * a FREE user's deck is the daily plus whatever they've revealed this
///     session (the locked catalog is never shipped to them);
///   * a PREMIUM user's deck is the daily plus the whole catalog, in a stable
///     seeded order that survives a refetch.
void main() {
  Question q(String id) => Question(
    id: id,
    category: id.toUpperCase(),
    questionText: 'Question $id?',
  );

  Future<ProviderContainer> deckContainer({
    required Question daily,
    required List<Question> pool,
    bool premium = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        questionsProvider.overrideWith((ref) async => pool),
        todaysDailyQuestionProvider.overrideWith((ref) async => daily),
        isPremiumProvider.overrideWithValue(premium),
        deckShuffleSeedProvider.overrideWithValue(1),
      ],
    );
    addTearDown(container.dispose);
    await container.read(questionsProvider.future);
    await container.read(todaysDailyQuestionProvider.future);
    return container;
  }

  test('free deck is the daily alone until questions are revealed', () async {
    final daily = q('daily');
    final container = await deckContainer(daily: daily, pool: [daily, q('x')]);

    // The locked catalog is NOT in a free user's deck — only the daily.
    expect(container.read(questionDeckProvider).map((e) => e.id).toList(), [
      'daily',
    ]);

    // Revealing appends to the session feed, growing the deck in order.
    container.read(revealedFeedProvider.notifier).append(q('r1'));
    container.read(revealedFeedProvider.notifier).append(q('r2'));
    expect(container.read(questionDeckProvider).map((e) => e.id).toList(), [
      'daily',
      'r1',
      'r2',
    ]);
  });

  test('premium deck is the daily plus the whole catalog', () async {
    final daily = q('daily');
    final pool = [daily, q('a'), q('b'), q('c')];

    final container = await deckContainer(
      daily: daily,
      pool: pool,
      premium: true,
    );
    final deck = container.read(questionDeckProvider);

    expect(deck, hasLength(4));
    expect(deck.first.id, 'daily');
    expect(deck.map((e) => e.id).toSet(), {'daily', 'a', 'b', 'c'});
  });

  test(
    'premium deck order is stable across a pool refetch (seeded shuffle)',
    () async {
      final daily = q('daily');
      final pool = [daily, for (var i = 0; i < 8; i++) q('q$i')];

      final container = await deckContainer(
        daily: daily,
        pool: pool,
        premium: true,
      );
      final firstOrder = container
          .read(questionDeckProvider)
          .map((e) => e.id)
          .toList();

      container.invalidate(questionsProvider);
      await container.read(questionsProvider.future);

      final secondOrder = container
          .read(questionDeckProvider)
          .map((e) => e.id)
          .toList();
      expect(secondOrder, firstOrder);
    },
  );

  test('premium deck puts UNSEEN questions before the seen archive', () async {
    final daily = q('daily');
    Question seen(String id) =>
        Question(id: id, category: id, questionText: 'Q $id?', seen: true);

    // Catalog mixes seen and unseen; the deck must front-load the unseen ones.
    final pool = [daily, seen('s1'), q('u1'), seen('s2'), q('u2'), q('u3')];

    final container = await deckContainer(
      daily: daily,
      pool: pool,
      premium: true,
    );
    final deck = container.read(questionDeckProvider).map((e) => e.id).toList();

    expect(deck.first, 'daily');
    // The three unseen questions come first (in some shuffled order), then the
    // two seen ones — never a seen question ahead of an unseen one.
    expect(deck.sublist(1, 4).toSet(), {'u1', 'u2', 'u3'});
    expect(deck.sublist(4).toSet(), {'s1', 's2'});
  });

  test('the current index survives a pool refetch (premium)', () async {
    final daily = q('daily');
    final pool = [daily, for (var i = 0; i < 8; i++) q('q$i')];

    final container = await deckContainer(
      daily: daily,
      pool: pool,
      premium: true,
    );

    final index = container.read(questionIndexProvider.notifier);
    index.next();
    index.next();
    expect(container.read(questionIndexProvider), 2);

    container.invalidate(questionsProvider);
    await container.read(questionsProvider.future);

    expect(container.read(questionIndexProvider), 2);
  });
}
