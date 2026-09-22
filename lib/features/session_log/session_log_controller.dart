import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show SnackBar, Text;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app.dart' show rootMessengerKey;
import '../../core/error/error_logger.dart';
import '../../core/secrets/app_lock.dart' show appLocalizationsFor;
import '../../core/settings/settings_controller.dart';
import '../../core/terminal/terminal_session.dart';
import '../../l10n/app_localizations.dart';
import '../sessions/session_manager.dart';
import 'domain/log_encoders.dart';
import 'domain/log_format.dart';
import 'domain/session_logger.dart';
import 'session_log_settings.dart';

/// One tab's running log, as the UI sees it.
@immutable
class ActiveSessionLog {
  const ActiveSessionLog({
    required this.path,
    required this.format,
    this.oversized = false,
  });

  final String path;
  final SessionLogFormat format;

  /// Past [kSessionLogWarnBytes]; the indicator turns to the error colour.
  final bool oversized;

  String get fileName => p.basename(path);

  ActiveSessionLog copyWith({bool? oversized}) => ActiveSessionLog(
    path: path,
    format: format,
    oversized: oversized ?? this.oversized,
  );

  @override
  bool operator ==(Object other) =>
      other is ActiveSessionLog &&
      other.path == path &&
      other.format == format &&
      other.oversized == oversized;

  @override
  int get hashCode => Object.hash(path, format, oversized);
}

/// Opens the file a log is written to. Replaced in tests with a list.
final sessionLogSinkFactoryProvider = Provider<SessionLogSinkFactory>(
  (ref) => FileSessionLogSink.open,
);

/// The folder logs go to when the app chooses: the app's documents folder on
/// a phone, where the share sheet can reach them. Replaced in tests.
final sessionLogAppFolderProvider = Provider<Future<String> Function()>(
  (ref) =>
      () async => p.join(
        (await getApplicationDocumentsDirectory()).path,
        'session-logs',
      ),
);

/// Makes a [SessionLogger]; replaced in tests to crank its clock and timer.
typedef SessionLoggerFactory = SessionLogger Function({
  required SessionLogEncoder encoder,
  required SessionLogSink sink,
  void Function()? onWarn,
  void Function(Object error)? onError,
});

final sessionLoggerFactoryProvider = Provider<SessionLoggerFactory>(
  (ref) =>
      ({required encoder, required sink, onWarn, onError}) => SessionLogger(
        encoder: encoder,
        sink: sink,
        onWarn: onWarn,
        onError: onError,
      ),
);

/// The tabs being logged, by session id.
///
/// Watches the session list so a log follows its tab: a tab that closes
/// finishes its log, and — with "Always log new sessions" on — a tab that
/// opens starts one. A log outlives a dropped connection; the reconnect
/// feeds the same file, with a marker at each drop and return.
class SessionLogController extends Notifier<Map<String, ActiveSessionLog>> {
  final Map<String, _Run> _runs = {};

  /// Session ids already seen, so "always log" starts a log for a tab once,
  /// when it opens, and never for one the user has since stopped.
  final Set<String> _known = {};

  /// Session ids whose log is being opened, so two starts cannot race.
  final Set<String> _opening = {};

  AppLifecycleListener? _lifecycle;

  /// The words last used, for the one place `ref` cannot be read: disposal.
  AppLocalizations? _lastL10n;

  AppLocalizations get _l10n => _lastL10n = appLocalizationsFor(
    ref.read(settingsControllerProvider.select((s) => s.localeCode)),
  );

  @override
  Map<String, ActiveSessionLog> build() {
    final stopped = _l10n.sessionLogMarkerStopped;
    ref.onDispose(() {
      // The app going away: finish every file. Not awaited — nothing can
      // wait here — but each close is already under way, and
      // [_onExitRequested] waits for them where the platform allows it.
      // Riverpod forbids reading providers in here, so the marker is the
      // one worded last.
      final marker = _lastL10n?.sessionLogMarkerStopped ?? stopped;
      for (final run in _runs.values) {
        run.detach();
        unawaited(run.logger.close(finalMarker: marker));
      }
      _runs.clear();
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    ref.listen(sessionManagerProvider, (_, sessions) => _sync(sessions));
    // Tabs open before anything asked for this controller are as new as the
    // ones that come after — this is the first it has heard of them. Not
    // from inside build, which must not change state.
    final initial = ref.read(sessionManagerProvider);
    if (initial.isNotEmpty) {
      scheduleMicrotask(() => _sync(ref.read(sessionManagerProvider)));
    }
    return const {};
  }

  bool isLogging(String sessionId) =>
      _runs.containsKey(sessionId) || _opening.contains(sessionId);

  void _sync(List<TerminalSession> sessions) {
    final ids = {for (final s in sessions) s.id};
    for (final id in _runs.keys.toList()) {
      if (!ids.contains(id)) {
        unawaited(_finish(id, _l10n.sessionLogMarkerTabClosed));
      }
    }
    final settings = ref.read(sessionLogSettingsProvider);
    for (final session in sessions) {
      if (!_known.add(session.id)) continue;
      if (settings.alwaysLog) unawaited(_startAutomatic(session, settings));
    }
    _known.retainAll(ids);
  }

  Future<void> _startAutomatic(
    TerminalSession session,
    SessionLogSettings settings,
  ) async {
    try {
      final folder = ref.read(sessionLogUsesAppFolderProvider)
          ? await ref.read(sessionLogAppFolderProvider)()
          : settings.folder;
      // A desktop with no folder chosen has nowhere to write without
      // asking; the setting cannot be turned on in that state, but a folder
      // cleared since can leave it so.
      if (folder == null) return;
      final name = sessionLogFileName(
        session.title,
        DateTime.now(),
        settings.format,
      );
      await start(session, settings.format, p.join(folder, name));
    } on Object catch (e, st) {
      ErrorLogger.instance.record(e, st);
      _toast(_l10n.sessionLogFailed);
    }
  }

  /// Starts logging [session] to [path] in [format]. Does nothing if it is
  /// already being logged. Throws if the file cannot be opened.
  Future<void> start(
    TerminalSession session,
    SessionLogFormat format,
    String path,
  ) async {
    if (isLogging(session.id)) return;
    _opening.add(session.id);
    final SessionLogSink sink;
    try {
      sink = await ref.read(sessionLogSinkFactoryProvider)(path);
    } finally {
      _opening.remove(session.id);
    }
    if (!ref.mounted) {
      await sink.close();
      return;
    }
    // The tab closed while the file was being opened.
    if (!ref.read(sessionManagerProvider).any((s) => s.id == session.id)) {
      await sink.close();
      return;
    }

    late final SessionLogger logger;
    logger = ref.read(sessionLoggerFactoryProvider)(
      encoder: SessionLogEncoder.forFormat(format),
      sink: sink,
      onWarn: () => _warn(session.id),
      onError: (error) => _failed(session.id, logger, error),
    );
    final target = session.target;
    logger.start(
      SessionLogHeader(
        title: '${target.username}@${target.hostname}',
        started: DateTime.now(),
        columns: session.terminal.viewWidth,
        rows: session.terminal.viewHeight,
      ),
    );
    final run = _Run(
      session: session,
      logger: logger,
      markers: (
        disconnected: _l10n.sessionLogMarkerDisconnected,
        reconnected: _l10n.sessionLogMarkerReconnected,
      ),
    )..attach();
    _runs[session.id] = run;
    _known.add(session.id);
    state = {
      ...state,
      session.id: ActiveSessionLog(path: path, format: format),
    };
    _watchLifecycle();
  }

  /// Stops logging [sessionId] and returns the file, or null if it was not
  /// being logged.
  Future<ActiveSessionLog?> stop(String sessionId) =>
      _finish(sessionId, _l10n.sessionLogMarkerStopped);

  Future<ActiveSessionLog?> _finish(String sessionId, String marker) async {
    final run = _runs.remove(sessionId);
    if (run == null) return null;
    final info = state[sessionId];
    run.detach();
    if (ref.mounted) {
      state = {
        for (final entry in state.entries)
          if (entry.key != sessionId) entry.key: entry.value,
      };
    }
    await run.logger.close(finalMarker: marker);
    if (_runs.isEmpty) {
      _lifecycle?.dispose();
      _lifecycle = null;
    }
    return info;
  }

  /// Writes out what every log has buffered — when the app is hidden, which
  /// on a phone may be the last chance before it is killed.
  Future<void> flushAll() async {
    await Future.wait([for (final run in _runs.values) run.logger.flush()]);
  }

  void _warn(String sessionId) {
    final info = state[sessionId];
    if (info == null || !ref.mounted) return;
    state = {...state, sessionId: info.copyWith(oversized: true)};
    _toast(_l10n.sessionLogLarge(info.fileName));
  }

  void _failed(String sessionId, SessionLogger logger, Object error) {
    ErrorLogger.instance.record(error, StackTrace.current);
    final run = _runs[sessionId];
    if (run == null || !identical(run.logger, logger)) return;
    _runs.remove(sessionId);
    run.detach();
    if (ref.mounted) {
      state = {
        for (final entry in state.entries)
          if (entry.key != sessionId) entry.key: entry.value,
      };
    }
    _toast(_l10n.sessionLogFailed);
  }

  void _toast(String message) {
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Flushes when the app is hidden and finishes every file before a desktop
  /// app exits. Only while something is being logged, and never fatal: a
  /// context with no binding just goes without.
  void _watchLifecycle() {
    if (_lifecycle != null) return;
    try {
      _lifecycle = AppLifecycleListener(
        onHide: () => unawaited(flushAll()),
        onExitRequested: _onExitRequested,
      );
    } on Object {
      _lifecycle = null;
    }
  }

  Future<AppExitResponse> _onExitRequested() async {
    final marker = _l10n.sessionLogMarkerStopped;
    final runs = _runs.values.toList();
    _runs.clear();
    for (final run in runs) {
      run.detach();
    }
    await Future.wait([
      for (final run in runs) run.logger.close(finalMarker: marker),
    ]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
    return AppExitResponse.exit;
  }
}

final sessionLogControllerProvider =
    NotifierProvider<SessionLogController, Map<String, ActiveSessionLog>>(
      SessionLogController.new,
    );

/// A log and the listeners that feed it from its session.
class _Run {
  // Read now, not lazily: a `late` initialiser would run at the first status
  // change — after the drop it was meant to be compared against.
  _Run({required this.session, required this.logger, required this.markers})
    : _wasLive = session.isLive,
      _everLive = session.isLive;

  final TerminalSession session;
  final SessionLogger logger;
  final ({String disconnected, String reconnected}) markers;

  bool _wasLive;

  /// Whether the shell has been up while logging. A log started on a tab
  /// that is still connecting marks its first connection as nothing.
  bool _everLive;

  void _output(Uint8List bytes) => logger.output(
    bytes,
    columns: session.terminal.viewWidth,
    rows: session.terminal.viewHeight,
  );

  /// A drop and a return, marked where they happened. Read from the
  /// session's status rather than its notices: the notices are words for the
  /// screen, and the status is what actually changed.
  void _statusChanged() {
    final live = session.isLive;
    if (live == _wasLive) return;
    _wasLive = live;
    if (!live) {
      logger.marker(markers.disconnected);
    } else if (_everLive) {
      logger.marker(markers.reconnected);
    }
    if (live) _everLive = true;
  }

  void attach() {
    session.addOutputListener(_output);
    session.addListener(_statusChanged);
  }

  /// Allowed on a disposed session: removing a listener is.
  void detach() {
    session.removeOutputListener(_output);
    session.removeListener(_statusChanged);
  }
}
