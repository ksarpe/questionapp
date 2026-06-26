import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sub_screen_chrome.dart';
import '../../account/providers/session_providers.dart';

/// Soft orange radial glow anchored to the top of the screen.
/// Left-aligned identity block (name, email) with a close button
/// floating in the top-right corner.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.account,
    required this.hasAccount,
    required this.onClose,
  });

  final SessionState? account;
  final bool hasAccount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final name = hasAccount
        ? _displayName(account, context.l10n.yourAccount)
        : context.l10n.guestSession;
    final subtitle = hasAccount
        ? (account?.email ?? '')
        : context.l10n.signInToSaveProgress;

    return Stack(
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      children: [
        Padding(
          // Reserve room on the right so the name never slides under the
          // floating close button.
          padding: const EdgeInsets.only(right: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.spark,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.colors.subtle, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: SubScreenCloseButton(onTap: onClose),
        ),
      ],
    );
  }

  static String _displayName(SessionState? account, String fallback) {
    final name = account?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = account?.email;
    if (email != null && email.contains('@')) {
      final handle = email.split('@').first;
      if (handle.isNotEmpty) {
        return handle[0].toUpperCase() + handle.substring(1);
      }
    }
    return fallback;
  }
}
