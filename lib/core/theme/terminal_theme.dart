import 'package:material_ui/material_ui.dart';
import 'package:xterm2/xterm.dart';

/// The monospace face, in one place.
///
/// It was spelled out at five call sites with three different fallback lists,
/// which is how a fingerprint ends up in a different font from the mapping
/// beside it. Anything that has to line up in a column — a fingerprint, a
/// `listen → target` mapping, a stack trace — uses this.
abstract final class Mono {
  /// A generic family every platform resolves, with the usual per-platform
  /// faces named ahead of it so the result is the one people expect rather
  /// than whatever the system considers "monospace".
  static const String family = 'monospace';

  static const List<String> fallback = [
    'SF Mono', // macOS
    'Menlo', // macOS, older
    'Consolas', // Windows
    'Cascadia Mono', // Windows, newer
    'DejaVu Sans Mono', // Linux
    'Roboto Mono', // Android
    'monospace',
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

/// The terminal's colours, matched to the app's.
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
TerminalTheme appTerminalTheme(ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  final ansi = dark ? _darkAnsi : _lightAnsi;

  return TerminalTheme(
    cursor: scheme.primary,
    // Alpha rather than a solid fill: a selection must not hide the text it
    // is selecting, which is the one thing the user is looking at.
    selection: scheme.primary.withValues(alpha: 0.30),
    foreground: scheme.onSurface,
    background: scheme.surface,
    black: ansi.black,
    red: ansi.red,
    green: ansi.green,
    yellow: ansi.yellow,
    blue: ansi.blue,
    magenta: ansi.magenta,
    cyan: ansi.cyan,
    white: ansi.white,
    brightBlack: ansi.brightBlack,
    brightRed: ansi.brightRed,
    brightGreen: ansi.brightGreen,
    brightYellow: ansi.brightYellow,
    brightBlue: ansi.brightBlue,
    brightMagenta: ansi.brightMagenta,
    brightCyan: ansi.brightCyan,
    brightWhite: ansi.brightWhite,
    searchHitBackground: scheme.tertiaryContainer,
    searchHitBackgroundCurrent: scheme.tertiary,
    searchHitForeground: scheme.onTertiaryContainer,
  );
}

/// The sixteen ANSI colours for one brightness.
class _Ansi {
  const _Ansi({
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
  });

  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;
}

/// For a dark ground: saturated enough to read, not so bright they glare.
const _darkAnsi = _Ansi(
  black: Color(0xFF3F4451),
  red: Color(0xFFE06C75),
  green: Color(0xFF98C379),
  yellow: Color(0xFFE5C07B),
  blue: Color(0xFF61AFEF),
  magenta: Color(0xFFC678DD),
  cyan: Color(0xFF56B6C2),
  white: Color(0xFFABB2BF),
  brightBlack: Color(0xFF5C6370),
  brightRed: Color(0xFFFF7A85),
  brightGreen: Color(0xFFB5E890),
  brightYellow: Color(0xFFF5D08A),
  brightBlue: Color(0xFF7FC4FF),
  brightMagenta: Color(0xFFDA8FF0),
  brightCyan: Color(0xFF68CBD8),
  brightWhite: Color(0xFFE6E6E6),
);

/// For a light ground: darker and more saturated, because the same hues that
/// read well on black wash out completely on white. A palette that is merely
/// inverted is a palette that makes yellow invisible.
const _lightAnsi = _Ansi(
  black: Color(0xFF383A42),
  red: Color(0xFFCA1243),
  green: Color(0xFF3F7F2F),
  yellow: Color(0xFF9A6800),
  blue: Color(0xFF0184BC),
  magenta: Color(0xFFA626A4),
  cyan: Color(0xFF0997B3),
  white: Color(0xFF6A737D),
  brightBlack: Color(0xFF57606A),
  brightRed: Color(0xFFE4506B),
  brightGreen: Color(0xFF2F6F1F),
  brightYellow: Color(0xFF7A5300),
  brightBlue: Color(0xFF0166A6),
  brightMagenta: Color(0xFF8B1D8A),
  brightCyan: Color(0xFF077D96),
  brightWhite: Color(0xFF24292F),
);
