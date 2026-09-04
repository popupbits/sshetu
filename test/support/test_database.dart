import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshetu/core/db/database.dart';

/// An in-memory database with the real schema applied.
///
/// For repository tests, which should run against the *real* schema —
/// migrations and all. A fake database would let a repository pass its tests
/// against a schema the app does not actually have.
///
/// Use it from `test()`, not `testWidgets()`: sqflite does real I/O, and real
/// I/O cannot complete under the fake async a widget test runs in. A widget
/// test that needs data should override the data providers instead.
///
/// FFI is registered explicitly because `AppDatabase.open` only does so for
/// desktop targets, and a test reports itself as Android.
///
/// Each call gets its own file, and that is not a detail. sqflite keeps open
/// databases in a map **keyed by path**, so two opens of `:memory:` hand back
/// the *same* database — which is what this helper used to do. A test that
/// copies rows from one database to another then reads them back out of the
/// database it wrote them to, and passes while proving nothing. Found exactly
/// that way: a transfer test asserted the receiving database was empty and
/// found the sender's rows in it.
Future<AppDatabase> openTestDatabase() async {
  // `AppDatabase.open` reads its migrations through `rootBundle` and checks
  // `defaultTargetPlatform`, both of which need a binding. A plain `test()`
  // has none until this is called.
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final directory = Directory.systemTemp.createTempSync('sshetu-test-db');
  addTearDown(() {
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // The database is usually still open when the test ends; the OS
      // reclaims the temp directory either way.
    }
  });
  return AppDatabase.open(path: '${directory.path}/test.db');
}
