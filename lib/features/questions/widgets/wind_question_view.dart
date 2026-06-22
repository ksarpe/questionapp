import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_toast.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/question.dart';
import '../../../services/purchases_service.dart';
import '../../../services/supabase_service.dart';
import '../../account/providers/session_providers.dart';
import '../../account/providers/stats_providers.dart';
import '../../account/widgets/save_pro_prompt.dart';
import '../../monetization/providers/monetization_providers.dart';
import '../providers/question_providers.dart';
import 'falling_words_text.dart';
import 'styled_question_text.dart';

/// Displays the current question and runs the signature "wind" transition.
///
/// On a horizontal swipe the current text accelerates off in the direction of
/// the swipe — as if blown away — then, after a short beat, the *next* question
/// assembles itself word by word, each word dropping in from above (see
/// [FallingWordsText]). No cards, no flips: just text in motion.
///
/// Navigation depends on the tier:
///   * PREMIUM walks the whole catalog, wrapping around; every question reads.
///   * A FREE user walks a forward "feed": the daily, then the questions they
///     reveal one at a time. Swiping LEFT goes forward; once past the last
///     revealed question they hit the "reveal slot" — if they hold the daily
///     credit it auto-reveals the next question, otherwise a paywall offers a
///     rewarded ad (or PRO). The server picks the next UNSEEN question and
///     returns its text; it is held in session memory only (see
///     [revealedFeedProvider]) and is not re-readable after the app closes.
///     Swiping RIGHT steps back through the questions revealed this session.
class WindQuestionView extends ConsumerStatefulWidget {
  const WindQuestionView({super.key});

  @override
  ConsumerState<WindQuestionView> createState() => _WindQuestionViewState();
}

class _WindQuestionViewState extends ConsumerState<WindQuestionView>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  /// Drives the lock-opening flourish played over the canvas right before a
  /// freely-unlocked question assembles (see [_playLockReveal]). Separate from
  /// the wind controller so the two never fight over a single timeline.
  late final AnimationController _lockController;

  /// True while the lock flourish owns the canvas — takes priority over the
  /// reveal-slot paywall/spinner in [build] so the big lock is what shows.
  bool _lockRevealing = false;

  // Offsets are expressed as a fraction of screen width and converted to pixels
  // at paint time, so the text fully clears the screen regardless of its size.
  Animation<Offset> _offset = const AlwaysStoppedAnimation(Offset.zero);
  Animation<double> _opacity = const AlwaysStoppedAnimation(1);

  /// The question currently painted. While idle it tracks the provider; during
  /// a transition it is frozen so the OUT phase keeps showing the old question.
  Question? _displayed;
  bool _animating = false;

  /// An ad or purchase flow is in flight — blocks the paywall buttons + swipes.
  bool _unlocking = false;

  /// A reveal RPC is in flight (credit or ad) — the slot shows a brief spinner.
  /// Off the slot (or once it clears) the paywall is what the slot shows by
  /// default, so there is no separate "show paywall" flag.
  bool _revealing = false;

  /// A reveal came back empty — the user has seen everything eligible for now.
  bool _exhausted = false;

  /// The next question peeked for the paywall teaser ({id, teaser}), or null
  /// before it's fetched. Its id is passed to the ad reveal so the ad reveals the
  /// exact question that was teased.
  ({String id, String teaser})? _peeked;

  /// A peek RPC is in flight — the slot shows a spinner until the teaser arrives.
  bool _peeking = false;

  /// The in-flight peek future, or null. A peek is non-consuming (no text, no
  /// credit, not marked seen), so it is started EAGERLY while the user is still
  /// on the last feed item (see [_maybePrefetchPeek]) — by the time they swipe to
  /// the slot the teaser is usually already in [_peeked] and the paywall shows
  /// instantly, with no round-trip on the critical path. Held so a swipe that
  /// beats the prefetch reuses the same in-flight call instead of firing another.
  Future<({String id, String teaser})?>? _peekFuture;

  /// A credit reveal started BEFORE the wind-out animation, so its round-trip
  /// hides behind the ~320ms animation instead of a spinner afterwards. Held
  /// alongside its result/error and a "done" flag so the post-animation step can
  /// paint the revealed question in the same frame when the round-trip already
  /// won the race — and only fall back to the [_Revealing] spinner when the
  /// network is genuinely slower than the animation.
  Future<Question?>? _pendingReveal;
  Question? _pendingRevealResult;
  Object? _pendingRevealError;
  bool _pendingRevealDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _lockController.dispose();
    super.dispose();
  }

  /// [direction] is the sign of the swipe: -1 leftward, +1 rightward.
  Future<void> _advance(int direction) async {
    if (_animating || _unlocking || _revealing || _peeking || _lockRevealing) {
      return;
    }

    // PREMIUM: any swipe advances forward through the wrapped catalog.
    if (ref.read(isPremiumProvider)) {
      _animating = true;
      await _animateOut(direction);
      if (!mounted) {
        _animating = false;
        return;
      }
      ref.read(questionIndexProvider.notifier).next();
      _settleIn(ref.read(currentQuestionProvider));
      _animating = false;
      return;
    }

    // FREE FEED.
    final notifier = ref.read(questionIndexProvider.notifier);
    final idx = ref.read(questionIndexProvider);
    final deckLen = ref.read(questionDeckProvider).length;
    final atSlot = idx >= deckLen;

    // RIGHT swipe — step back through this session's revealed questions.
    if (direction > 0) {
      if (idx == 0) return; // already on the daily
      _animating = true;
      await _animateOut(direction);
      if (!mounted) {
        _animating = false;
        return;
      }
      notifier.backLinear();
      _settleIn(ref.read(currentQuestionProvider));
      _animating = false;
      return;
    }

    // LEFT swipe while already on the slot — reveal with the credit if we have
    // one; otherwise the paywall buttons drive it.
    if (atSlot) {
      if (_exhausted) return;
      if (ref.read(freeUnlockCreditsProvider) >= 1) {
        setState(() => _revealing = true);
        await _reveal(viaAd: false);
      }
      return;
    }

    // LEFT swipe forward onto the next position (a revealed question, or the slot).
    //
    // If this swipe is going to land on the reveal slot, start its network work
    // NOW — concurrently with the wind-out animation — so the round-trip hides
    // behind the ~320ms animation instead of a spinner afterwards. With a credit
    // we auto-reveal the next question (the credit is spent ONLY here, on a
    // committed forward swipe, never while merely reading the daily); without one
    // we peek the teaser for the paywall. Both are awaited after the animation.
    // `willLandOnSlot` is exact: nothing mutates the deck during the animation
    // (we are the only writer and have not appended yet), so it equals the
    // post-animation slot check — the credit is never spent for a swipe that
    // ends up elsewhere.
    final willLandOnSlot = (idx + 1) >= deckLen;
    final hasCredit = ref.read(freeUnlockCreditsProvider) >= 1;
    if (willLandOnSlot && !_exhausted) {
      if (hasCredit) {
        _pendingRevealResult = null;
        _pendingRevealError = null;
        _pendingRevealDone = false;
        final reveal = ref.read(questionRepositoryProvider).revealFreeQuestion();
        _pendingReveal = reveal;
        // Record the outcome as it arrives so the post-animation step can skip
        // the spinner when the reveal already won the race against the animation.
        reveal
            .then(
              (q) => _pendingRevealResult = q,
              onError: (Object e) => _pendingRevealError = e,
            )
            .whenComplete(() => _pendingRevealDone = true);
      } else if (_peeked == null && _peekFuture == null) {
        // No eager prefetch yet (e.g. a very fast swipe) — start the peek now so
        // it at least overlaps the wind-out animation.
        _startPeek();
      }
    }

    _animating = true;
    await _animateOut(direction);
    if (!mounted) {
      _animating = false;
      return;
    }
    notifier.forwardLinear();

    if (!ref.read(isAtRevealSlotProvider)) {
      // Landed on an already-revealed question — step straight onto it.
      _settleIn(ref.read(currentQuestionProvider));
      _animating = false;
      return;
    }

    // On the reveal slot. Apply whatever we pre-started during the animation.
    final pendingReveal = _pendingReveal;
    _pendingReveal = null;
    if (pendingReveal != null) {
      if (_pendingRevealDone) {
        // The reveal beat the animation — paint it in the same frame, no spinner
        // and no paywall flash (these setStates coalesce into one rebuild).
        _animating = false;
        _settleIn(null); // snap the transform back to centre
        await _applyRevealResult(
          _pendingRevealResult,
          _pendingRevealError,
          viaAd: false,
        );
      } else {
        // Slower than the animation: show the brief spinner until it lands.
        setState(() => _revealing = true);
        _settleIn(ref.read(currentQuestionProvider));
        _animating = false;
        await _applyReveal(pendingReveal, viaAd: false);
      }
    } else {
      // No credit: show the paywall. Its teaser is usually already prefetched
      // (instant); only a swipe that beat the prefetch waits on the peek here.
      _settleIn(ref.read(currentQuestionProvider));
      _animating = false;
      await _peekNext();
    }
  }

  /// Eagerly prefetches the next teaser while the user is still parked on the
  /// last item of the feed (the daily, or the most recent revealed question), so
  /// the reveal-slot paywall is instant instead of waiting on a round-trip. Only
  /// for a free user who would actually hit the paywall: premium never does, and
  /// a user holding the daily credit auto-reveals (consuming) rather than peeks,
  /// so peeking ahead for them would be wasted. Cheap and idempotent — a single
  /// in-flight peek is kept and reused. Called from [build].
  void _maybePrefetchPeek() {
    if (_animating || ref.read(isPremiumProvider)) return;
    if (_peeked != null || _peekFuture != null) return; // already have / getting it
    final deck = ref.read(questionDeckProvider);
    if (deck.isEmpty) return;
    if (ref.read(questionIndexProvider) != deck.length - 1) return; // not the last item
    if (ref.read(freeUnlockCreditsProvider) >= 1) return; // a credit reveals, not peeks
    _startPeek();
  }

  /// Fires a peek and resolves it into [_peeked] whenever it lands — even if no
  /// one is awaiting (the eager prefetch case). Stores the future in [_peekFuture]
  /// so a concurrent swipe reuses it. A null result (ran out) is left for
  /// [_peekNext] / the slot to turn into the "no more" state.
  Future<({String id, String teaser})?> _startPeek() {
    final future = ref.read(questionRepositoryProvider).peekNextQuestion();
    _peekFuture = future;
    future
        .then((peeked) {
          if (!mounted || !identical(_peekFuture, future)) return;
          _peekFuture = null;
          if (peeked != null && _peeked == null) {
            setState(() => _peeked = peeked);
          }
        })
        .catchError((Object e) {
          debugPrint('peek failed: $e');
          if (mounted && identical(_peekFuture, future)) _peekFuture = null;
          return null;
        });
    return future;
  }

  /// Ensures the paywall has its teaser, awaiting the peek only when it isn't
  /// ready yet. Returns instantly when the teaser was already prefetched, so the
  /// common path shows no spinner; an empty result marks the slot "exhausted".
  Future<void> _peekNext() async {
    if (_peeked != null) return; // already prefetched — instant paywall
    final future = _peekFuture ?? _startPeek();
    setState(() => _peeking = true);
    try {
      final peeked = await future;
      if (!mounted) return;
      setState(() {
        _peeking = false;
        if (peeked != null) {
          _peeked = peeked;
        } else {
          _exhausted = true;
        }
      });
    } catch (e) {
      debugPrint('peek failed: $e');
      if (!mounted) return;
      setState(() => _peeking = false); // paywall shows without a teaser
    }
  }

  /// Accelerates the current text off the swiped edge, fading as it goes, then
  /// holds an empty canvas for a beat before the next content assembles.
  Future<void> _animateOut(int direction) async {
    final exitEnd = Offset(1.5 * direction, 0);
    _offset = Tween(
      begin: Offset.zero,
      end: exitEnd,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
    _opacity = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    await _controller.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 80));
  }

  /// Snaps the outer transform back to centre and (when given) paints [q].
  void _settleIn(Question? q) {
    setState(() {
      _offset = const AlwaysStoppedAnimation(Offset.zero);
      _opacity = const AlwaysStoppedAnimation(1);
      if (q != null) _displayed = q;
    });
  }

  /// Reveals the next unseen question — via the daily credit or after an ad —
  /// and appends it to this session's feed. The index already points at the new
  /// question's slot, so appending lands the user on it. Empty result => the
  /// user has run out for now.
  Future<void> _reveal({required bool viaAd, String? questionId}) {
    final repo = ref.read(questionRepositoryProvider);
    final future = viaAd
        ? repo.revealAdQuestion(questionId: questionId)
        : repo.revealFreeQuestion();
    return _applyReveal(future, viaAd: viaAd);
  }

  /// Awaits an in-flight reveal [future] (started here or earlier, in parallel
  /// with the wind-out animation) and paints its result.
  Future<void> _applyReveal(
    Future<Question?> future, {
    required bool viaAd,
  }) async {
    Question? q;
    Object? error;
    try {
      q = await future;
    } catch (e) {
      error = e;
    }
    await _applyRevealResult(q, error, viaAd: viaAd);
  }

  /// Plays the lock-opening flourish over the canvas: a big padlock fades in,
  /// its shackle swings open, then it fades out — the moment a freely-unlocked
  /// question is "released" before it assembles. Awaited on the reveal path so
  /// the question only starts falling once the lock has opened.
  Future<void> _playLockReveal() async {
    if (!mounted) return;
    setState(() => _lockRevealing = true);
    await _lockController.forward(from: 0);
  }

  /// Paints a resolved reveal: appends the revealed [q] to this session's feed
  /// (which grows the deck and steps the user off the slot onto it), or shows the
  /// "exhausted" / error state. On a free (credit) unlock it first plays the
  /// lock-opening flourish ([_playLockReveal]) so the padlock visibly opens
  /// before the question assembles; an ad reveal skips it (the ad was
  /// interruption enough) and paints straight away.
  Future<void> _applyRevealResult(
    Question? q,
    Object? error, {
    required bool viaAd,
  }) async {
    if (!mounted) return;
    if (error != null) {
      debugPrint('reveal failed: $error');
      _notify(context.l10n.revealFailed, type: ToastType.error);
      // Re-sync the server's view of the credit. A free reveal can fail because
      // the client thought it had a credit but the server disagreed (already
      // spent on another device, or stale after a UTC-midnight rollover). Without
      // this the next forward swipe re-reads the same stale credit and re-fires
      // the doomed reveal — an infinite retry loop. Re-syncing drops the credit
      // to 0 so the slot falls through to the ad / PRO paywall instead.
      ref.invalidate(userStatsProvider);
      // Stay on the slot; with _revealing cleared the paywall shows again so the
      // user can retry via ad / PRO.
      setState(() => _revealing = false);
      return;
    }
    if (q == null) {
      setState(() {
        _revealing = false;
        _exhausted = true;
      });
      return;
    }

    // Free credit unlock: open the padlock before the question appears.
    if (!viaAd) {
      await _playLockReveal();
      if (!mounted) return;
    }

    ref.read(revealedFeedProvider.notifier).append(q);
    if (!viaAd) ref.invalidate(userStatsProvider); // a credit was spent
    setState(() {
      _revealing = false;
      _lockRevealing = false;
      _peeked = null; // consumed
      _displayed = q;
    });
  }

  /// Watches a rewarded video, then reveals the next unseen question.
  Future<void> _watchAdReveal() async {
    if (_unlocking || _revealing) return;
    setState(() => _unlocking = true);

    final ads = ref.read(rewardedAdServiceProvider);
    if (!ads.isReady) {
      ads.preload();
      _notify(context.l10n.adLoading);
      if (mounted) setState(() => _unlocking = false);
      return;
    }

    // showRewardedAd resolves to whether the reward was actually earned — the
    // reward is captured inside the service and is no longer raced by the
    // dismiss callback (see RewardedAdService). Wrapped so a throw here can't
    // leave the paywall stuck with _unlocking == true (a wedged spinner reads as
    // "it broke" to the user).
    bool earned;
    try {
      earned = await ads.showRewardedAd(
        userId: ref.read(sessionProvider).value?.userId,
        questionId: _peeked?.id,
      );
    } catch (e) {
      debugPrint('showRewardedAd failed: $e');
      earned = false;
    }
    if (!mounted) return; // widget torn down while the ad was on screen

    if (!earned) {
      _notify(context.l10n.adNoReward, type: ToastType.error);
      setState(() => _unlocking = false);
      return;
    }

    // Reward earned. Guarantee a live authenticated session BEFORE the reveal
    // RPC: the JWT can lapse during a 30s ad, or a guest's anon sign-in may have
    // failed silently at launch — either way reveal_ad_question (granted to
    // `authenticated` only) would throw a raw "permission denied" AFTER the user
    // already watched the whole ad. ensureSignedIn is a no-op fast path when a
    // session already exists.
    final userId = await SupabaseService.ensureSignedIn();
    if (!mounted) return;
    if (SupabaseService.isInitialised && userId == null) {
      _notify(context.l10n.noConnection, type: ToastType.error);
      setState(() => _unlocking = false);
      return;
    }

    setState(() {
      _unlocking = false;
      _revealing = true;
    });
    // Reveal the teased question (falls back to random server-side if it's no
    // longer eligible).
    await _reveal(viaAd: true, questionId: _peeked?.id);
  }

  /// Opens the RevenueCat paywall. On a completed purchase the session is
  /// refreshed so the deck switches to the full premium catalog.
  Future<void> _goPremium() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);

    final purchased = await PurchasesService.presentPaywall();
    if (!mounted) return;

    if (purchased) {
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      ref.invalidate(questionsProvider); // load the catalog premium now reads
      setState(() => _unlocking = false);
      // A guest's PRO rides on the anonymous identity — nudge them to save it to
      // a real account so a reinstall / new device can't lose it. No-ops for a
      // user who already has an account.
      await promptSaveProAccount(context, ref);
    } else {
      _notify(context.l10n.purchaseNotCompleted);
      setState(() => _unlocking = false);
    }
  }

  /// Escape hatch from the reveal slot back to the free daily — wired into both
  /// the paywall and the "no more questions" state so neither is a dead end.
  void _backToDaily() {
    if (_unlocking || _revealing) return;
    ref.read(questionIndexProvider.notifier).toDaily();
  }

  /// Restores a previous purchase — the store-required path for someone who
  /// already bought PRO (reinstalled, or a guest now on a fresh anonymous
  /// identity) so they aren't charged twice. Surfaced on the paywall because the
  /// other restore lives in Settings, which a guest can't reach.
  Future<void> _restorePurchases() async {
    if (_unlocking || _revealing) return;
    setState(() => _unlocking = true);

    final restored = await PurchasesService.restorePurchases();
    if (!mounted) return;
    if (restored) {
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      ref.invalidate(questionsProvider); // load the catalog premium now reads
    }
    _notify(
      restored
          ? context.l10n.purchaseRestoredCelebrate
          : context.l10n.noPreviousPurchase,
      type: restored ? ToastType.success : ToastType.info,
    );
    if (mounted) setState(() => _unlocking = false);
  }

  void _notify(String message, {ToastType type = ToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, message, type: type);
  }

  /// Fires as each word of the new question lands. The hook is intentionally
  /// empty for now — this is where a per-word haptic tick will go.
  void _onWordLanded() {
    // TODO(vibration): add a short haptic here, e.g.
    // HapticFeedback.selectionClick(), so each landing word can be felt.
  }

  @override
  Widget build(BuildContext context) {
    final atRevealSlot = ref.watch(isAtRevealSlotProvider);

    // A new signed-in identity invalidates any teaser peeked for the previous one
    // (peek eligibility is per-uuid). Drop it so [_maybePrefetchPeek] re-peeks for
    // the new user rather than teasing a question they may already have seen.
    ref.listen(sessionProvider.select((s) => s.value?.userId), (prev, next) {
      if (prev != next) {
        _peeked = null;
        _peekFuture = null;
      }
    });

    // Keep the painted question in sync with the provider while idle. Assigning
    // the field here (rather than setState) is safe — we are already building.
    final current = ref.watch(currentQuestionProvider);
    if (!_animating && current != null) _displayed = current;

    // Off the slot, clear the in-flight flags so the next slot starts clean.
    // NOTE: we deliberately do NOT null _peeked here — a transient rebuild while
    // the paywall is on screen would otherwise wipe the teaser. It's harmless
    // off the slot (never read), and re-entering the slot re-peeks over it.
    if (!atRevealSlot) {
      _revealing = false;
      _exhausted = false;
      _peeking = false;
    }

    // Warm the next teaser while the user lingers on the last feed item, so the
    // reveal-slot paywall opens instantly instead of after a round-trip.
    _maybePrefetchPeek();

    final width = MediaQuery.of(context).size.width;
    final displayed = _displayed;

    final Widget child;
    if (_lockRevealing) {
      // The lock flourish owns the canvas until the question is ready to fall.
      child = _LockReveal(controller: _lockController);
    } else if (atRevealSlot) {
      if (_revealing || _peeking) {
        child = const _Revealing();
      } else if (_exhausted) {
        child = _NoMoreQuestions(onBackToDaily: _backToDaily);
      } else {
        child = _RevealPaywall(
          teaser: _peeked?.teaser,
          onWatchAd: _watchAdReveal,
          onGetPremium: _goPremium,
          onBackToDaily: _backToDaily,
          onRestore: _restorePurchases,
          busy: _unlocking,
        );
      }
    } else {
      child = FallingWordsText(
        displayed?.questionText ?? '',
        onWordLanded: _onWordLanded,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 100) _advance(velocity > 0 ? 1 : -1);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_offset.value.dx * width, 0),
            child: Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// The lock-opening flourish: a big violet padlock fades in, its shackle swings
/// open around the base of its right leg, then the whole thing fades out — the
/// "released" beat played over the canvas right before a freely-unlocked
/// question assembles. Driven by an external controller (0 → 1) so the caller
/// can await its completion before painting the question.
class _LockReveal extends StatelessWidget {
  const _LockReveal({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final keyholeColor = context.colors.background;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // Pop in with a little overshoot, swing the shackle open mid-way, then
        // grow + fade out at the end.
        final appear = Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));
        final open = Curves.easeOutCubic.transform(
          ((t - 0.40) / 0.32).clamp(0.0, 1.0),
        );
        final exit = Curves.easeIn.transform(
          ((t - 0.80) / 0.20).clamp(0.0, 1.0),
        );
        final fadeIn = (t / 0.18).clamp(0.0, 1.0);
        final opacity = (fadeIn * (1 - exit)).clamp(0.0, 1.0);
        final scale = (0.6 + 0.4 * appear) * (1 + 0.18 * exit);
        // Glow swells as the lock opens, then fades away with the exit.
        final glow = (open * (1 - exit)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              size: const Size(132, 132),
              painter: _LockPainter(
                open: open,
                glow: glow,
                color: AppTheme.spark,
                keyholeColor: keyholeColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the padlock for [_LockReveal]: a rounded body with a punched-out
/// keyhole and a stroked shackle that rotates open around the base of its right
/// leg as [open] runs 0 → 1, with a soft [glow] halo behind it.
class _LockPainter extends CustomPainter {
  _LockPainter({
    required this.open,
    required this.glow,
    required this.color,
    required this.keyholeColor,
  });

  /// 0 = closed, 1 = fully open (shackle swung up and back).
  final double open;

  /// 0 = no halo, 1 = full halo.
  final double glow;

  /// The padlock fill + shackle colour.
  final Color color;

  /// Colour used to punch the keyhole out of the body (the canvas behind it).
  final Color keyholeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final w = size.width;

    // Body: a rounded rectangle filling the lower portion of the box.
    final bodyW = w * 0.62;
    final bodyH = size.height * 0.46;
    final bodyTop = size.height * 0.50;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - bodyW / 2, bodyTop, bodyW, bodyH),
      Radius.circular(w * 0.10),
    );

    // Soft halo behind everything, brightest as the lock opens.
    if (glow > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.45 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 * glow + 6);
      canvas.drawCircle(Offset(cx, size.height * 0.5), w * 0.42, glowPaint);
    }

    // Shackle — drawn first so the body overlaps the bottoms of its legs.
    final shackleR = bodyW * 0.34;
    final legBottom = bodyTop + 2; // tuck slightly under the body's top edge
    final shTop = bodyTop - shackleR * 1.15;
    final shacklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.save();
    // Pivot at the base of the RIGHT leg; opening swings the shackle up and back
    // around it and lifts it clear of the body.
    final pivot = Offset(cx + shackleR, legBottom);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-open * 0.55);
    canvas.translate(0, -open * shackleR * 0.5);
    canvas.translate(-pivot.dx, -pivot.dy);

    final shackle = Path()
      ..moveTo(cx - shackleR, legBottom)
      ..lineTo(cx - shackleR, shTop)
      ..arcToPoint(
        Offset(cx + shackleR, shTop),
        radius: Radius.circular(shackleR),
      )
      ..lineTo(cx + shackleR, legBottom);
    canvas.drawPath(shackle, shacklePaint);
    canvas.restore();

    // Body fill on top of the legs.
    canvas.drawRRect(bodyRect, Paint()..color = color);

    // Keyhole punched out of the body: a circle over a tapered slot.
    final khCenter = Offset(cx, bodyTop + bodyH * 0.40);
    final khPaint = Paint()..color = keyholeColor;
    canvas.drawCircle(khCenter, bodyW * 0.12, khPaint);
    final slot = Path()
      ..moveTo(khCenter.dx - bodyW * 0.05, khCenter.dy)
      ..lineTo(khCenter.dx + bodyW * 0.05, khCenter.dy)
      ..lineTo(khCenter.dx + bodyW * 0.085, khCenter.dy + bodyH * 0.32)
      ..lineTo(khCenter.dx - bodyW * 0.085, khCenter.dy + bodyH * 0.32)
      ..close();
    canvas.drawPath(slot, khPaint);
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      old.open != open ||
      old.glow != glow ||
      old.color != color ||
      old.keyholeColor != keyholeColor;
}

/// The brief placeholder shown while a reveal RPC is in flight on the slot.
class _Revealing extends StatelessWidget {
  const _Revealing();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.spark,
          ),
        ),
      ],
    );
  }
}

/// Shown on the reveal slot when the user has run out of eligible questions.
/// Carries its own "back to the daily" action so it is never a dead end — the
/// user has consumed every ad/credit-revealable question, so the only forward
/// path left is PRO, and the only sideways path is back to today's free daily.
class _NoMoreQuestions extends StatelessWidget {
  const _NoMoreQuestions({required this.onBackToDaily});

  final VoidCallback onBackToDaily;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, color: context.colors.subtle, size: 40),
        const SizedBox(height: 16),
        Text(
          context.l10n.noMoreTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.noMoreBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.subtle, fontSize: 14),
        ),
        const SizedBox(height: 28),
        _BackToDailyLink(onTap: onBackToDaily),
      ],
    );
  }
}

/// A borderless "← Wróć do pytania dnia" link used on the reveal-slot states,
/// so the paywall and the "no more" screen each carry their own visible escape
/// back to today's free daily instead of relying on a faint bottom-of-screen
/// link the user may not notice.
class _BackToDailyLink extends StatelessWidget {
  const _BackToDailyLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.colors.subtle,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: Text(context.l10n.backToDailyQuestion),
    );
  }
}

/// The reveal-slot paywall: watch a rewarded ad to reveal the next question, or
/// go PRO for unlimited reading. [busy] disables both and shows a spinner while
/// an ad or purchase is in flight.
class _RevealPaywall extends StatelessWidget {
  const _RevealPaywall({
    required this.onWatchAd,
    required this.onGetPremium,
    required this.onBackToDaily,
    required this.onRestore,
    required this.busy,
    this.teaser,
  });

  final VoidCallback onWatchAd;
  final VoidCallback onGetPremium;
  final VoidCallback onBackToDaily;
  final VoidCallback onRestore;
  final bool busy;

  /// First couple of words of the next question (from `peek_next_question`),
  /// teased above the CTAs. Falls back to a generic line when absent.
  final String? teaser;

  @override
  Widget build(BuildContext context) {
    final tease = teaser?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tease.isNotEmpty)
          StyledQuestionText('$tease…')
        else
          Text(
            context.l10n.nextQuestionWaiting,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          context.l10n.watchAdToReveal,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.subtle, fontSize: 14),
        ),
        const SizedBox(height: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UnlockButton(
                icon: Icons.play_circle_outline,
                label: context.l10n.unlockWithAd,
                onTap: busy ? null : onWatchAd,
              ),
              const SizedBox(height: 12),
              _UnlockButton(
                icon: Icons.workspace_premium_outlined,
                label: context.l10n.goPro,
                onTap: busy ? null : onGetPremium,
                primary: true,
              ),
              // Reserve room for the in-flight spinner so the buttons don't jump
              // when an ad loads or the paywall resolves.
              SizedBox(
                height: 30,
                child: Center(
                  child: busy
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.subtle,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Visible escape back to the free daily, so a user who doesn't want to
        // watch an ad isn't cornered on the paywall.
        _BackToDailyLink(onTap: busy ? () {} : onBackToDaily),
        // Store-required restore path — reachable here because a guest can't
        // open Settings (where the other restore lives).
        TextButton(
          onPressed: busy ? null : onRestore,
          style: TextButton.styleFrom(
            foregroundColor: context.colors.subtle,
            textStyle: const TextStyle(fontSize: 13),
          ),
          child: Text(context.l10n.restorePurchase),
        ),
      ],
    );
  }
}

/// One of the two paywall CTAs, styled to the app's language: a rounded pill
/// with an icon + uppercase label. [primary] paints it in the signature violet
/// "spark" with a soft glow (the recommended PRO path); otherwise it sits on the
/// muted accent surface. A null [onTap] dims it.
class _UnlockButton extends StatelessWidget {
  const _UnlockButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  static final BorderRadius _radius = BorderRadius.circular(30);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: primary
              ? const [
                  BoxShadow(
                    color: Color(0x558B5CF6),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: primary ? AppTheme.spark : context.colors.accent,
          borderRadius: _radius,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: context.colors.ink, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
