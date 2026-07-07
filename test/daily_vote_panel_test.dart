import 'package:debatly/data/models/vote_result.dart';
import 'package:debatly/data/repositories/question_repository.dart';
import 'package:debatly/features/account/providers/session_providers.dart';
import 'package:debatly/features/questions/providers/question_providers.dart';
import 'package:debatly/features/questions/widgets/daily_vote_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_test_app.dart';

/// The daily TAK/NIE panel. Two guarantees matter for release:
///   * a guest may neither vote nor see the community split — tapping a side
///     sends them to sign-in, and no percentage ever renders for them;
///   * an account that votes is shown the split (green %, red %, with "VS"
///     between) with its own side marked.
void main() {
  SessionState guest() => const SessionState(userId: 'anon', isAnonymous: true);
  SessionState account() =>
      const SessionState(userId: 'u1', isAnonymous: false);

  Future<_VotePanelRepo> pumpPanel(
    WidgetTester tester, {
    required SessionState session,
    required VoteResult initial,
    VoteResult? castReturns,
  }) async {
    final repo = _VotePanelRepo(initial: initial)..castReturns = castReturns;
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSession(session)),
        questionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedTestApp(
          home: Scaffold(
            body: Center(child: DailyVotePanel(questionId: 'q1')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('a guest sees the buttons but tapping opens sign-in, no vote', (
    tester,
  ) async {
    final repo = await pumpPanel(
      tester,
      session: guest(),
      initial: VoteResult.empty,
    );

    expect(find.text('TAK'), findsOneWidget);
    expect(find.text('NIE'), findsOneWidget);
    // A guest must never see a community percentage.
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('VS'), findsNothing);

    await tester.tap(find.text('TAK'));
    await tester.pumpAndSettle(); // run the sign-in sheet transition

    // The sign-in card opened (its email/password fields), not a vote.
    expect(
      find.byType(TextField),
      findsWidgets,
      reason: 'a guest tap is a login prompt, not a vote',
    );
    expect(repo.castCalls, 0, reason: 'no vote is recorded for a guest');
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets(
    'an account that has not voted sees the buttons, no split leaked',
    (tester) async {
      await pumpPanel(
        tester,
        session: account(),
        initial: VoteResult.empty, // myChoice null → not voted
      );

      expect(find.text('TAK'), findsOneWidget);
      expect(find.text('NIE'), findsOneWidget);
      expect(find.text('VS'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    },
  );

  testWidgets('voting reveals the green/red split with VS and marks my side', (
    tester,
  ) async {
    final repo = await pumpPanel(
      tester,
      session: account(),
      initial: VoteResult.empty,
      castReturns: const VoteResult(
        yesCount: 60,
        noCount: 40,
        myChoice: VoteResult.yes,
      ),
    );

    await tester.tap(find.text('TAK'));
    await tester.pumpAndSettle(); // cast + AnimatedSwitcher to the results

    expect(repo.castCalls, 1);
    expect(repo.lastChoice, VoteResult.yes);

    // The split: both percentages plus the "VS" separator between them.
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    // The user's own side carries the check mark.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // ...and a muted "Twój głos" caption sits under the picked tile.
    expect(find.text('Twój głos'), findsOneWidget);
  });

  testWidgets(
    'an offline cached vote confirms my side but withholds the community split',
    (tester) async {
      // A snapshot served from cache offline: the user's own vote is known, but
      // the community split must not be shown (it may be stale).
      await pumpPanel(
        tester,
        session: account(),
        initial: const VoteResult(
          yesCount: 61,
          noCount: 39,
          myChoice: VoteResult.yes,
          fromCache: true,
        ),
      );

      // My side is still confirmed (check mark + the VS shell), so it reads as
      // "you voted" rather than an empty gap...
      expect(find.byKey(const ValueKey('results')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // ...but no percentage leaks — a dash stands in on both sides, with a
      // caption explaining the numbers return online.
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('–'), findsNWidgets(2));
      expect(find.text('Wyniki wrócą po połączeniu'), findsOneWidget);
      // The "your vote" caption still shows offline (it's my own data).
      expect(find.text('Twój głos'), findsOneWidget);
    },
  );

  testWidgets(
    'after voting, leaving the daily and returning still shows the split — '
    'no second vote',
    (tester) async {
      // Server-faithful repo: once a vote is cast, get_daily_vote_state reports
      // the post-vote state (myChoice set), exactly like the real RPC.
      final repo = _PersistingVoteRepo();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSession(account())),
          questionRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // A panel that can be mounted/unmounted to simulate swiping off the daily
      // (isDaily=false → panel gone) and back to it.
      Widget tree({required bool showPanel}) => UncontrolledProviderScope(
        container: container,
        child: LocalizedTestApp(
          home: Scaffold(
            body: Center(
              child: showPanel
                  ? const DailyVotePanel(questionId: 'q1')
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pumpWidget(tree(showPanel: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TAK'));
      await tester.pumpAndSettle();
      expect(repo.castCalls, 1);
      // The result bars (keyed 'results'), not the vote buttons (keyed 'buttons').
      expect(find.byKey(const ValueKey('results')), findsOneWidget);

      // Swipe to another question: the daily panel unmounts (its local state is
      // discarded).
      await tester.pumpWidget(tree(showPanel: false));
      await tester.pumpAndSettle();

      // Come back to the daily: a fresh panel mounts with no local state.
      await tester.pumpWidget(tree(showPanel: true));
      await tester.pumpAndSettle();

      // It must still show the split, never the buttons — and must not let the
      // user cast a second vote. (Both rows label their sides "TAK"/"NIE", so the
      // distinguishing signal is the AnimatedSwitcher child key, not the text.)
      expect(find.byKey(const ValueKey('results')), findsOneWidget);
      expect(find.byKey(const ValueKey('buttons')), findsNothing);
      expect(
        repo.castCalls,
        1,
        reason: 'returning to the daily is not a re-vote',
      );
    },
  );
}

/// A repo that remembers a cast vote, so `getDailyVoteState` reflects it on the
/// next read — mirroring the server, where the vote is persisted and the panel
/// is meant to read it back as "already voted".
class _PersistingVoteRepo extends MockQuestionRepository {
  VoteResult? _voted;
  int castCalls = 0;

  @override
  Future<VoteResult> getDailyVoteState(String questionId) async =>
      _voted ?? VoteResult.empty;

  @override
  Future<VoteResult> castDailyVote(String questionId, int choice) async {
    castCalls++;
    return _voted = VoteResult(
      yesCount: choice == VoteResult.yes ? 60 : 40,
      noCount: choice == VoteResult.no ? 60 : 40,
      myChoice: choice,
    );
  }
}

/// A session fixed to a known identity, so the account/guest branch can be
/// exercised without touching Supabase.
class _FakeSession extends SessionNotifier {
  _FakeSession(this._state);

  final SessionState _state;

  @override
  Future<SessionState> build() async => _state;
}

/// Mock repo with a controllable initial vote state and a recorded cast.
class _VotePanelRepo extends MockQuestionRepository {
  _VotePanelRepo({required this.initial});

  final VoteResult initial;
  VoteResult? castReturns;
  int castCalls = 0;
  int? lastChoice;

  @override
  Future<VoteResult> getDailyVoteState(String questionId) async => initial;

  @override
  Future<VoteResult> castDailyVote(String questionId, int choice) async {
    castCalls++;
    lastChoice = choice;
    return castReturns ??
        VoteResult(
          yesCount: choice == VoteResult.yes ? 60 : 40,
          noCount: choice == VoteResult.no ? 60 : 40,
          myChoice: choice,
        );
  }
}
