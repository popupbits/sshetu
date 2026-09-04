import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/shell/workspace_layout.dart';
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
  );
}

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
