import 'package:material_ui/material_ui.dart';

import 'terminal_theme.dart';

/// Every terminal colour scheme the app offers, and the rules for finding one.
///
/// The fixed palettes are copied from each theme's own published source, cited
/// beside it, so a correction is a comparison against one file rather than an
/// argument about taste. Colour literals are allowed here and nowhere near a
/// widget: a terminal palette is data that programs address by index, not a
/// piece of the app's chrome.
abstract final class TerminalThemePresets {
  /// The adaptive preset, and what a missing or unknown id resolves to.
  static const String defaultId = 'sshetu';

  /// Follows the app: light or dark, and the chosen accent.
  static const sshetu = TerminalThemePreset(id: defaultId, name: 'SSHetu');

  /// Source: Dracula's own Alacritty port, which carries the spec's terminal
  /// colours — https://github.com/dracula/alacritty/blob/master/dracula.toml
  /// (see also https://draculatheme.com/spec).
  static const dracula = TerminalThemePreset(
    id: 'dracula',
    name: 'Dracula',
    palette: TerminalPalette(
      foreground: Color(0xFFF8F8F2),
      background: Color(0xFF282A36),
      cursor: Color(0xFFF8F8F2),
      selection: Color(0xFF44475A),
      ansi: [
        Color(0xFF21222C),
        Color(0xFFFF5555),
        Color(0xFF50FA7B),
        Color(0xFFF1FA8C),
        Color(0xFFBD93F9),
        Color(0xFFFF79C6),
        Color(0xFF8BE9FD),
        Color(0xFFF8F8F2),
        Color(0xFF6272A4),
        Color(0xFFFF6E6E),
        Color(0xFF69FF94),
        Color(0xFFFFFFA5),
        Color(0xFFD6ACFF),
        Color(0xFFFF92DF),
        Color(0xFFA4FFFF),
        Color(0xFFFFFFFF),
      ],
    ),
  );

  /// Source: Nord's official Xresources port, which maps the sixteen ANSI
  /// slots onto nord0–nord15 —
  /// https://github.com/nordtheme/xresources/blob/develop/src/nord.
  /// Selection is nord2, which Nord's docs name for selection highlights.
  static const nord = TerminalThemePreset(
    id: 'nord',
    name: 'Nord',
    palette: TerminalPalette(
      foreground: Color(0xFFD8DEE9), // nord4
      background: Color(0xFF2E3440), // nord0
      cursor: Color(0xFFD8DEE9), // nord4
      selection: Color(0xFF434C5E), // nord2
      ansi: [
        Color(0xFF3B4252), // nord1
        Color(0xFFBF616A), // nord11
        Color(0xFFA3BE8C), // nord14
        Color(0xFFEBCB8B), // nord13
        Color(0xFF81A1C1), // nord9
        Color(0xFFB48EAD), // nord15
        Color(0xFF88C0D0), // nord8
        Color(0xFFE5E9F0), // nord5
        Color(0xFF4C566A), // nord3
        Color(0xFFBF616A), // nord11
        Color(0xFFA3BE8C), // nord14
        Color(0xFFEBCB8B), // nord13
        Color(0xFF81A1C1), // nord9
        Color(0xFFB48EAD), // nord15
        Color(0xFF8FBCBB), // nord7
        Color(0xFFECEFF4), // nord6
      ],
    ),
  );

  /// Solarized's sixteen ANSI slots, shared by both variants — the table in
  /// https://github.com/altercation/solarized/blob/master/README.md
  /// (https://ethanschoonover.com/solarized/): black base02, white base2,
  /// bright black base03, bright green/yellow/blue/cyan base01/base00/base0/
  /// base1, bright red orange, bright magenta violet, bright white base3.
  static const _solarizedAnsi = <Color>[
    Color(0xFF073642), // base02
    Color(0xFFDC322F), // red
    Color(0xFF859900), // green
    Color(0xFFB58900), // yellow
    Color(0xFF268BD2), // blue
    Color(0xFFD33682), // magenta
    Color(0xFF2AA198), // cyan
    Color(0xFFEEE8D5), // base2
    Color(0xFF002B36), // base03
    Color(0xFFCB4B16), // orange
    Color(0xFF586E75), // base01
    Color(0xFF657B83), // base00
    Color(0xFF839496), // base0
    Color(0xFF6C71C4), // violet
    Color(0xFF93A1A1), // base1
    Color(0xFFFDF6E3), // base3
  ];

  /// Source: as [_solarizedAnsi]. Body text base0 on base03, as the README
  /// specifies for the dark mode.
  static const solarizedDark = TerminalThemePreset(
    id: 'solarized-dark',
    name: 'Solarized Dark',
    palette: TerminalPalette(
      foreground: Color(0xFF839496), // base0
      background: Color(0xFF002B36), // base03
      cursor: Color(0xFF93A1A1), // base1
      selection: Color(0xFF073642), // base02
      ansi: _solarizedAnsi,
    ),
  );

  /// Source: as [_solarizedAnsi], with one deliberate departure. The README
  /// sets light-mode body text in base00 (#657B83), which measures 4.1:1
  /// against base3 — under WCAG's 4.5:1 for body text, and a terminal is
  /// nothing but body text. This uses base01 (#586E75, 5.0:1), the next step
  /// of the same ramp, which Solarized itself assigns to emphasised content.
  static const solarizedLight = TerminalThemePreset(
    id: 'solarized-light',
    name: 'Solarized Light',
    palette: TerminalPalette(
      foreground: Color(0xFF586E75), // base01, see above
      background: Color(0xFFFDF6E3), // base3
      cursor: Color(0xFF586E75), // base01
      selection: Color(0xFFEEE8D5), // base2
      ansi: _solarizedAnsi,
    ),
  );

  /// Source: the gruvbox palette, https://github.com/morhetz/gruvbox (README
  /// palette and `colors/gruvbox.vim`), dark mode with medium contrast.
  /// Selection is bg3 (#665C54), gruvbox's selection grey.
  static const gruvboxDark = TerminalThemePreset(
    id: 'gruvbox-dark',
    name: 'Gruvbox Dark',
    palette: TerminalPalette(
      foreground: Color(0xFFEBDBB2), // fg / light1
      background: Color(0xFF282828), // bg / dark0
      cursor: Color(0xFFEBDBB2),
      selection: Color(0xFF665C54), // bg3
      ansi: [
        Color(0xFF282828),
        Color(0xFFCC241D),
        Color(0xFF98971A),
        Color(0xFFD79921),
        Color(0xFF458588),
        Color(0xFFB16286),
        Color(0xFF689D6A),
        Color(0xFFA89984),
        Color(0xFF928374),
        Color(0xFFFB4934),
        Color(0xFFB8BB26),
        Color(0xFFFABD2F),
        Color(0xFF83A598),
        Color(0xFFD3869B),
        Color(0xFF8EC07C),
        Color(0xFFEBDBB2),
      ],
    ),
  );

  /// Source: the "night" variant as shipped for terminals by the theme's
  /// author — https://github.com/folke/tokyonight.nvim/blob/main/extras/kitty/tokyonight_night.conf
  static const tokyoNight = TerminalThemePreset(
    id: 'tokyo-night',
    name: 'Tokyo Night',
    palette: TerminalPalette(
      foreground: Color(0xFFC0CAF5),
      background: Color(0xFF1A1B26),
      cursor: Color(0xFFC0CAF5),
      selection: Color(0xFF283457),
      ansi: [
        Color(0xFF15161E),
        Color(0xFFF7768E),
        Color(0xFF9ECE6A),
        Color(0xFFE0AF68),
        Color(0xFF7AA2F7),
        Color(0xFFBB9AF7),
        Color(0xFF7DCFFF),
        Color(0xFFA9B1D6),
        Color(0xFF414868),
        Color(0xFFFF899D),
        Color(0xFF9FE044),
        Color(0xFFFABA4A),
        Color(0xFF8DB0FF),
        Color(0xFFC7A9FF),
        Color(0xFFA4DAFF),
        Color(0xFFC0CAF5),
      ],
    ),
  );

  /// Source: Atom's One Dark defines no terminal, so the chrome is Atom's own
  /// — background, text, cursor (`@syntax-accent`) and selection
  /// (`lighten(@syntax-bg, 10%)`) from
  /// https://github.com/atom/atom/tree/master/packages/one-dark-syntax/styles
  /// — and the sixteen ANSI colours are Zed's One Dark terminal, the
  /// maintained port of the same palette:
  /// https://github.com/zed-industries/zed/blob/main/assets/themes/one/one.json
  static const oneDark = TerminalThemePreset(
    id: 'one-dark',
    name: 'One Dark',
    palette: TerminalPalette(
      foreground: Color(0xFFABB2BF),
      background: Color(0xFF282C34),
      cursor: Color(0xFF528BFF),
      selection: Color(0xFF3E4451),
      ansi: [
        Color(0xFF282C34),
        Color(0xFFE06C75),
        Color(0xFF98C379),
        Color(0xFFE5C07B),
        Color(0xFF61AFEF),
        Color(0xFFC678DD),
        Color(0xFF56B6C2),
        Color(0xFFABB2BF),
        Color(0xFF636D83),
        Color(0xFFEA858B),
        Color(0xFFAAD581),
        Color(0xFFFFD885),
        Color(0xFF85C1FF),
        Color(0xFFD398EB),
        Color(0xFF6ED5DE),
        Color(0xFFFAFAFA),
      ],
    ),
  );

  /// Source: Monokai (Wimer Hazenberg) as specified for base16 —
  /// https://github.com/tinted-theming/schemes/blob/spec-0.11/base16/monokai.yaml
  /// — mapped onto the ANSI slots the way base16-shell does (base00, 08, 0B,
  /// 0A, 0D, 0E, 0C, 05; base03; the same six hues; base07). The original
  /// Monokai is an editor theme with no terminal colours of its own, so this
  /// is the published mapping rather than an invented one.
  static const monokai = TerminalThemePreset(
    id: 'monokai',
    name: 'Monokai',
    palette: TerminalPalette(
      foreground: Color(0xFFF8F8F2), // base05
      background: Color(0xFF272822), // base00
      cursor: Color(0xFFF8F8F2), // base05
      selection: Color(0xFF49483E), // base02
      ansi: [
        Color(0xFF272822), // base00
        Color(0xFFF92672), // base08
        Color(0xFFA6E22E), // base0B
        Color(0xFFF4BF75), // base0A
        Color(0xFF66D9EF), // base0D
        Color(0xFFAE81FF), // base0E
        Color(0xFFA1EFE4), // base0C
        Color(0xFFF8F8F2), // base05
        Color(0xFF75715E), // base03
        Color(0xFFF92672), // base08
        Color(0xFFA6E22E), // base0B
        Color(0xFFF4BF75), // base0A
        Color(0xFF66D9EF), // base0D
        Color(0xFFAE81FF), // base0E
        Color(0xFFA1EFE4), // base0C
        Color(0xFFF9F8F5), // base07
      ],
    ),
  );

  /// In the order the picker shows them: the default first.
  static const List<TerminalThemePreset> all = [
    sshetu,
    dracula,
    nord,
    solarizedDark,
    solarizedLight,
    gruvboxDark,
    tokyoNight,
    oneDark,
    monokai,
  ];

  /// Whether [id] names a preset this build knows.
  static bool isKnown(String? id) => all.any((p) => p.id == id);

  /// The preset for [id]; the default for null or anything unknown.
  ///
  /// Unknown is a real case, not a defensive one: a host row restored from a
  /// backup made by a newer build can name a preset this one never shipped.
  static TerminalThemePreset byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => sshetu);

  /// The preset a host's terminal draws with: its own override when that
  /// names a preset, the app setting otherwise.
  static TerminalThemePreset resolve({
    required String? hostOverride,
    required String appDefault,
  }) => isKnown(hostOverride) ? byId(hostOverride) : byId(appDefault);
}
