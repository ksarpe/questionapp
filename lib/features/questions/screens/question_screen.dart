import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/providers/session_providers.dart';
import '../../monetization/providers/monetization_providers.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/question_providers.dart';
import '../widgets/hint_handle.dart';
import '../widgets/smaczki_panel.dart';
import '../widgets/wind_question_view.dart';

/// The home screen: a single styled question centred on a clean canvas, with a
/// settings gear top-right and a small info icon just above the question.
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(questionsProvider);

    // Kick off silent anonymous auth + entitlement loading at launch, and start
    // pre-loading a rewarded ad so the unlock sheet is responsive the first time
    // a free user is gated. Reading them here is enough to instantiate them; the
    // screen renders regardless of their state (the first question is free).
    ref.watch(sessionProvider);
    ref.watch(rewardedAdServiceProvider);

    return Scaffold(
      // The "Smaczki" panel slides in from the right, opened by the hand handle.
      endDrawer: const SmaczkiPanel(),
      // Let the body fill the whole screen so the question centres against the
      // true midpoint; the (transparent) app bar floats over the top.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Settings gear in the top-right corner.
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: questions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load questions.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.subtle),
            ),
          ),
        ),
        data: (_) => const _QuestionBody(),
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody();

  @override
  Widget build(BuildContext context) {
    // The question is centred against the FULL screen (no SafeArea around it),
    // so the app bar and system insets don't nudge it off-centre. Only the
    // overlays — the hand handle and the swipe hint — respect the safe area.
    return Stack(
      children: [
        const Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(child: WindQuestionView()),
          ),
        ),
        // Hand handle poking out of the right edge, just above the question.
        // Tap it or pull it left to open the "Smaczki" panel.
        const SafeArea(
          child: Align(alignment: Alignment(1, -0.5), child: HintHandle()),
        ),
        // Subtle hint that questions are swipeable.
        const SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Swipe for the next question',
                style: TextStyle(color: AppTheme.subtle, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
