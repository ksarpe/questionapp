import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/question.dart';
import '../../../services/purchases_service.dart';
import '../../account/providers/session_providers.dart';
import '../../account/providers/stats_providers.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [direction] is the sign of the swipe: -1 leftward, +1 rightward.
  Future<void> _advance(int direction) async {
    if (_animating || _unlocking || _revealing || _peeking) return;

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
    _animating = true;
    await _animateOut(direction);
    if (!mounted) {
      _animating = false;
      return;
    }
    notifier.forwardLinear();

    final landedOnSlot = ref.read(isAtRevealSlotProvider);
    final hasCredit = ref.read(freeUnlockCreditsProvider) >= 1;
    // Set the slot's state BEFORE settling in so there's no flash of the generic
    // "next question" text: with a credit we auto-reveal (spinner), otherwise we
    // peek the teaser (spinner until it arrives).
    if (landedOnSlot && hasCredit) {
      _revealing = true;
    } else if (landedOnSlot) {
      _peeking = true;
    }
    _settleIn(ref.read(currentQuestionProvider));
    _animating = false;

    if (landedOnSlot && hasCredit) {
      await _reveal(viaAd: false);
    } else if (landedOnSlot) {
      await _peekNext(); // fetch the teaser for the paywall
    }
  }

  /// Peeks the next question (id + teaser) to bait the paywall, without revealing
  /// it. Empty result => the user has run out, so the slot shows the "no more"
  /// state instead.
  Future<void> _peekNext() async {
    setState(() => _peeking = true);
    try {
      final peeked = await ref.read(questionRepositoryProvider).peekNextQuestion();
      if (!mounted) return;
      setState(() {
        _peeking = false;
        _peeked = peeked;
        if (peeked == null) _exhausted = true;
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
  Future<void> _reveal({required bool viaAd, String? questionId}) async {
    try {
      final repo = ref.read(questionRepositoryProvider);
      final q = viaAd
          ? await repo.revealAdQuestion(questionId: questionId)
          : await repo.revealFreeQuestion();
      if (!mounted) return;

      if (q == null) {
        setState(() {
          _revealing = false;
          _exhausted = true;
        });
        return;
      }

      ref.read(revealedFeedProvider.notifier).append(q);
      if (!viaAd) ref.invalidate(userStatsProvider); // a credit was spent
      setState(() {
        _revealing = false;
        _peeked = null; // consumed
        _displayed = q;
      });
    } catch (e) {
      debugPrint('reveal failed: $e');
      if (!mounted) return;
      _notify('Nie udało się odsłonić pytania — spróbuj ponownie.');
      // Stay on the slot; with _revealing cleared the paywall shows again so the
      // user can retry via ad / PRO.
      setState(() => _revealing = false);
    }
  }

  /// Watches a rewarded video, then reveals the next unseen question.
  Future<void> _watchAdReveal() async {
    if (_unlocking || _revealing) return;
    setState(() => _unlocking = true);

    final ads = ref.read(rewardedAdServiceProvider);
    if (!ads.isReady) {
      ads.preload();
      _notify('Reklama jeszcze się ładuje — spróbuj za chwilę.');
      if (mounted) setState(() => _unlocking = false);
      return;
    }

    var earned = false;
    await ads.showRewardedAd(
      onReward: () => earned = true,
      userId: ref.read(sessionProvider).value?.userId,
    );
    if (!mounted) return;

    if (earned) {
      setState(() {
        _unlocking = false;
        _revealing = true;
      });
      // Reveal the teased question (falls back to random server-side if it's no
      // longer eligible).
      await _reveal(viaAd: true, questionId: _peeked?.id);
    } else {
      _notify('Brak nagrody — obejrzyj całe wideo, aby odblokować.');
      setState(() => _unlocking = false);
    }
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
    } else {
      _notify('Zakup nie został dokończony.');
    }
    if (mounted) setState(() => _unlocking = false);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

    final width = MediaQuery.of(context).size.width;
    final displayed = _displayed;

    final Widget child;
    if (atRevealSlot) {
      if (_revealing || _peeking) {
        child = const _Revealing();
      } else if (_exhausted) {
        child = const _NoMoreQuestions();
      } else {
        child = _RevealPaywall(
          teaser: _peeked?.teaser,
          onWatchAd: _watchAdReveal,
          onGetPremium: _goPremium,
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
class _NoMoreQuestions extends StatelessWidget {
  const _NoMoreQuestions();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, color: AppTheme.subtle, size: 40),
        SizedBox(height: 16),
        Text(
          'To wszystkie pytania na teraz',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Wróć po więcej wkrótce.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.subtle, fontSize: 14),
        ),
      ],
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
    required this.busy,
    this.teaser,
  });

  final VoidCallback onWatchAd;
  final VoidCallback onGetPremium;
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
          const Text(
            'Kolejne pytanie czeka',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 10),
        const Text(
          'Obejrzyj reklamę, aby odsłonić nowe pytanie.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.subtle, fontSize: 14),
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
                label: 'Odblokuj reklamą',
                onTap: busy ? null : onWatchAd,
              ),
              const SizedBox(height: 12),
              _UnlockButton(
                icon: Icons.workspace_premium_outlined,
                label: 'Przejdź na PRO',
                onTap: busy ? null : onGetPremium,
                primary: true,
              ),
              // Reserve room for the in-flight spinner so the buttons don't jump
              // when an ad loads or the paywall resolves.
              SizedBox(
                height: 30,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.subtle,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
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
          color: primary ? AppTheme.spark : AppTheme.accent,
          borderRadius: _radius,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppTheme.ink, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.ink,
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
