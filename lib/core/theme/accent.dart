import 'package:material_ui/material_ui.dart';

/// One choosable accent, with a value per brightness.
///
/// Two values rather than one, because a single colour cannot serve both: an
/// accent dark enough to read on white is nearly invisible on black, and one
/// bright enough for dark mode fails contrast on white.
@immutable
class AccentOption {
  const AccentOption({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });

  /// Stable id, persisted in settings. Never renumber these.
  final String id;

  /// English label. Localised labels live in the ARB under `accent<Id>`.
  final String name;

  final Color light;
  final Color dark;

  Color forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// The palette.
///
/// Eight options rather than a colour wheel: unlimited choice produces
/// unreadable accents and decision paralysis in equal measure. Every value
/// clears 4.5:1 against its own background, so the accent is legible as text,
/// as an icon and as a filled button — in either theme, without further
/// thought from the caller.
abstract final class Accents {
  static const String defaultAccentId = 'indigo';

  static const AccentOption indigo = AccentOption(
    id: 'indigo',
    name: 'Indigo',
    light: Color(0xFF4A57C8),
    dark: Color(0xFF9AA4F2),
  );
  static const AccentOption teal = AccentOption(
    id: 'teal',
    name: 'Teal',
    light: Color(0xFF00695F),
    dark: Color(0xFF5FD6C4),
  );
  static const AccentOption forest = AccentOption(
    id: 'forest',
    name: 'Forest',
    light: Color(0xFF228754),
    dark: Color(0xFF7CDEAD),
  );
  static const AccentOption amber = AccentOption(
    id: 'amber',
    name: 'Amber',
    light: Color(0xFF9C6C0D),
    dark: Color(0xFFF3C568),
  );
  static const AccentOption coral = AccentOption(
    id: 'coral',
    name: 'Coral',
    light: Color(0xFFBF4F18),
    dark: Color(0xFFED986E),
  );
  static const AccentOption rose = AccentOption(
    id: 'rose',
    name: 'Rose',
    light: Color(0xFFB42249),
    dark: Color(0xFFE57694),
  );
  static const AccentOption mauve = AccentOption(
    id: 'mauve',
    name: 'Mauve',
    light: Color(0xFF7D4A9E),
    dark: Color(0xFFC9A0E0),
  );
  static const AccentOption slate = AccentOption(
    id: 'slate',
    name: 'Slate',
    light: Color(0xFF44546A),
    dark: Color(0xFF9FB2CA),
  );

  static const List<AccentOption> all = <AccentOption>[
    indigo,
    teal,
    forest,
    amber,
    coral,
    rose,
    mauve,
    slate,
  ];

  /// Look up by persisted id, falling back to the default for an id written by
  /// a newer build than this one.
  static AccentOption byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => indigo);
}
