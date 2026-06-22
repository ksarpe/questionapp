import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/providers/session_providers.dart';
import '../../account/providers/stats_providers.dart';
import '../../account/screens/auth_screen.dart';
import '../../monetization/providers/monetization_providers.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/question_providers.dart';
import '../widgets/daily_badge.dart';
import '../widgets/daily_vote_panel.dart';
import '../widgets/go_deeper_button.dart';
import '../widgets/smaczki_panel.dart';
import '../widgets/stat_chips.dart';
import '../widgets/wind_question_view.dart';

/// The home screen: a single styled question centred on a clean canvas, with a
/// settings gear top-right and a small info icon just above the question.
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off silent anonymous auth + entitlement loading at launch, and start
    // pre-loading a rewarded ad so the unlock sheet is responsive the first time
    // a free user is gated. Reading them here is enough to instantiate them; the
    // daily question every user opens to is free.
    final hasAccount = ref.watch(sessionProvider).value?.hasAccount ?? false;
    ref.watch(rewardedAdServiceProvider);

    // Sync the user's engagement state once the session resolves. This drives
    // the streak + free-unlock chips AND performs today's free-credit top-up
    // (server-side, once per UTC day) — the replacement for the old random
    // bonus claim. Premium users get no credit; guests are signed in too.
    ref.watch(userStatsProvider);

    // When the signed-in identity changes (log in / log out / account switch),
    // drop every per-user cache so the new user never inherits the previous
    // one's daily vote, unlocked text or smaczki. Providers keyed only on
    // question id (e.g. dailyVoteStateProvider) otherwise keep serving the prior
    // user's answer until the app restarts — which is why a logged-out user still
    // saw their daily vote. (userStatsProvider already watches the session, so it
    // refreshes on its own.)
    ref.listen(sessionProvider.select((s) => s.value?.userId), (prev, next) {
      if (prev != next) {
        ref.invalidate(questionsProvider);
        ref.invalidate(todaysDailyQuestionProvider);
        ref.invalidate(dailyVoteStateProvider);
        ref.invalidate(smaczkiProvider);
        // Revealed questions are per-identity and held only in memory — drop them
        // and snap back to the daily so a new user never inherits the previous
        // user's feed.
        ref.read(revealedFeedProvider.notifier).clear();
        ref.read(questionIndexProvider.notifier).toDaily();
      }
    });

    // Premium walks the whole catalog, so record each question it lands on in the
    // seen-memory — that's what lets the next launch surface UNSEEN questions
    // first instead of looping the same ones forever. Free users only ever reach
    // the daily + their reveals (both recorded server-side already), so this is
    // premium-only; the daily is also skipped here (get_daily_question records
    // it). Fire-and-forget: the repo swallows errors, and we deliberately do NOT
    // refetch the pool, so the current session's deck order stays put.
    ref.listen(currentQuestionProvider, (prev, next) {
      if (next == null || next.isLocked == true) return;
      if (prev?.id == next.id) return;
      if (!ref.read(isPremiumProvider)) return;
      final daily = ref.read(todaysDailyQuestionProvider).asData?.value;
      if (daily != null && next.id == daily.id) return;
      ref.read(questionRepositoryProvider).markQuestionSeen(next.id);
    });

    // The deck drives the body: it stays empty until today's daily resolves, so
    // every user opens to the daily rather than a flash of the pool. Watching it
    // here also kicks off the daily fetch at launch, alongside the question pool.
    // Either fetch failing leaves the deck empty; surface BOTH so an offline
    // launch shows a retry instead of an endless spinner (the daily's error in
    // particular never reached the UI before, so the deck just stayed empty).
    final loadError =
        ref.watch(questionsProvider).error ??
        ref.watch(todaysDailyQuestionProvider).error;
    final deck = ref.watch(questionDeckProvider);

    return Scaffold(
      // Let the body fill the whole screen so the question centres against the
      // true midpoint; the (transparent) app bar floats over the top.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Status cluster centred at the top. The streak flame is only meaningful
        // for a real account (a guest's progress isn't saved), so it's hidden for
        // guests; the free-unlock chip self-hides off the daily / for guests.
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAccount) const StreakChip(),
            const FreeUnlockChip(),
          ],
        ),
        // Top-right action. A signed-in user gets the person/settings icon; a
        // guest gets a quiet "Zaloguj" text button instead, opening the sign-in
        // sheet.
        actions: [
          if (hasAccount)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: context.l10n.settingsTooltip,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => showAuthSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.subtle,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(context.l10n.signInShort),
              ),
            ),
        ],
      ),
      // Only treat a load error as fatal when there's genuinely nothing to show:
      // a transient pool error while the daily loaded fine still renders the
      // daily rather than blocking the whole screen.
      body: deck.isEmpty && loadError != null
          ? _LoadError(
              onRetry: () {
                ref.invalidate(sessionProvider);
                ref.invalidate(questionsProvider);
                ref.invalidate(todaysDailyQuestionProvider);
                ref.invalidate(userStatsProvider);
              },
            )
          : deck.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : const _QuestionBody(),
    );
  }
}

class _QuestionBody extends ConsumerWidget {
  const _QuestionBody();

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
                        style: const TextStyle(
                          color: AppTheme.subtle,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // The glowing "go deeper" pill opens the Smaczki panel for
                      // the question currently on screen.
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
      icon: const Icon(Icons.arrow_back, size: 18, color: AppTheme.subtle),
      label: Text(
        context.l10n.dailyShort,
        style: const TextStyle(
          color: AppTheme.subtle,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.subtle,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// Shown when the launch fetch fails (typically no network) and there is nothing
/// to render. Replaces the old endless spinner with a friendly message and a
/// retry that re-runs sign-in + the question/daily/stats fetches.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppTheme.subtle, size: 40),
            const SizedBox(height: 16),
            Text(
              context.l10n.loadErrorTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.loadErrorBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.subtle, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
