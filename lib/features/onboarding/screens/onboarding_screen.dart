import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/screens/auth_screen.dart';
import '../widgets/onboarding_choice_card.dart';
import '../widgets/onboarding_dots.dart';
import '../widgets/onboarding_glyph_bubble.dart';
import '../widgets/onboarding_intro_card.dart';
import '../widgets/onboarding_notifications_card.dart';
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

    // The interactive "taste" vote sits among the intro pages. The user must vote
    // (or skip) to move on, so the split reveal — the payoff — isn't missed;
    // voting unveils its own "Continue".
    final votePage = TasteVoteCard(onContinue: _next);

    // Straight after the aha, while the app still feels fresh, we ask to turn on
    // the daily reminder. The card carries its own buttons (Enable / Not now),
    // both of which advance to the account choice.
    final notifyPage = OnboardingNotificationsCard(onContinue: _next);

    final votePageIndex = introCards.length;
    final notifyPageIndex = introCards.length + 1;

    // Account choice comes after the taste vote + the notifications ask.
    _introCount = introCards.length + 2;

    final pageCount = _introCount + 1; // + the account-choice card

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        // Cap the content width and centre it so cards and buttons don't stretch
        // edge-to-edge on tablets. Matches the auth sheet's 480 cap; a no-op on
        // phones, which are narrower.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                      notifyPage,
                      OnboardingChoiceCard(
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
                      OnboardingDots(count: pageCount, index: _index),
                      const SizedBox(height: 20),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        // The taste-vote page (its "Continue" revealed after voting),
                        // the notifications page and the choice page each carry their
                        // own buttons, so the global "Next" only drives the plain
                        // intro cards.
                        child:
                            (_isChoicePage ||
                                _index == votePageIndex ||
                                _index == notifyPageIndex)
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
        ),
      ),
    );
  }
}
