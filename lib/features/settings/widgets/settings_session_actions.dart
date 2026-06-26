import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/app_info_provider.dart';
import 'account_action_buttons.dart';

/// The bottom of the settings page: the session-action buttons (sign out +
/// delete for a real account, sign in for a guest) followed by a quiet build
/// stamp that signs off the page the way mature apps do.
///
/// The owning [SettingsScreen] keeps the action logic and the in-flight
/// sign-out state; this widget is the visual section and forwards taps.
class SettingsSessionActions extends StatelessWidget {
  const SettingsSessionActions({
    super.key,
    required this.hasAccount,
    required this.signingOut,
    required this.appInfo,
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.onSignIn,
  });

  final bool hasAccount;
  final bool signingOut;
  final AppInfo? appInfo;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final appInfo = this.appInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Session actions --------------------------------
        if (hasAccount) ...[
          const SizedBox(height: 26),
          SignOutButton(onTap: onSignOut, loading: signingOut),
          const SizedBox(height: 8),
          DeleteAccountButton(onTap: onDeleteAccount),
        ] else ...[
          const SizedBox(height: 26),
          SignInButton(onTap: onSignIn),
        ],

        // Quiet build stamp at the very bottom, the way mature
        // apps sign off their settings page.
        if (appInfo != null) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Debatly · v${appInfo.version} (${appInfo.build})',
              style: TextStyle(color: context.colors.subtle, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
