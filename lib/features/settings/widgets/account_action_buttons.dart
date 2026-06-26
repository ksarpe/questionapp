import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import 'settings_primitives.dart';

/// Full-width bordered "Sign out" action. Shows a spinner and ignores taps
/// while a sign-out is in flight, so a slow token revoke never looks like a
/// dead button or fires twice.
class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key, required this.onTap, this.loading = false});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.hairline),
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: context.colors.ink,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: context.colors.ink,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.l10n.signOut,
                      style: TextStyle(
                        color: context.colors.ink,
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
class SignInButton extends StatelessWidget {
  const SignInButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
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
class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: kDanger),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: Text(
          context.l10n.deleteAccount,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
