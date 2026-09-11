import 'package:flutter/material.dart';

import '../ui/chamfer.dart';

/// Circuit Noir palette: AMOLED black with the brand blue → teal.
abstract final class LS {
  static const bg = Color(0xFF000000);
  static const well = Color(0xFF04080C);
  static const surface = Color(0xFF0A1016);
  static const surface2 = Color(0xFF111A23);
  static const line = Color(0xFF1E2A36);
  static const trace = Color(0xFF0A131B);

  static const text = Color(0xFFEAF2F7);
  static const muted = Color(0xFF8C9DAD);
  static const dim = Color(0xFF667A8C);

  static const teal = Color(0xFF34C29A);
  static const blue = Color(0xFF3B7BF0);
  static const aqua = Color(0xFF2BB3D6);
  static const violet = Color(0xFF8C8CFF);
  static const gold = Color(0xFFF5C542);
  static const coral = Color(0xFFFF5A6E);

  static const brandGradient = LinearGradient(colors: [blue, teal]);
}

/// Bundled font families (assets/fonts). Missing files fall back to the
/// platform font, so layout never breaks.
abstract final class LSFonts {
  static const display = 'Rajdhani';
  static const body = 'IBMPlexSans';
  static const mono = 'JetBrainsMono';
}

abstract final class LSText {
  /// Condensed uppercase titles. Callers pass text through [DisplayText],
  /// which upper-cases it.
  static TextStyle display(double size, {Color color = LS.text}) => TextStyle(
    fontFamily: LSFonts.display,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: size * 0.03,
    color: color,
  );

  static TextStyle body(
    double size, {
    Color color = LS.text,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
  }) => TextStyle(
    fontFamily: LSFonts.body,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
  );

  /// Data and labels: scores, counts, section headings.
  static TextStyle mono(
    double size, {
    Color color = LS.muted,
    FontWeight weight = FontWeight.w500,
    double spacing = 0.12,
  }) => TextStyle(
    fontFamily: LSFonts.mono,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: size * spacing,
    height: 1.2,
    color: color,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: LS.bg,
    fontFamily: LSFonts.body,
    colorScheme: const ColorScheme.dark(
      primary: LS.teal,
      onPrimary: LS.bg,
      secondary: LS.blue,
      onSecondary: LS.bg,
      surface: LS.surface,
      onSurface: LS.text,
      error: LS.coral,
    ),
    splashColor: LS.teal.withValues(alpha: 0.12),
    highlightColor: LS.teal.withValues(alpha: 0.06),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: LS.teal,
      selectionColor: LS.teal.withValues(alpha: 0.3),
      selectionHandleColor: LS.teal,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: LS.surface2,
      contentTextStyle: LSText.body(14),
      behavior: SnackBarBehavior.floating,
      shape: chamfer(Cut.sm),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: LS.surface,
      shape: chamfer(Cut.lg, border: LS.line),
      titleTextStyle: LSText.display(24),
      contentTextStyle: LSText.body(15, color: LS.muted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBarrierColor: Color(0xB3020908),
    ),
  );
}
