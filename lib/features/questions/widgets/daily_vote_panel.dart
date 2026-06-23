import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_toast.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../core/network/network_error.dart';
import '../../../data/models/rank.dart';
import '../../../data/models/vote_result.dart';
import '../../../services/notification_service.dart';
import '../../account/providers/session_providers.dart';
import '../../account/providers/stats_providers.dart';
import '../../account/screens/auth_screen.dart';
import '../../settings/providers/reminder_providers.dart';
import '../../settings/providers/review_providers.dart';
import '../providers/question_providers.dart';
import 'vote_visuals.dart';

/// The binary (TAK / NIE) vote shown under the daily question.
///
/// Before voting it shows the two buttons; voting on the daily advances the
/// user's streak server-side. After voting it shows the community split as two
/// bars with the user's own side highlighted. Give it a `ValueKey(questionId)`
/// so swiping to a new question resets its local state.
///
/// Guests see the buttons too, but may neither vote nor see the community split:
/// tapping either side sends them to the sign-in sheet instead of casting a vote.
class DailyVotePanel extends ConsumerStatefulWidget {
  const DailyVotePanel({required this.questionId, super.key});

  final String questionId;

  @override
  ConsumerState<DailyVotePanel> createState() => _DailyVotePanelState();
}

class _DailyVotePanelState extends ConsumerState<DailyVotePanel> {
  /// The freshest result this session (from the cast RPC), preferred over the
  /// initially-loaded provider value so the bars appear without a refetch.
  VoteResult? _local;
  bool _busy = false;

  Future<void> _vote(int choice) async {
    if (_busy) return;
    setState(() => _busy = true);
    // Captured before the await so we never read context across an async gap.
    final notifTitle = context.l10n.notificationDailyTitle;
    final notifBody = context.l10n.notificationDailyBody;
    try {
      final result = await ref
          .read(questionRepositoryProvider)
          .castDailyVote(widget.questionId, choice);
      if (!mounted) return;
      // The vote may have moved the streak — refresh the top chip.
      ref.invalidate(userStatsProvider);
      setState(() => _local = result);
      await _suppressTonightsReminder(notifTitle, notifBody);
      await _maybeAskForReview();
    } catch (e) {
      if (!mounted) return;
      // Offline gets the calmer "no connection" line — the vote isn't lost, it
      // just needs a connection; any other failure is the generic vote error.
      AppToast.error(
        context,
        isOfflineError(e) ? context.l10n.noConnection : context.l10n.voteFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Now that today's daily is answered, skip tonight's reminder (this panel only
  /// renders under the daily, so a vote here is always today's daily). Stamps the
  /// local vote date — which also keeps the nudge skipped across a same-day
  /// relaunch — and re-arms the schedule to fire from tomorrow.
  ///
  /// Best-effort: reminder suppression must never break the vote, so a missing
  /// prefs/notification setup (dev/tests) is swallowed.
  Future<void> _suppressTonightsReminder(String title, String body) async {
    try {
      await ref.read(reminderControllerProvider.notifier).markVotedToday();
      final reminder = ref.read(reminderControllerProvider);
      if (reminder.enabled) {
        await NotificationService.scheduleDailyReminder(
          hour: reminder.hour,
          minute: reminder.minute,
          title: title,
          body: body,
          skipToday: true,
        );
      }
    } catch (_) {
      // Non-critical: the vote already counted; the reminder will self-correct
      // on the next launch / vote.
    }
  }

  /// After a successful daily vote — a natural high point, especially when it
  /// just extended a streak — consider asking for a store rating. The streak is
  /// read from the now-refreshed stats; the controller enforces the milestone +
  /// weekly cooldown, so the vast majority of votes ask for nothing.
  ///
  /// Best-effort and fired last: a rating ask must never interfere with the vote
  /// that already counted, so any failure (offline stats refetch, missing prefs
  /// in tests) is swallowed.
  Future<void> _maybeAskForReview() async {
    try {
      final stats = await ref.read(userStatsProvider.future);
      final streak = stats?.currentStreak ?? 0;

      // On the day the streak crosses into a new rank, the rank-up celebration
      // (confetti + share card) owns the moment — don't stack the OS review
      // sheet on top of it. The very first review milestone (streak 3) lines up
      // exactly with the first promotion, so this collision is the common case,
      // not an edge one. The review ask comes around again on the next eligible
      // day per its own cooldown.
      final ladder = ref.read(ranksProvider).value ?? kDefaultRanks;
      final isPromotionDay =
          ladder.any((r) => r.tier > 0 && r.minStreak == streak);
      if (isPromotionDay) return;

      await ref
          .read(reviewPromptControllerProvider.notifier)
          .maybePromptForStreak(streak);
    } catch (_) {
      // Non-critical: skipping the ask is always an acceptable outcome.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = ref.watch(
      sessionProvider.select((s) => s.value?.hasAccount ?? false),
    );

    // Guests: show the buttons but never the split. Tapping either side opens the
    // sign-in sheet rather than casting a vote — so no community % leaks out and
    // a vote is only ever recorded for a real account. (No provider read here, so
    // we don't even fetch the split for a guest.)
    if (!hasAccount) {
      return VoteButtonsRow(
        busy: false,
        onVote: (_) => showAuthSheet(context),
      );
    }

    final async = ref.watch(dailyVoteStateProvider(widget.questionId));
    final result = _local ?? async.value;

    // Until the state is known, reserve the space with a slim placeholder so the
    // overlay doesn't jump when the buttons/bars appear.
    if (result == null) {
      return const SizedBox(height: 52);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: result.hasVoted
          ? VoteResultsRow(key: const ValueKey('results'), result: result)
          : VoteButtonsRow(
              key: const ValueKey('buttons'),
              busy: _busy,
              onVote: _vote,
            ),
    );
  }
}

