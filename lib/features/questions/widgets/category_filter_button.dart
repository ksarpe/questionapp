import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/question_providers.dart';

/// Premium-only catalog category filter, sitting just right of the favorite star.
///
/// A small "tune" icon that opens a modern themed bottom sheet of category chips
/// (plus an "All categories" reset). Picking one narrows the browseable deck to
/// that category — the daily stays free and exempt — and jumps to its first
/// question; the icon tints to the brand orange while a filter is active.
///
/// Rendered ONLY for premium — a free user can't browse the arbitrary catalog, so
/// the filter is meaningless for them. Unlike the favorite star it is therefore
/// hidden rather than shown as a paywall hook. Also hides itself until the
/// catalog (and so its categories) has loaded.
class CategoryFilterButton extends ConsumerWidget {
  const CategoryFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(availableCategoriesProvider);
    if (categories.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(selectedCategoryProvider);
    final active = selected != null;
    // Orange when a filter is on (brand "spark", visible on both themes), muted
    // otherwise — the same on/off language the rest of the app uses.
    final color = active ? AppTheme.spark : context.colors.subtle;

    return IconButton(
      tooltip: context.l10n.categoryFilterTooltip,
      icon: Icon(Icons.tune_rounded, size: 24, color: color),
      onPressed: () => _openSheet(context, ref),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final categories = ref.read(availableCategoriesProvider);
    final counts = ref.read(categoryCountsProvider);
    final selected = ref.read(selectedCategoryProvider);

    final choice = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      backgroundColor: context.colors.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _CategorySheet(
        categories: categories,
        counts: counts,
        selected: selected,
      ),
    );

    // Null = the user dismissed the sheet (tapped outside / swiped down) — leave
    // the filter as-is. A real pick (incl. "All", whose category is null) carries
    // a [_CategoryChoice] wrapper so we can tell a clear apart from a dismiss.
    if (choice == null) return;
    ref.read(selectedCategoryProvider.notifier).select(choice.category);
    // Land on the first question of the chosen category (index 1, right after the
    // always-present daily), or back on the daily when the filter is cleared.
    ref
        .read(questionIndexProvider.notifier)
        .jumpTo(choice.category == null ? 0 : 1);
  }
}

/// The picked category, wrapped so a real selection (including the null "All
/// categories" reset) is distinguishable from dismissing the sheet (which returns
/// a bare null).
class _CategoryChoice {
  const _CategoryChoice(this.category);

  /// The chosen category, or null for "all categories".
  final String? category;
}

/// The bottom-sheet body: a handle, a title, and a soft cloud of rounded category
/// chips. The active chip is filled with the brand orange and checked; the rest
/// sit on the muted accent surface. Tapping any chip pops the sheet with its
/// choice. Styled to the app rather than the platform default.
class _CategorySheet extends StatelessWidget {
  const _CategorySheet({
    required this.categories,
    required this.counts,
    required this.selected,
  });

  final List<String> categories;
  final Map<String, int> counts;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.categoryFilterTitle,
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.categoryFilterSubtitle,
              style: TextStyle(color: context.colors.subtle, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _CategoryChip(
                  label: context.l10n.categoryAll,
                  count: total,
                  active: selected == null,
                  onTap: () =>
                      Navigator.of(context).pop(const _CategoryChoice(null)),
                ),
                for (final category in categories)
                  _CategoryChip(
                    label: localizedCategory(context, category),
                    count: counts[category],
                    active: selected == category,
                    onTap: () =>
                        Navigator.of(context).pop(_CategoryChoice(category)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One rounded category pill. Active = filled orange with a check; inactive =
/// muted accent surface. The optional [count] rides along as a quieter trailing
/// number so the chip cloud reads as data-rich without shouting.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : context.colors.ink;
    final countColor = active
        ? Colors.white.withValues(alpha: 0.75)
        : context.colors.subtle;
    return Material(
      color: active ? AppTheme.spark : context.colors.accent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 7),
                Text(
                  '$count',
                  style: TextStyle(
                    color: countColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Maps a raw catalog category (stored language-neutral, e.g. `'Society'`) to its
/// localized label.
///
/// Falls back to the raw string for any category not in the known set, so a
/// category added later via the dashboard still shows (just untranslated) rather
/// than breaking. Kept here next to its only caller.
String localizedCategory(BuildContext context, String category) {
  final l = context.l10n;
  switch (category) {
    case 'Society':
      return l.categorySociety;
    case 'Ethics':
      return l.categoryEthics;
    case 'Justice':
      return l.categoryJustice;
    case 'Technology':
      return l.categoryTechnology;
    case 'Money':
      return l.categoryMoney;
    case 'Connection':
      return l.categoryConnection;
    case 'Dreams':
      return l.categoryDreams;
    case 'Environment':
      return l.categoryEnvironment;
    case 'Family':
      return l.categoryFamily;
    case 'Reflection':
      return l.categoryReflection;
    default:
      return category;
  }
}
