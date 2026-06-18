import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A small tab that pokes out from the right edge of the screen, showing a hand
/// rotated 90° to the left. Tapping it — or pulling it leftwards — slides the
/// "Smaczki" panel ([SmaczkiPanel], wired as the Scaffold's endDrawer) into view.
class HintHandle extends StatelessWidget {
  const HintHandle({super.key});

  void _open(BuildContext context) => Scaffold.of(context).openEndDrawer();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      // A leftward pull (negative velocity) opens the panel, like grabbing it.
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -50) _open(context);
      },
      // Generous padding keeps the tap/drag target comfortable without a
      // visible background — just the bare hand sitting on the canvas.
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Transform.rotate(
          // 90° counter-clockwise, so the fingers point left toward the text.
          angle: -math.pi / 2,
          child: const Icon(
            Icons.back_hand,
            color: AppTheme.ink,
            size: 48,
          ),
        ),
      ),
    );
  }
}
