import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app.dart';
import 'core/bootstrap.dart';
import 'core/error/error_logger.dart';
import 'core/settings/settings_controller.dart';
import 'core/db/database.dart';

void main() {
  // Before anything else, so a failure during startup itself is recorded
  // rather than lost. Installing the handlers costs nothing and needs no
  // async work — reading the stored log happens later, in bootstrap.
  ErrorLogger.instance.install();

  // The zone is the outermost net. `ensureInitialized` and `runApp` have to
  // happen inside it, which is why the whole body lives in the closure.
  ErrorLogger.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final BootstrapResult bootstrap;
    try {
      bootstrap = await runBootstrap();
    } catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'bootstrap');
      // Nothing to show the user but the reason. This beats a white screen: it
      // is nearly always a device-storage problem they can act on.
      runApp(StartupFailureApp(error: error));
      return;
    }

    // Errors stay on this device, and there is nowhere for them to go: this
    // app has no backend. `ErrorLogger.attachSink` exists if that ever
    // changes, but sending error data off the device is a privacy decision —
    // stack traces carry more about a session than they appear to — and
    // belongs in a privacy policy before it belongs in code.

    runApp(
      ProviderScope(
        // Built here rather than returned from bootstrap because Riverpod 3
        // does not export the `Override` type, so a List<Override> cannot be
        // named in a signature. Inference handles it fine at this call site.
        overrides: [
          sharedPreferencesProvider.overrideWithValue(bootstrap.preferences),
          settingsControllerProvider.overrideWith(
            () => SettingsController(initial: bootstrap.settings),
          ),
          databaseProvider.overrideWithValue(bootstrap.database),
        ],
        child: const SshetuApp(),
      ),
    );
  });
}
