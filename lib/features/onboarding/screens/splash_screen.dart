import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../widgets/spark_logo.dart';

/// The launch splash: just the animated wordmark, centred on the black canvas.
///
/// Shown for a beat on every cold start (see `AppEntry`), it carries no logic of
/// its own — the parent decides how long it lingers and what comes next (the
/// tutorial on a first run, the daily otherwise).
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(child: SparkLogo(size: 64)),
    );
  }
}
