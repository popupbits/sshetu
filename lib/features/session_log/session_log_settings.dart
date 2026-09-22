import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import 'domain/log_format.dart';

/// The session-logging preferences.
///
/// Kept in this feature rather than in `AppSettings`: nothing outside
/// logging reads them, and a feature that owns its own three keys can be
/// added — or taken out — without touching the settings every other screen
/// depends on.
@immutable
class SessionLogSettings {
  const SessionLogSettings({
    this.folder,
    this.alwaysLog = false,
    this.format = SessionLogFormat.plain,
  });

  /// Where logs go without asking, on a desktop. Null until chosen; a phone
  /// always uses the app's own documents folder.
  final String? folder;

  /// Whether every new terminal tab starts logging by itself. Off by
  /// default, always: a file of everything a server printed is not
  /// something to start keeping without being asked.
  final bool alwaysLog;

  /// The format automatic logs use, and the one the start dialog offers
  /// first.
  final SessionLogFormat format;

  SessionLogSettings copyWith({
    String? folder,
    bool clearFolder = false,
    bool? alwaysLog,
    SessionLogFormat? format,
  }) => SessionLogSettings(
    folder: clearFolder ? null : (folder ?? this.folder),
    alwaysLog: alwaysLog ?? this.alwaysLog,
    format: format ?? this.format,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionLogSettings &&
      other.folder == folder &&
      other.alwaysLog == alwaysLog &&
      other.format == format;

  @override
  int get hashCode => Object.hash(folder, alwaysLog, format);
}

/// Whether logs are written to the app's own folder and shared from there,
/// rather than saved where the user chooses. A platform capability — a phone
/// has no save dialog worth the name — not a layout decision.
final sessionLogUsesAppFolderProvider = Provider<bool>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

const _keyFolder = 'sessionLog.folder';
const _keyAlways = 'sessionLog.alwaysLog';
const _keyFormat = 'sessionLog.format';

class SessionLogSettingsController extends Notifier<SessionLogSettings> {
  @override
  SessionLogSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T? read<T>(T? Function() get) {
      try {
        return get();
      } on Object {
        // Another type under the key: treat it as unset.
        return null;
      }
    }

    return SessionLogSettings(
      folder: read(() => prefs.getString(_keyFolder)),
      alwaysLog: read(() => prefs.getBool(_keyAlways)) ?? false,
      format: SessionLogFormat.fromId(read(() => prefs.getString(_keyFormat))),
    );
  }

  Future<void> setFolder(String? folder) async {
    state = state.copyWith(folder: folder, clearFolder: folder == null);
    final prefs = ref.read(sharedPreferencesProvider);
    folder == null
        ? await prefs.remove(_keyFolder)
        : await prefs.setString(_keyFolder, folder);
  }

  Future<void> setAlwaysLog(bool value) async {
    state = state.copyWith(alwaysLog: value);
    await ref.read(sharedPreferencesProvider).setBool(_keyAlways, value);
  }

  Future<void> setFormat(SessionLogFormat format) async {
    state = state.copyWith(format: format);
    await ref.read(sharedPreferencesProvider).setString(_keyFormat, format.id);
  }
}

final sessionLogSettingsProvider =
    NotifierProvider<SessionLogSettingsController, SessionLogSettings>(
      SessionLogSettingsController.new,
    );
