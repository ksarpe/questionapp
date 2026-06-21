import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Renders the question with a white fill, crisp black outline and drop shadow.
///
/// Flutter can't both fill and stroke one [Text], so two are stacked: the
/// stroke (+ shadow) layer underneath and the white fill layer on top. Both use
/// identical layout so they align perfectly.
class StyledQuestionText extends StatelessWidget {
  const StyledQuestionText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final upper = text.toUpperCase();
    final size = QuestionTextStyles.fontSizeFor(text);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          upper,
          textAlign: TextAlign.center,
          style: QuestionTextStyles.strokeFor(size),
        ),
        Text(
          upper,
          textAlign: TextAlign.center,
          style: QuestionTextStyles.fillFor(size),
        ),
      ],
    );
  }
}

/// A single word in the question's signature style — the same stacked
/// stroke + fill treatment as [StyledQuestionText], but sized to one word so it
/// can be laid out and animated independently (see `FallingWordsText`).
///
/// [fontSize] is decided from the whole sentence (not this word), so every word
/// in a question shares one size — see [QuestionTextStyles.fontSizeFor].
class StyledWord extends StatelessWidget {
  const StyledWord(this.word, {required this.fontSize, super.key});

  final String word;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final upper = word.toUpperCase();
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(upper, style: QuestionTextStyles.strokeFor(fontSize)),
        Text(upper, style: QuestionTextStyles.fillFor(fontSize)),
      ],
    );
  }
}
