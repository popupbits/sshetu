import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'error_record.dart';

/// Somewhere for errors to go beyond the device. Nothing implements this:
/// the app has no backend, and reporting off-device is a privacy decision.
///
/// Implementations must never throw and never block: a failure to report a
/// failure has to stay invisible.
abstract class ErrorSink {
  Future<void> send(ErrorRecord record);
}

/// The app's record of what went wrong.
///
/// A released app that cannot see its own runtime failures is guessing, and
/// the failures that matter most in a `material_ui` app are exactly the ones
/// `flutter analyze` cannot see. This captures all three routes an error can
/// take out of a Flutter app:
///
///  * [FlutterError.onError] — anything thrown inside a build, layout or paint
///  * [PlatformDispatcher.onError] — uncaught async errors
///  * [runGuarded] — everything else in the zone, including `main` itself
///
/// It is a singleton rather than a provider because it must be installed
/// before the first line of `main` does anything interesting, which is well
/// before there is a `ProviderScope` to read from. [errorLoggerProvider]
/// exposes the same instance to feature code.
class ErrorLogger {
  ErrorLogger._();

  static final ErrorLogger instance = ErrorLogger._();

  /// Bounded on purpose. Old records are dropped oldest-first.
  static const int maxRecords = 50;

  static const String storageKey = 'diagnostics.errors.v1';

  static const int _maxStackLines = 12;
  static const int _maxMessageChars = 500;

  final ValueNotifier<List<ErrorRecord>> _records = ValueNotifier(
    const <ErrorRecord>[],
  );

  SharedPreferences? _preferences;
  ErrorSink? _sink;
  bool _installed = false;
  bool _saving = false;
  bool _dirty = false;

  /// Most recent first. Listen to rebuild when a new error arrives.
  ValueListenable<List<ErrorRecord>> get records => _records;

  bool get isEmpty => _records.value.isEmpty;

  /// Take over Flutter's error handlers. Safe to call more than once.
  ///
  /// The previous [FlutterError.onError] is kept and still called, so the
  /// console output and the debug red screen behave exactly as before. This
  /// observes; it does not swallow.
  void install() {
    if (_installed) return;
    _installed = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(
        details.exception,
        details.stack,
        source: 'flutter',
        // `silent` marks errors the framework itself considers routine.
        ignore: details.silent,
      );
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, source: 'platform');
      // True means handled: without it the platform prints the error a second
      // time. It is already in the log and, in debug, already on the console.
      return true;
    };
  }

  /// Load whatever was recorded on previous runs.
  ///
  /// Called from bootstrap, once preferences are open. Errors thrown before
  /// this point are already in memory and are merged, not lost.
  Future<void> attachStorage(SharedPreferences preferences) async {
    _preferences = preferences;
    try {
      final raw = preferences.getString(storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final restored = <ErrorRecord>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final record = ErrorRecord.fromJson(Map<String, dynamic>.from(entry));
        if (record != null) restored.add(record);
      }

      // In-memory records are newer, so they win a fingerprint collision.
      final seen = {for (final r in _records.value) r.fingerprint};
      _records.value = [
        ..._records.value,
        ...restored.where((r) => !seen.contains(r.fingerprint)),
      ]..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    } catch (error) {
      // A corrupt log is not worth a crash. Start over.
      developer.log(
        'could not read the error log',
        name: 'diagnostics',
        error: error,
      );
      await preferences.remove(storageKey);
    }
  }

  /// Attach a remote destination. Optional, and always best-effort.
  void attachSink(ErrorSink sink) => _sink = sink;

  /// Updates the notifier, waiting for the frame to end if one is running.
  ///
  /// A layout overflow is reported from inside paint, and anything listening
  /// to this notifier calls `setState` when it changes — which during a frame
  /// is itself an error ("Build scheduled during frame"). So one overflow
  /// became two errors, the second louder and less true than the first, and
  /// the diagnostics screen filled up with the logger's own noise.
  ///
  /// Outside a frame this is immediate, because the common case — a caught
  /// exception on a button tap — should not wait for anything.
  void _publish(List<ErrorRecord> next) {
    final binding = _binding;
    final phase = binding?.schedulerPhase ?? SchedulerPhase.idle;
    if (binding == null ||
        phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _records.value = next;
      return;
    }
    binding.addPostFrameCallback((_) {
      _records.value = next;
    });
  }

  /// The scheduler, if Flutter is running at all.
  ///
  /// Null before a binding exists. Bootstrap records errors from its very
  /// first lines, and `SchedulerBinding.instance` throws until something has
  /// initialised one — a logger that needs the framework up in order to log
  /// is useless at exactly the moment things are going wrong. It swallowed
  /// every record, silently, because `record` catches everything.
  ///
  /// No frames means nothing to wait for, so that case publishes immediately.
  static SchedulerBinding? get _binding {
    try {
      return SchedulerBinding.instance;
    } on Object {
      return null;
    }
  }

  /// Record an error. Never throws.
  ///
  /// [ignore] records nothing but still returns normally, so callers can pass
  /// a condition instead of writing an `if` around every call.
  void record(
    Object error,
    StackTrace? stack, {
    String source = 'manual',
    bool ignore = false,
  }) {
    if (ignore) return;
    try {
      final now = DateTime.now();
      final message = _truncate(error.toString(), _maxMessageChars);
      final trimmedStack = _trimStack(stack);
      final fingerprint = ErrorRecord.fingerprintOf(
        '${error.runtimeType}|$message|${_topFrame(trimmedStack)}',
      );

      final current = _records.value;
      final index = current.indexWhere((r) => r.fingerprint == fingerprint);

      final ErrorRecord updated;
      if (index >= 0) {
        updated = current[index].seenAgain(now);
        _publish([updated, ...current]..removeAt(index + 1));
      } else {
        updated = ErrorRecord(
          fingerprint: fingerprint,
          type: error.runtimeType.toString(),
          message: message,
          stack: trimmedStack,
          source: source,
          firstSeen: now,
          lastSeen: now,
          count: 1,
        );
        _publish([updated, ...current].take(maxRecords).toList());
      }

      _scheduleSave();
      _forward(updated);
    } catch (nested) {
      // The logger failing must not become the app's crash. Say so on the
      // console and carry on.
      developer.log(
        'the error logger itself failed',
        name: 'diagnostics',
        error: nested,
      );
    }
  }

  /// Run [body] inside a zone that reports anything escaping it.
  ///
  /// This is the outermost net: it catches what the two handlers above cannot,
  /// including a throw from `main` before the first frame.
  static void runGuarded(void Function() body) {
    runZonedGuarded(body, (error, stack) {
      instance.record(error, stack, source: 'zone');
    });
  }

  Future<void> clear() async {
    _records.value = const <ErrorRecord>[];
    await _preferences?.remove(storageKey);
  }

  /// The whole log as text, for sharing or attaching to a support email.
  ///
  /// Deliberately plain: a user should be able to read what they are about to
  /// send before they send it.
  String export() {
    final buffer = StringBuffer()
      ..writeln('${AppConfig.appName} diagnostics')
      ..writeln('generated ${DateTime.now().toIso8601String()}')
      ..writeln('${_records.value.length} record(s)')
      ..writeln();

    for (final record in _records.value) {
      buffer
        ..writeln(exportOne(record))
        ..writeln();
    }
    return buffer.toString();
  }

  /// One record, in the same shape [export] uses.
  ///
  /// The whole log is the wrong thing to paste into an issue about one error,
  /// and a stack trace on screen is not something anyone retypes — so a single
  /// record has to be copyable on its own.
  static String exportOne(ErrorRecord record) {
    final buffer = StringBuffer()
      ..writeln('--- ${record.type} (${record.source}) x${record.count}')
      ..writeln('first ${record.firstSeen.toIso8601String()}')
      ..writeln('last  ${record.lastSeen.toIso8601String()}')
      ..writeln(record.message);
    if (record.stack.isNotEmpty) buffer.writeln(record.stack);
    return buffer.toString().trimRight();
  }

  /// Forgets one record.
  ///
  /// Separate from [clear] because the two are different intentions: clearing
  /// is "I have dealt with all of this", removing one is "I have dealt with
  /// *this*, and want to see whether it comes back" — which is exactly how
  /// someone checks whether a fix worked.
  void remove(String fingerprint) {
    _publish([
      for (final record in _records.value)
        if (record.fingerprint != fingerprint) record,
    ]);
    _scheduleSave();
  }

  /// Coalescing write. A burst of errors produces one save, not one per
  /// error — deliberately without a `Timer`, which would leave a pending
  /// timer behind and fail widget tests.
  void _scheduleSave() {
    _dirty = true;
    if (_saving) return;
    _saving = true;
    scheduleMicrotask(() async {
      try {
        while (_dirty) {
          _dirty = false;
          final preferences = _preferences;
          if (preferences == null) return;
          await preferences.setString(
            storageKey,
            jsonEncode([for (final r in _records.value) r.toJson()]),
          );
        }
      } catch (error) {
        developer.log(
          'could not save the error log',
          name: 'diagnostics',
          error: error,
        );
      } finally {
        _saving = false;
      }
    });
  }

  void _forward(ErrorRecord record) {
    final sink = _sink;
    if (sink == null) return;
    // Unawaited and swallowed: reporting is never allowed to be the thing
    // that goes wrong.
    unawaited(sink.send(record).catchError((Object _) {}));
  }

  static String _truncate(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';

  static String _trimStack(StackTrace? stack) {
    if (stack == null) return '';
    final lines = stack.toString().trimRight().split('\n');
    return lines.take(_maxStackLines).join('\n');
  }

  static String _topFrame(String stack) =>
      stack.isEmpty ? '' : stack.split('\n').first.trim();
}

/// The singleton, for feature code that would rather inject than reach for a
/// static. `ref.read(errorLoggerProvider).record(error, stack)`.
final errorLoggerProvider = Provider<ErrorLogger>(
  (ref) => ErrorLogger.instance,
);
