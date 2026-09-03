import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/openssh_import.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/features/import/import_controller.dart';

import '../support/test_database.dart';

/// End-to-end over the import: a real `.ssh` directory on disk, the real
/// parser, the real database, and the real vault interface.
///
/// Import is the feature that makes this app usable in the first five minutes,
/// and it is also where the most can go quietly wrong — a host pointed at the
/// wrong machine, a key that did not come across, or a selection the user
/// never made being written anyway.
void main() {
  late Directory sshDir;
  late AppDatabase database;
  late InMemorySecretVault vault;
  late ProviderContainer container;

  const privateKey = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
-----END OPENSSH PRIVATE KEY-----
''';
  const publicKey =
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP1kR7QhQxPPFdMbCfvhLDNyIYAmYaLPnJTMkQGDtxNu me@laptop';

  setUp(() async {
    sshDir = await Directory.systemTemp.createTemp('sshetu_import');
    database = await openTestDatabase();
    vault = InMemorySecretVault();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(vault),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    if (sshDir.existsSync()) sshDir.deleteSync(recursive: true);
  });

  Future<void> writeKey(String name) async {
    await File('${sshDir.path}/$name').writeAsString(privateKey);
    await File('${sshDir.path}/$name.pub').writeAsString(publicKey);
  }

  Future<OpenSshScanResult> scan() =>
      OpenSshScanner(explicitDirectory: sshDir.path).scan();

  Future<void> writeConfig(String text) =>
      File('${sshDir.path}/config').writeAsString(text);

  test('imports hosts and keys, and links a host to its key', () async {
    await writeKey('id_ed25519');
    await writeConfig('''
Host web
  HostName web.example.com
  User deploy
  Port 2222
  IdentityFile ${sshDir.path}/id_ed25519
''');

    final result = await scan();
    final outcome = await container
        .read(importControllerProvider)
        .import(
          scan: result,
          hostAliases: {'web'},
          keyPaths: {'${sshDir.path}/id_ed25519'},
        );

    expect(outcome.hosts, 1);
    expect(outcome.keys, 1);

    final hosts = await container.read(hostRepositoryProvider).all();
    final host = hosts.single;
    expect(host.label, 'web');
    expect(host.hostname, 'web.example.com');
    expect(host.port, 2222);
    expect(host.username, 'deploy');

    // The link is the point: importing keys and hosts separately would leave
    // the user wiring them together by hand, which is most of the work they
    // came here to avoid.
    final identities = await container.read(identityRepositoryProvider).all();
    expect(host.identityId, identities.single.id);
    expect(host.authMethod, SshAuthMethod.publicKey);
  });

  test('the private key lands in the vault, never in the database', () async {
    await writeKey('id_ed25519');
    await writeConfig('Host web\n  HostName web.example.com');

    final result = await scan();
    await container
        .read(importControllerProvider)
        .import(
          scan: result,
          hostAliases: {'web'},
          keyPaths: {'${sshDir.path}/id_ed25519'},
        );

    final identity =
        (await container.read(identityRepositoryProvider).all()).single;

    expect(
      await vault.read(SecretRef.identityPrivateKey(identity.id)),
      privateKey,
    );

    // And nothing key-shaped reached SQLite.
    final rows = await database.raw.query('identities');
    expect(rows.single.values.join(), isNot(contains('PRIVATE KEY')));
  });

  test('importing only keys creates no hosts', () async {
    // The bug this pins: opening "import keys" from the Keys tab showed the
    // host list too, every row ticked, and importing brought in servers the
    // user never asked for.
    await writeKey('id_ed25519');
    await writeConfig('Host web\n  HostName web.example.com');

    final result = await scan();
    final outcome = await container
        .read(importControllerProvider)
        .import(
          scan: result,
          hostAliases: const {},
          keyPaths: {'${sshDir.path}/id_ed25519'},
        );

    expect(outcome.hosts, 0);
    expect(outcome.keys, 1);
    expect(await container.read(hostRepositoryProvider).all(), isEmpty);
  });

  test('importing only hosts creates no keys', () async {
    await writeKey('id_ed25519');
    await writeConfig('Host web\n  HostName web.example.com');

    final result = await scan();
    final outcome = await container
        .read(importControllerProvider)
        .import(scan: result, hostAliases: {'web'}, keyPaths: const {});

    expect(outcome.keys, 0);
    expect(await container.read(identityRepositoryProvider).all(), isEmpty);

    final host = (await container.read(hostRepositoryProvider).all()).single;
    expect(host.identityId, isNull, reason: 'no key was imported to link');
    expect(
      host.authMethod,
      SshAuthMethod.publicKey,
      reason:
          'a host that names no IdentityFile is a key host that has not '
          'named a key, not a password host — `ssh` offers the default keys '
          'and only falls back to a password if the server refuses them. '
          'Importing these as password hosts is what made nine of ten '
          'imported hosts prompt for a password they did not need.',
    );
  });

  test('a deselected host is not imported', () async {
    await writeConfig('''
Host keep
  HostName keep.example.com

Host drop
  HostName drop.example.com
''');

    final result = await scan();
    await container
        .read(importControllerProvider)
        .import(scan: result, hostAliases: {'keep'}, keyPaths: const {});

    final labels = (await container.read(hostRepositoryProvider).all())
        .map((h) => h.label)
        .toList();
    expect(labels, ['keep']);
  });

  test('ProxyJump is resolved within the import', () async {
    await writeConfig('''
Host db
  HostName db.internal
  ProxyJump bastion

Host bastion
  HostName bastion.example.com
''');

    final result = await scan();
    await container
        .read(importControllerProvider)
        .import(
          scan: result,
          hostAliases: {'db', 'bastion'},
          keyPaths: const {},
        );

    final repository = container.read(hostRepositoryProvider);
    final hosts = await repository.all();
    final db = hosts.firstWhere((h) => h.label == 'db');
    final bastion = hosts.firstWhere((h) => h.label == 'bastion');

    expect(db.jumpHostId, bastion.id);

    final target = await repository.targetFor(db);
    expect(target.chain.map((t) => t.hostname).toList(), [
      'bastion.example.com',
      'db.internal',
    ]);
  });

  test('a jump host left out of the import does not dangle', () async {
    // The schema restricts jump_host_id to a real row, so pointing at a host
    // that was never imported would fail the insert and lose the whole batch.
    await writeConfig('''
Host db
  HostName db.internal
  ProxyJump bastion

Host bastion
  HostName bastion.example.com
''');

    final result = await scan();
    await container
        .read(importControllerProvider)
        .import(scan: result, hostAliases: {'db'}, keyPaths: const {});

    final host = (await container.read(hostRepositoryProvider).all()).single;
    expect(host.label, 'db');
    expect(host.jumpHostId, isNull);
  });

  test('an encrypted key is recorded as needing a passphrase', () async {
    await File('${sshDir.path}/legacy').writeAsString('''
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,0123456789ABCDEF

abcdef
-----END RSA PRIVATE KEY-----
''');

    final result = await scan();
    await container
        .read(importControllerProvider)
        .import(
          scan: result,
          hostAliases: const {},
          keyPaths: {'${sshDir.path}/legacy'},
        );

    final identity =
        (await container.read(identityRepositoryProvider).all()).single;
    expect(
      identity.hasPassphrase,
      isTrue,
      reason:
          'so the app can ask at the right moment rather than failing '
          'mid-handshake',
    );
  });
}
