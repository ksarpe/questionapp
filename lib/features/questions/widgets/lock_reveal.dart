import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The lock-opening flourish: a big orange padlock fades in, its shackle swings
/// open around the base of its right leg, then the whole thing fades out — the
/// "released" beat played over the canvas right before a freely-unlocked
/// question assembles. Driven by an external controller (0 → 1) so the caller
/// can await its completion before painting the question.
class LockReveal extends StatelessWidget {
  const LockReveal({super.key, required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final keyholeColor = context.colors.background;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // Pop in with a little overshoot, swing the shackle open mid-way, then
        // grow + fade out at the end.
        final appear = Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));
        final open = Curves.easeOutCubic.transform(
          ((t - 0.40) / 0.32).clamp(0.0, 1.0),
        );
        final exit = Curves.easeIn.transform(
          ((t - 0.80) / 0.20).clamp(0.0, 1.0),
        );
        final fadeIn = (t / 0.18).clamp(0.0, 1.0);
        final opacity = (fadeIn * (1 - exit)).clamp(0.0, 1.0);
        final scale = (0.6 + 0.4 * appear) * (1 + 0.18 * exit);
        // Glow swells as the lock opens, then fades away with the exit.
        final glow = (open * (1 - exit)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              size: const Size(132, 132),
              painter: _LockPainter(
                open: open,
                glow: glow,
                color: AppTheme.spark,
                keyholeColor: keyholeColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the padlock for [LockReveal]: a rounded body with a punched-out
/// keyhole and a stroked shackle that rotates open around the base of its right
/// leg as [open] runs 0 → 1, with a soft [glow] halo behind it.
class _LockPainter extends CustomPainter {
  _LockPainter({
    required this.open,
    required this.glow,
    required this.color,
    required this.keyholeColor,
  });

  /// 0 = closed, 1 = fully open (shackle swung up and back).
  final double open;

  /// 0 = no halo, 1 = full halo.
  final double glow;

  /// The padlock fill + shackle colour.
  final Color color;

  /// Colour used to punch the keyhole out of the body (the canvas behind it).
  final Color keyholeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final w = size.width;

    // Body: a rounded rectangle filling the lower portion of the box.
    final bodyW = w * 0.62;
    final bodyH = size.height * 0.46;
    final bodyTop = size.height * 0.50;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - bodyW / 2, bodyTop, bodyW, bodyH),
      Radius.circular(w * 0.10),
    );

    // Soft halo behind everything, brightest as the lock opens.
    if (glow > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.45 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 * glow + 6);
      canvas.drawCircle(Offset(cx, size.height * 0.5), w * 0.42, glowPaint);
    }

    // Shackle — drawn first so the body overlaps the bottoms of its legs.
    final shackleR = bodyW * 0.34;
    final legBottom = bodyTop + 2; // tuck slightly under the body's top edge
    final shTop = bodyTop - shackleR * 1.15;
    final shacklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.save();
    // Pivot at the base of the RIGHT leg; opening swings the shackle up and back
    // around it and lifts it clear of the body.
    final pivot = Offset(cx + shackleR, legBottom);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-open * 0.55);
    canvas.translate(0, -open * shackleR * 0.5);
    canvas.translate(-pivot.dx, -pivot.dy);

    final shackle = Path()
      ..moveTo(cx - shackleR, legBottom)
      ..lineTo(cx - shackleR, shTop)
      ..arcToPoint(
        Offset(cx + shackleR, shTop),
        radius: Radius.circular(shackleR),
      )
      ..lineTo(cx + shackleR, legBottom);
    canvas.drawPath(shackle, shacklePaint);
    canvas.restore();

    // Body fill on top of the legs.
    canvas.drawRRect(bodyRect, Paint()..color = color);

    // Keyhole punched out of the body: a circle over a tapered slot.
    final khCenter = Offset(cx, bodyTop + bodyH * 0.40);
    final khPaint = Paint()..color = keyholeColor;
    canvas.drawCircle(khCenter, bodyW * 0.12, khPaint);
    final slot = Path()
      ..moveTo(khCenter.dx - bodyW * 0.05, khCenter.dy)
      ..lineTo(khCenter.dx + bodyW * 0.05, khCenter.dy)
      ..lineTo(khCenter.dx + bodyW * 0.085, khCenter.dy + bodyH * 0.32)
      ..lineTo(khCenter.dx - bodyW * 0.085, khCenter.dy + bodyH * 0.32)
      ..close();
    canvas.drawPath(slot, khPaint);
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      old.open != open ||
      old.glow != glow ||
      old.color != color ||
      old.keyholeColor != keyholeColor;
}
