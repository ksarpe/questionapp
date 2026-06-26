import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionapp/core/locale/app_locale.dart';
import 'package:questionapp/data/models/daily_history_entry.dart';
import 'package:questionapp/data/models/question.dart';
import 'package:questionapp/data/models/rank.dart';
import 'package:questionapp/data/models/smaczek.dart';
import 'package:questionapp/data/models/user_stats.dart';
import 'package:questionapp/data/models/vote_result.dart';
import 'package:questionapp/data/repositories/question_repository.dart';
import 'package:questionapp/features/questions/providers/question_providers.dart';
import 'package:questionapp/features/settings/providers/offline_download_providers.dart';
import 'package:questionapp/services/question_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The download controller must walk the whole catalog (one smaczki fetch per
/// question), stamp the sync time, and end in `done` — or surface `error` when a
/// fetch throws — without caching anything itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = _FakeRepo();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        questionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Question q(String id) =>
      Question(id: id, category: id, questionText: 'Q $id?');

  test('downloads every question, fetching smaczki per question, then done',
      () async {
    repo.catalog = [q('a'), q('b'), q('c')];
    final container = makeContainer();

    await container.read(offlineDownloadControllerProvider.notifier).download();

    final state = container.read(offlineDownloadControllerProvider);
    expect(state.status, OfflineDownloadStatus.done);
    expect(state.done, 3);
    expect(state.total, 3);
    expect(state.lastSyncAt, isNotNull);
    // One smaczki fetch per catalog question.
    expect(repo.smaczkiCallIds, ['a', 'b', 'c']);
    // The cache's sync stamp was written.
    expect(container.read(questionCacheProvider).lastSyncAt, isNotNull);
  });

  test('surfaces an error status when a fetch fails', () async {
    repo.failQuestions = true;
    final container = makeContainer();

    await container.read(offlineDownloadControllerProvider.notifier).download();

    expect(
      container.read(offlineDownloadControllerProvider).status,
      OfflineDownloadStatus.error,
    );
  });
}

class _FakeRepo implements QuestionRepository {
  List<Question> catalog = const [];
  bool failQuestions = false;
  final List<String> smaczkiCallIds = [];

  @override
  Future<List<Question>> fetchQuestions() async {
    if (failQuestions) throw Exception('boom');
    return catalog;
  }

  @override
  Future<List<Smaczek>> fetchSmaczki(String questionId) async {
    smaczkiCallIds.add(questionId);
    return const [];
  }

  @override
  Future<Question?> fetchDailyQuestion(DateTime date) async => null;

  @override
  Future<List<Rank>> fetchRanks() async => const [];

  @override
  Future<Set<String>> fetchFavoriteIds() async => const {};

  @override
  Future<List<Question>> fetchFavoriteQuestions() async => const [];

  @override
  Future<UserStats?> syncUserState() async => null;

  @override
  Future<({String id, String teaser})?> peekNextQuestion() async => null;

  @override
  Future<Question?> revealAdQuestion({String? questionId}) async => null;

  @override
  Future<Question?> revealFreeQuestion() async => null;

  @override
  Future<VoteResult> getDailyVoteState(String questionId) async =>
      VoteResult.empty;

  @override
  Future<VoteResult> castDailyVote(String questionId, int choice) async =>
      VoteResult.empty;

  @override
  Future<void> markQuestionSeen(String questionId) async {}

  @override
  Future<bool> toggleFavorite(String questionId) async => false;

  @override
  Future<List<DailyHistoryEntry>> fetchDailyHistory() async => const [];
}
