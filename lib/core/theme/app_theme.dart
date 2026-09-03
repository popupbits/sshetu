import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'accent.dart';
import 'google_fonts_text_theme.dart';
import 'tokens.dart';

/// Builds the app's light and dark themes from the chosen accent.
///
/// The accent is a parameter rather than a constant so a colour the user picked
/// reaches every widget through the theme, instead of through hardcoded values
/// scattered across screens.
abstract final class AppTheme {
  static ThemeData light(AccentOption accent) =>
      _build(Brightness.light, accent);

  static ThemeData dark(AccentOption accent) => _build(Brightness.dark, accent);

  static ThemeData _build(Brightness brightness, AccentOption accent) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent.forBrightness(brightness),
      brightness: brightness,
    );

    final base = ThemeData(brightness: brightness, colorScheme: colorScheme);

    return base.copyWith(
      // See google_fonts_text_theme.dart for why this is not
      // `GoogleFonts.interTextTheme()`.
      textTheme: googleFontsTextTheme(base.textTheme, GoogleFonts.inter),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        centerTitle: false,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: Spacing.md),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: BorderWidths.hairline,
        color: colorScheme.outlineVariant,
      ),
    );
  }
}
