import 'dart:convert';
import 'dart:typed_data';

/// One key of a `.reg` file: its full path and its named values.
class RegKey {
  const RegKey(this.path, this.values);

  /// `HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\My%20Server`.
  final String path;

  /// Value name to value: a [String] for `"..."`, an [int] for `dword:`.
  /// Binary and other hex types are dropped — PuTTY stores nothing SSHetu
  /// needs in them.
  final Map<String, Object> values;

  String? string(String name) {
    final value = values[name];
    return value is String ? value : null;
  }

  int? dword(String name) {
    final value = values[name];
    return value is int ? value : null;
  }
}

/// Reads the text of a `.reg` file as `reg.exe export` or regedit writes it.
///
/// **Encoding.** `reg export` and regedit write UTF-16LE with a byte-order
/// mark; an older `REGEDIT4` file, or one someone saved from an editor, may
/// be UTF-8 or plain ANSI. The BOM decides; without one, a NUL in every
/// other byte is UTF-16LE all the same, and anything else is read as UTF-8
/// with Latin-1 as the fallback — a hostname is ASCII either way.
String decodeRegBytes(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _utf16(bytes, 2, littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _utf16(bytes, 2, littleEndian: false);
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 4 && bytes[1] == 0 && bytes[3] == 0) {
    return _utf16(bytes, 0, littleEndian: true);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

String _utf16(Uint8List bytes, int start, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

/// Parses `.reg` text into keys, in file order.
///
/// Tolerant by design: a line it does not understand is skipped rather than
/// failing the file, because the file is someone's whole PuTTY history and
/// one odd value should not cost them the other forty sessions.
///
/// Handled: `[key]` headers, `"name"="string"` with `\\` and `\"` escapes,
/// `"name"=dword:0000001f`, `@=` default values (ignored), `hex…:` values
/// continued across lines with a trailing `\` (skipped), comments starting
/// `;`, and a `[-key]` deletion header (ignored along with its values).
List<RegKey> parseRegText(String text) {
  final keys = <RegKey>[];
  String? path;
  var values = <String, Object>{};
  var skipping = false;

  void flush() {
    final current = path;
    if (current != null && !skipping) keys.add(RegKey(current, values));
    values = <String, Object>{};
  }

  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (i == 0 && line.startsWith('\u{FEFF}')) line = line.substring(1).trim();
    if (line.isEmpty || line.startsWith(';')) continue;

    if (line.startsWith('[') && line.endsWith(']')) {
      flush();
      final inner = line.substring(1, line.length - 1);
      skipping = inner.startsWith('-');
      path = skipping ? inner.substring(1) : inner;
      continue;
    }
    if (path == null || skipping || !line.startsWith('"')) {
      // A continued hex value runs on with trailing backslashes; step over
      // the whole thing so its tail is not mistaken for a value.
      while (line.endsWith(r'\') && i + 1 < lines.length) {
        line = lines[++i].trim();
      }
      continue;
    }

    final name = _readQuoted(line, 0);
    if (name == null) continue;
    final rest = line.substring(name.end).trimLeft();
    if (!rest.startsWith('=')) continue;
    final raw = rest.substring(1).trimLeft();

    if (raw.startsWith('"')) {
      final value = _readQuoted(raw, 0);
      if (value != null) values[name.text] = value.text;
    } else if (raw.toLowerCase().startsWith('dword:')) {
      final parsed = int.tryParse(raw.substring(6).trim(), radix: 16);
      if (parsed != null) values[name.text] = parsed;
    } else {
      var continued = raw;
      while (continued.endsWith(r'\') && i + 1 < lines.length) {
        continued = lines[++i].trim();
      }
    }
  }
  flush();
  return keys;
}

/// A quoted string starting at [start], unescaped, and where it ended.
({String text, int end})? _readQuoted(String line, int start) {
  if (start >= line.length || line[start] != '"') return null;
  final out = StringBuffer();
  var i = start + 1;
  while (i < line.length) {
    final char = line[i];
    if (char == r'\' && i + 1 < line.length) {
      out.write(line[i + 1]);
      i += 2;
      continue;
    }
    if (char == '"') return (text: out.toString(), end: i + 1);
    out.write(char);
    i++;
  }
  return null;
}

/// PuTTY's escaping of a session name into a registry key name, undone.
///
/// PuTTY writes every byte outside `A-Za-z0-9` and a few punctuation marks
/// as `%XX` — `My Server` is stored as `My%20Server`. The bytes are in the
/// system code page; UTF-8 is tried first because it is what a modern
/// Windows uses for anything outside ASCII, and Latin-1 is the fallback so a
/// name never fails to decode.
String decodePuttySessionName(String escaped) {
  final bytes = <int>[];
  for (var i = 0; i < escaped.length; i++) {
    final char = escaped[i];
    if (char == '%' && i + 2 < escaped.length) {
      final hex = int.tryParse(escaped.substring(i + 1, i + 3), radix: 16);
      if (hex != null) {
        bytes.add(hex);
        i += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(char));
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}
