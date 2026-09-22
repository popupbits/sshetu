import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'error/error_logger.dart';
import 'settings/app_settings.dart';
import 'settings/settings_controller.dart';
import 'db/database.dart';
import 'db/database_move.dart';
import 'theme/terminal_fonts.dart';

/// Async work that must finish before the first frame.
///
/// Two kinds of step live here, and the difference matters:
///
///  * **Resources** — preferences, the database — are opened directly in
///    [runBootstrap] and returned on [BootstrapResult], because `main` hands
///    them to providers as overrides. Riverpod 3 does not export the `Override`
///    type, so it cannot be named in a signature; building the list inline in
///    `main`, where inference does the work, is the way through.
///  * **Side effects** — [optionalSteps] — return nothing and are allowed to
///    fail. Notifications not initialising should degrade reminders, not stop
///    the app from opening.
abstract class BootstrapStep {
  const BootstrapStep();

  /// Shown in logs and in the Settings diagnostics row.
  String get name;

  Future<void> run();
}

/// Non-critical steps, in order. This is the seam a feature extends.
const List<BootstrapStep> optionalSteps = <BootstrapStep>[
  RegisterFontLicenses(),
];

/// A step that failed. Startup continued without it.
class BootstrapFailure {
  const BootstrapFailure(this.step, this.error);

  final String step;
  final Object error;
}

/// What bootstrap opened, handed to `main` to install as provider overrides.
class BootstrapResult {
  const BootstrapResult({
    required this.preferences,
    required this.settings,
    required this.database,
    required this.failures,
  });

  final SharedPreferences preferences;

  /// Read before the first frame, so the app paints in the user's accent and
  /// theme immediately rather than flashing the defaults and correcting itself.
  final AppSettings settings;
  final AppDatabase database;

  final List<BootstrapFailure> failures;
}

/// Throws if [identity] is a debug build whose app data folder is not its own.
///
/// A release build returns at once and asks the platform for nothing. See
/// [AppIdentity.isolationProblem] for what is checked and why.
Future<void> ensureIdentityIsolated(AppIdentity identity) async {
  if (!identity.isDebug || kIsWeb) return;
  final support = (await getApplicationSupportDirectory()).path;
  final problem = identity.isolationProblem(defaultTargetPlatform, support);
  if (problem != null) throw StateError(problem);
}

/// Finds the database — moving it first, if this launch is the one that moves
/// it (see `DatabaseMove`) — and only then opens it.
///
/// [locate] runs to completion before [open] is called, so no connection can
/// exist while files are being copied and renamed.
Future<AppDatabase> openAppDatabase({
  required Future<String> Function() locate,
  required Future<AppDatabase> Function(String path) open,
}) async {
  final path = await locate();
  return open(path);
}

/// Open resources, then run the optional steps.
///
/// Throws if a resource cannot be opened — `main` turns that into
/// [StartupFailureApp]. Without preferences there is nowhere to read settings
/// from and nowhere to write them to, which is worth saying out loud rather
/// than running an app that silently forgets every change.
Future<BootstrapResult> runBootstrap() async {
  // Before anything is opened: a debug build that would share the real app's
  // files must not get as far as opening them.
  await ensureIdentityIsolated(AppIdentity.current);

  final preferences = await SharedPreferences.getInstance();

  // As early as possible: anything already captured in memory is merged with
  // what previous runs recorded, so nothing thrown before this point is lost.
  await ErrorLogger.instance.attachStorage(preferences);

  final settings = readSettings(preferences);

  // Nothing opens the database before this line. On a desktop release the
  // first launch of this version moves it out of Documents here, and that
  // must finish — or fail and fall back — before any connection exists.
  final database = await openAppDatabase(
    locate: () => locateDatabase(
      identity: AppIdentity.current,
      platform: defaultTargetPlatform,
      preferences: preferences,
      documentsDirectory: () async =>
          (await getApplicationDocumentsDirectory()).path,
      supportDirectory: () async =>
          (await getApplicationSupportDirectory()).path,
    ),
    open: (path) => AppDatabase.open(path: path),
  );

  final failures = <BootstrapFailure>[];
  for (final step in optionalSteps) {
    try {
      await step.run();
    } catch (error, stackTrace) {
      developer.log(
        'bootstrap step "${step.name}" failed',
        name: 'bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
      failures.add(BootstrapFailure(step.name, error));
      // Also into the log, so a step that fails only on one user's device is
      // visible on that device rather than only in a console they never see.
      ErrorLogger.instance.record(error, stackTrace, source: 'bootstrap');
    }
  }

  return BootstrapResult(
    preferences: preferences,
    settings: settings,
    database: database,
    failures: failures,
  );
}

/// Shown when bootstrap cannot open something the app needs.
///
/// Depends on nothing but the framework — the whole point is that it renders
/// when the app's own infrastructure did not come up.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SSHetu could not start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text('$error'),
                const SizedBox(height: 24),
                const Text(
                  'Restarting usually clears this. If it keeps happening, '
                  'reinstalling will reset local storage.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
