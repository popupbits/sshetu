import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/shell/workspace_layout.dart';
import '../theme/terminal_fonts.dart';
import '../theme/terminal_theme_presets.dart';
import 'app_settings.dart';

/// The preferences instance opened during bootstrap.
///
/// Overridden there; reading it without that override is a programming error,
/// and failing loudly beats handing back a second, empty instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider was read before bootstrap installed it',
  ),
);

/// Current user settings. Overridden during bootstrap with the persisted
/// values so the first frame already paints in the user's chosen accent.
final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

const _keyAccent = 'settings.accent';
const _keyThemeMode = 'settings.themeMode';
const _keyLocale = 'settings.locale';
const _keyTextScale = 'settings.textScale';
const _keyPanelWidth = 'settings.panelWidth';
const _keyDefaultIdentity = 'settings.defaultIdentity';
const _keyTerminalFontSize = 'settings.terminalFontSize';
const _keyRequireUnlock = 'settings.requireUnlock';
const _keyConfirmMultilinePaste = 'settings.confirmMultilinePaste';
const _keyKeepAlive = 'settings.keepAliveInBackground';
const _keyKeepSessionsOnServer = 'settings.keepSessionsOnServer';
const _keyTerminalTheme = 'settings.terminalTheme';
const _keyTerminalFont = 'settings.terminalFont';
const _keyScrollbackLines = 'settings.scrollbackLines';
const _keyCursorShape = 'settings.cursorShape';
const _keyCursorBlink = 'settings.cursorBlink';
const _keyReopenTabs = 'settings.reopenTabs';

/// Read persisted settings, falling back to defaults for anything missing or
/// corrupt. Called from bootstrap before the first frame.
AppSettings readSettings(SharedPreferences preferences) {
  return AppSettings(
    accentId: preferences.getString(_keyAccent) ?? const AppSettings().accentId,
    themeMode: AppThemeMode.fromId(preferences.getString(_keyThemeMode)),
    localeCode: preferences.getString(_keyLocale),
    textScale: preferences.getDouble(_keyTextScale) ?? 1.0,
    // Clamped on read as well as on write: a preferences file edited by hand,
    // or written by a build whose limits differed, should not be able to
    // produce a panel that swallows the window.
    panelWidth: WorkspaceLayout.clampPreference(
      preferences.getDouble(_keyPanelWidth) ?? WorkspaceLayout.defaultPanel,
    ),
    defaultIdentityId: preferences.getString(_keyDefaultIdentity),
    terminalFontSize: _clampTerminalFontSize(
      preferences.getDouble(_keyTerminalFontSize) ??
          AppSettings.defaultTerminalFontSize,
    ),
    // Anything but a stored `true` is off: a lock is turned on deliberately,
    // never by a corrupt or foreign value.
    requireUnlock: _readBool(preferences, _keyRequireUnlock) ?? false,
    confirmMultilinePaste:
        _readBool(preferences, _keyConfirmMultilinePaste) ?? true,
    keepAliveInBackground: _readBool(preferences, _keyKeepAlive) ?? true,
    keepSessionsOnServer:
        _readBool(preferences, _keyKeepSessionsOnServer) ?? true,
    // Unknown ids are normalised to the defaults here, so the Settings rows
    // name what the terminal actually draws with rather than a stale id.
    terminalThemeId: TerminalThemePresets.byId(
      _readString(preferences, _keyTerminalTheme),
    ).id,
    terminalFontId: TerminalFonts.byId(
      _readString(preferences, _keyTerminalFont),
    ).id,
    scrollbackLines: AppSettings.clampScrollback(
      _readInt(preferences, _keyScrollbackLines) ??
          AppSettings.defaultScrollbackLines,
    ),
    cursorShape: TerminalCursorShape.fromId(
      _readString(preferences, _keyCursorShape),
    ),
    cursorBlink: _readBool(preferences, _keyCursorBlink) ?? false,
    reopenTabs: ReopenTabs.fromId(_readString(preferences, _keyReopenTabs)),
  );
}

String? _readString(SharedPreferences preferences, String key) {
  try {
    return preferences.getString(key);
  } on Object {
    return null;
  }
}

int? _readInt(SharedPreferences preferences, String key) {
  try {
    return preferences.getInt(key);
  } on Object {
    return null;
  }
}

bool? _readBool(SharedPreferences preferences, String key) {
  try {
    return preferences.getBool(key);
  } on Object {
    // A value of another type under this key; treat it as unset.
    return null;
  }
}

double _clampTerminalFontSize(double size) => size.clamp(
  AppSettings.minTerminalFontSize,
  AppSettings.maxTerminalFontSize,
);

class SettingsController extends Notifier<AppSettings> {
  SettingsController({this.initial});

  /// Settings read during bootstrap. Null in tests that do not care.
  final AppSettings? initial;

  @override
  AppSettings build() => initial ?? const AppSettings();

  void setAccent(String accentId) =>
      _update(state.copyWith(accentId: accentId), _keyAccent, accentId);

  void setThemeMode(AppThemeMode mode) =>
      _update(state.copyWith(themeMode: mode), _keyThemeMode, mode.id);

  /// Pass null to follow the device language again.
  void setLocale(String? localeCode) => _update(
    state.copyWith(localeCode: localeCode, clearLocale: localeCode == null),
    _keyLocale,
    localeCode,
  );

  void setTextScale(double scale) {
    final clamped = scale.clamp(textScaleSteps.first, textScaleSteps.last);
    _update(state.copyWith(textScale: clamped), _keyTextScale, clamped);
  }

  /// The key new hosts start with. Pass null for no preference.
  void setDefaultIdentity(String? identityId) => _update(
    state.copyWith(
      defaultIdentityId: identityId,
      clearDefaultIdentity: identityId == null,
    ),
    _keyDefaultIdentity,
    identityId,
  );

  /// Sets the terminal grid's font size, clamped to the supported range.
  void setTerminalFontSize(double size) {
    final clamped = _clampTerminalFontSize(size);
    _update(
      state.copyWith(terminalFontSize: clamped),
      _keyTerminalFontSize,
      clamped,
    );
  }

  /// Steps the terminal font size by [delta] points.
  void adjustTerminalFontSize(double delta) =>
      setTerminalFontSize(state.terminalFontSize + delta);

  void resetTerminalFontSize() =>
      setTerminalFontSize(AppSettings.defaultTerminalFontSize);

  /// Stores whether saved credentials need an unlock to be read.
  ///
  /// Call it through `AppLockController`: turning the lock on without first
  /// proving the device can satisfy it is the lockout that controller exists
  /// to prevent.
  void setRequireUnlock(bool enabled) => _update(
    state.copyWith(requireUnlock: enabled),
    _keyRequireUnlock,
    enabled,
  );

  /// Whether a paste containing a line break asks before it is sent.
  void setConfirmMultilinePaste(bool confirm) => _update(
    state.copyWith(confirmMultilinePaste: confirm),
    _keyConfirmMultilinePaste,
    confirm,
  );

  /// Android only: whether a foreground service keeps connections alive in
  /// the background. Off stops a running one.
  void setKeepAliveInBackground(bool enabled) => _update(
    state.copyWith(keepAliveInBackground: enabled),
    _keyKeepAlive,
    enabled,
  );

  /// Whether new terminal tabs keep their shell running on the server, in
  /// tmux. Tabs already open keep what they started with.
  void setKeepSessionsOnServer(bool keep) => _update(
    state.copyWith(keepSessionsOnServer: keep),
    _keyKeepSessionsOnServer,
    keep,
  );

  /// The terminal colour scheme hosts use by default. An unknown id is stored
  /// as the default rather than as itself.
  void setTerminalTheme(String id) {
    final known = TerminalThemePresets.byId(id).id;
    _update(state.copyWith(terminalThemeId: known), _keyTerminalTheme, known);
  }

  /// The terminal face, by [TerminalFont.id].
  void setTerminalFont(String id) {
    final known = TerminalFonts.byId(id).id;
    _update(state.copyWith(terminalFontId: known), _keyTerminalFont, known);
  }

  /// Lines of history for new terminal tabs, clamped to the supported range.
  void setScrollbackLines(int lines) {
    final clamped = AppSettings.clampScrollback(lines);
    _update(
      state.copyWith(scrollbackLines: clamped),
      _keyScrollbackLines,
      clamped,
    );
  }

  void setCursorShape(TerminalCursorShape shape) =>
      _update(state.copyWith(cursorShape: shape), _keyCursorShape, shape.id);

  void setCursorBlink(bool blink) =>
      _update(state.copyWith(cursorBlink: blink), _keyCursorBlink, blink);

  /// Whether last time's terminal tabs come back at launch.
  void setReopenTabs(ReopenTabs choice) =>
      _update(state.copyWith(reopenTabs: choice), _keyReopenTabs, choice.id);

  /// Sets how wide the desktop list panel should be.
  ///
  /// Called continuously while a divider is dragged, so it writes to disk
  /// only when [persist] says the drag has ended — a `setDouble` per frame
  /// would be sixty writes a second for one gesture.
  void setPanelWidth(double width, {bool persist = true}) {
    final clamped = WorkspaceLayout.clampPreference(width);
    if (clamped == state.panelWidth && !persist) return;
    state = state.copyWith(panelWidth: clamped);
    if (persist) unawaited(_persist(_keyPanelWidth, clamped));
  }

  /// Apply in memory first, then persist.
  ///
  /// The UI must not wait on disk to reflect a tap, and a failed write is not
  /// worth interrupting the user over — the setting simply does not survive a
  /// restart, which is visible enough on its own.
  void _update(AppSettings next, String key, Object? value) {
    state = next;
    unawaited(_persist(key, value));
  }

  Future<void> _persist(String key, Object? value) async {
    final preferences = ref.read(sharedPreferencesProvider);
    try {
      switch (value) {
        case null:
          await preferences.remove(key);
        case final String text:
          await preferences.setString(key, text);
        case final double number:
          await preferences.setDouble(key, number);
        case final int number:
          await preferences.setInt(key, number);
        case final bool flag:
          await preferences.setBool(key, flag);
        default:
          await preferences.setString(key, value.toString());
      }
    } catch (error, stackTrace) {
      developer.log(
        'could not persist "$key"',
        name: 'settings',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
