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

  static const double _strokeWidth = 6;

  /// Bottom layer: the black outline, drawn slightly wider, with a drop shadow.
  static TextStyle get stroke => AppTheme.questionBase.copyWith(
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black,
    shadows: const [
      Shadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 6),
    ],
  );

  /// Top layer: the white fill sitting inside the outline.
  static TextStyle get fill =>
      AppTheme.questionBase.copyWith(color: Colors.white);
}
