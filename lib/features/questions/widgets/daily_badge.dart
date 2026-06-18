import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/question_providers.dart';

/// A small "Daily" pill marking the current question as today's free question.
///
/// It only appears while the question on screen is today's scheduled daily (see
/// [isShowingDailyProvider]); swiping on to the gated deck fades it away. The
/// violet "spark" wash and glow match the "go deeper" affordance so the free
/// daily reads as the highlighted, no-paywall question.
///
/// Label follows the active locale — Polish shows "PYTANIE DNIA", everything
/// else falls back to "DAILY".
class DailyBadge extends ConsumerWidget {
  const DailyBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDaily = ref.watch(isShowingDailyProvider);
    final isPolish = Localizations.localeOf(context).languageCode == 'pl';

    // Fade + slight scale so the badge appears with the daily and slips away as
    // the user swipes to a non-daily question, rather than popping in/out.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(animation),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
      child: isDaily
          ? _Pill(label: isPolish ? 'PYTANIE DNIA' : 'DAILY')
          : const SizedBox.shrink(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Faint violet wash + hairline so the pill sits softly on the black
        // canvas, with a small halo to make it feel "lit".
        color: const Color(0x148B5CF6),
        border: Border.all(color: const Color(0x408B5CF6)),
        boxShadow: const [
          BoxShadow(color: Color(0x338B5CF6), blurRadius: 14, spreadRadius: -4),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wb_sunny_rounded, color: AppTheme.spark, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
