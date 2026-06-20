import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/vote_result.dart';
import '../../account/providers/session_providers.dart';
import '../../account/providers/stats_providers.dart';
import '../../account/screens/auth_screen.dart';
import '../providers/question_providers.dart';

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
    try {
      final result = await ref
          .read(questionRepositoryProvider)
          .castDailyVote(widget.questionId, choice);
      if (!mounted) return;
      // The vote may have moved the streak — refresh the top chip.
      ref.invalidate(userStatsProvider);
      setState(() => _local = result);
    } catch (e) {
      if (!mounted) return;
      final isPolish = Localizations.localeOf(context).languageCode == 'pl';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPolish ? 'Nie udało się zagłosować.' : 'Could not record your vote.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPolish = Localizations.localeOf(context).languageCode == 'pl';
    final hasAccount = ref.watch(
      sessionProvider.select((s) => s.value?.hasAccount ?? false),
    );

    // Guests: show the buttons but never the split. Tapping either side opens the
    // sign-in sheet rather than casting a vote — so no community % leaks out and
    // a vote is only ever recorded for a real account. (No provider read here, so
    // we don't even fetch the split for a guest.)
    if (!hasAccount) {
      return _Buttons(
        isPolish: isPolish,
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
          ? _Results(key: const ValueKey('results'), result: result, isPolish: isPolish)
          : _Buttons(
              key: const ValueKey('buttons'),
              isPolish: isPolish,
              busy: _busy,
              onVote: _vote,
            ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.isPolish,
    required this.busy,
    required this.onVote,
    super.key,
  });

  final bool isPolish;
  final bool busy;
  final void Function(int choice) onVote;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        children: [
          Expanded(
            child: _VoteButton(
              label: isPolish ? 'TAK' : 'YES',
              onTap: busy ? null : () => onVote(VoteResult.yes),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _VoteButton(
              label: isPolish ? 'NIE' : 'NO',
              onTap: busy ? null : () => onVote(VoteResult.no),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result, required this.isPolish, super.key});

  final VoteResult result;
  final bool isPolish;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ResultBar(
            label: isPolish ? 'TAK' : 'YES',
            pct: result.yesPct,
            fraction: result.yesFraction,
            mine: result.myChoice == VoteResult.yes,
          ),
          const SizedBox(height: 8),
          _ResultBar(
            label: isPolish ? 'NIE' : 'NO',
            pct: result.noPct,
            fraction: result.noFraction,
            mine: result.myChoice == VoteResult.no,
          ),
          const SizedBox(height: 6),
          Text(
            isPolish
                ? '${result.total} ${_glosy(result.total)}'
                : '${result.total} ${result.total == 1 ? 'vote' : 'votes'}',
            style: const TextStyle(color: AppTheme.subtle, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _glosy(int n) {
    if (n == 1) return 'głos';
    final lastTwo = n % 100;
    final last = n % 10;
    if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) return 'głosy';
    return 'głosów';
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({
    required this.label,
    required this.pct,
    required this.fraction,
    required this.mine,
  });

  final String label;
  final int pct;
  final double fraction;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final fill = mine ? AppTheme.spark : AppTheme.subtle;
    return Stack(
      children: [
        // Track + animated fill.
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Container(height: 40, color: AppTheme.accent),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 40,
                  color: fill.withValues(alpha: mine ? 0.45 : 0.28),
                ),
              ),
            ],
          ),
        ),
        // Label + percentage on top of the bar.
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_rounded, color: AppTheme.spark, size: 16),
                    ],
                  ],
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
