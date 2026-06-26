import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared rounded shell for the streak and rank stat cards.
class StatCardShell extends StatelessWidget {
  const StatCardShell({super.key, required this.child, this.onTap});

  final Widget child;

  /// When provided, the card becomes tappable (with a matching ripple).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: context.colors.cardSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: context.colors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: child,
          ),
        ),
      ),
    );
  }
}
