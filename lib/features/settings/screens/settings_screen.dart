import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/providers/session_providers.dart';
import '../../account/screens/account_screen.dart';
import '../../account/screens/auth_screen.dart';
import '../../../services/purchases_service.dart';
import '../../../services/supabase_service.dart';

/// Settings screen with account, preferences and monetization entry points.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final account = session.value;
    final hasAccount = account?.hasAccount ?? false;
    final email = account?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (!hasAccount)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Account'),
              subtitle: Text(
                account?.isAnonymous == true
                    ? 'Guest session active'
                    : 'Login or create an account',
              ),
              onTap: () => _openAuth(context),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Account'),
              subtitle: Text(email ?? 'Signed in'),
              onTap: () => _openAccount(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await SupabaseService.signOut();
                ref.invalidate(sessionProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Logged out.')));
                }
              },
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Preferences'),
            subtitle: const Text('Categories, notifications, theme'),
            onTap: () => _todo(context, 'Preferences'),
          ),
          if (account?.isPremium == true)
            const ListTile(
              leading: Icon(Icons.workspace_premium, color: AppTheme.ink),
              title: Text('Premium active'),
              subtitle: Text('Every question unlocked — thank you!'),
            )
          else
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Go Premium'),
              subtitle: const Text('Unlock every question'),
              onTap: () => _openPaywall(context, ref),
            ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore purchases'),
            subtitle: const Text('Already bought Premium? Restore it here'),
            onTap: () => _restorePurchases(context, ref),
          ),
        ],
      ),
    );
  }

  /// Shows the RevenueCat paywall, then refreshes the session so the gate sees
  /// the upgrade immediately.
  Future<void> _openPaywall(BuildContext context, WidgetRef ref) async {
    final purchased = await PurchasesService.presentPaywall();
    if (!context.mounted) return;
    if (purchased) {
      await ref.read(sessionProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Welcome to Premium! 🎉')));
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
              ? 'Premium restored.'
              : 'No previous purchase found to restore.',
        ),
      ),
    );
  }

  void _openAuth(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
  }

  void _openAccount(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
  }

  void _todo(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        backgroundColor: AppTheme.ink,
      ),
    );
  }
}
