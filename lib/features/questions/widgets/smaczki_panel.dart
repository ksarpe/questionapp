import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The "Smaczki" panel — a side sheet that slides in from the right edge,
/// pulled open by the hand handle. For now it holds a placeholder; eventually
/// it will host the discussion prompts ("smaczki") for the current question.
class SmaczkiPanel extends StatelessWidget {
  const SmaczkiPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.back_hand_outlined, color: AppTheme.ink),
                  const SizedBox(width: 12),
                  Text(
                    'Smaczki',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Tu pojawią się smaczki — argumenty i podpowiedzi do dyskusji '
                'wokół bieżącego pytania.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.subtle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
