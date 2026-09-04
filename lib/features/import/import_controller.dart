import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/ssh/openssh_import.dart';
import '../../core/ssh/ssh_target.dart';
import '../hosts/domain/ssh_host.dart';
import '../hosts/hosts_controller.dart';
import '../keys/domain/ssh_identity.dart';
import '../keys/keys_controller.dart';

/// What a completed import did.
class ImportOutcome {
  const ImportOutcome({required this.hosts, required this.keys});

  final int hosts;
  final int keys;
}

/// The directory the user picked, if any. Null means "look in ~/.ssh".
class PickedSshDirectory extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? path) => state = path;
}

final pickedSshDirectoryProvider =
    NotifierProvider<PickedSshDirectory, String?>(PickedSshDirectory.new);

/// Scans for an existing OpenSSH setup.
///
/// `autoDispose` so leaving the screen and coming back re-scans: the user may
/// have gone away specifically to add a key, and showing them a cached
/// "nothing found" would be actively misleading.
final openSshScanProvider = FutureProvider.autoDispose<OpenSshScanResult>(
  (ref) =>
      OpenSshScanner(explicitDirectory: ref.watch(pickedSshDirectoryProvider))
          .scan(),
);

/// Turns scan results into saved hosts and identities.
class ImportController {
  const ImportController(this._ref);

  final Ref _ref;

  /// Imports the chosen hosts and keys.
  ///
  /// Keys are imported **first**, so a host that names an `IdentityFile` can be
  /// linked to the identity it refers to in the same pass. Doing it the other
  /// way round would import every host with no key attached and leave the user
  /// to wire them up by hand — which is most of the work they came here to
  /// avoid.
  Future<ImportOutcome> import({
    required OpenSshScanResult scan,
    required Set<String> hostAliases,
    required Set<String> keyPaths,
  }) async {
    final now = DateTime.now().toUtc();
    final identities = _ref.read(identitiesControllerProvider);
    final hosts = _ref.read(hostsControllerProvider);

    // Key file path → the identity id it became, so hosts can be linked.
    // Canonical throughout: on Windows `listSync()` and a hand-written config
    // spell the same file differently, and `==` then links no host to its key.
    final byPath = <String, String>{};
    final selectedPaths = {for (final path in keyPaths) p.canonicalize(path)};
    var importedKeys = 0;

    for (final key in scan.keys) {
      if (!selectedPaths.contains(p.canonicalize(key.path))) continue;

      final String material;
      try {
        material = await File(key.path).readAsString();
      } on Object {
        // A key that cannot be read is skipped rather than failing the whole
        // import; the hosts are still worth having.
        continue;
      }

      final id = _newId();
      await identities.save(
        SshIdentity(
          id: id,
          label: key.label,
          keyType: key.keyType,
          publicKey: key.publicKey,
          fingerprint: key.fingerprint,
          hasPassphrase: key.isEncrypted,
          origin: IdentityOrigin.sshConfig,
          createdAt: now,
          updatedAt: now,
        ),
        privateKey: material,
      );
      byPath[p.canonicalize(key.path)] = id;
      importedKeys++;
    }

    // Alias → new host id, so ProxyJump can be resolved after every host
    // exists. A bastion may appear below the host that uses it in the file.
    final aliasToId = <String, String>{};
    final chosen = scan.hosts
        .where((h) => hostAliases.contains(h.alias))
        .toList();
    for (final host in chosen) {
      aliasToId[host.alias] = _newId();
    }

    final records = <SshHost>[];
    for (final discovered in chosen) {
      final identityId = discovered.identityFile == null
          ? null
          : byPath[p.canonicalize(discovered.identityFile!)];

      records.add(
        SshHost(
          id: aliasToId[discovered.alias]!,
          label: discovered.alias,
          hostname: discovered.hostname,
          port: discovered.port,
          // OpenSSH falls back to the local account name; so do we, rather
          // than saving a host with an empty username that cannot connect.
          username: discovered.username ?? _localUsername(),
          // publicKey even when the config named no IdentityFile. That is
          // what `ssh` does: it offers the user's default keys and only asks
          // for a password if the server refuses them. Marking these as
          // password hosts is what made nine of ten imported hosts prompt for
          // a password they did not need.
          authMethod: SshAuthMethod.publicKey,
          identityId: identityId,
          // Only within this import: pointing at a host that was not brought
          // across would leave a dangling reference the schema would reject.
          jumpHostId: aliasToId[discovered.jumpAlias],
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // One transaction: a half-finished import leaves the user unsure what they
    // now have, and re-running it would duplicate whatever landed.
    await hosts.saveAll(records);

    return ImportOutcome(hosts: records.length, keys: importedKeys);
  }

  static String _localUsername() =>
      Platform.environment['USER'] ??
      Platform.environment['USERNAME'] ??
      'root';

  static final _random = Random.secure();

  static String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      20,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}

final importControllerProvider = Provider<ImportController>(
  ImportController.new,
);
