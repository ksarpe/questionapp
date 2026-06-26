import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vote_result.dart';

/// The shared visual language of the binary TAK/NIE vote: the two slanted
/// buttons and the green/red community-split panels with the floating "VS".
///
/// Extracted so the real daily vote ([DailyVotePanel]) and the onboarding
/// "taste" vote render the SAME shapes — the onboarding card has to feel like
/// the real thing for the aha to land. The widgets here are purely presentational
/// (no providers, no network): the caller owns the state and the result, so the
/// same pixels back a live cast and a curated demo split alike.

/// Horizontal slant (in px) applied to the vote shapes so the two sides read as
/// a diagonal `/` split rather than two flat pills.
const double _kSkew = 16;

/// Shared height of the slanted buttons and result panels.
const double _kVoteHeight = 56;

/// The pre-vote state: the two slanted TAK / NIE buttons. [onVote] is handed the
/// chosen side ([VoteResult.yes] / [VoteResult.no]); [busy] dims + disables them
/// while a cast is in flight.
class VoteButtonsRow extends StatelessWidget {
  const VoteButtonsRow({required this.busy, required this.onVote, super.key});

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

/// The post-vote state: the two slanted result panels (green TAK %, red NIE %)
/// with the "VS" badge over the seam and the total beneath. The caller's own
/// side ([VoteResult.myChoice]) is brightened and checked.
class VoteResultsRow extends StatelessWidget {
  const VoteResultsRow({required this.result, super.key});

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
            style: TextStyle(color: context.colors.subtle, fontSize: 12),
          ),
        ],
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
        color: context.colors.accent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _kVoteHeight,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: context.colors.ink,
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
        color: context.colors.background,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.accent, width: 2),
      ),
      child: Text(
        'VS',
        style: TextStyle(
          color: context.colors.ink,
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
