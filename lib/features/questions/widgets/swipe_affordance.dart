import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';

/// A gentle, looping "swipe left for more" affordance pinned to the right edge of
/// the canvas: two chevrons that nudge leftward and brighten on a slow loop. The
/// motion — not colour — is what draws the eye, so it stays tasteful against the
/// clean question canvas and never competes with the violet "go deeper" glow.
///
/// Purely decorative: wrapped in [IgnorePointer] so the swipe gesture underneath
/// (handled by `WindQuestionView`) passes straight through, with a [Semantics]
/// label so screen readers still announce the gesture. The caller shows it only
/// until the user has swiped forward once (see `swipeDiscoveredControllerProvider`),
/// after which the canvas is left clean.
class SwipeAffordance extends StatefulWidget {
  const SwipeAffordance({super.key});

  @override
  State<SwipeAffordance> createState() => _SwipeAffordanceState();
}

class _SwipeAffordanceState extends State<SwipeAffordance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: context.l10n.swipeHint,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // One eased there-and-back pass per loop: brightest, and furthest
                // left, at the mid-point (t == 1).
                final t = Curves.easeInOut.transform(
                  1 - (2 * _controller.value - 1).abs(),
                );
                return Transform.translate(
                  offset: Offset(-10 * t, 0),
                  child: Opacity(
                    opacity: 0.30 + 0.55 * t,
                    child: Icon(
                      Icons.keyboard_double_arrow_left,
                      size: 30,
                      color: context.colors.subtle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
