import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/smaczek.dart';
import '../../../services/purchases_service.dart';
import '../../account/providers/session_providers.dart';
import '../providers/question_providers.dart';

/// Opens the "Smaczki" panel as a modal sheet that slides up from the bottom.
///
/// Shows the discussion prompts for [questionId]: a free user sees the first one
/// plus the rest as blurred, locked placeholders; premium users see them all.
/// The gate is enforced server-side (the `get_question_smaczki` RPC) — locked
/// smaczki never carry real text, so the blur is purely cosmetic.
Future<void> showSmaczkiSheet(BuildContext context, String questionId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.background,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SmaczkiSheet(questionId: questionId),
  );
}

class _SmaczkiSheet extends ConsumerStatefulWidget {
  const _SmaczkiSheet({required this.questionId});

  final String questionId;

  @override
  ConsumerState<_SmaczkiSheet> createState() => _SmaczkiSheetState();
}

class _SmaczkiSheetState extends ConsumerState<_SmaczkiSheet> {
  /// Blocks the premium button while the paywall / purchase is in flight.
  bool _busy = false;

  Future<void> _getPremium() async {
    setState(() => _busy = true);

    final purchased = await PurchasesService.presentPaywall();
    if (!mounted) return;

    if (purchased) {
      // The entitlement is the source of truth: refresh the session so the gate
      // sees the upgrade, then drop the cached smaczki so they re-fetch — this
      // time the RPC returns the now-unlocked text.
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      ref.invalidate(smaczkiProvider(widget.questionId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zakup nie został dokończony.')),
      );
    }

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final smaczkiAsync = ref.watch(smaczkiProvider(widget.questionId));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppTheme.spark),
                  const SizedBox(width: 10),
                  Text(
                    'Smaczki',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Podpowiedzi, jak pogłębić rozmowę wokół tego pytania.',
                style: TextStyle(color: AppTheme.subtle, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Flexible(
                child: smaczkiAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nie udało się wczytać smaczków.\n$e',
                      style: const TextStyle(color: AppTheme.subtle),
                    ),
                  ),
                  data: (smaczki) => _SmaczkiList(
                    smaczki: smaczki,
                    busy: _busy,
                    onGetPremium: _busy ? null : _getPremium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The resolved list: numbered cards for readable smaczki, blurred placeholders
/// for the locked ones, and a single premium upsell when anything is locked.
class _SmaczkiList extends StatelessWidget {
  const _SmaczkiList({
    required this.smaczki,
    required this.busy,
    required this.onGetPremium,
  });

  final List<Smaczek> smaczki;
  final bool busy;
  final VoidCallback? onGetPremium;

  @override
  Widget build(BuildContext context) {
    if (smaczki.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Do tego pytania nie ma jeszcze smaczków.',
          style: TextStyle(color: AppTheme.subtle),
        ),
      );
    }

    // Premium users get no locked rows, so the upsell only shows for free users.
    final hasLocked = smaczki.any((s) => s.isLocked);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < smaczki.length; i++)
            smaczki[i].isLocked
                ? _LockedSmaczekCard(index: i + 1)
                : _SmaczekCard(index: i + 1, text: smaczki[i].text ?? ''),
          if (hasLocked) ...[
            const SizedBox(height: 4),
            _PremiumCta(busy: busy, onTap: onGetPremium),
          ],
        ],
      ),
    );
  }
}

/// A readable smaczek: a numbered violet dot and the prompt text.
class _SmaczekCard extends StatelessWidget {
  const _SmaczekCard({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IndexDot(index: index),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A locked smaczek: a blurred dummy line plus a lock icon.
///
/// The server sent `text == null` for this one, so there is no real content on
/// the client. We render a fixed placeholder ([_dummy]) under a blur — even if
/// someone removes the blur, all they find is the dummy string, never the real
/// smaczek. Tapping the premium CTA below is the only way to reveal it.
class _LockedSmaczekCard extends StatelessWidget {
  const _LockedSmaczekCard({required this.index});

  final int index;

  static const _dummy =
      'aaabbbbaaabbb aaabbbbaaabbb aaabbbbaaabbb aaabbbbaaabbb '
      'aaabbbbaaabbb aaabbbbaaabbb aaabbbbaaabbb aaabbbbaaabbb';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IndexDot(index: index, locked: true),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: const Text(
                  _dummy,
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: AppTheme.subtle,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.lock_outline, color: AppTheme.subtle, size: 18),
        ],
      ),
    );
  }
}

/// Small numbered circle to the left of each smaczek; dimmed when locked.
class _IndexDot extends StatelessWidget {
  const _IndexDot({required this.index, this.locked = false});

  final int index;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: locked ? AppTheme.background : AppTheme.spark,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: TextStyle(
          color: locked ? AppTheme.subtle : AppTheme.ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The "unlock everything with Premium" button. A null [onTap] (while busy)
/// disables it and shows a spinner.
class _PremiumCta extends StatelessWidget {
  const _PremiumCta({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.ink,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppTheme.background,
                size: 26,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Odblokuj wszystkie smaczki',
                      style: TextStyle(
                        color: AppTheme.background,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Premium — pełne podpowiedzi do każdego pytania.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.background,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
