import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/purchases_service.dart';
import '../../../services/supabase_service.dart';
import '../../account/providers/session_providers.dart';
import '../../account/screens/auth_screen.dart';

/// Surfaces specific to the profile screen — a touch lighter than the pure
/// black canvas so the cards read as a distinct layer (mirrors the auth sheet).
const Color _kCardSurface = Color(0xFF131318);
const Color _kHairline = Color(0xFF26262E);

/// Soft lavender used for the user's name and the "member since" badge.
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
/// Streak and rank are intentionally placeholders for now.
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

                      // ---- Stats (placeholders) ---------------------------
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
                      const _SectionLabel('USTAWIENIA APLIKACJI'),
                      const SizedBox(height: 12),
                      _Card(
                        children: [
                          _ToggleRow(
                            icon: Icons.notifications_none_rounded,
                            title: 'Przypomnienia',
                            subtitle: 'Przypomnienie o codziennym pytaniu',
                            value: _dailyReminders,
                            onChanged: (v) =>
                                setState(() => _dailyReminders = v),
                          ),

                          const _RowDivider(),
                          _NavRow(
                            icon: Icons.language_rounded,
                            title: 'Język',
                            trailingText: 'Polski',
                            onTap: () => _todo('Wybór języka'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ---- Account ----------------------------------------
                      const _SectionLabel('KONTO'),
                      const SizedBox(height: 12),
                      _Card(
                        children: [
                          if (isPremium)
                            _NavRow(
                              icon: Icons.workspace_premium,
                              iconColor: const Color(0xFF7CE38B),
                              title: 'Premium aktywne',
                              titleColor: const Color(0xFF7CE38B),
                              showChevron: false,
                            )
                          else
                            _NavRow(
                              icon: Icons.star_rounded,
                              iconColor: _kGold,
                              title: 'Przejdź na Premium',
                              titleColor: _kGold,
                              onTap: _openPaywall,
                            ),
                          const _RowDivider(),
                          _NavRow(
                            icon: Icons.shield_outlined,
                            title: 'Prywatność i dane',
                            onTap: () => _todo('Prywatność i dane'),
                          ),
                          const _RowDivider(),
                          _NavRow(
                            icon: Icons.restore_rounded,
                            title: 'Przywróć zakup',
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
      _showMessage('Premium aktywne. 🎉');
    }
  }

  Future<void> _restorePurchases() async {
    final restored = await PurchasesService.restorePurchases();
    if (!mounted) return;
    if (restored) {
      await ref.read(sessionProvider.notifier).refresh();
    }
    if (!mounted) return;
    _showMessage(
      restored ? 'Zakup przywrócony.' : 'Nie znaleziono wcześniejszego zakupu.',
    );
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    ref.invalidate(sessionProvider);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    _showMessage('Wylogowano.');
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kCardSurface,
        title: const Text('Usunąć konto?'),
        content: const Text(
          'Tej operacji nie można cofnąć. Stracisz dostęp do swoich postępów '
          'i subskrypcji.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: _kDanger),
            child: const Text('Usuń konto'),
          ),
        ],
      ),
    );
    if (confirmed == true) _todo('Usuwanie konta');
  }

  void _openAuth() => showAuthSheet(context);

  void _todo(String label) => _showMessage('$label — wkrótce');

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

/// Centred identity block (name, email, "member since") with a close button
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
    final name = hasAccount ? _displayName(account) : 'Sesja gościa';
    final subtitle = hasAccount
        ? (account?.email ?? '')
        : 'Zaloguj się, aby zapisać postępy';
    final since = hasAccount ? account?.createdAt : null;

    return Stack(
      // Without this the shrink-wrapped identity column pins itself to the
      // Stack's top-left (its default alignment) and looks lopsided against the
      // close button on the right. topCenter keeps the block screen-centred.
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.center,
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
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.subtle, fontSize: 14),
                ),
              ],
              if (since != null) ...[
                const SizedBox(height: 14),
                _MemberSinceBadge(since: since),
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

  static String _displayName(SessionState? account) {
    final name = account?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = account?.email;
    if (email != null && email.contains('@')) {
      final handle = email.split('@').first;
      if (handle.isNotEmpty) {
        return handle[0].toUpperCase() + handle.substring(1);
      }
    }
    return 'Twoje konto';
  }
}

class _MemberSinceBadge extends StatelessWidget {
  const _MemberSinceBadge({required this.since});

  final DateTime since;

  static const List<String> _months = [
    'STY',
    'LUT',
    'MAR',
    'KWI',
    'MAJ',
    'CZE',
    'LIP',
    'SIE',
    'WRZ',
    'PAŹ',
    'LIS',
    'GRU',
  ];

  @override
  Widget build(BuildContext context) {
    final label = 'Z NAMI OD ${_months[since.month - 1]} ${since.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.spark.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.spark.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _kLavender,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
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

// ---- Stat cards (placeholders) ---------------------------------------------

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    return _StatCardShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.local_fire_department, color: _kFlame, size: 28),
          SizedBox(height: 8),
          Text(
            '14',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'DNI Z RZĘDU',
            style: TextStyle(
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

class _RankCard extends StatelessWidget {
  const _RankCard();

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'PROWOKATOR',
            style: TextStyle(
              color: AppTheme.spark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'RANGA',
            style: TextStyle(
              color: AppTheme.subtle,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              value: 0.62,
              minHeight: 5,
              backgroundColor: _kHairline,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.spark),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '16 dni do: Podpalacz',
            style: TextStyle(color: AppTheme.subtle, fontSize: 11),
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
    this.trailingText,
    this.iconColor,
    this.titleColor,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;
  final bool showChevron;

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
            if (showChevron)
              const Icon(Icons.chevron_right, color: AppTheme.subtle, size: 22),
          ],
        ),
      ),
    );
  }
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
            children: const [
              Icon(Icons.logout_rounded, color: AppTheme.ink, size: 20),
              SizedBox(width: 10),
              Text(
                'Wyloguj się',
                style: TextStyle(
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
          child: const SizedBox(
            height: 54,
            child: Center(
              child: Text(
                'Zaloguj się',
                style: TextStyle(
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
        label: const Text(
          'Usuń konto',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
