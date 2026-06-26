import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/providers/session_providers.dart';
import '../providers/question_providers.dart';
import '../providers/swipe_hint_providers.dart';
import 'daily_badge.dart';
import 'daily_vote_panel.dart';
import 'go_deeper_button.dart';
import 'history_screen.dart';
import 'share_question_button.dart';
import 'smaczki_panel.dart';
import 'swipe_hand_hint.dart';
import 'wind_question_view.dart';

class QuestionBody extends ConsumerWidget {
  const QuestionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The question currently on screen. A locked question is a pure paywall —
    // WindQuestionView renders its lock + unlock CTA — so it gets NO bottom
    // overlay and NO smaczki affordance. Only a readable question does.
    final current = ref.watch(currentQuestionProvider);
    final questionId = current?.id;
    final isReadable = current != null && current.isLocked != true;

    // The daily is where the streak is earned, so its overlay carries the binary
    // vote panel (TAK/NIE → community split). Other readable questions don't.
    final isDaily = ref.watch(isShowingDailyProvider);

    // On the reveal slot the paywall / "no more questions" body carries its own
    // visible "back to daily" link, so suppress the faint bottom one here to
    // avoid showing two competing back actions.
    final atRevealSlot = ref.watch(isAtRevealSlotProvider);

    // Whether the user has ever swiped forward. Until they have, a gentle
    // right-edge arrow nudges them to discover that the feed continues past the
    // daily — the swipe gesture isn't obvious from the faint text hint alone.
    // Flipped (and persisted) by the first forward swipe in WindQuestionView.
    final swipeDiscovered = ref.watch(swipeDiscoveredControllerProvider);

    // Folded into the vote panel's key so its local state (the cast result it
    // holds to avoid a refetch) resets when the account changes, not only when
    // the question does — otherwise a fresh user keeps seeing the old vote bars.
    final userId = ref.watch(sessionProvider.select((s) => s.value?.userId));

    // Warm the smaczki for a readable question in the background, so the "go
    // deeper" panel opens straight to content instead of a spinner. The result
    // is ignored here — the panel reads the same, now-resolved provider
    // (FutureProvider.family caches per question id). Each swipe re-warms the
    // newly visible question. Locked questions have no panel, so skip them.
    if (isReadable && questionId != null) {
      ref.watch(smaczkiProvider(questionId));
    }

    // Centred group: the "Daily" badge, the question, and — on the daily — the
    // TAK/NIE vote right beneath the question, so the buttons sit by the question
    // rather than pinned to the screen bottom. Only the swipe hint + "go deeper"
    // stay in the bottom overlay (readable questions only).
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Self-hiding "Daily" pill, sitting just above the question.
                  const DailyBadge(),
                  if (isDaily) const SizedBox(height: 18),
                  // Stable key: the conditional SizedBox above shifts this
                  // widget's position in the Column when `isDaily` flips, which
                  // would otherwise rebuild it with a fresh State and drop its
                  // in-memory state (the peeked teaser). The key preserves it.
                  const WindQuestionView(key: ValueKey('wind_question_view')),
                  // Vote on the daily — builds the streak and reveals the
                  // community split. Keyed by (user, id) so it resets both when
                  // swiping to a new question and when the account changes.
                  if (isDaily && isReadable && questionId != null) ...[
                    const SizedBox(height: 28),
                    DailyVotePanel(
                      key: ValueKey('${userId ?? ''}:$questionId'),
                      questionId: questionId,
                    ),
                  ],
                  // A visible share pill sitting right under the question (and
                  // under the vote panel on the daily), so it's an obvious
                  // action rather than the faint icon it used to be down in the
                  // bottom overlay. Readable questions only — never a teaser. On
                  // the daily it's paired with the "Historia" pill, the quick way
                  // into the PRO history of past dailies + how people voted.
                  if (isReadable && questionId != null) ...[
                    const SizedBox(height: 24),
                    if (isDaily)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShareQuestionButton(
                            questionText: current.questionText,
                          ),
                          const SizedBox(width: 12),
                          const HistoryButton(),
                        ],
                      )
                    else
                      ShareQuestionButton(questionText: current.questionText),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Bottom overlay. On a readable question it carries the swipe hint and
        // the "go deeper" pill. Whenever the user has swiped off the daily —
        // readable OR locked — it also offers a borderless "← Daily" return, so
        // a free user who landed on a locked teaser and doesn't want to watch an
        // ad can get back to the free daily in one tap instead of being stuck.
        if ((isReadable && questionId != null || !isDaily) && !atRevealSlot)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isReadable && questionId != null) ...[
                      // Subtle hint that questions are swipeable.
                      Text(
                        context.l10n.swipeHint,
                        style: TextStyle(
                          color: context.colors.subtle,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // The glowing "go deeper" pill. (Share lives up by the
                      // question now, not down here.)
                      GoDeeperButton(
                        onTap: () => showSmaczkiSheet(context, questionId),
                      ),
                    ],
                    if (!isDaily) ...[
                      if (isReadable && questionId != null)
                        const SizedBox(height: 12),
                      _BackToDailyButton(
                        onTap: () =>
                            ref.read(questionIndexProvider.notifier).toDaily(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        // A finger that demonstrates the leftward "swipe for more" gesture if
        // the user lingers ~10s on a readable question without swiping. Shown
        // only on a readable, non-slot question, and — in release — only until
        // the first forward swipe sets `swipeDiscovered`, so it teaches once per
        // install. In debug builds the gate is relaxed so the animation can be
        // eyeballed without clearing app data. Decorative (IgnorePointer), so
        // the real swipe underneath passes straight through.
        if (isReadable &&
            questionId != null &&
            !atRevealSlot &&
            (!swipeDiscovered || kDebugMode))
          const Positioned.fill(child: SwipeHandHint()),
      ],
    );
  }
}

/// A borderless "← Daily" link pinned at the bottom of the screen, shown only
/// when the user has swiped off the daily. Tapping it returns to today's free
/// daily question — the escape hatch from a locked pool teaser.
class _BackToDailyButton extends StatelessWidget {
  const _BackToDailyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.arrow_back, size: 18, color: context.colors.subtle),
      label: Text(
        context.l10n.dailyShort,
        style: TextStyle(
          color: context.colors.subtle,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: context.colors.subtle,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
