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
    this.requireUnlock = false,
    this.confirmMultilinePaste = true,
    this.keepAliveInBackground = true,
    this.keepSessionsOnServer = true,
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

  /// Whether reading a saved password or key needs the user to confirm it is
  /// them — fingerprint, face, or the device PIN.
  ///
  /// **Off by default, always.** A prompt nobody asked for, on an app someone
  /// needs in a hurry, is how people get locked out of their own servers.
  /// Turning it on goes through `AppLockController`, which insists on one
  /// successful unlock first.
  final bool requireUnlock;

  /// Whether a paste that would press Enter — one containing a line break —
  /// asks first. On by default: a trailing newline copied off a web page runs
  /// the command before anyone has read it.
  final bool confirmMultilinePaste;

  /// Android only: hold a foreground service while anything is connected, so
  /// backgrounding the app does not drop every session. See
  /// `core/background/keep_alive_service.dart`.
  final bool keepAliveInBackground;

  /// Whether a terminal tab runs its shell inside tmux on the server, so a
  /// dropped connection reattaches to the same shell — programs still
  /// running — instead of starting a new one. On by default: it is the
  /// practical answer to a phone suspending the app, and it falls back to an
  /// ordinary shell by itself where the server has no tmux.
  final bool keepSessionsOnServer;

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
    bool? requireUnlock,
    bool? confirmMultilinePaste,
    bool? keepAliveInBackground,
    bool? keepSessionsOnServer,
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
      requireUnlock: requireUnlock ?? this.requireUnlock,
      confirmMultilinePaste:
          confirmMultilinePaste ?? this.confirmMultilinePaste,
      keepAliveInBackground:
          keepAliveInBackground ?? this.keepAliveInBackground,
      keepSessionsOnServer: keepSessionsOnServer ?? this.keepSessionsOnServer,
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
      other.terminalFontSize == terminalFontSize &&
      other.requireUnlock == requireUnlock &&
      other.confirmMultilinePaste == confirmMultilinePaste &&
      other.keepAliveInBackground == keepAliveInBackground &&
      other.keepSessionsOnServer == keepSessionsOnServer;

  @override
  int get hashCode => Object.hash(
    accentId,
    themeMode,
    localeCode,
    textScale,
    panelWidth,
    defaultIdentityId,
    terminalFontSize,
    requireUnlock,
    confirmMultilinePaste,
    keepAliveInBackground,
    keepSessionsOnServer,
  );
}

/// The text-scale steps offered in Settings. A slider invites values that
/// break layouts; four named steps do not.
const List<double> textScaleSteps = <double>[0.9, 1.0, 1.15, 1.3];
