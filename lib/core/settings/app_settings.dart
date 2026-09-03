import 'package:material_ui/material_ui.dart';

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
  });

  /// Id of the chosen [AccentOption]; see [Accents.byId].
  final String accentId;

  final AppThemeMode themeMode;

  /// `null` means "follow the device language". A code here pins the app to
  /// one of the supported locales regardless of the system setting.
  final String? localeCode;

  /// Multiplier applied on top of the platform text scale. Clamped on write.
  final double textScale;

  AccentOption get accent => Accents.byId(accentId);

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppSettings copyWith({
    String? accentId,
    AppThemeMode? themeMode,
    String? localeCode,
    bool clearLocale = false,
    double? textScale,
  }) {
    return AppSettings(
      accentId: accentId ?? this.accentId,
      themeMode: themeMode ?? this.themeMode,
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      textScale: textScale ?? this.textScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.accentId == accentId &&
      other.themeMode == themeMode &&
      other.localeCode == localeCode &&
      other.textScale == textScale;

  @override
  int get hashCode => Object.hash(accentId, themeMode, localeCode, textScale);
}

/// The text-scale steps offered in Settings. A slider invites values that
/// break layouts; four named steps do not.
const List<double> textScaleSteps = <double>[0.9, 1.0, 1.15, 1.3];
