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

    // The pill marks the one no-paywall question — today's daily — and fades
    // away on the gated deck. Fade + slight scale so it slips in/out rather than
    // popping.
    final Widget pill = isDaily
        ? _Pill(
            label: isPolish ? 'PYTANIE DNIA' : 'DAILY',
            icon: Icons.wb_sunny_rounded,
          )
        : const SizedBox.shrink();

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
      child: pill,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

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
            Icon(icon, color: AppTheme.spark, size: 14),
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
