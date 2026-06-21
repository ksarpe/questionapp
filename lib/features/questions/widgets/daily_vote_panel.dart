import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voteFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
      return _Buttons(
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
          ? _Results(key: const ValueKey('results'), result: result)
          : _Buttons(
              key: const ValueKey('buttons'),
              busy: _busy,
              onVote: _vote,
            ),
    );
  }
}

/// Horizontal slant (in px) applied to the vote shapes so the two sides read as
/// a diagonal `/` split rather than two flat pills.
const double _kSkew = 16;

/// Shared height of the slanted buttons and result panels.
const double _kVoteHeight = 56;

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.busy,
    required this.onVote,
    super.key,
  });

  final bool busy;
  final void Function(int choice) onVote;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Row(
          children: [
            Expanded(
              child: _VoteButton(
                label: context.l10n.voteYes,
                hint: AppTheme.yes,
                slant: _Slant.left,
                onTap: busy ? null : () => onVote(VoteResult.yes),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VoteButton(
                label: context.l10n.voteNo,
                hint: AppTheme.no,
                slant: _Slant.right,
                onTap: busy ? null : () => onVote(VoteResult.no),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.hint,
    required this.slant,
    required this.onTap,
  });

  final String label;

  /// Side colour shown as a thin accent strip so the button previews its meaning.
  final Color hint;
  final _Slant slant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _SkewClipper(slant),
      child: Material(
        color: AppTheme.accent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _kVoteHeight,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                // Thin colour strip at the bottom hinting which side this is.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 4, color: hint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result, super.key});

  final VoteResult result;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The two slanted panels plus a "VS" badge floating over the seam.
          SizedBox(
            height: _kVoteHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ResultPanel(
                        label: context.l10n.voteYes,
                        pct: result.yesPct,
                        color: AppTheme.yes,
                        slant: _Slant.left,
                        mine: result.myChoice == VoteResult.yes,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: _ResultPanel(
                        label: context.l10n.voteNo,
                        pct: result.noPct,
                        color: AppTheme.no,
                        slant: _Slant.right,
                        mine: result.myChoice == VoteResult.no,
                      ),
                    ),
                  ],
                ),
                const _VsBadge(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.votesCount(result.total),
            style: const TextStyle(color: AppTheme.subtle, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.label,
    required this.pct,
    required this.color,
    required this.slant,
    required this.mine,
  });

  final String label;
  final int pct;
  final Color color;
  final _Slant slant;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _SkewClipper(slant),
      child: Container(
        height: _kVoteHeight,
        color: color.withValues(alpha: mine ? 0.30 : 0.16),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_rounded, color: color, size: 13),
                ],
              ],
            ),
            Text(
              '$pct%',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular "VS" badge that sits over the diagonal seam between the panels.
class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accent, width: 2),
      ),
      child: const Text(
        'VS',
        style: TextStyle(
          color: AppTheme.ink,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Which way a slanted shape leans. Both share the same `/` diagonal so the two
/// sides mirror around the central seam.
enum _Slant { left, right }

/// Clips a box into a parallelogram leaning along a `/` diagonal. Both sides
/// share the same lean so the panels stay parallel; [_Slant.left] is the TAK
/// side (seam on its right), [_Slant.right] is the NIE side (seam on its left).
class _SkewClipper extends CustomClipper<Path> {
  const _SkewClipper(this.slant);

  final _Slant slant;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    // Top edge is shifted right by _kSkew relative to the bottom edge → `/`.
    return Path()
      ..moveTo(_kSkew, 0)
      ..lineTo(w, 0)
      ..lineTo(w - _kSkew, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(_SkewClipper oldClipper) => oldClipper.slant != slant;
}
