import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'openssh_config.dart';
import 'ssh_target.dart';

/// A host found in an OpenSSH config, ready to be reviewed and imported.
class DiscoveredHost {
  const DiscoveredHost({
    required this.alias,
    required this.hostname,
    required this.port,
    required this.username,
    this.identityFile,
    this.jumpAlias,
    this.unsupported = const [],
  });

  /// The `Host` line's name — what the user types after `ssh`, and the best
  /// label to import it under.
  final String alias;

  /// `HostName`, falling back to the alias when the config omits it, exactly
  /// as OpenSSH does.
  final String hostname;
  final int port;

  /// `User`, or null when the config leaves it to the local username.
  final String? username;

  /// Absolute path from `IdentityFile`, `~` already expanded.
  final String? identityFile;

  /// The alias named by `ProxyJump`, resolved to a real host after import.
  final String? jumpAlias;

  /// Options present in the config that this app cannot honour.
  ///
  /// Surfaced in the import preview rather than dropped silently: a user whose
  /// `ProxyCommand` or `LocalForward` did not come across should be told, not
  /// left to discover it when a connection behaves differently than it does in
  /// their terminal.
  final List<String> unsupported;

  /// What to show as the subtitle in the import list.
  String get description =>
      '${username == null ? '' : '$username@'}$hostname'
      '${port == 22 ? '' : ':$port'}';
}

/// A private key found on disk.
class DiscoveredKey {
  const DiscoveredKey({
    required this.path,
    required this.label,
    required this.keyType,
    required this.isEncrypted,
    this.publicKey,
    this.fingerprint,
  });

  final String path;

  /// The file's basename — `id_ed25519`, `work.pem`.
  final String label;

  /// `ssh-ed25519`, `ssh-rsa`, … or `unknown` when it could not be determined
  /// without the passphrase.
  final String keyType;

  /// Whether the private key is passphrase-protected. Known before import, so
  /// the app can say which keys will need a passphrase at connect time.
  final bool isEncrypted;

  /// The matching `.pub` contents, when one sits beside the private key.
  final String? publicKey;

  /// `SHA256:<base64>`, computed from the public key when one was found.
  final String? fingerprint;
}

/// Everything one scan turned up.
class OpenSshScanResult {
  const OpenSshScanResult({
    required this.sshDirectory,
    required this.hosts,
    required this.keys,
    required this.configPath,
  });

  /// The directory scanned, for display. Null when none was found.
  final String? sshDirectory;

  /// The config file read, if any.
  final String? configPath;

  final List<DiscoveredHost> hosts;
  final List<DiscoveredKey> keys;

  bool get isEmpty => hosts.isEmpty && keys.isEmpty;
}

/// Finds an existing OpenSSH setup and reads what can be imported.
///
/// The point of this class is the first five minutes. Anyone who would want
/// this app already has their servers written down in `~/.ssh/config`, and
/// typing them all in again is the reason an app gets deleted before it is
/// ever used.
///
/// It reads and never writes. Nothing here modifies, moves or deletes a file
/// the user's own `ssh` depends on.
class OpenSshScanner {
  const OpenSshScanner({this.fileSystemRoot, this.explicitDirectory});

  /// Overrides the home directory. For tests; production passes null and the
  /// platform's own home is used.
  final String? fileSystemRoot;

  /// A directory the user picked, used in place of `~/.ssh`.
  ///
  /// Needed because macOS sandboxes this app: `~/.ssh` cannot be reached on
  /// our own initiative, and it should not be — that folder holds every key
  /// the user owns, so reading it is a decision they make in a file panel
  /// rather than one an app takes silently. Picking the folder is what grants
  /// the sandbox permission to read it.
  final String? explicitDirectory;

  /// Whether this platform can have an OpenSSH setup to find at all.
  ///
  /// On Android and iOS an app cannot see `~/.ssh` — there isn't one — so
  /// auto-detection is a button that would never find anything. Those
  /// platforms import through a file the user picks instead.
  static bool get canAutoDetect =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  /// The user's home directory, or null if the platform will not say.
  String? get homeDirectory {
    if (fileSystemRoot != null) return fileSystemRoot;
    final env = Platform.environment;
    return env['HOME'] ?? env['USERPROFILE'];
  }

  /// The directory to scan: the one the user picked, else `~/.ssh`.
  Directory? get sshDirectory {
    final explicit = explicitDirectory;
    if (explicit != null) {
      final dir = Directory(explicit);
      return dir.existsSync() ? dir : null;
    }
    final home = homeDirectory;
    if (home == null) return null;
    final dir = Directory(p.join(home, '.ssh'));
    // existsSync() is false under a sandbox that denies access, which is
    // indistinguishable from "not there" — hence the picker.
    return dir.existsSync() ? dir : null;
  }

  /// The conventional `~/.ssh` path, **without checking that it exists**.
  ///
  /// Used to open the folder picker already inside it. `.ssh` is a dotfile, so
  /// a panel that opens at the home directory hides the one folder the user
  /// came to choose behind a keyboard shortcut most people do not know
  /// (cmd-shift-period). Existence is deliberately not checked: under a
  /// sandbox the check fails even when the folder is there, which is the whole
  /// reason the picker exists.
  String? get defaultSshPath {
    final home = homeDirectory;
    return home == null ? null : p.join(home, '.ssh');
  }

  /// Whether this platform can read `~/.ssh` without the user picking it.
  ///
  /// False on macOS: the sandbox denies it, so the picker is the only route.
  static bool get canScanHomeDirectly => Platform.isLinux || Platform.isWindows;

  /// Scans for hosts and keys. Never throws — a directory that cannot be read
  /// yields an empty result, because "found nothing" is a state the import
  /// screen already has to handle.
  Future<OpenSshScanResult> scan() async {
    final dir = sshDirectory;
    if (dir == null) {
      return const OpenSshScanResult(
        sshDirectory: null,
        configPath: null,
        hosts: [],
        keys: [],
      );
    }

    final configFile = File(p.join(dir.path, 'config'));
    var hosts = <DiscoveredHost>[];
    String? configPath;
    if (configFile.existsSync()) {
      try {
        hosts = parseHosts(await configFile.readAsString());
        configPath = configFile.path;
      } on Object {
        // An unreadable config is not a reason to abandon the key scan.
      }
    }

    return OpenSshScanResult(
      sshDirectory: dir.path,
      configPath: configPath,
      hosts: hosts,
      keys: await scanKeys(dir),
    );
  }

  /// Turns config text into importable hosts.
  List<DiscoveredHost> parseHosts(String text) {
    final config = OpenSshConfig.parse(text);
    return [
      for (final alias in config.importableAliases)
        _toHost(alias, config.resolve(alias)),
    ];
  }

  DiscoveredHost _toHost(String alias, Map<String, String> options) {
    final unsupported = <String>[
      for (final key in const [
        'proxycommand',
        'localforward',
        'remoteforward',
        'dynamicforward',
        'forwardagent',
        'permitlocalcommand',
        'localcommand',
      ])
        if (options.containsKey(key)) key,
    ];

    return DiscoveredHost(
      // OpenSSH falls back to the alias when HostName is absent, and so must
      // we: `Host db` with no HostName really does connect to `db`.
      alias: alias,
      hostname: options['hostname'] ?? alias,
      port: int.tryParse(options['port'] ?? '') ?? 22,
      username: options['user'],
      identityFile: _expandHome(options['identityfile']),
      jumpAlias: options['proxyjump'],
      unsupported: unsupported,
    );
  }

  /// Finds private keys in [dir].
  ///
  /// Detection is by *content*, not by filename: `id_ed25519` is a convention,
  /// not a rule, and plenty of people keep `work.pem` or `cust-prod-key`. Any
  /// file whose first line is a PEM `BEGIN` header is a candidate.
  Future<List<DiscoveredKey>> scanKeys(Directory dir) async {
    final keys = <DiscoveredKey>[];

    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync();
    } on Object {
      return keys;
    }

    for (final entry in entries) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);

      // Never candidates, and reading them wastes time on large files.
      if (name.endsWith('.pub') ||
          name == 'known_hosts' ||
          name == 'known_hosts.old' ||
          name == 'config' ||
          name == 'authorized_keys') {
        continue;
      }

      String content;
      try {
        // A private key is small. Anything large is not one, and this avoids
        // pulling a stray archive into memory.
        if (await entry.length() > 64 * 1024) continue;
        content = await entry.readAsString();
      } on Object {
        continue; // Unreadable, or not text at all.
      }

      if (!_looksLikePrivateKey(content)) continue;

      final pub = File('${entry.path}.pub');
      String? publicKey;
      if (pub.existsSync()) {
        try {
          publicKey = (await pub.readAsString()).trim();
        } on Object {
          publicKey = null;
        }
      }

      keys.add(
        DiscoveredKey(
          path: entry.path,
          label: name,
          keyType: _keyTypeOf(publicKey, content),
          isEncrypted: isEncryptedPem(content),
          publicKey: publicKey,
          fingerprint: publicKey == null ? null : fingerprintOf(publicKey),
        ),
      );
    }

    keys.sort((a, b) => a.label.compareTo(b.label));
    return keys;
  }

  /// Whether [content] opens with a PEM private-key header.
  static bool _looksLikePrivateKey(String content) {
    final head = content.trimLeft();
    return head.startsWith('-----BEGIN ') && head.contains('PRIVATE KEY');
  }

  /// Whether the key is passphrase-protected.
  ///
  /// Covers both forms: classic PEM announces it in a `Proc-Type: 4,ENCRYPTED`
  /// header, while the modern OpenSSH format records a KDF name inside the
  /// base64 body — `none` when unencrypted.
  static bool isEncryptedPem(String content) {
    if (content.contains('Proc-Type: 4,ENCRYPTED')) return true;
    if (content.contains('DEK-Info:')) return true;

    if (content.contains('BEGIN OPENSSH PRIVATE KEY')) {
      final body = _pemBody(content);
      if (body == null) return false;
      final Uint8ListLike bytes;
      try {
        bytes = base64.decode(body);
      } on Object {
        return false;
      }
      // openssh-key-v1\0 then a string for the cipher name. An unencrypted key
      // says "none"; anything else is a cipher, which means a passphrase.
      final text = latin1.decode(bytes.take(64).toList(), allowInvalid: true);
      return !text.contains('none');
    }
    return false;
  }

  /// `SHA256:<base64 without padding>` for an OpenSSH public key line —
  /// exactly what `ssh-keygen -lf` prints, so a user can compare the two.
  static String? fingerprintOf(String publicKeyLine) {
    final parts = publicKeyLine.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    try {
      final blob = base64.decode(parts[1]);
      final digest = sha256.convert(blob);
      final encoded = base64.encode(digest.bytes).replaceAll('=', '');
      return 'SHA256:$encoded';
    } on Object {
      return null;
    }
  }

  static String _keyTypeOf(String? publicKey, String privateKey) {
    if (publicKey != null) {
      final first = publicKey.trim().split(RegExp(r'\s+')).firstOrNull;
      if (first != null && first.startsWith('ssh-') ||
          (first?.startsWith('ecdsa-') ?? false)) {
        return first!;
      }
    }
    // Without a .pub there is nothing reliable to read from an encrypted key,
    // and guessing the algorithm wrong is worse than admitting we do not know.
    if (privateKey.contains('BEGIN RSA PRIVATE KEY')) return 'ssh-rsa';
    if (privateKey.contains('BEGIN EC PRIVATE KEY')) return 'ecdsa';
    return 'unknown';
  }

  static String? _pemBody(String content) {
    final lines = content.split('\n');
    final start = lines.indexWhere((l) => l.startsWith('-----BEGIN'));
    final end = lines.indexWhere((l) => l.startsWith('-----END'));
    if (start < 0 || end <= start) return null;
    return lines
        .sublist(start + 1, end)
        .where((l) => !l.contains(':'))
        .join()
        .trim();
  }

  String? _expandHome(String? path) {
    if (path == null) return null;
    if (!path.startsWith('~')) return path;
    final home = homeDirectory;
    if (home == null) return path;
    return p.join(home, path.substring(1).replaceFirst(RegExp(r'^[/\\]'), ''));
  }
}

/// Alias so the base64 decode above reads clearly without importing
/// `dart:typed_data` for one annotation.
typedef Uint8ListLike = List<int>;

/// Builds the connection target an imported host describes.
///
/// [fallbackUser] stands in when the config named no `User`, the way OpenSSH
/// falls back to the local account.
SshTarget targetForDiscovered(
  DiscoveredHost host, {
  required String fallbackUser,
  String? identityId,
  SshTarget? jumpTarget,
}) => SshTarget(
  hostname: host.hostname,
  port: host.port,
  username: host.username ?? fallbackUser,
  authMethod: identityId == null
      ? SshAuthMethod.password
      : SshAuthMethod.publicKey,
  identityId: identityId,
  jumpTarget: jumpTarget,
);
