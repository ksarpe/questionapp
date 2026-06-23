import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_toast.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/providers/stats_providers.dart';
import '../providers/question_providers.dart';
import 'animated_flame_icon.dart';
import 'rank_sheet.dart';

/// The two minimalist status icons that sit in the top bar: the streak flame
/// and the free-unlock count. Kept deliberately light (icon + number, a soft
/// glow when active) so they sit quietly on the black canvas.

/// Marks the streak flame glyph in the top bar so the streak-up celebration
/// (see `streak_up_celebration.dart`) knows where to fly its big flame TO. A
/// single chip is ever mounted, so a plain shared [GlobalKey] is safe here.
final streakChipKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());

/// 🔥 Streak — consecutive days the user voted on the daily. Muted at 0; a
/// living, shimmering flame once it is running (see [AnimatedFlameIcon]).
/// Tapping it opens the rank sheet.
class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsValueProvider);
    final active = stats.currentStreak > 0;
    return _StatChip(
      // Tag the flame with the shared key so the streak-up flourish can read its
      // on-screen position and land the flying flame exactly on it.
      icon: KeyedSubtree(
        key: ref.read(streakChipKeyProvider),
        child: AnimatedFlameIcon(
          streak: stats.currentStreak,
          rankTier: stats.rankTier,
        ),
      ),
      label: '${stats.currentStreak}',
      labelColor: active ? flameColor(context) : context.colors.subtle,
      tooltip: context.l10n.streakTooltip,
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
      icon: Icon(
        Icons.lock_open_rounded,
        color: AppTheme.spark,
        size: 20,
        shadows: [
          Shadow(color: AppTheme.spark.withValues(alpha: 0.6), blurRadius: 12),
        ],
      ),
      label: '$credits',
      labelColor: AppTheme.spark,
      tooltip: context.l10n.freeUnlockTooltip,
      onTap: () => _explain(context),
    );
  }

  void _explain(BuildContext context) {
    AppToast.info(context, context.l10n.freeUnlockExplain);
  }
}

/// Shared chrome for both top chips: a (pre-built) [icon] + count, wrapped in a
/// tap target. The caller renders the icon so each chip can carry its own
/// treatment — a plain glowing glyph for free-unlocks, the living
/// [AnimatedFlameIcon] for the streak.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.tooltip,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final Color labelColor;
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
              icon,
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
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
