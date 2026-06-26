import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/screens/auth_screen.dart';
import '../widgets/onboarding_glyph_bubble.dart';
import '../widgets/onboarding_intro_card.dart';
import '../widgets/onboarding_primary_button.dart';
import '../widgets/spark_logo.dart';
import '../widgets/taste_vote_card.dart';

/// The first-launch tutorial: a swipeable deck that welcomes the user, walks
/// through the headline features (daily, streak, unlocks, tidbits) and ends on
/// the account choice — start anonymously, or sign in to keep progress.
///
/// It owns no persistence; reaching the end (via either choice) calls [onFinish],
/// and `AppEntry` records that the tutorial is done and swaps in the live app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  /// Invoked once the user is through onboarding — after picking a path on the
  /// final card (anonymous) or after the sign-in sheet closes.
  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  /// Number of intro cards shown before the final account-choice page. Set from
  /// the page list each build (it's constant in practice); the choice card sits
  /// at this index.
  int _introCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isChoicePage => _index >= _introCount;

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// "Skip" jumps straight to the account-choice card (the last page).
  void _skip() {
    _controller.animateToPage(
      _introCount,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _signIn() async {
    // The sheet handles its own success/cancel; either way the tutorial is done
    // afterwards, so land the user on the daily.
    await showAuthSheet(context);
    if (mounted) widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // A deliberately short funnel: a warm welcome, ONE feature card (the daily),
    // then the real moment — a juicy question to actually vote on. The taste card
    // is the aha; everything before it is kept brief so the user reaches it fast.
    final introCards = <Widget>[
      OnboardingIntroCard(
        glyph: const SparkLogo(size: 52),
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
      ),
      OnboardingIntroCard(
        glyph: const OnboardingGlyphBubble(
          icon: Icons.wb_sunny_rounded,
          color: AppTheme.spark,
        ),
        title: l10n.onboardingDailyTitle,
        body: l10n.onboardingDailyBody,
      ),
    ];

    // The interactive "taste" vote sits last among the intro pages, right before
    // the account choice. The user must vote (or skip) to move on, so the split
    // reveal — the payoff — isn't missed; voting unveils its own "Continue".
    final votePage = TasteVoteCard(onContinue: _next);

    // Account choice comes after the taste vote.
    _introCount = introCards.length + 1; // intro cards + the taste vote page
    final votePageIndex = _introCount - 1;

    final pageCount = _introCount + 1; // + the account-choice card

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: a quiet "Skip" that jumps to the account choice. Hidden on
            // the choice page itself (nothing left to skip).
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isChoicePage ? 0 : 1,
                  child: TextButton(
                    onPressed: _isChoicePage ? null : _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.subtle,
                    ),
                    child: Text(l10n.onboardingSkip),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  ...introCards,
                  votePage,
                  _ChoiceCard(
                    onStartAnonymous: widget.onFinish,
                    onSignIn: _signIn,
                  ),
                ],
              ),
            ),
            // Progress dots + the "Next" CTA on intro pages; the choice card
            // carries its own buttons, so only the dots remain there.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  _Dots(count: pageCount, index: _index),
                  const SizedBox(height: 20),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    // The taste-vote page carries its own "Continue" (revealed
                    // after voting) and the choice page its own buttons, so the
                    // global "Next" only drives the plain intro cards.
                    child: (_isChoicePage || _index == votePageIndex)
                        ? const SizedBox(width: double.infinity)
                        : OnboardingPrimaryButton(
                            label: l10n.onboardingNext,
                            onPressed: _next,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The final card: the user picks how to start. Sign-in is the highlighted path
/// (it saves progress); starting anonymously is the quieter secondary option.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.onStartAnonymous, required this.onSignIn});

  final VoidCallback onStartAnonymous;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.onboardingChoiceTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.onboardingChoiceBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.subtle,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 36),
          _ChoiceButton(
            label: l10n.onboardingSignInCta,
            hint: l10n.onboardingSignInHint,
            icon: Icons.person_rounded,
            primary: true,
            onTap: onSignIn,
          ),
          const SizedBox(height: 14),
          _ChoiceButton(
            label: l10n.onboardingStartAnon,
            hint: l10n.onboardingStartAnonHint,
            icon: Icons.bolt,
            primary: false,
            onTap: onStartAnonymous,
          ),
        ],
      ),
    );
  }
}

/// A full-width option on the choice card: an icon, a bold label and a small
/// hint underneath. [primary] gives it the orange gradient; otherwise it's a
/// hairline-outlined surface.
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.hint,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = primary ? Colors.white : context.colors.ink;
    final hintColor = primary
        ? Colors.white.withValues(alpha: 0.85)
        : context.colors.subtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                  )
                : null,
            color: primary ? null : context.colors.accent,
            borderRadius: BorderRadius.circular(16),
            border: primary ? null : Border.all(color: context.colors.hairline),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: AppTheme.spark.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: labelColor, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(color: hintColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: labelColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The page-progress dots beneath the deck: the active one stretches into a
/// orange pill, the rest stay small and grey.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.spark
                : context.colors.subtle.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
