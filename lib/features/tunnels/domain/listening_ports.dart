/// Which TCP ports a server is listening on, read from whatever tool it has.
///
/// Three sources, tried in order by [portsScript] on the server: `ss`, then
/// `netstat`, then the kernel's own `/proc/net/tcp{,6}`. Each parser here is
/// pure and forgiving — a line it does not understand is skipped, never
/// fatal — because the output of all three varies by distribution, version
/// and locale, and one odd line must not hide every port on the machine.
library;

import '../../server_info/domain/sections.dart';

/// One port the server listens on, merged across the addresses it is bound
/// to — `0.0.0.0:3000` and `[::]:3000` are one service, not two rows.
class ListeningPort {
  const ListeningPort({
    required this.port,
    required this.addresses,
    this.process,
    this.pid,
  });

  final int port;

  /// Bound addresses as the tool printed them, brackets and `%iface`
  /// stripped: `0.0.0.0`, `::`, `127.0.0.1`, `::1`, `*`.
  final List<String> addresses;

  /// The owning program's name, when the tool could see it. `ss -p` shows
  /// it for the user's own processes without root, which is exactly the
  /// case that matters here — a dev server someone just started.
  final String? process;
  final int? pid;

  /// Whether every address this port is bound to is loopback — reachable
  /// only from the server itself, which is when a forward is the only way
  /// in at all.
  bool get isLoopbackOnly =>
      addresses.isNotEmpty && addresses.every(isLoopbackAddress);

  /// Whether it is bound to every interface.
  bool get isWildcard => addresses.any(isWildcardAddress);

  /// Where a forward should dial, from the server's side.
  ///
  /// `127.0.0.1` for anything reachable over IPv4 loopback: a wildcard bind
  /// (IPv4, or IPv6 on a dual-stack kernel, Linux's default) or an IPv4
  /// loopback one. `::1` for a service bound to IPv6 loopback only, which
  /// `127.0.0.1` would not reach. A service bound to one specific address
  /// is dialled at that address, since loopback would not reach it either.
  String get targetHost {
    if (addresses.any(
      (a) => isWildcardAddress(a) || (_isIpv4(a) && isLoopbackAddress(a)),
    )) {
      return '127.0.0.1';
    }
    if (addresses.any((a) => isLoopbackAddress(a) && !_isIpv4(a))) {
      return '::1';
    }
    return addresses.isEmpty ? '127.0.0.1' : addresses.first;
  }

  @override
  bool operator ==(Object other) =>
      other is ListeningPort &&
      other.port == port &&
      other.process == process &&
      other.pid == pid &&
      _sameList(other.addresses, addresses);

  @override
  int get hashCode =>
      Object.hash(port, process, pid, Object.hashAll(addresses));

  @override
  String toString() =>
      'ListeningPort($port, ${addresses.join(',')}'
      '${process == null ? '' : ', $process'})';
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Ports never worth offering a forward for: the system's own plumbing,
/// present on nearly every server and never what someone is looking for.
///
/// Kept small and explicit on purpose. Anything a person might plausibly
/// have started themselves — a database, a web server on 80 — stays in.
///
/// - 22: sshd, which this connection already rides.
/// - 25: the local mail transfer agent.
/// - 53: DNS, including systemd-resolved's loopback stubs on 127.0.0.53
///   and 127.0.0.54, and dnsmasq.
/// - 111: rpcbind.
/// - 631: CUPS.
/// - 5355: LLMNR, which systemd-resolved listens on by default.
const Set<int> ignoredSystemPorts = {22, 25, 53, 111, 631, 5355};

/// The ports to show: [ports] without [ignoredSystemPorts] or [alsoIgnore]
/// (the port this connection's own sshd listens on, when it is not 22),
/// sorted by port.
List<ListeningPort> visiblePorts(
  Iterable<ListeningPort> ports, {
  Set<int> alsoIgnore = const {},
}) {
  final shown = [
    for (final port in ports)
      if (!ignoredSystemPorts.contains(port.port) &&
          !alsoIgnore.contains(port.port))
        port,
  ]..sort((a, b) => a.port.compareTo(b.port));
  return shown;
}

/// Whether [address] only reaches the machine itself.
bool isLoopbackAddress(String address) {
  final a = address.toLowerCase();
  return a.startsWith('127.') ||
      a == '::1' ||
      a == 'localhost' ||
      a.startsWith('::ffff:127.') ||
      // An IPv4-mapped loopback as /proc/net/tcp6 spells it once decoded.
      a.startsWith('::ffff:7f');
}

/// Whether [address] means "every interface".
bool isWildcardAddress(String address) =>
    address == '0.0.0.0' ||
    address == '*' ||
    address == '::' ||
    address.isEmpty;

bool _isIpv4(String address) =>
    RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(address);

/// Splits a tool's `address:port` (or BSD `address.port`) token.
///
/// Handles `0.0.0.0:22`, `*:80`, `[::]:22`, `[::1]:631`, `:::22` (older
/// `ss`/`netstat` for IPv6 wildcard), `127.0.0.53%lo:53`,
/// `[fe80::1%eth0]:5353`, and BSD `netstat`'s `127.0.0.1.631`, `*.22` and
/// `::1.631`. Null for anything else, including a `*` port.
({String address, int port})? splitHostPort(String token) {
  String address;
  String portText;
  final colon = token.lastIndexOf(':');
  final afterColon = colon < 0 ? '' : token.substring(colon + 1);
  if (colon >= 0 && RegExp(r'^\d+$').hasMatch(afterColon)) {
    address = token.substring(0, colon);
    portText = afterColon;
  } else {
    final dot = token.lastIndexOf('.');
    if (dot < 0) return null;
    portText = token.substring(dot + 1);
    if (!RegExp(r'^\d+$').hasMatch(portText)) return null;
    address = token.substring(0, dot);
  }
  if (address.startsWith('[') && address.endsWith(']')) {
    address = address.substring(1, address.length - 1);
  }
  final zone = address.indexOf('%');
  if (zone >= 0) address = address.substring(0, zone);
  final port = int.tryParse(portText);
  if (port == null || port < 1 || port > 65535) return null;
  return (address: address, port: port);
}

final RegExp _ssUser = RegExp(r'users:\(\("((?:[^"\\]|\\.)*)",pid=(\d+)');

/// Parses `ss -tln` output, with or without `-H` (no header) and `-p`
/// (`users:(("node",pid=4242,fd=21))`).
///
/// The local address is found as the first `address:port` token rather than
/// by column number: `ss` versions disagree about whether a State column is
/// printed at all, and Recv-Q/Send-Q are bare numbers that cannot be
/// mistaken for one.
List<ListeningPort> parseSsOutput(String output) {
  final raw = <ListeningPort>[];
  for (final line in _lines(output)) {
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.first == 'State' || tokens.first == 'Netid') {
      continue;
    }
    // `ss` with other socket kinds prints a Netid column; only TCP counts.
    if (tokens.first == 'udp' || tokens.first == 'u_str') continue;
    ({String address, int port})? local;
    for (final token in tokens) {
      if (!token.contains(':')) continue;
      local = splitHostPort(token);
      if (local != null) break;
    }
    if (local == null) continue;
    final user = _ssUser.firstMatch(line);
    raw.add(
      ListeningPort(
        port: local.port,
        addresses: [local.address],
        process: user?.group(1),
        pid: user == null ? null : int.tryParse(user.group(2)!),
      ),
    );
  }
  return mergePorts(raw);
}

/// Parses `netstat -tln` / `netstat -tlnp` (Linux, net-tools) and
/// `netstat -an -p tcp` (macOS, BSD).
///
/// Only rows whose protocol starts with `tcp` and whose state is `LISTEN`;
/// BSD's `-an` lists every connection, and a header or a "(Not all
/// processes could be identified…)" note is not a row. `-p` adds
/// `1234/node` after the state, or `-` for a process owned by someone else.
List<ListeningPort> parseNetstatOutput(String output) {
  final raw = <ListeningPort>[];
  for (final line in _lines(output)) {
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.length < 4 || !tokens.first.startsWith('tcp')) continue;
    final state = tokens.indexOf('LISTEN');
    if (state < 0) continue;
    final local = splitHostPort(tokens[3]);
    if (local == null) continue;
    String? process;
    int? pid;
    if (state + 1 < tokens.length) {
      final owner = tokens[state + 1];
      final slash = owner.indexOf('/');
      if (slash > 0) {
        pid = int.tryParse(owner.substring(0, slash));
        final name = owner.substring(slash + 1).replaceAll(RegExp(r':$'), '');
        if (pid != null && name.isNotEmpty) process = name;
      }
    }
    raw.add(
      ListeningPort(
        port: local.port,
        addresses: [local.address],
        process: process,
        pid: process == null ? null : pid,
      ),
    );
  }
  return mergePorts(raw);
}

/// Parses `/proc/net/tcp` and `/proc/net/tcp6`: every row in state `0A`
/// (TCP_LISTEN).
///
/// Addresses are hex, each 32-bit word in the host's byte order —
/// little-endian on every architecture a server is realistically running —
/// and ports are big-endian hex. `/proc` names no process, so none is given.
List<ListeningPort> parseProcNetTcp(String output) {
  final raw = <ListeningPort>[];
  for (final line in _lines(output)) {
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.length < 4 || tokens.first == 'sl') continue;
    if (tokens[3].toUpperCase() != '0A') continue;
    final local = tokens[1];
    final colon = local.indexOf(':');
    if (colon < 0) continue;
    final port = int.tryParse(local.substring(colon + 1), radix: 16);
    final address = decodeProcAddress(local.substring(0, colon));
    if (port == null || port < 1 || port > 65535 || address == null) continue;
    raw.add(ListeningPort(port: port, addresses: [address]));
  }
  return mergePorts(raw);
}

/// A `/proc/net/tcp{,6}` hex address as text: 8 hex digits for IPv4, 32 for
/// IPv6. Null for anything else.
String? decodeProcAddress(String hex) {
  if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hex)) return null;
  if (hex.length != 8 && hex.length != 32) return null;
  final bytes = <int>[];
  // Each 32-bit word is stored little-endian: reverse its four bytes.
  for (var word = 0; word < hex.length; word += 8) {
    final chunk = [
      for (var i = 0; i < 8; i += 2)
        int.parse(hex.substring(word + i, word + i + 2), radix: 16),
    ];
    bytes.addAll(chunk.reversed);
  }
  if (bytes.length == 4) return bytes.join('.');
  return _formatIpv6(bytes);
}

/// RFC 5952 text for 16 bytes: lowercase, no leading zeros, the longest run
/// of two or more zero groups as `::`.
String _formatIpv6(List<int> bytes) {
  final groups = [
    for (var i = 0; i < 16; i += 2) (bytes[i] << 8) | bytes[i + 1],
  ];
  var bestStart = -1;
  var bestLength = 0;
  for (var i = 0; i < 8;) {
    if (groups[i] != 0) {
      i++;
      continue;
    }
    var j = i;
    while (j < 8 && groups[j] == 0) {
      j++;
    }
    if (j - i > bestLength && j - i >= 2) {
      bestStart = i;
      bestLength = j - i;
    }
    i = j;
  }
  String hex(Iterable<int> part) =>
      part.map((g) => g.toRadixString(16)).join(':');
  if (bestStart < 0) return hex(groups);
  final head = hex(groups.sublist(0, bestStart));
  final tail = hex(groups.sublist(bestStart + bestLength));
  return '$head::$tail';
}

/// Folds rows for the same port into one [ListeningPort], keeping every
/// distinct address and the first process name any row knew.
List<ListeningPort> mergePorts(Iterable<ListeningPort> ports) {
  final byPort = <int, ListeningPort>{};
  for (final port in ports) {
    final existing = byPort[port.port];
    if (existing == null) {
      byPort[port.port] = port;
      continue;
    }
    byPort[port.port] = ListeningPort(
      port: port.port,
      addresses: [
        ...existing.addresses,
        for (final address in port.addresses)
          if (!existing.addresses.contains(address)) address,
      ],
      process: existing.process ?? port.process,
      pid: existing.process != null ? existing.pid : port.pid,
    );
  }
  return byPort.values.toList()..sort((a, b) => a.port.compareTo(b.port));
}

Iterable<String> _lines(String output) => output
    .replaceAll('\r\n', '\n')
    .split('\n')
    .map((line) => line.replaceAll('\r', '').trim())
    .where((line) => line.isNotEmpty);

/// The shell script that lists listening TCP ports, run as `sh -s`.
///
/// One exec, the first tool that answers: `ss` (with `-p` for process
/// names, which needs no root for the user's own processes, and `-H` where
/// it exists), then `netstat` (Linux flags, then BSD's), then the raw
/// `/proc` tables for a minimal container with neither. Each in a section,
/// so [parsePortsOutput] knows which parser to use; errors go to
/// `/dev/null` so a missing flag falls through instead of printing noise.
const String portsScript = r'''
out=''
if command -v ss >/dev/null 2>&1; then
  out=$(ss -Htlnp 2>/dev/null || ss -tlnp 2>/dev/null || ss -tln 2>/dev/null)
fi
if [ -n "$out" ]; then echo '@@sshetu:ss'; printf '%s\n' "$out"; exit 0; fi
if command -v netstat >/dev/null 2>&1; then
  out=$(netstat -tlnp 2>/dev/null || netstat -tln 2>/dev/null || netstat -an -p tcp 2>/dev/null)
fi
if [ -n "$out" ]; then echo '@@sshetu:netstat'; printf '%s\n' "$out"; exit 0; fi
echo '@@sshetu:tcp'; cat /proc/net/tcp 2>/dev/null
echo '@@sshetu:tcp6'; cat /proc/net/tcp6 2>/dev/null
exit 0
''';

/// Parses [portsScript]'s output with whichever parser its section names.
List<ListeningPort> parsePortsOutput(String output) {
  final sections = splitSections(output);
  final ss = sections['ss'];
  if (ss != null) return parseSsOutput(ss.join('\n'));
  final netstat = sections['netstat'];
  if (netstat != null) return parseNetstatOutput(netstat.join('\n'));
  return mergePorts([
    ...parseProcNetTcp((sections['tcp'] ?? const []).join('\n')),
    ...parseProcNetTcp((sections['tcp6'] ?? const []).join('\n')),
  ]);
}
