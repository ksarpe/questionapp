import 'package:debatly/data/repositories/question_repository.dart';
import 'package:debatly/features/account/providers/session_providers.dart';
import 'package:debatly/features/questions/providers/favorites_providers.dart';
import 'package:debatly/features/questions/providers/question_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose only real behaviour is a favorites store, so the notifier's
/// optimistic-toggle + rollback can be exercised without a backend. Everything
/// else falls through to the mock.
class _FakeFavRepo extends MockQuestionRepository {
  _FakeFavRepo();

  final Set<String> store = <String>{};
  bool throwOnToggle = false;

  @override
  Future<Set<String>> fetchFavoriteIds() async => {...store};

  @override
  Future<bool> toggleFavorite(String questionId) async {
    if (throwOnToggle) throw Exception('premium required');
    if (store.remove(questionId)) return false;
    store.add(questionId);
    return true;
  }
}

/// A session pinned to a premium account, so the notifier never touches Supabase
/// / RevenueCat in tests.
class _FakeSession extends SessionNotifier {
  _FakeSession(this._state);

  final SessionState _state;

  @override
  Future<SessionState> build() async => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(_FakeFavRepo repo) async {
    final c = ProviderContainer(
      overrides: [
        questionRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith(
          () => _FakeSession(
            const SessionState(
              userId: 'u1',
              isAnonymous: false,
              isPremium: true,
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Settle the session first, then let the initial fetchFavoriteIds resolve —
    // mirrors the user-stats tests, so the dependent provider's `.future`
    // completes instead of waiting on a still-loading session.
    await c.read(sessionProvider.future);
    await c.read(favoriteIdsProvider.future);
    return c;
  }

  group('FavoriteIdsNotifier.toggle', () {
    test('adds a question and reflects the server result', () async {
      final repo = _FakeFavRepo();
      final c = await containerWith(repo);

      final nowFavorite = await c
          .read(favoriteIdsProvider.notifier)
          .toggle('q1');

      expect(nowFavorite, isTrue);
      expect(c.read(favoriteIdsProvider).value, {'q1'});
      expect(repo.store, {'q1'}, reason: 'the add reached the repository');
    });

    test('removes a question that was already a favorite', () async {
      final repo = _FakeFavRepo()..store.add('q1');
      final c = await containerWith(repo);
      expect(c.read(favoriteIdsProvider).value, {'q1'});

      final nowFavorite = await c
          .read(favoriteIdsProvider.notifier)
          .toggle('q1');

      expect(nowFavorite, isFalse);
      expect(c.read(favoriteIdsProvider).value, isEmpty);
      expect(repo.store, isEmpty);
    });

    test('rolls back and rethrows when the toggle fails', () async {
      final repo = _FakeFavRepo()..throwOnToggle = true;
      final c = await containerWith(repo);

      await expectLater(
        c.read(favoriteIdsProvider.notifier).toggle('q1'),
        throwsA(isA<Exception>()),
      );

      // The optimistic add was undone — a failed save (e.g. lapsed premium) must
      // not leave a phantom star filled.
      expect(c.read(favoriteIdsProvider).value, isEmpty);
    });

    test(
      'the optimistic flip is visible before the round-trip settles',
      () async {
        final repo = _FakeFavRepo();
        final c = await containerWith(repo);

        // Don't await: the optimistic state must already show the star filled.
        final pending = c.read(favoriteIdsProvider.notifier).toggle('q1');
        expect(c.read(favoriteIdsProvider).value, {'q1'});
        await pending;
        expect(c.read(favoriteIdsProvider).value, {'q1'});
      },
    );
  });
}
