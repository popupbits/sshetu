import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/backup/domain/backup_file.dart';
import 'package:sshetu/features/transfer/domain/transfer_payload.dart';

import '../support/test_database.dart';

/// The backup format, attacked.
///
/// A backup is the one thing this app produces that outlives the device: it
/// goes to a cloud folder or an email and sits there. So the tests that matter
/// are not "it round-trips" but "what happens to someone who has the file".
void main() {
  late AppDatabase source;
  late AppDatabase destination;
  late InMemorySecretVault sourceVault;
  late InMemorySecretVault destinationVault;

  setUp(() async {
    source = await openTestDatabase();
    destination = await openTestDatabase();
    sourceVault = InMemorySecretVault();
    destinationVault = InMemorySecretVault();
  });

  tearDown(() async {
    await source.raw.close();
    await destination.raw.close();
  });

  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> seed({int hosts = 2}) async {
    await source.raw.insert('identities', {
      'id': 'k1',
      'label': 'laptop',
      'key_type': 'ssh-ed25519',
      'has_passphrase': 0,
      'origin': 'generated',
      'created_at': now,
      'updated_at': now,
    });
    for (var i = 0; i < hosts; i++) {
      await source.raw.insert('hosts', {
        'id': 'h$i',
        'label': 'server-$i',
        'hostname': '10.0.0.$i',
        'port': 22,
        'username': 'root',
        'auth_method': 'publicKey',
        'identity_id': 'k1',
        'allow_legacy_algorithms': 0,
        'keepalive_seconds': 30,
        'created_at': now,
        'updated_at': now,
      });
    }
    await sourceVault.write(SecretRef.identityPrivateKey('k1'), 'PRIVATE-KEY');
  }

  Future<Uint8List> backup({
    String passphrase = 'correct horse battery staple',
    bool includeSecrets = true,
  }) async => BackupFile.write(
    payload: await (await TransferPayload.read(source.raw, includeSecrets: includeSecrets)).withSecrets(sourceVault),
    passphrase: passphrase,
    appVersion: '1.0.0+1',
  );

  test('a backup restores onto an empty device', () async {
    await seed();

    final opened = await BackupFile.read(
      bytes: await backup(),
      passphrase: 'correct horse battery staple',
    );
    await opened.payload.apply(destination.raw, vault: destinationVault);

    expect(await destination.raw.query('hosts'), hasLength(2));
    expect(await destination.raw.query('identities'), hasLength(1));
    expect(
      await destinationVault.read(SecretRef.identityPrivateKey('k1')),
      'PRIVATE-KEY',
    );
  });

  test('the wrong passphrase gets nothing', () async {
    await seed();
    final bytes = await backup();

    await expectLater(
      BackupFile.read(bytes: bytes, passphrase: 'correct horse battery stapl'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('does not open'),
        ),
      ),
    );
  });

  test('nothing secret is readable without the passphrase', () async {
    await seed();
    final text = utf8.decode(await backup());

    // The whole file, as anyone who finds it sees it.
    expect(text, isNot(contains('PRIVATE-KEY')));
    expect(text, isNot(contains('server-0')));
    expect(text, isNot(contains('10.0.0.0')));
    expect(text, isNot(contains('laptop')));
  });

  test('the file does not say how much is in it', () async {
    // Counts live inside the sealed body: a backup in a shared folder should
    // not advertise how many servers its owner runs.
    //
    // Asserted as an exact key set rather than "no 7 anywhere", which a
    // timestamp or a base64 salt satisfies by accident. Adding a field to the
    // envelope should have to be a deliberate edit here.
    await seed(hosts: 7);
    final header =
        jsonDecode(utf8.decode(await backup())) as Map<String, Object?>;

    expect(header.keys.toSet(), {
      'format',
      'version',
      'created',
      'app',
      'cipher',
      'kdf',
      'body',
    });
    expect((header['kdf']! as Map).keys.toSet(), {
      'name',
      'memory',
      'iterations',
      'parallelism',
      'salt',
    });
  });

  test('but it says enough to be opened, and to be recognised', () async {
    await seed();
    final header =
        jsonDecode(utf8.decode(await backup())) as Map<String, Object?>;

    expect(header['format'], 'sshetu.backup');
    expect(header['version'], 1);
    expect((header['kdf']! as Map)['name'], 'argon2id');
    expect((header['kdf']! as Map)['salt'], isA<String>());
  });

  test('what it holds is known only after opening it', () async {
    await seed(hosts: 3);

    final opened = await BackupFile.read(
      bytes: await backup(),
      passphrase: 'correct horse battery staple',
    );

    expect(opened.contents.hosts, 3);
    expect(opened.contents.identities, 1);
    expect(opened.contents.includesSecrets, isTrue);
    expect(opened.contents.appVersion, '1.0.0+1');
  });

  test('a backup without secrets says so', () async {
    await seed();

    final opened = await BackupFile.read(
      bytes: await backup(includeSecrets: false),
      passphrase: 'correct horse battery staple',
    );

    expect(opened.contents.includesSecrets, isFalse);
    expect(opened.payload.secrets, isEmpty);
    expect(opened.contents.hosts, 2);
  });

  test('a tampered body is refused', () async {
    await seed();
    final header =
        jsonDecode(utf8.decode(await backup())) as Map<String, Object?>;

    final sealed = base64.decode(header['body']! as String);
    sealed[sealed.length - 1] ^= 1;
    header['body'] = base64.encode(sealed);

    await expectLater(
      BackupFile.read(
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(header))),
        passphrase: 'correct horse battery staple',
      ),
      throwsA(isA<BackupException>()),
    );
  });

  test('a rewritten header is refused, even with the right passphrase', () async {
    // The header is plaintext, so anyone can edit it. The fingerprint sealed
    // inside the body is what makes that pointless.
    await seed();
    final header =
        jsonDecode(utf8.decode(await backup())) as Map<String, Object?>;

    header['app'] = 'not the version that wrote this';

    await expectLater(
      BackupFile.read(
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(header))),
        passphrase: 'correct horse battery staple',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('altered'),
        ),
      ),
    );
  });

  test('two backups of the same data never look alike', () async {
    await seed();

    final first =
        jsonDecode(utf8.decode(await backup())) as Map<String, Object?>;
    final second =
        jsonDecode(utf8.decode(await backup())) as Map<String, Object?>;

    // A fresh salt each time, so identical content does not betray itself by
    // producing an identical file.
    expect((first['kdf']! as Map)['salt'],
        isNot((second['kdf']! as Map)['salt']));
    expect(first['body'], isNot(second['body']));
  });

  test('a newer format says so rather than failing obscurely', () async {
    await seed();
    final header =
        jsonDecode(utf8.decode(await backup())) as Map<String, Object?>;
    header['version'] = 99;

    await expectLater(
      BackupFile.read(
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(header))),
        passphrase: 'correct horse battery staple',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          allOf(contains('99'), contains('Update SSHetu')),
        ),
      ),
    );
  });

  test('something else entirely is refused before a passphrase is used', () async {
    for (final rubbish in <String>[
      'not json at all',
      '{}',
      '{"format":"something.else","version":1}',
      '[1,2,3]',
      '',
    ]) {
      await expectLater(
        BackupFile.read(
          bytes: Uint8List.fromList(utf8.encode(rubbish)),
          passphrase: 'anything',
        ),
        throwsA(isA<BackupException>()),
        reason: rubbish,
      );
    }
  });

  test('an empty passphrase is refused at the door', () async {
    await seed();

    await expectLater(
      backup(passphrase: ''),
      throwsA(isA<BackupException>()),
    );
  });
}
