import 'dart:io';

import 'package:debatly/data/models/daily_history_entry.dart';
import 'package:debatly/data/models/question.dart';
import 'package:debatly/data/models/rank.dart';
import 'package:debatly/data/models/smaczek.dart';
import 'package:debatly/data/models/user_stats.dart';
import 'package:debatly/data/models/vote_result.dart';
import 'package:debatly/data/repositories/caching_question_repository.dart';
import 'package:debatly/data/repositories/question_repository.dart';
import 'package:debatly/services/question_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The caching decorator must:
///   * refresh the cache on a successful fetch and serve it on a transport error;
///   * rethrow a genuine server error rather than masking it with stale cache;
///   * never serve a premium-text cache to a now-free identity (and wipe it).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo inner;
  late QuestionCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = QuestionCache(await SharedPreferences.getInstance());
    inner = _FakeRepo();
  });

  CachingQuestionRepository repo({bool premium = false}) =>
      CachingQuestionRepository(
        inner: inner,
        cache: cache,
        locale: 'pl',
        isPremium: premium,
      );

  Question q(String id) =>
      Question(id: id, category: id, questionText: 'Q $id?');

  test('serves the cached catalog when the network drops', () async {
    inner.catalog = [q('a'), q('b')];
    final r = repo(premium: true);

    // First call succeeds and warms the cache.
    expect((await r.fetchQuestions()).map((e) => e.id), ['a', 'b']);

    // Now the network is gone — the same data comes back from cache.
    inner.error = const SocketException('offline');
    expect((await r.fetchQuestions()).map((e) => e.id), ['a', 'b']);
  });

  test(
    'rethrows a genuine server error instead of masking it with cache',
    () async {
      inner.catalog = [q('a')];
      final r = repo(premium: true);
      await r.fetchQuestions(); // warm cache

      // A non-transport error must propagate even though a cache exists.
      inner.error = StateError('boom');
      expect(r.fetchQuestions(), throwsA(isA<StateError>()));
    },
  );

  test('rethrows offline when there is no cache to fall back on', () async {
    inner.error = const SocketException('offline');
    expect(
      repo(premium: true).fetchQuestions(),
      throwsA(isA<SocketException>()),
    );
  });

  test(
    'refuses to serve a premium cache to a now-free identity, and wipes it',
    () async {
      // A premium session caches the full catalog.
      inner.catalog = [q('a'), q('b')];
      await repo(premium: true).fetchQuestions();
      expect(cache.cachedAsPremium, isTrue);

      // The user lapses to free and goes offline. The premium-text cache must NOT
      // be served, and it should be wiped on the attempt.
      inner.error = const SocketException('offline');
      final free = repo(premium: false);
      await expectLater(free.fetchQuestions(), throwsA(isA<SocketException>()));
      expect(cache.readCatalog('pl'), isNull);
    },
  );

  test(
    'daily falls back to the latest cached daily on a fresh-day outage',
    () async {
      inner.daily = q('d-mon');
      final r = repo();
      await r.fetchDailyQuestion(DateTime(2026, 6, 23)); // cache Monday's daily

      // Next day, offline: the exact date misses but we still surface Monday's.
      inner.error = const SocketException('offline');
      final result = await r.fetchDailyQuestion(DateTime(2026, 6, 24));
      expect(result?.id, 'd-mon');
    },
  );

  test(
    'ranks fall back to the compiled-in default when offline with no cache',
    () async {
      inner.error = const SocketException('offline');
      final ranks = await repo().fetchRanks();
      expect(ranks, hasLength(kDefaultRanks.length));
    },
  );

  test('favorite ids degrade to an empty set offline', () async {
    inner.error = const SocketException('offline');
    expect(await repo().fetchFavoriteIds(), isEmpty);
  });

  test('stats serve the last sync offline instead of null', () async {
    inner.stats = const UserStats(
      currentStreak: 4,
      longestStreak: 4,
      freeUnlockCredits: 1,
      rankTier: 1,
      rankName: 'Prowokator',
    );
    final r = repo();
    await r.syncUserState(); // warm cache

    inner.error = const SocketException('offline');
    final stats = await r.syncUserState();
    expect(stats?.currentStreak, 4);
  });
}

/// A configurable in-memory [QuestionRepository]: every read returns its canned
/// value, or throws [error] when set (to simulate an outage). Pass-through
/// writes aren't exercised here, so they throw if unexpectedly called.
class _FakeRepo implements QuestionRepository {
  Object? error;
  List<Question> catalog = const [];
  Question? daily;
  List<Smaczek> smaczki = const [];
  List<Rank> ranks = const [];
  UserStats? stats;
  Set<String> favoriteIds = const {};
  List<Question> favoriteQuestions = const [];

  T _read<T>(T value) {
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<List<Question>> fetchQuestions() async => _read(catalog);

  @override
  Future<Question?> fetchDailyQuestion(DateTime date) async => _read(daily);

  @override
  Future<List<Smaczek>> fetchSmaczki(String questionId) async => _read(smaczki);

  @override
  Future<UserStats?> syncUserState() async => _read(stats);

  @override
  Future<List<Rank>> fetchRanks() async => _read(ranks);

  @override
  Future<Set<String>> fetchFavoriteIds() async => _read(favoriteIds);

  @override
  Future<List<Question>> fetchFavoriteQuestions() async =>
      _read(favoriteQuestions);

  @override
  Future<({String id, String teaser})?> peekNextQuestion() =>
      throw UnimplementedError();

  @override
  Future<Question?> revealAdQuestion({String? questionId}) =>
      throw UnimplementedError();

  @override
  Future<Question?> revealFreeQuestion() => throw UnimplementedError();

  @override
  Future<VoteResult> getDailyVoteState(String questionId) =>
      throw UnimplementedError();

  @override
  Future<VoteResult> castDailyVote(String questionId, int choice) =>
      throw UnimplementedError();

  @override
  Future<void> markQuestionSeen(String questionId) async {}

  @override
  Future<bool> toggleFavorite(String questionId) => throw UnimplementedError();

  @override
  Future<List<DailyHistoryEntry>> fetchDailyHistory() =>
      throw UnimplementedError();
}
