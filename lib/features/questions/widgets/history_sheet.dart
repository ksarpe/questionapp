import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_toast.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/daily_history_entry.dart';
import '../../../data/models/vote_result.dart';
import '../../../services/purchases_service.dart';
import '../../account/providers/session_providers.dart';
import '../providers/question_providers.dart';

/// Gold accent for the PRO upsell, matching the "go Premium" hooks elsewhere.
const Color _kGold = Color(0xFFFFC857);

/// Opens the PRO "question history": a bottom-sheet table of every PAST daily
/// question and how the community voted, so a user who missed a day can still
/// catch up. Styled to match [showRankSheet] / [showSmaczkiSheet].
///
/// The sheet gates itself: premium sees the history, everyone else sees a PRO
/// upsell — so it's safe to open from anywhere without a premium check up front.
Future<void> showHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.background,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _HistorySheet(),
  );
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    return SafeArea(
      child: ConstrainedBox(
        // Cap the height so a long history scrolls inside the sheet instead of
        // swallowing the whole screen; a short one sizes to its content.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: isPremium ? const _HistoryBody() : const _HistoryUpsell(),
        ),
      ),
    );
  }
}

/// The premium view: the title, then the scrollable list of past dailies (or a
/// loading / error / empty state).
class _HistoryBody extends ConsumerWidget {
  const _HistoryBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(dailyHistoryProvider);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(),
        const SizedBox(height: 16),
        Flexible(
          child: historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => _HistoryMessage(
              icon: Icons.cloud_off_rounded,
              title: context.l10n.historyLoadError,
              action: TextButton(
                onPressed: () => ref.invalidate(dailyHistoryProvider),
                child: Text(context.l10n.tryAgain),
              ),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return _HistoryMessage(
                  icon: Icons.history_toggle_off_rounded,
                  title: context.l10n.historyEmptyTitle,
                  subtitle: context.l10n.historyEmptyBody,
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _HistoryRow(entry: entries[i], lang: lang),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, color: AppTheme.spark, size: 22),
            const SizedBox(width: 10),
            Text(
              context.l10n.historyTitle,
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.historySubtitle,
          style: TextStyle(
            color: context.colors.subtle,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// One history row: the date it ran, the question text, and the community split.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.lang});

  final DailyHistoryEntry entry;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: context.colors.accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: context.colors.subtle,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(entry.publishDate, lang),
                style: TextStyle(
                  color: context.colors.subtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.votesCount(entry.votes.total),
                style: TextStyle(color: context.colors.subtle, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.questionText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.ink,
              fontSize: 14.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _MiniVoteBar(result: entry.votes),
        ],
      ),
    );
  }
}

/// The compact community split for one past question: a TAK%/NIE% label line
/// over a single split bar, with a check on the side the caller voted. Collapses
/// to a quiet "no votes" line when nobody voted.
class _MiniVoteBar extends StatelessWidget {
  const _MiniVoteBar({required this.result});

  final VoteResult result;

  @override
  Widget build(BuildContext context) {
    if (result.total == 0) {
      return Text(
        context.l10n.historyNoVotes,
        style: TextStyle(
          color: context.colors.subtle,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final mineYes = result.myChoice == VoteResult.yes;
    final mineNo = result.myChoice == VoteResult.no;

    return Column(
      children: [
        Row(
          children: [
            _SideLabel(
              label: context.l10n.voteYes,
              pct: result.yesPct,
              color: AppTheme.yes,
              mine: mineYes,
            ),
            const Spacer(),
            _SideLabel(
              label: context.l10n.voteNo,
              pct: result.noPct,
              color: AppTheme.no,
              mine: mineNo,
              trailing: true,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                // Full-width NIE (red) track …
                Positioned.fill(
                  child: ColoredBox(
                    color: AppTheme.no.withValues(alpha: 0.85),
                  ),
                ),
                // … overlaid by the TAK (green) portion from the left.
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: result.yesFraction.clamp(0.0, 1.0),
                  child: ColoredBox(
                    color: AppTheme.yes.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({
    required this.label,
    required this.pct,
    required this.color,
    required this.mine,
    this.trailing = false,
  });

  final String label;
  final int pct;
  final Color color;
  final bool mine;

  /// When true the percentage leads and the label follows (the NIE side), so the
  /// two sides read symmetrically from the centre out.
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
    final percent = Text(
      '$pct%',
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
    final check = mine
        ? Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.check_circle_rounded, color: color, size: 13),
          )
        : const SizedBox.shrink();

    return Row(
      children: trailing
          ? [percent, const SizedBox(width: 6), name, check]
          : [name, const SizedBox(width: 6), percent, check],
    );
  }
}

/// Centred message block for the empty / error states.
class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.colors.subtle, size: 40),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.subtle, fontSize: 13),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}

/// The non-premium view: explains the history is a PRO feature and offers the
/// paywall. On purchase the session refreshes and the parent sheet rebuilds into
/// the real history (it watches [isPremiumProvider]).
class _HistoryUpsell extends ConsumerStatefulWidget {
  const _HistoryUpsell();

  @override
  ConsumerState<_HistoryUpsell> createState() => _HistoryUpsellState();
}

class _HistoryUpsellState extends ConsumerState<_HistoryUpsell> {
  bool _opening = false;

  Future<void> _goPro() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final purchased = await PurchasesService.presentPaywall();
      if (!mounted) return;
      if (purchased) {
        await ref.read(sessionProvider.notifier).refresh();
        if (!mounted) return;
        AppToast.success(context, context.l10n.settingsPremiumActiveToast);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGold.withValues(alpha: 0.14),
              border: Border.all(color: _kGold.withValues(alpha: 0.45)),
            ),
            child: const Icon(Icons.history_rounded, color: _kGold, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.historyPremiumTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.historyPremiumBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.subtle,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          _GoProButton(busy: _opening, onTap: _goPro),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _GoProButton extends StatelessWidget {
  const _GoProButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kGold,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.black,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.goPro,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A quiet outlined "Historia" pill, sized and styled to sit next to the share
/// pill under the daily question. Opens [showHistorySheet]; the sheet itself
/// gates premium, so this is shown to everyone on the daily (free users land on
/// the PRO upsell).
class HistoryButton extends StatelessWidget {
  const HistoryButton({super.key});

  static const _radius = BorderRadius.all(Radius.circular(30));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.historyTooltip,
      child: Tooltip(
        message: context.l10n.historyTooltip,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: _radius,
            side: BorderSide(color: context.colors.hairline),
          ),
          child: InkWell(
            borderRadius: _radius,
            onTap: () => showHistorySheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: context.colors.subtle,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.historyLabel,
                    style: TextStyle(
                      color: context.colors.subtle,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Short, locale-aware date for a history row, e.g. PL "22 cze 2026", EN
/// "Jun 22, 2026". Hand-rolled to avoid pulling in `intl`'s date initialisation
/// (the rest of the app formats dates the same way — see settings_screen).
String _formatDate(DateTime date, String lang) {
  const monthsPl = [
    'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
    'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
  ];
  const monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = date.toLocal();
  if (lang == 'pl') {
    return '${d.day} ${monthsPl[d.month - 1]} ${d.year}';
  }
  return '${monthsEn[d.month - 1]} ${d.day}, ${d.year}';
}
