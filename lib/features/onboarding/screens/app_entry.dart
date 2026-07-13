import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/ads_bootstrap.dart';
import '../../monetization/providers/monetization_providers.dart';
import '../../questions/screens/question_screen.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart';

/// The app's first widget under `MaterialApp`: a tiny launch state machine that
/// shows the brand splash, then routes to the welcome tutorial on a first run or
/// straight to the daily for a returning user.
///
/// The onboarding flag is read synchronously (it's resolved off SharedPreferences
/// before the first frame in `main()`), so the branch is decided up front with no
/// loading flash. Phases cross-fade into one another.
class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

enum _Phase { splash, onboarding, home }

class _AppEntryState extends ConsumerState<AppEntry> {
  _Phase _phase = _Phase.splash;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final onboardingDone = ref.read(onboardingControllerProvider);
    // A brand moment on every launch — a touch longer on a first run (it leads
    // into the tutorial) than for a returning user (who just wants their daily).
    final splashFor = onboardingDone
        ? const Duration(milliseconds: 1100)
        : const Duration(milliseconds: 1900);
    _timer = Timer(splashFor, () {
      if (!mounted) return;
      if (onboardingDone) {
        _enterHome();
      } else {
        setState(() => _phase = _Phase.onboarding);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finishOnboarding() {
    // Persist so the tutorial never runs again, then reveal the live app.
    ref.read(onboardingControllerProvider.notifier).complete();
    if (mounted) _enterHome();
  }

  /// Reveals the live app and brings up the ad stack behind it.
  ///
  /// Consent (the UMP GDPR form + iOS ATT prompt) is deliberately gathered only
  /// HERE — once the home screen is on, never during onboarding — so the legal
  /// dialogs can't interrupt the welcome funnel (see [AdsBootstrap]). Once
  /// consent + AdMob are up, the shared rewarded-ad service re-preloads: its
  /// creation-time preload no-ops while the SDK is uninitialised, so this is
  /// what actually warms the first ad.
  void _enterHome() {
    setState(() => _phase = _Phase.home);
    unawaited(
      AdsBootstrap.ensureStarted().then((_) {
        if (mounted) ref.read(rewardedAdServiceProvider).preload();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_phase) {
      _Phase.splash => const SplashView(),
      _Phase.onboarding => OnboardingScreen(onFinish: _finishOnboarding),
      _Phase.home => const QuestionScreen(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Key on the phase so the switcher cross-fades between screens rather than
      // reusing the previous element.
      child: KeyedSubtree(key: ValueKey(_phase), child: child),
    );
  }
}
