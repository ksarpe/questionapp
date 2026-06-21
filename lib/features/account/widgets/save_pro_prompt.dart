import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/session_providers.dart';
import '../screens/auth_screen.dart';

/// Card surface mirroring the settings / auth sheets.
const Color _kCardSurface = Color(0xFF131318);

/// Gold accent shared with the "go Premium" upsell + auth notices.
const Color _kGold = Color(0xFFFFC857);

/// After a guest buys PRO, nudges them to attach the purchase to a real account.
///
/// A guest's entitlement rides on the anonymous Supabase identity, which is lost
/// on reinstall or a second device (store-level restore still works, but a saved
/// account is the friendlier, recoverable path — and registering with
/// email/password upgrades the anonymous user in place, so the same UUID keeps
/// the entitlement).
///
/// No-ops unless the session is now premium AND still a guest, so callers can
/// fire it unconditionally right after any successful purchase.
Future<void> promptSaveProAccount(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionProvider).value;
  if (session == null || !session.isPremium || session.hasAccount) return;

  final wantsAccount = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (dialogContext) => AlertDialog(
      backgroundColor: _kCardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: _kGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.l10n.proActiveTitle,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        context.l10n.savePromptBody,
        style: const TextStyle(
          color: AppTheme.subtle,
          height: 1.4,
          fontSize: 14.5,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppTheme.subtle),
          child: Text(context.l10n.later),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.spark),
          child: Text(
            context.l10n.createAccount,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  if (wantsAccount == true && context.mounted) {
    await showAuthSheet(context);
  }
}
