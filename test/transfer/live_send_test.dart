@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/transfer/domain/transfer_payload.dart';
import 'package:sshetu/features/transfer/transfer_session.dart';

/// Runs a real sender against this machine's own database, and waits.
///
/// Not an assertion — a fixture. It exists so the receiving half can be driven
/// on an actual phone against actual data, which is the only way to find the
/// things a loopback test cannot: a code that will not scan, an address the
/// other device cannot route to, a payload that is fine in a test and enormous
/// in life.
///
/// `SSHETU_SEND_ADDRESS` overrides the advertised address, because an Android
/// emulator reaches its host at 10.0.2.2 and at no other address.
void main() {
  test('waits for a device to take this machine and its hosts', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final home = Platform.environment['HOME']!;
    final live = File(
      '$home/Library/Containers/com.popupbits.sshetu/Data/Documents/sshetu.db',
    );
    if (!live.existsSync()) {
      markTestSkipped('no macOS database at ${live.path}');
      return;
    }

    // Copied, not opened in place: the app may be running, and this fixture
    // has no business writing to a database someone is using.
    final directory = Directory.systemTemp.createTempSync('sshetu-live-send');
    addTearDown(() => directory.deleteSync(recursive: true));
    final copy = live.copySync('${directory.path}/sshetu.db');

    final database = await AppDatabase.open(path: copy.path);
    addTearDown(database.raw.close);

    final payload = await TransferPayload.read(
      database.raw,
      // The real keychain is not reachable from a test binding, so secrets are
      // stubbed. The rows are the real ones.
      vault: InMemorySecretVault(),
      includeSecrets: false,
    );

    final sender = await TransferSender.start(
      payload: payload,
      deviceName: Platform.localHostname,
      addresses: [Platform.environment['SSHETU_SEND_ADDRESS'] ?? '10.0.2.2'],
    );
    addTearDown(sender.close);

    stdout.writeln('CODE ${sender.code.encode()}');
    stdout.writeln('HOSTS ${payload.hostCount}');

    final receiver = await sender.handOver(timeout: const Duration(minutes: 3));
    stdout.writeln('SENT-TO $receiver');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
