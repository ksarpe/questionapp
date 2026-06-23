import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'styled_question_text.dart';

/// A self-contained, share-ready poster of a single question: the Debatly
/// wordmark, the question rendered in the app's signature white-fill /
/// black-outline "sticker" style, and a tagline, on a dark orange-tinted
/// gradient.
///
/// Deliberately **theme-independent** — it reads no `context.colors`, so it
/// renders identically whether the app is in light or dark mode (and when drawn
/// off-screen by [renderWidgetToPng], where no app theme is in scope). That same
/// fixed dark look is what makes the render double as App Store / Play
/// screenshot source art, not just a chat-share image.
///
/// The default [size] is 9:16; captured at a 3× pixel ratio it yields a
/// 1080×1920 PNG.
class QuestionShareCard extends StatelessWidget {
  const QuestionShareCard({
    super.key,
    required this.questionText,
    required this.tagline,
    this.size = const Size(360, 640),
  });

  /// The full question text to feature (rendered uppercased, like on screen).
  final String questionText;

  /// Short brand line under the question, e.g. "Jedno przewrotne pytanie
  /// dziennie." Passed in (not hard-coded) so it stays localized.
  final String tagline;

  /// Logical size of the poster. 9:16 by default.
  final Size size;

  // Fixed palette (not from AppColors) so the poster looks the same in either
  // theme and when rendered with no theme at all.
  static const Color _bgTop = Color(0xFF0C0A14);
  static const Color _bgBottom = Color(0xFF171124);
  static const Color _taglineInk = Color(0xFFB9B4C6);

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            // Soft orange halo bleeding in from the top, echoing the splash glow.
            Positioned(
              top: -size.height * 0.16,
              left: -size.width * 0.10,
              right: -size.width * 0.10,
              child: Center(
                child: Container(
                  width: size.width * 1.1,
                  height: size.width * 1.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.spark.withValues(alpha: 0.30),
                        AppTheme.spark.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.09,
                vertical: size.height * 0.075,
              ),
              child: Column(
                children: [
                  _Wordmark(fontSize: size.width * 0.085),
                  // The hero: the question in the signature stacked stroke+fill
                  // style, centred in the band between the wordmark and the
                  // tagline. QuestionTextStyles already picks a font size from
                  // the length; the FittedBox is a backstop that scales a
                  // pathologically long question down so it can never overflow
                  // the fixed-height poster (normal lengths fit and aren't
                  // scaled).
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: size.width * 0.82,
                          child: StyledQuestionText(questionText),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TaglineFooter(text: tagline, accentWidth: size.width * 0.14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The static Debatly wordmark: a glowing orange bolt beside "Debatly" set in the
/// display font. A non-animated sibling of the splash/onboarding [SparkLogo],
/// safe to paint in a one-shot off-screen render.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.bolt,
          size: fontSize * 1.18,
          color: AppTheme.spark,
          shadows: [
            Shadow(
              color: AppTheme.spark.withValues(alpha: 0.55),
              blurRadius: fontSize * 0.7,
            ),
          ],
        ),
        SizedBox(width: fontSize * 0.06),
        Text(
          'Debatly',
          style: TextStyle(
            fontFamily: 'Anton',
            fontSize: fontSize,
            height: 1,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// A short spark-coloured rule above a muted, letter-spaced tagline — the
/// poster's footer.
class _TaglineFooter extends StatelessWidget {
  const _TaglineFooter({required this.text, required this.accentWidth});

  final String text;
  final double accentWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: accentWidth,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.spark,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: QuestionShareCard._taglineInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
