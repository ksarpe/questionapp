import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';

/// Shown when the launch fetch fails (typically no network) and there is nothing
/// to render. Replaces the old endless spinner with a friendly message and a
/// retry that re-runs sign-in + the question/daily/stats fetches.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: context.colors.subtle, size: 40),
            const SizedBox(height: 16),
            Text(
              context.l10n.loadErrorTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.loadErrorBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.subtle, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
