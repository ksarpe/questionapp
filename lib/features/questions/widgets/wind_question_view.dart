import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../monetization/providers/monetization_providers.dart';
import '../../monetization/widgets/unlock_question_sheet.dart';
import '../providers/question_providers.dart';
import 'falling_words_text.dart';

/// Displays the current question and runs the signature "wind" transition.
///
/// On a horizontal swipe the current text accelerates off in the direction of
/// the swipe — as if blown away — then, after a short beat, the *next* question
/// in the queue assembles itself word by word, each word dropping in from above
/// (see [FallingWordsText]). Swiping right does not go back; it only changes the
/// direction the old text leaves by. No cards, no flips: just text in motion.
class WindQuestionView extends ConsumerStatefulWidget {
  const WindQuestionView({super.key});

  @override
  ConsumerState<WindQuestionView> createState() => _WindQuestionViewState();
}

class _WindQuestionViewState extends ConsumerState<WindQuestionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Offsets are expressed as a fraction of screen width and converted to pixels
  // at paint time, so the text fully clears the screen regardless of its size.
  Animation<Offset> _offset = const AlwaysStoppedAnimation(Offset.zero);
  Animation<double> _opacity = const AlwaysStoppedAnimation(1);

  /// The text currently painted. While idle it tracks the provider; during a
  /// transition it is frozen so the OUT phase keeps showing the old question.
  String _displayedText = '';
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Intercepts a swipe and decides whether the "wind" transition runs.
  ///
  /// Premium users (and free users with an unlock credit) advance immediately.
  /// A free user out of credits is *not* animated; instead the unlock sheet
  /// opens, and the swipe only completes if they watch an ad or buy premium.
  Future<void> _attemptAdvance(int direction) async {
    if (_animating) return;

    final gate = ref.read(swipeGateProvider);
    if (gate.requestAdvance() == SwipeDecision.allowed) {
      await _flyToNext(direction);
      return;
    }

    // Gated: open the unlock sheet rather than animating the text.
    final outcome = await showUnlockSheet(context);
    if (!mounted || outcome != UnlockOutcome.unlocked) return;

    // The sheet granted a credit (ad) or upgraded to premium — spend one for
    // this swipe and run the transition.
    if (ref.read(swipeGateProvider).requestAdvance() == SwipeDecision.allowed) {
      await _flyToNext(direction);
    }
  }

  /// Runs the transition to the next question.
  ///
  /// [direction] is the sign of the swipe: -1 for a leftward swipe (text leaves
  /// to the left) and +1 for a rightward swipe (text leaves to the right). The
  /// deck always advances forward regardless of direction; once the old text
  /// has blown away the new question drops in word by word.
  Future<void> _flyToNext(int direction) async {
    if (_animating) return;
    _animating = true;

    // OUT — accelerate the current text off the swiped edge, fading as it goes.
    final exitEnd = Offset(1.5 * direction, 0);
    _offset = Tween(begin: Offset.zero, end: exitEnd)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
    _opacity = Tween(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    await _controller.forward(from: 0);

    // A short beat with an empty canvas before the new sentence assembles.
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    // Advance the deck, snap the outer transform back to centre, and hand the
    // new text to FallingWordsText, which drops it in word by word.
    ref.read(questionIndexProvider.notifier).next();
    final next = ref.read(currentQuestionProvider);
    setState(() {
      _offset = const AlwaysStoppedAnimation(Offset.zero);
      _opacity = const AlwaysStoppedAnimation(1);
      _displayedText = next?.questionText ?? _displayedText;
    });

    _animating = false;
  }

  /// Fires as each word of the new question lands. The hook is intentionally
  /// empty for now — this is where a per-word haptic tick will go.
  void _onWordLanded() {
    // TODO(vibration): add a short haptic here, e.g.
    // HapticFeedback.selectionClick(), so each landing word can be felt.
  }

  @override
  Widget build(BuildContext context) {
    // Keep the painted text in sync with the provider while idle. Assigning the
    // field here (rather than setState) is safe — we are already building.
    final current = ref.watch(currentQuestionProvider);
    if (!_animating && current != null && current.questionText != _displayedText) {
      _displayedText = current.questionText;
    }

    final width = MediaQuery.of(context).size.width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // A negative velocity is a leftward swipe, positive is rightward; the
        // sign drives which edge the text leaves by. The monetization gate
        // decides whether the swipe actually advances (see _attemptAdvance).
        if (velocity.abs() > 100) _attemptAdvance(velocity > 0 ? 1 : -1);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_offset.value.dx * width, 0),
            child: Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: FallingWordsText(_displayedText, onWordLanded: _onWordLanded),
      ),
    );
  }
}
