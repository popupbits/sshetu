/// What a person typed, once it has been understood.
class ParsedConnection {
  const ParsedConnection({
    required this.hostname,
    this.username,
    this.port,
    this.identityFile,
  });

  final String hostname;

  /// Null when they typed only a host, which is not an error: the field can
  /// stay empty and be filled in below, exactly as `ssh host` would use the
  /// local account name.
  final String? username;

  /// Null when no port was given, so a caller can tell "they said 22" from
  /// "they said nothing" and leave its own default alone.
  final int? port;

  /// The path from `-i`, when one was pasted. Not used to pick a key — the
  /// app's keys live in its own vault, not at a path — but knowing it was
  /// there is what lets the UI say the flag was ignored rather than silently
  /// dropping it.
  final String? identityFile;

  @override
  String toString() =>
      'ParsedConnection($username@$hostname:$port, i=$identityFile)';
}

/// Reads the thing people actually have in their hand.
///
/// Nobody keeps a host, a username and a port in three separate places. They
/// have one string — out of a wiki, a terminal, a colleague's message — and it
/// is in one of a handful of shapes:
///
/// ```
/// 192.168.1.10
/// root@192.168.1.10
/// root@192.168.1.10:2222
/// ssh root@192.168.1.10
/// ssh -p 2222 root@host.example.com
/// ssh root@host -p 2222 -i ~/.ssh/id_ed25519
/// ssh://root@host.example.com:2222
/// [2001:db8::1]:2222
/// ```
///
/// Returns null when there is no hostname to be found, rather than guessing.
/// A wrong guess here is a host row that silently points somewhere else.
ParsedConnection? parseConnection(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;

  // A pasted command. Only the leading `ssh` is dropped: `ssh` appearing later
  // is part of a hostname (`ssh.example.com`) or an argument.
  if (text == 'ssh') return null;
  if (text.startsWith('ssh ')) text = text.substring(4).trim();

  // A URL, which carries everything in a shape Uri already knows.
  if (text.startsWith('ssh://')) {
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    return ParsedConnection(
      hostname: uri.host,
      username: uri.userInfo.isEmpty ? null : uri.userInfo.split(':').first,
      port: uri.hasPort ? uri.port : null,
    );
  }

  int? port;
  String? identityFile;
  final words = <String>[];

  // Flags first, so what is left is the destination and nothing else.
  final parts = text.split(RegExp(r'\s+'));
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (part == '-p' && i + 1 < parts.length) {
      port = int.tryParse(parts[++i]);
    } else if (part.startsWith('-p') && part.length > 2) {
      port = int.tryParse(part.substring(2));
    } else if (part == '-i' && i + 1 < parts.length) {
      identityFile = parts[++i];
    } else if (part == '-l' && i + 1 < parts.length) {
      // `ssh -l root host` — the other way of naming a user.
      words.insert(0, '${parts[++i]}@');
    } else if (part.startsWith('-')) {
      // Any other flag, with its argument if it takes one. Unknown flags are
      // skipped rather than mistaken for a hostname.
      if (_flagsWithValues.contains(part) && i + 1 < parts.length) i++;
    } else {
      words.add(part);
    }
  }

  // `-l root` contributed a bare "root@"; glue it to the destination.
  final destination = words.length >= 2 && words.first.endsWith('@')
      ? '${words.first}${words[1]}'
      : words.firstWhere((w) => !w.endsWith('@'), orElse: () => '');
  if (destination.isEmpty) return null;

  var rest = destination;
  String? username;

  // Rightmost @, so a username containing one still works.
  final at = rest.lastIndexOf('@');
  if (at >= 0) {
    username = rest.substring(0, at);
    rest = rest.substring(at + 1);
    if (username.isEmpty) username = null;
  }

  // A bracketed IPv6 literal, optionally with a port after it.
  if (rest.startsWith('[')) {
    final close = rest.indexOf(']');
    if (close < 0) return null;
    final address = rest.substring(1, close);
    final tail = rest.substring(close + 1);
    if (tail.startsWith(':')) port = int.tryParse(tail.substring(1)) ?? port;
    return _build(address, username, port, identityFile);
  }

  // `host:port`, but only when there is exactly one colon — more than one and
  // it is a bare IPv6 address, which has no port to take.
  final colon = rest.indexOf(':');
  if (colon >= 0 && rest.indexOf(':', colon + 1) < 0) {
    final tail = rest.substring(colon + 1);
    final parsed = int.tryParse(tail);
    if (parsed != null) {
      port = parsed;
      rest = rest.substring(0, colon);
    }
  }

  return _build(rest, username, port, identityFile);
}

ParsedConnection? _build(
  String hostname,
  String? username,
  int? port,
  String? identityFile,
) {
  final host = hostname.trim();
  if (host.isEmpty) return null;
  // A port outside the range is a typo, not a port. Dropping it beats saving a
  // host that cannot be dialled.
  final valid = port != null && port > 0 && port <= 65535 ? port : null;
  return ParsedConnection(
    hostname: host,
    username: username?.trim(),
    port: valid,
    identityFile: identityFile,
  );
}

/// `ssh` flags that take a value, so the value is not read as a hostname.
const _flagsWithValues = {
  '-b',
  '-c',
  '-D',
  '-E',
  '-e',
  '-F',
  '-I',
  '-J',
  '-L',
  '-m',
  '-O',
  '-o',
  '-Q',
  '-R',
  '-S',
  '-W',
  '-w',
};
