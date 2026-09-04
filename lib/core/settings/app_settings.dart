import 'package:material_ui/material_ui.dart';

import '../../features/shell/workspace_layout.dart';
import '../theme/accent.dart';

/// How the app resolves light vs dark.
///
/// Mirrors [ThemeMode] rather than reusing it so the persisted value has a
/// stable name of our own — a framework enum reordering would otherwise
/// silently repoint every stored index.
enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.id);

  final String id;

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  static AppThemeMode fromId(String? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => AppThemeMode.system);
}

/// Everything the user can personalise, in one immutable value.
@immutable
class AppSettings {
  const AppSettings({
    this.accentId = Accents.defaultAccentId,
    this.themeMode = AppThemeMode.system,
    this.localeCode,
    this.textScale = 1.0,
    this.panelWidth = WorkspaceLayout.defaultPanel,
    this.defaultIdentityId,
    this.terminalFontSize = defaultTerminalFontSize,
  });

  /// The terminal grid's own size, in logical pixels.
  static const double defaultTerminalFontSize = 13;
  static const double minTerminalFontSize = 8;
  static const double maxTerminalFontSize = 28;

  /// Id of the chosen [AccentOption]; see [Accents.byId].
  final String accentId;

  final AppThemeMode themeMode;

  /// `null` means "follow the device language". A code here pins the app to
  /// one of the supported locales regardless of the system setting.
  final String? localeCode;

  /// Multiplier applied on top of the platform text scale. Clamped on write.
  final double textScale;

  /// How wide the desktop workspace's list panel should be.
  ///
  /// A preference, not the width used: a window too narrow to honour it
  /// overrides it for as long as it is that narrow. See [WorkspaceLayout].
  final double panelWidth;

  /// The key a new host starts with.
  ///
  /// Most people have one key and use it everywhere; making them pick it on
  /// every host is a question with the same answer every time. Null means "no
  /// preference", which is not the same as having no keys — it is the state a
  /// fresh install is in, and the state someone returns to by choosing it.
  final String? defaultIdentityId;

  /// Set apart from [textScale] on purpose: that one sizes the interface, this
  /// one sizes the grid, and a dense display needs the second without the
  /// first.
  final double terminalFontSize;

  AccentOption get accent => Accents.byId(accentId);

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppSettings copyWith({
    String? accentId,
    AppThemeMode? themeMode,
    String? localeCode,
    bool clearLocale = false,
    double? textScale,
    double? panelWidth,
    String? defaultIdentityId,
    bool clearDefaultIdentity = false,
    double? terminalFontSize,
  }) {
    return AppSettings(
      accentId: accentId ?? this.accentId,
      themeMode: themeMode ?? this.themeMode,
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      textScale: textScale ?? this.textScale,
      panelWidth: panelWidth ?? this.panelWidth,
      defaultIdentityId: clearDefaultIdentity
          ? null
          : (defaultIdentityId ?? this.defaultIdentityId),
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.accentId == accentId &&
      other.themeMode == themeMode &&
      other.localeCode == localeCode &&
      other.textScale == textScale &&
      other.panelWidth == panelWidth &&
      other.defaultIdentityId == defaultIdentityId &&
      other.terminalFontSize == terminalFontSize;

  @override
  int get hashCode => Object.hash(
    accentId,
    themeMode,
    localeCode,
    textScale,
    panelWidth,
    defaultIdentityId,
    terminalFontSize,
  );
}

/// The text-scale steps offered in Settings. A slider invites values that
/// break layouts; four named steps do not.
const List<double> textScaleSteps = <double>[0.9, 1.0, 1.15, 1.3];
