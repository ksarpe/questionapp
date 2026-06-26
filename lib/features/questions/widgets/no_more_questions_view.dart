import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import 'back_to_daily_link.dart';

/// Shown on the reveal slot when the user has run out of eligible questions.
/// Carries its own "back to the daily" action so it is never a dead end — the
/// user has consumed every ad/credit-revealable question, so the only forward
/// path left is PRO, and the only sideways path is back to today's free daily.
class NoMoreQuestions extends StatelessWidget {
  const NoMoreQuestions({super.key, required this.onBackToDaily});

  final VoidCallback onBackToDaily;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline,
          color: context.colors.subtle,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.noMoreTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.noMoreBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.subtle, fontSize: 14),
        ),
        const SizedBox(height: 28),
        BackToDailyLink(onTap: onBackToDaily),
      ],
    );
  }
}
