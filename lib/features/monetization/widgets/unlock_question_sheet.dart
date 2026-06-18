import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/purchases_service.dart';
import '../../account/providers/session_providers.dart';
import '../providers/monetization_providers.dart';

/// How the unlock sheet resolved.
enum UnlockOutcome {
  /// The caller may advance to the next question — an ad was watched or premium
  /// was purchased.
  unlocked,

  /// The user closed the sheet without unlocking; stay on the current question.
  dismissed,
}

/// Presents the "unlock the next question" bottom sheet and resolves to how the
/// user left it. Never returns null — a swipe-to-dismiss maps to
/// [UnlockOutcome.dismissed].
Future<UnlockOutcome> showUnlockSheet(BuildContext context) async {
  final outcome = await showModalBottomSheet<UnlockOutcome>(
    context: context,
    backgroundColor: AppTheme.background,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const UnlockQuestionSheet(),
  );
  return outcome ?? UnlockOutcome.dismissed;
}

/// Two clean choices to keep going: watch a short rewarded video, or go
/// Premium. Handles the ad / purchase flows itself and pops with the resulting
/// [UnlockOutcome].
class UnlockQuestionSheet extends ConsumerStatefulWidget {
  const UnlockQuestionSheet({super.key});

  @override
  ConsumerState<UnlockQuestionSheet> createState() =>
      _UnlockQuestionSheetState();
}

class _UnlockQuestionSheetState extends ConsumerState<UnlockQuestionSheet> {
  /// Blocks both actions (and the close button) while an ad or purchase is in
  /// flight, so the user can't kick off two flows at once.
  bool _busy = false;

  Future<void> _watchAd() async {
    setState(() => _busy = true);

    final ads = ref.read(rewardedAdServiceProvider);
    if (!ads.isReady) {
      ads.preload();
      _notify('Ad not ready yet — give it a moment and try again.');
      if (mounted) setState(() => _busy = false);
      return;
    }

    var earned = false;
    await ads.showRewardedAd(onReward: () => earned = true);
    if (!mounted) return;

    if (earned) {
      ref.read(swipeGateProvider).grantAdReward();
      Navigator.of(context).pop(UnlockOutcome.unlocked);
    } else {
      _notify('No reward earned — watch the full video to unlock.');
      setState(() => _busy = false);
    }
  }

  Future<void> _getPremium() async {
    setState(() => _busy = true);

    final purchased = await PurchasesService.presentPaywall();
    if (!mounted) return;

    if (purchased) {
      // Refresh the session so the gate immediately sees the upgrade.
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(UnlockOutcome.unlocked);
    } else {
      _notify('Purchase didn\'t complete.');
      setState(() => _busy = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'One more question',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock the next question to keep the conversation going.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.subtle,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 24),
            _UnlockOption(
              icon: Icons.play_circle_outline,
              title: 'Watch a short video',
              subtitle: 'Unlocks the next $kUnlocksPerAd questions.',
              onTap: _busy ? null : _watchAd,
            ),
            const SizedBox(height: 12),
            _UnlockOption(
              icon: Icons.workspace_premium_outlined,
              title: 'Get Premium',
              subtitle: 'Unlimited questions & no ads.',
              onTap: _busy ? null : _getPremium,
              highlighted: true,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).pop(UnlockOutcome.dismissed),
              child: const Text(
                'Not now',
                style: TextStyle(color: AppTheme.subtle),
              ),
            ),
            // Slim progress indicator while an ad loads / a purchase resolves.
            SizedBox(
              height: 24,
              child: Center(
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single tappable unlock choice. [highlighted] inverts the colours (white
/// fill) to mark the recommended/premium action.
class _UnlockOption extends StatelessWidget {
  const _UnlockOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted ? AppTheme.background : AppTheme.ink;
    final subtleForeground = highlighted ? Colors.black54 : AppTheme.subtle;

    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: highlighted ? AppTheme.ink : AppTheme.accent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: subtleForeground, fontSize: 13),
                      ),
                    ],
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
