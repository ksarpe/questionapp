import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';

/// How long the user must linger on a readable question — without swiping —
/// before the finger demonstration kicks in. Short enough to catch someone who
/// is stuck, long enough that a reader who is simply thinking isn't nagged.
const Duration kSwipeHintLingerDelay = Duration(seconds: 10);

/// A translucent finger that, after the user has stared at a question for
/// [kSwipeHintLingerDelay] without swiping, slides in from the right edge,
/// presses (a soft spark-coloured contact ripple blooms under it), and drags
/// left — the swipe gesture, demonstrated literally. It plays a few unhurried
/// passes and then rests, so it teaches once without nagging.
///
/// Purely decorative: wrapped in [IgnorePointer] so the real swipe underneath
/// (handled by `WindQuestionView`) passes straight through, with a [Semantics]
/// label for screen readers. The caller shows it only on a readable, non-slot
/// question and only until the user has swiped forward once
/// (`swipeDiscoveredControllerProvider`), after which it retires for good.
class SwipeHandHint extends StatefulWidget {
  const SwipeHandHint({super.key});

  @override
  State<SwipeHandHint> createState() => _SwipeHandHintState();
}

class _SwipeHandHintState extends State<SwipeHandHint>
    with SingleTickerProviderStateMixin {
  /// One pass = enter → press → drag → lift → exit.
  late final AnimationController _controller;

  /// Fires once the linger window elapses; cancelled on dispose so a question
  /// the user swipes away from before 10s never starts the hand.
  Timer? _lingerTimer;

  /// The demonstration plays at most this many times, then leaves the canvas
  /// clean. The gesture only needs showing a couple of times to land.
  static const int _maxPasses = 3;
  int _passesPlayed = 0;

  /// False until the linger timer fires — until then we paint nothing (the
  /// chevron affordance is carrying the hint).
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..addStatusListener(_onPassComplete);
    _lingerTimer = Timer(kSwipeHintLingerDelay, _begin);
  }

  void _begin() {
    if (!mounted) return;
    setState(() => _started = true);
    _controller.forward(from: 0);
  }

  void _onPassComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _passesPlayed++;
    if (_passesPlayed >= _maxPasses) return; // rest — the lesson has landed
    // A beat of stillness between passes reads calmer than a tight loop.
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted && _passesPlayed < _maxPasses) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _lingerTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Linear interpolation; local so this widget pulls in no extra imports.
  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Maps [t] onto the 0→1 progress of the segment [a, b], clamped at the ends.
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final subtle = context.colors.subtle;

    return IgnorePointer(
      child: Semantics(
        label: context.l10n.swipeHint,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final v = _controller.value;

            // Horizontal travel, in fractions of screen width relative to the
            // canvas centre: enters from off the right edge, holds in the right
            // third while it presses, drags across to the left third, then exits
            // off the left edge.
            const offRight = 0.58;
            const restRight = 0.24;
            const restLeft = -0.24;
            const offLeft = -0.58;
            final double dxFrac;
            if (v < 0.16) {
              dxFrac = _lerp(
                offRight,
                restRight,
                Curves.easeOutCubic.transform(_seg(v, 0.0, 0.16)),
              );
            } else if (v < 0.72) {
              // Press holds at restRight until 0.30, then the drag runs to 0.72.
              dxFrac = _lerp(
                restRight,
                restLeft,
                Curves.easeInOut.transform(_seg(v, 0.30, 0.72)),
              );
            } else if (v < 0.84) {
              dxFrac = restLeft;
            } else {
              dxFrac = _lerp(
                restLeft,
                offLeft,
                Curves.easeInCubic.transform(_seg(v, 0.84, 1.0)),
              );
            }

            // Fade in on entry, out on exit; solid through the gesture.
            final double opacity = v < 0.16
                ? _seg(v, 0.0, 0.16)
                : (v < 0.84 ? 1.0 : 1 - _seg(v, 0.84, 1.0));

            // A small squash on contact, released as the finger lifts.
            final double scale;
            if (v < 0.18) {
              scale = 1.0;
            } else if (v < 0.30) {
              scale = _lerp(1.0, 0.9, _seg(v, 0.18, 0.30));
            } else if (v < 0.74) {
              scale = 0.9;
            } else if (v < 0.84) {
              scale = _lerp(0.9, 1.0, _seg(v, 0.74, 0.84));
            } else {
              scale = 1.0;
            }

            // The contact ripple: blooms as the finger lands and fades through
            // the drag, so the "touch" registers before the motion does.
            final ripple = _seg(v, 0.18, 0.62);
            final rippleOpacity = (1 - _seg(v, 0.24, 0.70)).clamp(0.0, 1.0);

            return Align(
              // Low on the canvas, roughly where a thumb would reach — below the
              // question text, never across it.
              alignment: const Alignment(0, 0.62),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(dxFrac * width, 0),
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(132, 132),
                          painter: _ContactRipple(
                            progress: ripple,
                            opacity: rippleOpacity,
                            color: AppTheme.spark,
                          ),
                        ),
                        Transform.scale(
                          scale: scale,
                          child: Icon(
                            Icons.touch_app,
                            size: 52,
                            color: subtle.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the soft spark-coloured "touch" under the finger: a blurred glow with
/// a single expanding ring, both fading as [opacity] runs to zero.
class _ContactRipple extends CustomPainter {
  _ContactRipple({
    required this.progress,
    required this.opacity,
    required this.color,
  });

  /// 0 → 1 expansion of the ring.
  final double progress;

  /// 0 → 1 overall visibility; the whole ripple is hidden at 0.
  final double opacity;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOut.transform(progress);
    final r = size.width * (0.16 + 0.30 * eased);

    // Soft inner glow.
    canvas.drawCircle(
      centre,
      r * 0.7,
      Paint()
        ..color = color.withValues(alpha: 0.16 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // The expanding ring.
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = color.withValues(alpha: 0.45 * opacity),
    );
  }

  @override
  bool shouldRepaint(_ContactRipple old) =>
      old.progress != progress ||
      old.opacity != opacity ||
      old.color != color;
}
