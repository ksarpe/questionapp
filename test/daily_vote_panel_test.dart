import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/data/models/vote_result.dart';
import 'package:questionapp/data/repositories/question_repository.dart';
import 'package:questionapp/features/account/providers/session_providers.dart';
import 'package:questionapp/features/questions/providers/question_providers.dart';
import 'package:questionapp/features/questions/widgets/daily_vote_panel.dart';

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
  });
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
