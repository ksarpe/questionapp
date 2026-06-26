import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import 'premium_active_row.dart';
import 'settings_nav_row.dart';
import 'settings_primitives.dart';

/// The "Account" card: subscription status (the active-premium row that opens
/// the manage sheet, or a gold "go Premium" upsell), the privacy & data entry,
/// restore-purchases and the about row.
///
/// The owning [SettingsScreen] keeps the actions; this widget is the visual
/// section and forwards taps back up through its callbacks.
class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({
    super.key,
    required this.isPremium,
    required this.localeCode,
    required this.appVersion,
    required this.onManageSubscription,
    required this.onGoPremium,
    required this.onPrivacy,
    required this.onRestore,
    required this.onAbout,
  });

  final bool isPremium;
  final String localeCode;
  final String? appVersion;
  final VoidCallback onManageSubscription;
  final VoidCallback onGoPremium;
  final VoidCallback onPrivacy;
  final VoidCallback onRestore;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Account ----------------------------------------
        SettingsSectionLabel(context.l10n.settingsSectionAccount),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            if (isPremium)
              PremiumActiveRow(
                localeCode: localeCode,
                onTap: onManageSubscription,
              )
            else
              SettingsNavRow(
                icon: Icons.star_rounded,
                iconColor: kGold,
                title: context.l10n.settingsGoPremium,
                titleColor: kGold,
                onTap: onGoPremium,
              ),
            const SettingsRowDivider(),
            SettingsNavRow(
              icon: Icons.shield_outlined,
              title: context.l10n.settingsPrivacy,
              onTap: onPrivacy,
            ),
            const SettingsRowDivider(),
            SettingsNavRow(
              icon: Icons.restore_rounded,
              title: context.l10n.restorePurchase,
              onTap: onRestore,
            ),
            const SettingsRowDivider(),
            SettingsNavRow(
              icon: Icons.info_outline_rounded,
              title: context.l10n.settingsAbout,
              trailingText: appVersion,
              onTap: onAbout,
            ),
          ],
        ),
      ],
    );
  }
}
