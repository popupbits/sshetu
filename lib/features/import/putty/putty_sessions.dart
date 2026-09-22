import '../../tunnels/domain/tunnel.dart';
import 'putty_reg.dart';

/// Why a saved PuTTY session cannot become a host.
enum PuttySkip {
  /// Telnet, rlogin, raw, serial… — SSHetu speaks SSH only.
  notSsh,

  /// No host name. Nothing to connect to.
  noHostName,
}

/// A proxy PuTTY was set to use, which SSHetu does not import.
class PuttyProxy {
  const PuttyProxy({required this.method, this.host, this.port});

  /// A short technical name: `SOCKS5`, `HTTP`, `ProxyCommand`…
  final String method;
  final String? host;
  final int? port;

  String get description {
    final where = host == null || host!.isEmpty
        ? ''
        : ' ${port == null ? host : '$host:$port'}';
    return '$method$where';
  }
}

/// One entry of PuTTY's `PortForwardings` value.
class PuttyForward {
  const PuttyForward({
    required this.raw,
    required this.kind,
    required this.listenPort,
    this.listenHost,
    this.targetHost,
    this.targetPort,
  });

  /// The entry exactly as PuTTY stored it — `L8080=localhost:80`.
  final String raw;
  final TunnelKind kind;

  /// Null when PuTTY named none, which means loopback.
  final String? listenHost;
  final int listenPort;
  final String? targetHost;
  final int? targetPort;
}

/// A saved PuTTY session, read from the registry or a `.reg` file.
class PuttySession {
  const PuttySession({
    required this.name,
    required this.hostname,
    required this.port,
    required this.protocol,
    this.username,
    this.keyFile,
    this.proxy,
    this.forwards = const [],
    this.invalidForwards = const [],
  });

  /// The session name as the user sees it in PuTTY, percent-decoding undone.
  final String name;
  final String hostname;
  final int port;
  final String? username;

  /// `ssh`, `telnet`, `raw`, `rlogin`, `serial`…
  final String protocol;

  /// PuTTY's `PublicKeyFile` — a `.ppk`, which SSHetu cannot read.
  final String? keyFile;

  final PuttyProxy? proxy;
  final List<PuttyForward> forwards;

  /// `PortForwardings` entries that could not be read.
  final List<String> invalidForwards;

  PuttySkip? get skip {
    if (hostname.isEmpty) return PuttySkip.noHostName;
    if (protocol != 'ssh') return PuttySkip.notSsh;
    return null;
  }

  bool get importable => skip == null;

  /// `user@host:port`, for a preview row.
  String get address {
    final user = username == null || username!.isEmpty ? '' : '$username@';
    return '$user$hostname${port == 22 ? '' : ':$port'}';
  }
}

/// The registry path PuTTY keeps its sessions under.
const String puttySessionsKey =
    r'HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions';

/// The sessions among [keys].
///
/// Matched on the `…\SimonTatham\PuTTY\Sessions\<name>` suffix, not the full
/// path, so a file exported from `HKEY_USERS\<sid>\…` on another machine
/// reads the same. `Default Settings` is PuTTY's template, not a server, and
/// is left out when it has no host name — which is nearly always.
List<PuttySession> puttySessionsFrom(List<RegKey> keys) {
  const marker = r'\simontatham\putty\sessions\';
  final sessions = <PuttySession>[];
  for (final key in keys) {
    final lower = key.path.toLowerCase();
    final at = lower.indexOf(marker);
    if (at < 0) continue;
    final escaped = key.path.substring(at + marker.length);
    if (escaped.isEmpty || escaped.contains(r'\')) continue;
    final session = _session(decodePuttySessionName(escaped), key);
    if (session.name == 'Default Settings' && session.hostname.isEmpty) {
      continue;
    }
    sessions.add(session);
  }
  return sessions;
}

PuttySession _session(String name, RegKey key) {
  var hostname = (key.string('HostName') ?? '').trim();
  var username = key.string('UserName')?.trim();
  // PuTTY accepts `user@host` in the host box and stores it verbatim.
  final at = hostname.lastIndexOf('@');
  if (at > 0) {
    if (username == null || username.isEmpty) {
      username = hostname.substring(0, at);
    }
    hostname = hostname.substring(at + 1);
  }

  final port = key.dword('PortNumber');
  final (forwards, invalid) = parsePuttyForwardings(
    key.string('PortForwardings') ?? '',
  );
  final keyFile = key.string('PublicKeyFile')?.trim();

  return PuttySession(
    name: name,
    hostname: hostname,
    port: port == null || port < 1 || port > 65535 ? 22 : port,
    // Absent means PuTTY's own default, which is SSH.
    protocol: (key.string('Protocol') ?? 'ssh').trim().toLowerCase(),
    username: username == null || username.isEmpty ? null : username,
    keyFile: keyFile == null || keyFile.isEmpty ? null : keyFile,
    proxy: _proxy(key),
    forwards: forwards,
    invalidForwards: invalid,
  );
}

PuttyProxy? _proxy(RegKey key) {
  final method = key.dword('ProxyMethod') ?? 0;
  if (method == 0) return null;
  final host = key.string('ProxyHost')?.trim();
  return PuttyProxy(
    method: switch (method) {
      1 => 'SOCKS4',
      2 => 'SOCKS5',
      3 => 'HTTP',
      4 => 'Telnet',
      5 => 'ProxyCommand',
      6 => 'SSH',
      _ => 'proxy $method',
    },
    host: method == 5 ? key.string('ProxyTelnetCommand') : host,
    port: method == 5 ? null : key.dword('ProxyPort'),
  );
}

/// Parses PuTTY's `PortForwardings`: `L8080=localhost:80,R2222=host:22,D1080`.
///
/// Each entry is an optional address family (`4` or `6`), a kind (`L`, `R`
/// or `D`), the listening side — a port, or `host:port` — and for `L` and
/// `R` an `=` and the destination `host:port`. IPv6 addresses may be in
/// brackets. Returns what it could read and, separately, what it could not.
(List<PuttyForward>, List<String>) parsePuttyForwardings(String value) {
  final forwards = <PuttyForward>[];
  final invalid = <String>[];
  for (final part in value.split(',')) {
    final raw = part.trim();
    if (raw.isEmpty) continue;
    final forward = _forward(raw);
    if (forward == null) {
      invalid.add(raw);
    } else {
      forwards.add(forward);
    }
  }
  return (forwards, invalid);
}

PuttyForward? _forward(String raw) {
  var rest = raw;
  if (rest.startsWith('4') || rest.startsWith('6')) rest = rest.substring(1);
  if (rest.isEmpty) return null;
  final kind = switch (rest[0].toUpperCase()) {
    'L' => TunnelKind.local,
    'R' => TunnelKind.remote,
    'D' => TunnelKind.socks,
    _ => null,
  };
  if (kind == null) return null;
  rest = rest.substring(1);

  final eq = rest.indexOf('=');
  final listen = eq < 0 ? rest : rest.substring(0, eq);
  final target = eq < 0 ? '' : rest.substring(eq + 1);

  final (listenHost, listenPort) = _hostPort(listen, portOnlyAllowed: true);
  if (!Tunnel.isValidPort(listenPort)) return null;

  if (!kind.requiresTarget) {
    return PuttyForward(
      raw: raw,
      kind: kind,
      listenHost: listenHost,
      listenPort: listenPort!,
    );
  }
  final (targetHost, targetPort) = _hostPort(target, portOnlyAllowed: false);
  if (targetHost == null ||
      targetHost.isEmpty ||
      !Tunnel.isValidPort(targetPort)) {
    return null;
  }
  return PuttyForward(
    raw: raw,
    kind: kind,
    listenHost: listenHost,
    listenPort: listenPort!,
    targetHost: targetHost,
    targetPort: targetPort,
  );
}

(String?, int?) _hostPort(String text, {required bool portOnlyAllowed}) {
  final value = text.trim();
  if (value.isEmpty) return (null, null);
  final colon = value.lastIndexOf(':');
  if (colon < 0) {
    return portOnlyAllowed ? (null, int.tryParse(value)) : (null, null);
  }
  var host = value.substring(0, colon);
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  return (host.isEmpty ? null : host, int.tryParse(value.substring(colon + 1)));
}
