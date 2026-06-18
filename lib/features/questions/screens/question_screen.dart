import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/providers/session_providers.dart';
import '../../monetization/providers/monetization_providers.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/question_providers.dart';
import '../widgets/daily_badge.dart';
import '../widgets/go_deeper_button.dart';
import '../widgets/smaczki_panel.dart';
import '../widgets/wind_question_view.dart';

/// The home screen: a single styled question centred on a clean canvas, with a
/// settings gear top-right and a small info icon just above the question.
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off silent anonymous auth + entitlement loading at launch, and start
    // pre-loading a rewarded ad so the unlock sheet is responsive the first time
    // a free user is gated. Reading them here is enough to instantiate them; the
    // daily question every user opens to is free.
    ref.watch(sessionProvider);
    ref.watch(rewardedAdServiceProvider);

    // The deck drives the body: it stays empty until today's daily resolves, so
    // every user opens to the daily rather than a flash of the pool. Watching it
    // here also kicks off the daily fetch at launch, alongside the question pool.
    final questionsError = ref.watch(questionsProvider).error;
    final deck = ref.watch(questionDeckProvider);

    return Scaffold(
      // Let the body fill the whole screen so the question centres against the
      // true midpoint; the (transparent) app bar floats over the top.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // "Daily" badge in the top-left, facing the settings gear. Wider than
        // the default leading slot so the localized label is not clipped; the
        // badge hides itself unless the daily question is the one on screen.
        leadingWidth: 180,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Align(alignment: Alignment.centerLeft, child: DailyBadge()),
        ),
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
      body: questionsError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load questions.\n$questionsError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.subtle),
                ),
              ),
            )
          : deck.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : const _QuestionBody(),
    );
  }
}

class _QuestionBody extends ConsumerWidget {
  const _QuestionBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Which question's smaczki the "go deeper" panel loads. The body only
    // renders once the deck is ready, so this is non-null in practice.
    final questionId = ref.watch(currentQuestionProvider)?.id;

    // Warm the smaczki for the visible question in the background, so the
    // "go deeper" panel opens straight to content instead of a spinner. The
    // result is ignored here — the panel reads the same, now-resolved provider
    // (FutureProvider.family caches per question id). Each swipe re-warms the
    // newly visible question.
    if (questionId != null) {
      ref.watch(smaczkiProvider(questionId));
    }

    // The question is centred against the FULL screen (no SafeArea around it),
    // so the app bar and system insets don't nudge it off-centre. Only the
    // bottom overlay — the swipe hint and the "go deeper" button — respects the
    // safe area.
    return Stack(
      children: [
        const Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(child: WindQuestionView()),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtle hint that questions are swipeable.
                  const Text(
                    'Przesuń, aby zobaczyć następne pytanie',
                    style: TextStyle(color: AppTheme.subtle, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  // The glowing "go deeper" pill opens the Smaczki panel for
                  // the question currently on screen.
                  GoDeeperButton(
                    onTap: questionId == null
                        ? () {}
                        : () => showSmaczkiSheet(context, questionId),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
