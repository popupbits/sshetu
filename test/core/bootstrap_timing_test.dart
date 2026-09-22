@Tags(['perf'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshetu/core/config/app_config.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/db/database_move.dart';
import 'package:sshetu/core/error/error_logger.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/theme/terminal_fonts.dart';

/// What each step before the first frame costs, with temp folders standing in
/// for the platform's.
///
/// What this can and cannot say: the Dart side of every step is real — the
/// migrations are the real SQL against a real SQLite file, the move is the
/// real copy-verify-rename, the error log is parsed from real JSON. What is
/// not real is the platform channel behind `SharedPreferences` (an in-memory
/// mock here) and the disk: a phone's flash is slower than a developer SSD.
/// So these numbers are a floor. The budgets are loose — they exist to catch a
/// step becoming seconds, not to rank milliseconds.
void main() {
  late Directory root;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    root = Directory.systemTemp.createTempSync('sshetu-boot');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can still hold a just-closed SQLite file for a moment.
    }
  });

  final timings = <String, Duration>{};

  Future<T> time<T>(String step, Future<T> Function() body) async {
    final watch = Stopwatch()..start();
    final result = await body();
    timings[step] = watch.elapsed;
    return result;
  }

  tearDownAll(() {
    // ignore: avoid_print
    print('bootstrap steps:');
    for (final MapEntry(:key, :value) in timings.entries) {
      // ignore: avoid_print
      print(
        '  ${key.padRight(52)} '
        '${(value.inMicroseconds / 1000).toStringAsFixed(1).padLeft(7)} ms',
      );
    }
  });

  Future<String> locate(
    SharedPreferences preferences,
    String documents,
    String support,
  ) => locateDatabase(
    identity: AppIdentity.release,
    platform: TargetPlatform.windows,
    preferences: preferences,
    documentsDirectory: () async => documents,
    supportDirectory: () async => support,
  );

  test('each step, a normal launch and a first launch', () async {
    // A full error log, the worst case attachStorage parses.
    SharedPreferences.setMockInitialValues({});
    final seed = await SharedPreferences.getInstance();
    for (var i = 0; i < ErrorLogger.maxRecords; i++) {
      ErrorLogger.instance.record(
        StateError('seed $i'),
        StackTrace.current,
        source: 'test',
      );
    }
    await ErrorLogger.instance.attachStorage(seed);
    final stored = seed.getString(ErrorLogger.storageKey);
    SharedPreferences.setMockInitialValues({ErrorLogger.storageKey: ?stored});

    final preferences = await time(
      'SharedPreferences.getInstance (mocked channel)',
      SharedPreferences.getInstance,
    );
    await time(
      'ErrorLogger.attachStorage (${ErrorLogger.maxRecords} records)',
      () => ErrorLogger.instance.attachStorage(preferences),
    );
    await time('readSettings', () async => readSettings(preferences));

    final documents = Directory(p.join(root.path, 'Documents'))..createSync();
    final support = Directory(p.join(root.path, 'Support'))..createSync();

    // First launch ever: no database anywhere, every migration runs.
    final fresh = await time(
      'locate + open, first launch (all migrations)',
      () async => AppDatabase.open(
        path: await locate(preferences, documents.path, support.path),
      ),
    );
    await fresh.close();

    // An ordinary launch: the database exists and is current.
    final steady = await time(
      'locate + open, ordinary launch',
      () async => AppDatabase.open(
        path: await locate(preferences, documents.path, support.path),
      ),
    );
    await steady.close();

    // The one launch that moves a desktop database out of Documents, with a
    // few hundred rows in it.
    final legacyRoot = Directory(p.join(root.path, 'legacy'))..createSync();
    final legacyDocs = Directory(p.join(legacyRoot.path, 'Documents'))
      ..createSync();
    final legacySupport = Directory(p.join(legacyRoot.path, 'Support'))
      ..createSync();
    final legacy = await AppDatabase.open(
      path: p.join(legacyDocs.path, 'sshetu.db'),
    );
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    for (var i = 0; i < 300; i++) {
      await legacy.raw.insert('hosts', {
        'id': 'h$i',
        'label': 'host $i',
        'hostname': 'h$i.example.com',
        'port': 22,
        'username': 'root',
        'auth_method': 'publicKey',
        'allow_legacy_algorithms': 0,
        'keepalive_seconds': 30,
        'created_at': now,
        'updated_at': now,
      });
    }
    await legacy.close();
    SharedPreferences.setMockInitialValues({});
    final movePreferences = await SharedPreferences.getInstance();
    final moved = await time(
      'locate + open, the launch that moves the database',
      () async => AppDatabase.open(
        path: await locate(
          movePreferences,
          legacyDocs.path,
          legacySupport.path,
        ),
      ),
    );
    expect(await moved.raw.query('hosts'), hasLength(300));
    await moved.close();

    await time(
      'RegisterFontLicenses.run',
      () => const RegisterFontLicenses().run(),
    );
    // What registering defers: reading every licence file, which happens only
    // when the licences page asks.
    await time('  (deferred) reading every font licence', () async {
      for (final font in TerminalFonts.all) {
        final asset = font.licenseAsset;
        if (asset != null) await rootBundle.loadString(asset);
      }
    });

    // After the first frame, when the integration is on: binding the MCP
    // server's socket.
    await time('  (after first frame) MCP loopback bind', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      await server.close(force: true);
    });

    for (final MapEntry(:key, :value) in timings.entries) {
      expect(
        value,
        lessThan(const Duration(seconds: 3)),
        reason: '$key must not take seconds',
      );
    }
  });
}
