import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';

/// A borderless "← Wróć do darmowego pytania" link used on the reveal-slot
/// states, so the paywall and the "no more" screen each carry their own visible
/// escape back to the free question instead of relying on a faint
/// bottom-of-screen link the user may not notice. The reveal slot is free-only
/// (premium never reaches it), so the "free question" wording always fits here.
class BackToDailyLink extends StatelessWidget {
  const BackToDailyLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.colors.subtle,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: Text(context.l10n.backToFreeQuestion),
    );
  }
}
