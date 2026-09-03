import 'package:material_ui/material_ui.dart';

/// Applies a Google Font to a `material_ui` [TextTheme].
///
/// ## Why this exists
///
/// `GoogleFonts.interTextTheme()` returns a `TextTheme` from
/// `package:flutter/material.dart` — the frozen Material library. `material_ui`
/// declares its own [TextTheme], and its [ThemeData] will not accept the frozen
/// one. The two types are structurally identical and mutually unassignable.
///
/// The way through is to never touch the package's `*TextTheme()` helpers and
/// instead call the per-font builder — `GoogleFonts.inter(textStyle: …)`, which
/// deals only in [TextStyle], a type both libraries share — once per slot, and
/// assemble a `material_ui` [TextTheme] from the results. That is exactly what
/// `interTextTheme` does internally; this is its body, retyped.
///
/// ```dart
/// textTheme: googleFontsTextTheme(base.textTheme, GoogleFonts.inter),
/// ```
///
/// Swapping fonts is a one-word change at the call site.
typedef GoogleFontBuilder = TextStyle Function({TextStyle? textStyle});

TextTheme googleFontsTextTheme(TextTheme base, GoogleFontBuilder font) {
  return TextTheme(
    displayLarge: font(textStyle: base.displayLarge),
    displayMedium: font(textStyle: base.displayMedium),
    displaySmall: font(textStyle: base.displaySmall),
    headlineLarge: font(textStyle: base.headlineLarge),
    headlineMedium: font(textStyle: base.headlineMedium),
    headlineSmall: font(textStyle: base.headlineSmall),
    titleLarge: font(textStyle: base.titleLarge),
    titleMedium: font(textStyle: base.titleMedium),
    titleSmall: font(textStyle: base.titleSmall),
    bodyLarge: font(textStyle: base.bodyLarge),
    bodyMedium: font(textStyle: base.bodyMedium),
    bodySmall: font(textStyle: base.bodySmall),
    labelLarge: font(textStyle: base.labelLarge),
    labelMedium: font(textStyle: base.labelMedium),
    labelSmall: font(textStyle: base.labelSmall),
  );
}
