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
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: QuestionTextStyles.stroke,
        ),
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: QuestionTextStyles.fill,
        ),
      ],
    );
  }
}

/// A single word in the question's signature style — the same stacked
/// stroke + fill treatment as [StyledQuestionText], but sized to one word so it
/// can be laid out and animated independently (see `FallingWordsText`).
class StyledWord extends StatelessWidget {
  const StyledWord(this.word, {super.key});

  final String word;

  @override
  Widget build(BuildContext context) {
    final upper = word.toUpperCase();
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(upper, style: QuestionTextStyles.stroke),
        Text(upper, style: QuestionTextStyles.fill),
      ],
    );
  }
}
