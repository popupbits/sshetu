import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/ssh/ssh_target.dart';
import '../../export/domain/json_import_plan.dart';
import '../../hosts/domain/ssh_host.dart';
import '../../tunnels/domain/tunnel.dart';
import 'putty_reg.dart';
import 'putty_sessions.dart';

/// Runs a program and returns how it went. A test passes one that never
/// starts a process.
typedef ProcessRun = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Reads PuTTY's saved sessions out of this user's registry.
///
/// Through `reg.exe export`, which every Windows ships, into a temporary
/// file — no native plugin and no FFI, and the output is the same `.reg`
/// format a user can hand us from another machine, so both paths share one
/// parser. `HKCU` only: another account's sessions are not ours to read.
class PuttyRegistryReader {
  PuttyRegistryReader({ProcessRun? run, Directory? tempDirectory})
    : _run = run ?? Process.run,
      _temp = tempDirectory;

  final ProcessRun _run;
  final Directory? _temp;

  /// A platform capability: the registry exists only on Windows.
  static bool get isSupported => Platform.isWindows;

  static const String registryKey = r'HKCU\Software\SimonTatham\PuTTY\Sessions';

  /// The exported bytes, or null when there is nothing to export — PuTTY was
  /// never installed, or never saved a session, and the key does not exist.
  Future<Uint8List?> export() async {
    final dir = await (_temp ?? Directory.systemTemp).createTemp(
      'sshetu-putty',
    );
    final file = File(p.join(dir.path, 'sessions.reg'));
    try {
      final result = await _run('reg', [
        'export',
        registryKey,
        file.path,
        '/y',
      ]);
      if (result.exitCode != 0 || !file.existsSync()) return null;
      return await file.readAsBytes();
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // A temp directory the OS will reclaim; not worth failing over.
      }
    }
  }
}

/// A PuTTY session as offered for import.
class PuttyCandidate {
  const PuttyCandidate({required this.session, this.alreadySaved = false});

  final PuttySession session;

  /// A saved host already has this address. Offered, but not pre-selected.
  final bool alreadySaved;
}

/// Turns PuTTY sessions into hosts and tunnels.
abstract final class PuttyImport {
  /// Every session in [bytes] (a `.reg` file's contents), with those already
  /// saved in [existing] marked.
  static List<PuttyCandidate> candidates(
    Uint8List bytes,
    List<SshHost> existing,
  ) {
    final saved = {
      for (final h in existing) _address(h.username, h.hostname, h.port),
    };
    return [
      for (final session in puttySessionsFrom(
        parseRegText(decodeRegBytes(bytes)),
      ))
        PuttyCandidate(
          session: session,
          alreadySaved:
              session.username != null &&
              saved.contains(
                _address(session.username!, session.hostname, session.port),
              ),
        ),
    ];
  }

  /// The hosts and forwards for [sessions]; non-SSH sessions are ignored.
  ///
  /// Every forward is saved with auto-start **off**, whatever it was: PuTTY
  /// opened them only while its window was open, and a forward someone set
  /// up years ago should be looked at before it starts listening on its own.
  ///
  /// No key is linked: PuTTY's keys are `.ppk` files, which SSHetu does not
  /// read. The host keeps key authentication, so an OpenSSH key converted
  /// with puttygen and imported later can be chosen for it.
  static JsonImportChanges changes(
    Iterable<PuttySession> sessions, {
    required String fallbackUsername,
    required DateTime now,
    String Function()? newId,
  }) {
    final id = newId ?? _newId;
    final hosts = <SshHost>[];
    final tunnels = <Tunnel>[];
    for (final session in sessions) {
      if (!session.importable) continue;
      final host = SshHost(
        id: id(),
        label: session.name,
        hostname: session.hostname,
        port: session.port,
        // PuTTY asks "login as:" when it has none; SSHetu needs one saved.
        // The local account is what `ssh` itself would use.
        username: session.username ?? fallbackUsername,
        authMethod: SshAuthMethod.publicKey,
        createdAt: now,
        updatedAt: now,
      );
      hosts.add(host);
      for (final forward in session.forwards) {
        tunnels.add(
          Tunnel(
            id: id(),
            hostId: host.id,
            label: 'PuTTY ${forward.raw}',
            kind: forward.kind,
            listenHost: forward.listenHost ?? Tunnel.defaultListenHost,
            listenPort: forward.listenPort,
            targetHost: forward.targetHost,
            targetPort: forward.targetPort,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    return JsonImportChanges(
      groups: const [],
      hosts: hosts,
      tunnels: tunnels,
      snippets: const [],
      knownHosts: const [],
    );
  }

  static String _address(String user, String host, int port) =>
      '$user@${host.toLowerCase()}:$port';

  static final _random = Random.secure();

  static String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      20,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
