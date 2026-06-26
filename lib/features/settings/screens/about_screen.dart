import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sub_screen_chrome.dart';
import '../../onboarding/widgets/spark_logo.dart';
import '../providers/app_info_provider.dart';

/// Reached from the "About" account row: the brand mark, the running version /
/// build (from [appInfoProvider]) and a one-line summary of what the app is.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final info = ref.watch(appInfoProvider).value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          const TopGlow(),
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
                      SubScreenHeader(
                        title: l10n.settingsAbout,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 56),
                      const Center(child: SparkLogo(size: 46)),
                      const SizedBox(height: 22),
                      if (info != null)
                        Center(
                          child: Text(
                            l10n.aboutVersion(info.version, info.build),
                            style: TextStyle(
                              color: context.colors.subtle,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.aboutTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.subtle,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          '© 2026 Debatly',
                          style: TextStyle(
                            color: context.colors.subtle,
                            fontSize: 12,
                          ),
                        ),
                      ),
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
}
