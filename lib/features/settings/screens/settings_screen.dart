import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/providers/session_providers.dart';
import '../../account/screens/auth_screen.dart';
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
              onTap: () => _openAuth(context),
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
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Go Premium'),
            subtitle: const Text('Unlock every question'),
            onTap: () => _todo(context, 'Premium / RevenueCat paywall'),
          ),
        ],
      ),
    );
  }

  void _openAuth(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
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
