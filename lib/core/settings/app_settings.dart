import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

import '../../features/shell/workspace_layout.dart';
import '../theme/accent.dart';
import '../theme/terminal_fonts.dart';
import '../theme/terminal_theme_presets.dart';

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

/// The shape the terminal draws its cursor in.
///
/// Our own enum with stable ids, for the same reason as [AppThemeMode]. A
/// program can still ask for another shape (DECSCUSR — vim does, for insert
/// mode); that request wins while it stands, and this is what it returns to.
enum TerminalCursorShape {
  block('block'),
  underline('underline'),
  bar('bar');

  const TerminalCursorShape(this.id);

  final String id;

  static TerminalCursorShape fromId(String? id) => values.firstWhere(
    (s) => s.id == id,
    orElse: () => TerminalCursorShape.block,
  );
}

/// Whether the terminal tabs open at the last exit come back at launch.
enum ReopenTabs {
  ask('ask'),
  always('always'),
  never('never');

  const ReopenTabs(this.id);

  /// The persisted value. Our own names, for the reason [AppThemeMode] has.
  final String id;

  static ReopenTabs? fromId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  /// The choice for someone who has not made one.
  ///
  /// **Always on a desktop, Ask on a phone.** A deliberate exception to "adapt
  /// by width, never by operating system": this is not layout, it is what
  /// launching the app *means* on each. Starting it on a desktop is starting
  /// a working session, and the tabs from the last one are what it is for.
  /// On a phone it is opened many times a day, often for one quick look at a
  /// different server, frequently on a metered or flaky network — dialling
  /// every server from last time, and perhaps raising a password prompt for
  /// one of them, before the user has said what they came for would be
  /// presumptuous. There, one tap on "Reopen" costs nothing.
  static ReopenTabs defaultFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => ReopenTabs.ask,
    _ => ReopenTabs.always,
  };
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
    this.terminalThemeId = TerminalThemePresets.defaultId,
    this.terminalFontId = TerminalFonts.defaultId,
    this.scrollbackLines = defaultScrollbackLines,
    this.cursorShape = TerminalCursorShape.block,
    this.cursorBlink = false,
    this.reopenTabs,
  });

  /// How many lines of history a terminal tab keeps.
  ///
  /// xterm2 stores a cell in 16 bytes (four 32-bit words: codepoint, fg, bg,
  /// attributes), so a line costs about `columns × 16` bytes plus its object:
  /// ~1.4 KB at 80 columns, ~3.3 KB at 200. 10,000 lines is therefore ~14 MB
  /// per tab at 80 columns, and the 100,000 ceiling ~140 MB — already a lot on
  /// a phone with several tabs open, which is why it stops there. The floor of
  /// 1,000 keeps a `make` or `journalctl` run scrollable at all.
  ///
  /// The buffer is a fixed-capacity ring (`IndexAwareCircularBuffer`) whose
  /// size xterm2 takes as a `final` constructor argument, so the value is read
  /// when a tab opens and a change applies to new tabs only.
  static const int defaultScrollbackLines = 10000;
  static const int minScrollbackLines = 1000;
  static const int maxScrollbackLines = 100000;

  /// The steps offered in Settings.
  static const List<int> scrollbackSteps = [
    1000,
    5000,
    10000,
    25000,
    50000,
    100000,
  ];

  /// Clamped to the supported range: a preferences file edited by hand must
  /// not be able to ask for a billion-line ring.
  static int clampScrollback(int lines) =>
      lines.clamp(minScrollbackLines, maxScrollbackLines);

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

  /// The terminal colour scheme hosts use unless they choose their own. An
  /// unknown id reads as the default; see [TerminalThemePresets.byId].
  final String terminalThemeId;

  /// The terminal face, by [TerminalFont.id].
  final String terminalFontId;

  /// Lines of history per terminal tab; see [defaultScrollbackLines].
  final int scrollbackLines;

  final TerminalCursorShape cursorShape;

  /// Off by default, as in xterm: a blinking cursor repaints the grid twice a
  /// second while it blinks, and a program that wants one can ask for it.
  final bool cursorBlink;

  /// Whether last time's terminal tabs are reopened at launch. Null until the
  /// user chooses; see [effectiveReopenTabs].
  final ReopenTabs? reopenTabs;

  /// [reopenTabs], or this platform's default when none was chosen.
  ReopenTabs get effectiveReopenTabs =>
      reopenTabs ?? ReopenTabs.defaultFor(defaultTargetPlatform);

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
    String? terminalThemeId,
    String? terminalFontId,
    int? scrollbackLines,
    TerminalCursorShape? cursorShape,
    bool? cursorBlink,
    ReopenTabs? reopenTabs,
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
      terminalThemeId: terminalThemeId ?? this.terminalThemeId,
      terminalFontId: terminalFontId ?? this.terminalFontId,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
      cursorShape: cursorShape ?? this.cursorShape,
      cursorBlink: cursorBlink ?? this.cursorBlink,
      reopenTabs: reopenTabs ?? this.reopenTabs,
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
      other.keepSessionsOnServer == keepSessionsOnServer &&
      other.terminalThemeId == terminalThemeId &&
      other.terminalFontId == terminalFontId &&
      other.scrollbackLines == scrollbackLines &&
      other.cursorShape == cursorShape &&
      other.cursorBlink == cursorBlink &&
      other.reopenTabs == reopenTabs;

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
    terminalThemeId,
    terminalFontId,
    scrollbackLines,
    cursorShape,
    cursorBlink,
    reopenTabs,
  );
}

/// The text-scale steps offered in Settings. A slider invites values that
/// break layouts; four named steps do not.
const List<double> textScaleSteps = <double>[0.9, 1.0, 1.15, 1.3];
