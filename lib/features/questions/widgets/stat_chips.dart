import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/providers/stats_providers.dart';
import '../providers/question_providers.dart';
import 'rank_sheet.dart';

/// Warm amber used for an active streak — the one place the app steps off its
/// violet/mono palette, so the "fire" reads as fire and is clearly distinct from
/// the violet free-unlock chip next to it.
const Color _flame = Color(0xFFF59E0B);

/// The two minimalist status icons that sit in the top bar: the streak flame
/// and the free-unlock count. Kept deliberately light (icon + number, a soft
/// glow when active) so they sit quietly on the black canvas.

/// 🔥 Streak — consecutive days the user voted on the daily. Muted at 0; warm +
/// glowing once it is running. Tapping it opens the rank sheet.
class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(currentStreakProvider);
    final active = streak > 0;
    return _StatChip(
      icon: Icons.local_fire_department_rounded,
      label: '$streak',
      color: active ? _flame : AppTheme.subtle,
      glow: active,
      tooltip: 'Twoja seria',
      onTap: () => showRankSheet(context),
    );
  }
}

/// 🔓 Free unlocks — the daily credit (0 or 1). It is auto-spent on the next
/// locked question the user swipes to, so it is only advertised on the DAILY
/// card (the spot before they dive into the locked deck). Hidden for premium
/// users, off the daily, or once the credit is used up. Tapping explains it.
class FreeUnlockChip extends ConsumerWidget {
  const FreeUnlockChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(userStatsValueProvider).isPremium;
    final onDaily = ref.watch(isShowingDailyProvider);
    final credits = ref.watch(freeUnlockCreditsProvider);

    if (isPremium || !onDaily || credits <= 0) return const SizedBox.shrink();

    return _StatChip(
      icon: Icons.lock_open_rounded,
      label: '$credits',
      color: AppTheme.spark,
      glow: true,
      tooltip: 'Darmowe odblokowanie',
      onTap: () => _explain(context),
    );
  }

  void _explain(BuildContext context) {
    final isPolish = Localizations.localeOf(context).languageCode == 'pl';
    final message = isPolish
        ? 'Masz jedno darmowe odblokowanie — przesuń na kolejne pytanie, a odblokuje się automatycznie.'
        : 'You have one free unlock — swipe to the next question and it unlocks automatically.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Shared chrome for both top chips: an icon + count, lit with a soft halo when
/// [glow] is set, wrapped in a tap target.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.glow,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool glow;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
                shadows: glow
                    ? [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12)]
                    : null,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
