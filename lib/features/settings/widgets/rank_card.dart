import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/providers/stats_providers.dart';
import '../../questions/widgets/rank_sheet.dart';
import 'stat_card_shell.dart';

class RankCard extends ConsumerWidget {
  const RankCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsValueProvider);
    final rankName = stats.rankName.isEmpty
        ? '—'
        : stats.rankName.toUpperCase();
    final next = stats.nextRankStreak;
    // Progress toward the next rank. Without the current rank's floor we
    // approximate against the next threshold — good enough for the profile card;
    // the rank sheet shows the precise ladder.
    final progress = (next != null && next > 0)
        ? (stats.currentStreak / next).clamp(0.0, 1.0)
        : 1.0;
    final remaining = next == null ? 0 : next - stats.currentStreak;
    final subtitle = next == null
        ? context.l10n.rankCardTopRank
        : (remaining > 0
              ? context.l10n.rankCardDaysToPromotion(remaining)
              : context.l10n.rankCardPromotionReady);

    return StatCardShell(
      // Tapping the rank card opens the same rank sheet as tapping the streak
      // flame on the main screen — the full ladder, progress and freeze state.
      onTap: () => showRankSheet(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            color: AppTheme.spark,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            rankName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.spark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.rankLabel,
            style: TextStyle(
              color: context.colors.subtle,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: context.colors.hairline,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.spark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: context.colors.subtle, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
