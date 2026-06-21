import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/purchases_service.dart';
import '../../../services/supabase_service.dart';
import '../../account/providers/session_providers.dart';
import '../../account/providers/stats_providers.dart';
import '../../account/screens/auth_screen.dart';

/// Surfaces specific to the profile screen — a touch lighter than the pure
/// black canvas so the cards read as a distinct layer (mirrors the auth sheet).
const Color _kCardSurface = Color(0xFF131318);
const Color _kHairline = Color(0xFF26262E);

/// Soft lavender used for the user's name.
const Color _kLavender = Color(0xFFCBBDF7);

/// Warm flame colour for the (placeholder) streak card.
const Color _kFlame = Color(0xFFFF7A29);

/// Gold accent for the "go Premium" upsell, matching the auth notice.
const Color _kGold = Color(0xFFFFC857);

const Color _kDanger = Color(0xFFFF6B6B);

/// The signed-in user's profile hub: identity, gamification stats, app
/// preferences, subscription and account actions — all on one scrollable page.
///
/// Reached by tapping the person icon in the top-right of [QuestionScreen].
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Local-only preference state for now — these flip the switches visually but
  // are not yet persisted or wired to behaviour.
  bool _dailyReminders = true;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(sessionProvider).value;
    final hasAccount = account?.hasAccount ?? false;
    final isPremium = account?.isPremium ?? false;
    final localeCode = ref.watch(localeControllerProvider).languageCode;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Faint violet glow bleeding down from the top, behind the header.
          const _TopGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHeader(
                        account: account,
                        hasAccount: hasAccount,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 24),

                      // ---- Stats (live from sync_user_state) --------------
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Expanded(child: _StreakCard()),
                            SizedBox(width: 14),
                            Expanded(child: _RankCard()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ---- App settings -----------------------------------
                      _SectionLabel(context.l10n.settingsSectionApp),
                      const SizedBox(height: 12),
                      _Card(
                        children: [
                          _ToggleRow(
                            icon: Icons.notifications_none_rounded,
                            title: context.l10n.settingsReminders,
                            subtitle: context.l10n.settingsRemindersSubtitle,
                            value: _dailyReminders,
                            onChanged: (v) =>
                                setState(() => _dailyReminders = v),
                          ),

                          const _RowDivider(),
                          _NavRow(
                            icon: Icons.language_rounded,
                            title: context.l10n.settingsLanguage,
                            trailingText: _languageName(localeCode),
                            onTap: _openLanguagePicker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ---- Account ----------------------------------------
                      _SectionLabel(context.l10n.settingsSectionAccount),
                      const SizedBox(height: 12),
                      _Card(
                        children: [
                          if (isPremium)
                            _PremiumActiveRow(
                              localeCode: localeCode,
                              onTap: _openManageSubscription,
                            )
                          else
                            _NavRow(
                              icon: Icons.star_rounded,
                              iconColor: _kGold,
                              title: context.l10n.settingsGoPremium,
                              titleColor: _kGold,
                              onTap: _openPaywall,
                            ),
                          const _RowDivider(),
                          _NavRow(
                            icon: Icons.shield_outlined,
                            title: context.l10n.settingsPrivacy,
                            onTap: () => _todo(context.l10n.settingsPrivacy),
                          ),
                          const _RowDivider(),
                          _NavRow(
                            icon: Icons.restore_rounded,
                            title: context.l10n.restorePurchase,
                            onTap: _restorePurchases,
                          ),
                        ],
                      ),

                      // ---- Session actions --------------------------------
                      if (hasAccount) ...[
                        const SizedBox(height: 26),
                        _SignOutButton(onTap: _signOut),
                        const SizedBox(height: 8),
                        _DeleteAccountButton(onTap: _confirmDeleteAccount),
                      ] else ...[
                        const SizedBox(height: 26),
                        _SignInButton(onTap: _openAuth),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions ---------------------------------------------------------------

  /// Shows the RevenueCat paywall, then refreshes the session so the gate sees
  /// the upgrade immediately.
  Future<void> _openPaywall() async {
    final purchased = await PurchasesService.presentPaywall();
    if (!mounted) return;
    if (purchased) {
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      _showMessage(context.l10n.settingsPremiumActiveToast);
    }
  }

  /// Opens the Manage-subscription sheet. The current entitlement details are
  /// already cached by [premiumStatusProvider]; the sheet refreshes them itself
  /// while it loads so a date that ticked over since open is still correct.
  Future<void> _openManageSubscription() async {
    final localeCode = ref.read(localeControllerProvider).languageCode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ManageSubscriptionSheet(localeCode: localeCode),
    );
  }

  Future<void> _restorePurchases() async {
    final restored = await PurchasesService.restorePurchases();
    if (!mounted) return;
    if (restored) {
      await ref.read(sessionProvider.notifier).refresh();
    }
    if (!mounted) return;
    _showMessage(
      restored
          ? context.l10n.purchaseRestored
          : context.l10n.noPreviousPurchase,
    );
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    ref.invalidate(sessionProvider);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    _showMessage(context.l10n.signedOut);
  }

  Future<void> _confirmDeleteAccount() async {
    // Account deletion needs a service-role server action (clients can't delete
    // their own auth user), which isn't built yet. Be honest about that rather
    // than showing a destructive "confirm" that silently does nothing.
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kCardSurface,
        title: Text(context.l10n.deleteAccountTitle),
        content: Text(context.l10n.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _openAuth() => showAuthSheet(context);

  /// Human-readable name for a language code, shown as the row's trailing label
  /// and the picker options. Each language is named in itself, the convention
  /// for language menus.
  static String _languageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'pl':
      default:
        return 'Polski';
    }
  }

  /// Opens the language picker and applies the choice.
  ///
  /// Switching the locale rebuilds the app into the new language and re-fetches
  /// the question content (the repository's `p_locale` follows the same source
  /// of truth — see [localeControllerProvider]).
  Future<void> _openLanguagePicker() async {
    final current = ref.read(localeControllerProvider);
    final picked = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: _kCardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                context.l10n.chooseLanguage,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final locale in kSupportedLocales)
              ListTile(
                title: Text(
                  _languageName(locale.languageCode),
                  style: const TextStyle(color: AppTheme.ink, fontSize: 15),
                ),
                trailing: locale.languageCode == current.languageCode
                    ? const Icon(Icons.check_rounded, color: AppTheme.spark)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(locale),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null) {
      await ref.read(localeControllerProvider.notifier).setLocale(picked);
    }
  }

  void _todo(String label) => _showMessage(context.l10n.comingSoonNamed(label));

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accent),
    );
  }
}

/// Soft violet radial glow anchored to the top of the screen.
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: 360,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 0.85,
              colors: [
                AppTheme.spark.withValues(alpha: 0.20),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Left-aligned identity block (name, email) with a close button
/// floating in the top-right corner.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
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
                  color: _kLavender,
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
                  style: const TextStyle(color: AppTheme.subtle, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: _CloseButton(onTap: onClose),
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCardSurface,
      shape: const CircleBorder(side: BorderSide(color: _kHairline)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.close, size: 20, color: AppTheme.subtle),
        ),
      ),
    );
  }
}

// ---- Stat cards (live from sync_user_state) --------------------------------

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(currentStreakProvider);
    return _StatCardShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_fire_department, color: _kFlame, size: 28),
          const SizedBox(height: 8),
          Text(
            '$streak',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.daysInARow,
            style: const TextStyle(
              color: AppTheme.subtle,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankCard extends ConsumerWidget {
  const _RankCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsValueProvider);
    final rankName = stats.rankName.isEmpty ? '—' : stats.rankName.toUpperCase();
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

    return _StatCardShell(
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
            style: const TextStyle(
              color: AppTheme.subtle,
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
              backgroundColor: _kHairline,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.spark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.subtle, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatCardShell extends StatelessWidget {
  const _StatCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: _kCardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kHairline),
      ),
      child: child,
    );
  }
}

// ---- Reusable building blocks ----------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.spark,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Rounded card grouping a column of rows.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCardSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Hairline separator inset past the leading icon, like iOS grouped lists.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: _kHairline,
      indent: 56,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.subtle, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.subtle, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFFCFCFCF),
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppTheme.spark
                  : const Color(0xFF2C2C33),
            ),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.subtle, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? AppTheme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppTheme.subtle,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  trailingText!,
                  style: const TextStyle(color: AppTheme.subtle, fontSize: 14),
                ),
              ),
            const Icon(Icons.chevron_right, color: AppTheme.subtle, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Soft green used for the active-premium state, matching the original row.
const Color _kPremiumGreen = Color(0xFF7CE38B);

/// The "Premium active" account row. Tapping opens the Manage-subscription
/// sheet. As soon as [premiumStatusProvider] resolves it shows the renewal date
/// — or, once the user has cancelled in the store, the date access ends — as a
/// subtitle, so the row answers "is this working / when does it renew?" at a
/// glance.
class _PremiumActiveRow extends ConsumerWidget {
  const _PremiumActiveRow({required this.localeCode, required this.onTap});

  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(premiumStatusProvider).value;
    return _NavRow(
      icon: Icons.workspace_premium,
      iconColor: _kPremiumGreen,
      title: context.l10n.settingsPremiumActive,
      titleColor: _kPremiumGreen,
      subtitle: _subtitle(context, status),
      onTap: onTap,
    );
  }

  String? _subtitle(BuildContext context, PremiumStatus? status) {
    final expiry = status?.expirationDate;
    if (expiry == null) return null;
    final date = _formatLongDate(expiry, localeCode);
    return status!.willRenew
        ? context.l10n.manageSubRenewsOn(date)
        : context.l10n.manageSubActiveUntil(date);
  }
}

/// Explains the active subscription and deep-links to the store's
/// subscription-management page.
///
/// Crucial product/UX point: neither the App Store nor Google Play lets an app
/// cancel a subscription itself — cancellation always happens in the store's own
/// "Subscriptions" screen. So this sheet doesn't (and can't) cancel anything; it
/// surfaces the renewal status and is a one-tap shortcut out to the right place,
/// with copy that differs per store.
class _ManageSubscriptionSheet extends ConsumerStatefulWidget {
  const _ManageSubscriptionSheet({required this.localeCode});

  final String localeCode;

  @override
  ConsumerState<_ManageSubscriptionSheet> createState() =>
      _ManageSubscriptionSheetState();
}

class _ManageSubscriptionSheetState
    extends ConsumerState<_ManageSubscriptionSheet> {
  bool _opening = false;
  bool _openFailed = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(premiumStatusProvider);
    final status = statusAsync.value;
    final store = status?.store ?? PremiumStore.other;
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kHairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: _kPremiumGreen,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.manageSubSheetTitle,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ---- Status card -------------------------------------------------
            if (statusAsync.isLoading && status == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _kPremiumGreen,
                    ),
                  ),
                ),
              )
            else
              _StatusCard(status: status, localeCode: widget.localeCode),

            const SizedBox(height: 14),
            Text(
              _storeNote(l10n, store),
              style: const TextStyle(
                color: AppTheme.subtle,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (_openFailed) ...[
              const SizedBox(height: 12),
              Text(
                _storeOpenFailed(l10n, store),
                style: const TextStyle(
                  color: _kDanger,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),

            _ManageButton(
              label: _storeButton(l10n, store),
              busy: _opening,
              onTap: () => _manage(status),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(foregroundColor: AppTheme.subtle),
                child: Text(l10n.later),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manage(PremiumStatus? status) async {
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    final opened = await PurchasesService.openManagement(status?.managementUrl);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {
        _opening = false;
        _openFailed = true;
      });
    }
  }
}

/// The renewal/cancellation status block inside the manage sheet.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.localeCode});

  final PremiumStatus? status;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cancelled = status?.isCancelled ?? false;
    final expiry = status?.expirationDate;

    final headline = cancelled
        ? l10n.manageSubStatusCancelled
        : l10n.manageSubStatusActive;
    final headlineColor = cancelled ? _kGold : _kPremiumGreen;

    String? dateLine;
    if (expiry != null) {
      final date = _formatLongDate(expiry, localeCode);
      dateLine = cancelled
          ? l10n.manageSubActiveUntil(date)
          : l10n.manageSubRenewsOn(date);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                cancelled
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: headlineColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                headline,
                style: TextStyle(
                  color: headlineColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (dateLine != null) ...[
            const SizedBox(height: 8),
            Text(
              dateLine,
              style: const TextStyle(color: AppTheme.ink, fontSize: 14),
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: 4),
            Text(
              _storeBilledLabel(l10n, status!.store),
              style: const TextStyle(color: AppTheme.subtle, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-width gold "Manage in …" button, matching the premium accent.
class _ManageButton extends StatelessWidget {
  const _ManageButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
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
                        Icons.open_in_new_rounded,
                        color: Colors.black,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
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

/// "Billed through …" line for the status card.
String _storeBilledLabel(AppLocalizations l10n, PremiumStore store) {
  switch (store) {
    case PremiumStore.appStore:
      return l10n.manageSubBilledAppStore;
    case PremiumStore.playStore:
      return l10n.manageSubBilledPlayStore;
    case PremiumStore.web:
    case PremiumStore.other:
      return l10n.manageSubBilledWeb;
  }
}

/// Explanatory note about where cancellation actually happens, per store.
String _storeNote(AppLocalizations l10n, PremiumStore store) {
  switch (store) {
    case PremiumStore.appStore:
      return l10n.manageSubNoteAppStore;
    case PremiumStore.playStore:
      return l10n.manageSubNotePlayStore;
    case PremiumStore.web:
    case PremiumStore.other:
      return l10n.manageSubNoteWeb;
  }
}

/// Label for the primary "Manage in …" button, per store.
String _storeButton(AppLocalizations l10n, PremiumStore store) {
  switch (store) {
    case PremiumStore.appStore:
      return l10n.manageSubButtonAppStore;
    case PremiumStore.playStore:
      return l10n.manageSubButtonPlayStore;
    case PremiumStore.web:
    case PremiumStore.other:
      return l10n.manageSubButtonGeneric;
  }
}

/// Fallback instructions shown if the management deep link can't be opened.
String _storeOpenFailed(AppLocalizations l10n, PremiumStore store) {
  switch (store) {
    case PremiumStore.appStore:
      return l10n.manageSubOpenFailedAppStore;
    case PremiumStore.playStore:
      return l10n.manageSubOpenFailedPlayStore;
    case PremiumStore.web:
    case PremiumStore.other:
      return l10n.manageSubOpenFailedGeneric;
  }
}

/// Full month names for the renewal/expiry date, hand-rolled per locale to
/// avoid pulling in `intl`'s date-symbol initialisation.
/// Polish months are in the genitive case ("21 lipca 2026"), as dates take it.
const List<String> _monthsEnFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _monthsPlGenitive = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

String _formatLongDate(DateTime date, String localeCode) {
  final local = date.toLocal();
  final months = localeCode == 'pl' ? _monthsPlGenitive : _monthsEnFull;
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// Full-width bordered "Sign out" action.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kHairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded, color: AppTheme.ink, size: 20),
              const SizedBox(width: 10),
              Text(
                context.l10n.signOut,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width gradient "Sign in" action, shown to guests reaching this screen.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 54,
            child: Center(
              child: Text(
                context.l10n.signIn,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centred destructive "Delete account" text action.
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: _kDanger),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: Text(
          context.l10n.deleteAccount,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
