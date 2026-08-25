import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'syntra_palette.dart';

abstract final class SyntraTheme {
  static TextStyle sans({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle serif({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.sourceSerif4(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SyntraPalette.voidColor,
      colorScheme: const ColorScheme.light(
        surface: SyntraPalette.surface,
        primary: SyntraPalette.rust,
        secondary: SyntraPalette.navy,
        onSurface: SyntraPalette.ink,
        onPrimary: SyntraPalette.onAccent,
        error: SyntraPalette.danger,
      ),
    );

    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          color: SyntraPalette.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
          height: 0.98,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          color: SyntraPalette.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: text.titleLarge?.copyWith(
          color: SyntraPalette.navy,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: text.titleMedium?.copyWith(
          color: SyntraPalette.navy,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: text.bodyLarge?.copyWith(
          color: SyntraPalette.ink,
          height: 1.5,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          color: SyntraPalette.inkMuted,
          height: 1.5,
        ),
        labelLarge: text.labelLarge?.copyWith(
          color: SyntraPalette.ink,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelSmall: text.labelSmall?.copyWith(
          color: SyntraPalette.inkFaint,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
