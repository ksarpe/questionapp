import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vote_result.dart';
import '../../questions/widgets/styled_question_text.dart';
import '../../questions/widgets/vote_visuals.dart';
import 'onboarding_primary_button.dart';

/// The onboarding "aha": a real, juicy question the user actually votes on,
/// before they've even chosen an account. Tapping a side flips straight to a
/// believable community split — with a personal "you're with the majority /
/// minority" line — so the very first interaction proves the app's promise
/// instead of describing it.
///
/// This is a no-stakes TASTE: the split is curated (not a live cast), so it works
/// instantly, offline and pre-login, and never touches the streak/credit logic.
/// The real, counting vote happens on the daily right after onboarding. It reuses
/// the exact [VoteButtonsRow] / [VoteResultsRow] visuals so it looks like the
/// real thing.
class TasteVoteCard extends StatefulWidget {
  const TasteVoteCard({super.key, required this.onContinue});

  /// Advances to the account-choice page once the user has had their moment.
  final VoidCallback onContinue;

  @override
  State<TasteVoteCard> createState() => _TasteVoteCardState();
}

class _TasteVoteCardState extends State<TasteVoteCard> {
  /// Curated split for the taste question — believable, and lopsided enough that
  /// landing in the minority feels like a real "huh". TAK is the majority side.
  static const int _yesPct = 63;
  static const int _noPct = 37;

  /// The user's pick, or null before they vote.
  int? _choice;

  void _onVote(int choice) => setState(() => _choice = choice);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choice = _choice;
    final voted = choice != null;

    // Centred, but scrollable so the taller post-vote state (split + line +
    // Continue) never overflows on short screens or with large text.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.onboardingTasteKicker,
              style: const TextStyle(
                color: AppTheme.spark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            StyledQuestionText(l10n.onboardingTasteQuestion),
            const SizedBox(height: 34),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: voted
                  ? Column(
                      key: const ValueKey('taste-result'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VoteResultsRow(
                          result: VoteResult(
                            yesCount: _yesPct,
                            noCount: _noPct,
                            myChoice: choice,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isMajority(choice)
                              ? l10n.onboardingTasteMajority
                              : l10n.onboardingTasteMinority,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Ride the post-vote high with a taste of the second
                        // value pillar: one real smaczek for this very question,
                        // in the same visual language as the in-app panel.
                        Text(
                          l10n.onboardingTasteSmaczekIntro,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.subtle,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SmaczekTeaser(text: l10n.onboardingTasteSmaczek),
                        const SizedBox(height: 24),
                        OnboardingPrimaryButton(
                          label: l10n.onboardingTasteContinue,
                          onPressed: widget.onContinue,
                        ),
                      ],
                    )
                  : VoteButtonsRow(
                      key: const ValueKey('taste-buttons'),
                      busy: false,
                      onVote: _onVote,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// TAK is the majority ([_yesPct] > [_noPct]); the user is "with the majority"
  /// only when their side is the larger one.
  bool _isMajority(int choice) =>
      choice == VoteResult.yes ? _yesPct >= _noPct : _noPct > _yesPct;
}

/// A single smaczek shown right after the taste vote — same look as the cards
/// in the in-app smaczki panel (accent surface, numbered orange dot), so the
/// first encounter with the app's depth already wears its real face.
class _SmaczekTeaser extends StatelessWidget {
  const _SmaczekTeaser({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.spark,
              shape: BoxShape.circle,
            ),
            child: Text(
              '1',
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
