import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'animated_flame_icon.dart' show kFlame, kGrace;

/// A one-shot confetti burst that rains across the whole overlay and then stops.
///
/// Hand-rolled (a [CustomPainter] driven by one [AnimationController]) rather
/// than a dependency, to match the app's other bespoke animations (the living
/// flame, the custom toast) and keep the celebration self-contained. Each piece
/// gets a fixed random profile at construction — column, colour, size, fall
/// speed, sideways drift and spin — so the field looks organic without any
/// per-frame allocation.
///
/// Plays once on mount and holds on the last (faded-out) frame; the caller
/// shows it only when motion is allowed, so there's no reduced-motion path here.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    this.count = 90,
    this.duration = const Duration(milliseconds: 2600),
  });

  /// Number of confetti pieces.
  final int count;

  /// How long the fall lasts before the field has settled past the bottom.
  final Duration duration;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Piece> _pieces;

  // The festive palette: the brand orange plus the warm/cool streak accents and
  // the vote colours, so the burst feels like "the app" celebrating.
  static const List<Color> _palette = [
    AppTheme.spark,
    kFlame,
    kGrace,
    AppTheme.yes,
    AppTheme.no,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _pieces = List.generate(widget.count, (i) {
      return _Piece(
        x: rnd.nextDouble(),
        color: _palette[rnd.nextInt(_palette.length)],
        size: 6 + rnd.nextDouble() * 7,
        aspect: 0.45 + rnd.nextDouble() * 0.9,
        // Stagger the starts so the field doesn't drop as one sheet.
        delay: rnd.nextDouble() * 0.28,
        fall: 0.85 + rnd.nextDouble() * 0.5,
        driftAmp: 12 + rnd.nextDouble() * 26,
        driftPhase: rnd.nextDouble() * math.pi * 2,
        driftFreq: 2 + rnd.nextDouble() * 2.5,
        spin: (rnd.nextBool() ? 1 : -1) * (1.5 + rnd.nextDouble() * 3),
      );
    });
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _controller.value),
          ),
        ),
      ),
    );
  }
}

/// One confetti piece's fixed random profile (see [ConfettiOverlay]).
class _Piece {
  _Piece({
    required this.x,
    required this.color,
    required this.size,
    required this.aspect,
    required this.delay,
    required this.fall,
    required this.driftAmp,
    required this.driftPhase,
    required this.driftFreq,
    required this.spin,
  });

  /// Horizontal column as a fraction of width (0..1).
  final double x;
  final Color color;

  /// Longer edge length in logical px.
  final double size;

  /// Short/long edge ratio, so pieces read as little rectangles, not squares.
  final double aspect;

  /// Fraction of the timeline before this piece starts falling (0..~0.3).
  final double delay;

  /// Fall-speed multiplier.
  final double fall;

  /// Sideways sway amplitude (px) and its phase/frequency.
  final double driftAmp;
  final double driftPhase;
  final double driftFreq;

  /// Total turns over the piece's life (signed for direction).
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);

  final List<_Piece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in pieces) {
      // Local life 0..1, shifted by the piece's start delay.
      final t = (progress - p.delay) / (1 - p.delay);
      if (t <= 0) continue;
      final tc = t.clamp(0.0, 1.0);

      // Fall from just above the top to just past the bottom, accelerating
      // slightly (gravity) via the >1 exponent.
      final y = (-0.08 + math.pow(tc, 1.25) * 1.2 * p.fall) * size.height;
      if (y > size.height + p.size) continue;

      final x = p.x * size.width +
          math.sin(tc * p.driftFreq * math.pi * 2 + p.driftPhase) * p.driftAmp;

      // Fade out over the last fifth so pieces dissolve rather than vanish.
      final opacity = tc < 0.8 ? 1.0 : (1 - (tc - 0.8) / 0.2).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tc * p.spin * math.pi * 2);
      paint.color = p.color.withValues(alpha: opacity);
      final w = p.size * p.aspect;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: p.size),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
