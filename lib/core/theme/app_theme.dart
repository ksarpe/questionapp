import 'package:flutter/material.dart';

/// Central place for colours, the global [ThemeData], and the signature
/// "outlined + shadowed" text styling used for the question.
class AppTheme {
  AppTheme._();

  /// Pure black canvas — high contrast and distraction-free.
  static const Color background = Color(0xFF000000);

  /// Primary foreground (text + icons): white.
  static const Color ink = Color(0xFFFFFFFF);

  /// Muted grey for secondary text and accent surfaces (buttons, dividers).
  static const Color subtle = Color(0xFF8A8A8A);

  /// Slightly darker grey used for raised/accent surfaces on the black canvas.
  static const Color accent = Color(0xFF2A2A2A);

  /// Violet "spark" accent — used for the glowing "go deeper" affordance.
  static const Color spark = Color(0xFF8B5CF6);

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: subtle,
      scaffoldBackgroundColor: background,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        surface: background,
        primary: subtle,
        secondary: subtle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      iconTheme: const IconThemeData(color: ink),
      dividerColor: accent,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
        ),
      ),
    );
  }

  /// Base geometry for the question text. Colour/stroke are applied per-layer
  /// in [QuestionTextStyles], so this only carries size, weight and spacing.
  /// The size is the *largest* used; long questions shrink it via
  /// [QuestionTextStyles.fontSizeFor] so they don't become a wall of text.
  static const TextStyle questionBase = TextStyle(
    fontFamily: 'Anton',
    fontSize: 42,
    fontWeight: FontWeight.w400,
    height: 1.15,
    letterSpacing: 0.5,
  );
}

/// The two paint layers that produce the white-fill / black-stroke look.
///
/// Flutter cannot fill *and* stroke a single [Text] in one pass, so the
/// question is rendered as two stacked [Text] widgets sharing these styles.
class QuestionTextStyles {
  QuestionTextStyles._();

  /// Largest font size, used for short questions.
  static const double maxFontSize = 42;

  /// Smallest font size, used for very long questions.
  static const double minFontSize = 26;

  /// Length (in characters) up to which the text stays at [maxFontSize], and
  /// the length at/after which it bottoms out at [minFontSize]. Between them the
  /// size scales linearly so longer questions read as several tidy lines rather
  /// than an overflowing block.
  static const int _shortLen = 55;
  static const int _longLen = 150;

  /// Outline width relative to the font size, so the stroke stays proportional
  /// when the text shrinks (6px at the 42px base size).
  static const double _strokeRatio = 6 / 42;

  /// Picks a font size for [text] based on its length, clamped to
  /// [minFontSize]..[maxFontSize].
  static double fontSizeFor(String text) {
    final len = text.trim().length;
    if (len <= _shortLen) return maxFontSize;
    if (len >= _longLen) return minFontSize;
    final t = (len - _shortLen) / (_longLen - _shortLen);
    return maxFontSize - t * (maxFontSize - minFontSize);
  }

  /// Bottom layer: the black outline, drawn slightly wider, with a drop shadow.
  static TextStyle strokeFor(double fontSize) =>
      AppTheme.questionBase.copyWith(
        fontSize: fontSize,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fontSize * _strokeRatio
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black,
        shadows: const [
          Shadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 6),
        ],
      );

  /// Top layer: the white fill sitting inside the outline.
  static TextStyle fillFor(double fontSize) =>
      AppTheme.questionBase.copyWith(fontSize: fontSize, color: Colors.white);
}
