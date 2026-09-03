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
Future<AppDatabase> openTestDatabase() async {
  // `AppDatabase.open` reads its migrations through `rootBundle` and checks
  // `defaultTargetPlatform`, both of which need a binding. A plain `test()`
  // has none until this is called.
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return AppDatabase.open(path: inMemoryDatabasePath);
}
