import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../data/models/question.dart';
import '../../../services/widget_sync_service.dart';
import '../../questions/providers/question_providers.dart';
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
    // Cover the case where the daily already resolved before this widget
    // mounted: ref.listen only fires on a *change*, so push the current value
    // once after the first frame (when Localizations — and so context.l10n —
    // is available).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWidget(ref.read(todaysDailyQuestionProvider).asData?.value);
    });

    final onboardingDone = ref.read(onboardingControllerProvider);
    // A brand moment on every launch — a touch longer on a first run (it leads
    // into the tutorial) than for a returning user (who just wants their daily).
    final splashFor = onboardingDone
        ? const Duration(milliseconds: 1100)
        : const Duration(milliseconds: 1900);
    _timer = Timer(splashFor, () {
      if (!mounted) return;
      setState(
        () => _phase = onboardingDone ? _Phase.home : _Phase.onboarding,
      );
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
    if (mounted) setState(() => _phase = _Phase.home);
  }

  /// Pushes [q] to the native home-screen widget(s). No-op for a missing or
  /// empty daily (the widget keeps showing its last good value). Best-effort —
  /// the service swallows any platform failure.
  void _syncWidget(Question? q) {
    if (!mounted || q == null || q.questionText.trim().isEmpty) return;
    WidgetSyncService.pushDaily(
      label: context.l10n.widgetDailyLabel,
      questionText: q.questionText,
      date: WidgetSyncService.dateOnly(DateTime.now()),
      questionId: q.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the home-screen widget in step with the app: push whenever the daily
    // resolves (loading → data), and re-push on a language change so the widget's
    // label follows the chosen language.
    ref.listen(todaysDailyQuestionProvider, (_, next) {
      _syncWidget(next.asData?.value);
    });
    ref.listen(localeControllerProvider, (_, _) {
      _syncWidget(ref.read(todaysDailyQuestionProvider).asData?.value);
    });

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
