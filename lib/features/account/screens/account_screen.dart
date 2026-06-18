import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/purchases_service.dart';
import '../../../services/supabase_service.dart';
import '../providers/session_providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final account = session.value;
    final email = account?.email;
    final userId = account?.userId;
    final isPremium = account?.isPremium == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AccountHeader(email: email, isPremium: isPremium),
                    const SizedBox(height: 18),
                    _Section(
                      title: 'Dane konta',
                      children: [
                        _InfoTile(
                          icon: Icons.alternate_email,
                          title: 'Email',
                          value: email ?? 'Brak emaila',
                        ),
                        if (userId != null)
                          _InfoTile(
                            icon: Icons.badge_outlined,
                            title: 'ID użytkownika',
                            value: userId,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      title: 'Subskrypcja',
                      children: [
                        _InfoTile(
                          icon: isPremium
                              ? Icons.workspace_premium
                              : Icons.workspace_premium_outlined,
                          title: isPremium ? 'Premium aktywne' : 'Plan Free',
                          value: isPremium
                              ? 'Wszystkie pytania są odblokowane.'
                              : 'Możesz przejść na Premium w dowolnym momencie.',
                        ),
                        if (!isPremium)
                          _ActionTile(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Przejdź na Premium',
                            subtitle: 'Otwórz ofertę subskrypcji',
                            onTap: () => _openPaywall(context, ref),
                          ),
                        _ActionTile(
                          icon: Icons.restore,
                          title: 'Przywróć zakup',
                          subtitle:
                              'Użyj po reinstalacji albo zmianie telefonu',
                          onTap: () => _restorePurchases(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      title: 'Bezpieczeństwo',
                      children: [
                        _ActionTile(
                          icon: Icons.logout,
                          title: 'Wyloguj się',
                          subtitle: 'Zakończ sesję na tym urządzeniu',
                          destructive: true,
                          onTap: () => _signOut(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPaywall(BuildContext context, WidgetRef ref) async {
    final purchased = await PurchasesService.presentPaywall();
    if (!context.mounted) return;
    if (purchased) {
      await ref.read(sessionProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Premium aktywne.')));
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final restored = await PurchasesService.restorePurchases();
    if (!context.mounted) return;
    if (restored) {
      await ref.read(sessionProvider.notifier).refresh();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? 'Zakup przywrócony.'
              : 'Nie znaleziono wcześniejszego zakupu.',
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await SupabaseService.signOut();
    ref.invalidate(sessionProvider);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wylogowano.')));
    }
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.email, required this.isPremium});

  final String? email;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.accent)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                border: Border.all(color: AppTheme.accent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPremium
                    ? Icons.workspace_premium
                    : Icons.account_circle_outlined,
                color: isPremium ? const Color(0xFF7CE38B) : AppTheme.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ustawienia konta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email ?? 'Konto użytkownika',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.subtle),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B0B0B),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTheme.accent),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.subtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFFF6B6B) : AppTheme.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
