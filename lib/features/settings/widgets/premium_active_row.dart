import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../services/purchases_service.dart';
import '../../account/providers/session_providers.dart';
import 'settings_nav_row.dart';
import 'settings_primitives.dart';

/// The "Premium active" account row. Tapping opens the Manage-subscription
/// sheet. As soon as [premiumStatusProvider] resolves it shows the renewal date
/// — or, once the user has cancelled in the store, the date access ends — as a
/// subtitle, so the row answers "is this working / when does it renew?" at a
/// glance.
class PremiumActiveRow extends ConsumerWidget {
  const PremiumActiveRow({
    super.key,
    required this.localeCode,
    required this.onTap,
  });

  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(premiumStatusProvider).value;
    return SettingsNavRow(
      icon: Icons.workspace_premium,
      iconColor: kPremiumGreen,
      title: context.l10n.settingsPremiumActive,
      titleColor: kPremiumGreen,
      subtitle: _subtitle(context, status),
      onTap: onTap,
    );
  }

  String? _subtitle(BuildContext context, PremiumStatus? status) {
    final expiry = status?.expirationDate;
    if (expiry == null) return null;
    final date = formatLongDate(expiry, localeCode);
    return status!.willRenew
        ? context.l10n.manageSubRenewsOn(date)
        : context.l10n.manageSubActiveUntil(date);
  }
}
