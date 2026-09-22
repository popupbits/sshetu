import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:xterm2/xterm.dart';

import 'script_fallback.dart';

/// The monospace face, in one place.
///
/// It was spelled out at five call sites with three different fallback lists,
/// which is how a fingerprint ends up in a different font from the mapping
/// beside it. Anything that has to line up in a column — a fingerprint, a
/// `listen → target` mapping, a stack trace — uses this.
abstract final class Mono {
  /// The platform's own terminal face. Naming a real one matters: only
  /// Android resolves `monospace` to something monospaced, and Windows
  /// resolves it to the proportional UI font, so [fallback] is never reached.
  static String get family => switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'Cascadia Mono',
    TargetPlatform.macOS || TargetPlatform.iOS => 'SF Mono',
    TargetPlatform.linux => 'DejaVu Sans Mono',
    TargetPlatform.android => 'Roboto Mono',
    _ => 'monospace',
  };

  /// The monospaced faces first, so a gap in the chosen face is filled by
  /// something that still keeps the grid; then the platform Devanagari faces,
  /// so Nepali printed by a remote shell (`echo नमस्ते`) is drawn rather than
  /// shown as boxes. No Devanagari face is monospaced — none exists — so
  /// those glyphs are drawn at the cell width the terminal assigns them.
  static const List<String> fallback = [
    'SF Mono', // macOS
    'Menlo', // macOS, older
    'Consolas', // Windows
    'Cascadia Mono', // Windows, newer
    'DejaVu Sans Mono', // Linux
    'Roboto Mono', // Android
    'monospace',
    ...ScriptFallback.devanagari,
  ];

  /// [style] in the monospace face, with tabular figures.
  ///
  /// Tabular figures matter more than the face does: digits of differing
  /// widths make a column of ports or addresses shimmer as it scrolls.
  static TextStyle apply(TextStyle? style) =>
      (style ?? const TextStyle()).copyWith(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// One terminal colour scheme, as data: the sixteen ANSI colours plus the
/// four a terminal paints around them.
///
/// Values, not code: a preset is a published palette copied in once and cited,
/// and the tests can walk every one of them and check it is whole and legible.
@immutable
class TerminalPalette {
  const TerminalPalette({
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.selection,
    required this.ansi,
  });

  final Color foreground;
  final Color background;
  final Color cursor;

  /// Painted *under* the selected text (xterm2 draws selection before the
  /// glyphs), so an opaque colour does not hide what is selected.
  final Color selection;

  /// The sixteen ANSI colours in escape-code order: black, red, green, yellow,
  /// blue, magenta, cyan, white, then the bright variant of each.
  final List<Color> ansi;

  /// The number of colours [ansi] must hold.
  static const int ansiCount = 16;

  /// Whether this palette is meant for a light ground.
  bool get isLight => background.computeLuminance() > 0.5;
}

/// A named terminal colour scheme the user can pick.
///
/// Either fixed — a [palette] copied from a published theme, the same whatever
/// the app looks like — or adaptive, following the app's light or dark mode
/// and its accent. There is exactly one adaptive preset: the default.
@immutable
class TerminalThemePreset {
  const TerminalThemePreset({
    required this.id,
    required this.name,
    this.palette,
  });

  /// Stored in settings and in `hosts.terminal_theme`. Never change one: a
  /// renamed id silently repoints every host that chose it to the default.
  final String id;

  /// The theme's own name. Not translated: "Dracula" and "Nord" are proper
  /// nouns, and they are what people search for.
  final String name;

  /// Null for the adaptive preset, which is built from the app's colours.
  final TerminalPalette? palette;

  bool get isAdaptive => palette == null;

  /// The colours this preset paints with under [scheme].
  TerminalPalette paletteFor(ColorScheme scheme) =>
      palette ?? adaptiveTerminalPalette(scheme);

  /// The xterm2 theme for this preset under [scheme].
  ///
  /// Search highlights come from [scheme] for every preset, fixed ones
  /// included: they are the app's find bar showing through the terminal, and
  /// the scheme's container / on-container pairs are the ones built to be
  /// legible together. Borrowing, say, a palette's yellow would put the
  /// palette's background colour on it as text, which fails on half of them.
  TerminalTheme toTerminalTheme(ColorScheme scheme) {
    final p = paletteFor(scheme);
    final a = p.ansi;
    return TerminalTheme(
      cursor: p.cursor,
      selection: p.selection,
      foreground: p.foreground,
      background: p.background,
      black: a[0],
      red: a[1],
      green: a[2],
      yellow: a[3],
      blue: a[4],
      magenta: a[5],
      cyan: a[6],
      white: a[7],
      brightBlack: a[8],
      brightRed: a[9],
      brightGreen: a[10],
      brightYellow: a[11],
      brightBlue: a[12],
      brightMagenta: a[13],
      brightCyan: a[14],
      brightWhite: a[15],
      searchHitBackground: scheme.tertiaryContainer,
      searchHitBackgroundCurrent: scheme.tertiary,
      searchHitForeground: scheme.onTertiaryContainer,
    );
  }
}

/// The default preset's colours, matched to the app's.
///
/// Two halves, decided differently on purpose:
///
///  * **The chrome** — background, foreground, cursor, selection — comes from
///    the app's [ColorScheme], so a terminal sits *in* the window rather than
///    looking pasted into it, and so it follows the accent and theme mode the
///    user chose.
///  * **The sixteen ANSI colours are fixed**, and deliberately not derived
///    from the seed. Programs address them by meaning: red is an error, green
///    is a pass, and `git diff` is unreadable if the theme decided red should
///    be a tasteful mauve this week. Generating them would make every accent a
///    new opportunity to render someone's build output illegible.
///
/// The two palettes below are tuned for contrast against a dark and a light
/// ground respectively. They are close to the widely-used One Dark / One Light
/// sets, which exist precisely because this problem has been solved carefully
/// before.
TerminalPalette adaptiveTerminalPalette(ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return TerminalPalette(
    foreground: scheme.onSurface,
    background: scheme.surface,
    cursor: scheme.primary,
    // Alpha rather than a solid fill, so the selection reads as a tint of the
    // accent on whichever surface the app is showing.
    selection: scheme.primary.withValues(alpha: 0.30),
    ansi: dark ? _darkAnsi : _lightAnsi,
  );
}

/// For a dark ground: saturated enough to read, not so bright they glare.
const _darkAnsi = <Color>[
  Color(0xFF3F4451), // black
  Color(0xFFE06C75), // red
  Color(0xFF98C379), // green
  Color(0xFFE5C07B), // yellow
  Color(0xFF61AFEF), // blue
  Color(0xFFC678DD), // magenta
  Color(0xFF56B6C2), // cyan
  Color(0xFFABB2BF), // white
  Color(0xFF5C6370), // bright black
  Color(0xFFFF7A85), // bright red
  Color(0xFFB5E890), // bright green
  Color(0xFFF5D08A), // bright yellow
  Color(0xFF7FC4FF), // bright blue
  Color(0xFFDA8FF0), // bright magenta
  Color(0xFF68CBD8), // bright cyan
  Color(0xFFE6E6E6), // bright white
];

/// For a light ground: darker and more saturated, because the same hues that
/// read well on black wash out completely on white. A palette that is merely
/// inverted is a palette that makes yellow invisible.
const _lightAnsi = <Color>[
  Color(0xFF383A42), // black
  Color(0xFFCA1243), // red
  Color(0xFF3F7F2F), // green
  Color(0xFF9A6800), // yellow
  Color(0xFF0184BC), // blue
  Color(0xFFA626A4), // magenta
  Color(0xFF0997B3), // cyan
  Color(0xFF6A737D), // white
  Color(0xFF57606A), // bright black
  Color(0xFFE4506B), // bright red
  Color(0xFF2F6F1F), // bright green
  Color(0xFF7A5300), // bright yellow
  Color(0xFF0166A6), // bright blue
  Color(0xFF8B1D8A), // bright magenta
  Color(0xFF077D96), // bright cyan
  Color(0xFF24292F), // bright white
];
