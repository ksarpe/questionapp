import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/network/connectivity_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/question_cache.dart';
import '../../account/providers/session_providers.dart';
import '../../account/providers/stats_providers.dart';
import '../../account/screens/auth_screen.dart';
import '../../monetization/providers/monetization_providers.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/question_providers.dart';
import '../providers/swipe_hint_providers.dart';
import '../widgets/history_screen.dart';
import '../widgets/category_filter_button.dart';
import '../widgets/daily_badge.dart';
import '../widgets/favorite_star_button.dart';
import '../widgets/daily_vote_panel.dart';
import '../widgets/go_deeper_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/rank_up_sheet.dart';
import '../widgets/share_question_button.dart';
import '../widgets/smaczki_panel.dart';
import '../widgets/stat_chips.dart';
import '../widgets/streak_up_celebration.dart';
import '../widgets/swipe_hand_hint.dart';
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
        // The premium category filter is per-session and per-identity — drop it
        // so a new user (who may not even be premium) never inherits a filter.
        ref.read(selectedCategoryProvider.notifier).clear();
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

    // When connectivity returns after an outage, re-run the launch fetches so a
    // user who opened on cached content (or hit the offline error screen)
    // converges on fresh data without needing to tap "retry" or relaunch. Only
    // fires on the offline→online edge, so a normal online session never
    // refetches. The session refresh also re-reconciles premium, which reshapes
    // the deck if an entitlement changed while offline.
    ref.listen(isOnlineValueProvider, (wasOnline, isOnline) {
      if (wasOnline == false && isOnline == true) {
        // refresh() (not invalidate) so the session reload doesn't flash to
        // loading — that would null userId and trip the identity listener above,
        // wiping the revealed feed and snapping back to the daily.
        ref.read(sessionProvider.notifier).refresh();
        ref.invalidate(questionsProvider);
        ref.invalidate(todaysDailyQuestionProvider);
        ref.invalidate(userStatsProvider);
      }
    });

    // Clear the cached content the moment premium lapses (true→false) so a former
    // subscriber can't keep reading the full catalog offline. Belt-and-suspenders
    // on top of the caching repo's read-time premium guard and the next online
    // refetch (which overwrites the cache with the now-locked free shape).
    ref.listen(isPremiumProvider, (wasPremium, isPremium) {
      if (wasPremium == true && isPremium == false) {
        ref.read(questionCacheProvider).clearContent();
      }
    });

    // Drives the offline strip under the app bar. A hint only — the cached
    // content still renders; a failed request is the real offline signal.
    final isOnline = ref.watch(isOnlineValueProvider);

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

    // The question currently on screen drives the top-left favorite star: it
    // saves THIS question. Premium fills it; a free user's tap opens the paywall
    // (favorites are premium). Hidden when there's nothing readable to save (the
    // free reveal slot).
    final current = ref.watch(currentQuestionProvider);

    // Premium gets a category-filter icon right next to the star, narrowing the
    // browseable catalog to one theme. Free users never browse the catalog, so
    // it's premium-only (premium never sits on the reveal slot, so `current` is
    // non-null whenever this matters).
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      // Let the body fill the whole screen so the question centres against the
      // true midpoint; the (transparent) app bar floats over the top.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Status cluster centred at the top. The streak flame is only meaningful
        // for a real account (a guest's progress isn't saved), so it's hidden for
        // guests; the free-unlock chip self-hides off the daily / for guests.
        automaticallyImplyLeading: false,
        // The offline strip rides in the app bar's `bottom` slot so it grows the
        // bar when offline and reserves no space when connected (rather than
        // overlaying the status chips).
        bottom: isOnline ? null : const OfflineBanner(),
        // Widen the leading slot when the category button rides alongside the star.
        leadingWidth: isPremium ? 104 : 56,
        leading: current != null
            ? Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FavoriteStarButton(questionId: current.id),
                    if (isPremium) const CategoryFilterButton(),
                  ],
                ),
              )
            : null,
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
                  foregroundColor: context.colors.subtle,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: deck.isEmpty && loadError != null
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
          ),
          // Celebrates a rank climb (confetti + shareable card) the moment the
          // synced stats cross a tier — caught on launch and after a daily vote.
          // Zero-size; mounts here so it lives for the whole session.
          const RankCelebrationListener(),
          // The everyday "+1": flies a flame up into the streak chip whenever the
          // streak grows (and it isn't a promotion day, which the rank-up owns).
          const StreakCelebrationListener(),
        ],
      ),
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
            Icon(Icons.cloud_off, color: context.colors.subtle, size: 40),
            const SizedBox(height: 16),
            Text(
              context.l10n.loadErrorTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.loadErrorBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.subtle, fontSize: 14),
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
