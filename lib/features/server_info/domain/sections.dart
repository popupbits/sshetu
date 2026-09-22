/// The framing every server-info script shares.
///
/// A script prints `@@sshetu:<name>` before each section, so one exec can
/// answer several questions and a missing tool costs only its own section.
/// Anything before the first marker — a login banner, an `echo` in someone's
/// `.bashrc` — is ignored rather than mistaken for data.
library;

const String sectionMarker = '@@sshetu:';

/// Splits [output] into sections by marker, keeping each section's lines.
///
/// A section named twice keeps the last one. Line endings are normalised, so
/// a server that answers in CRLF parses the same as one that does not.
Map<String, List<String>> splitSections(String output) {
  final sections = <String, List<String>>{};
  List<String>? current;
  for (final raw in output.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.replaceAll('\r', '');
    if (line.startsWith(sectionMarker)) {
      final name = line.substring(sectionMarker.length).trim();
      current = sections[name] = <String>[];
      continue;
    }
    current?.add(line);
  }
  // Trailing blank lines are noise from `echo`, not data.
  for (final lines in sections.values) {
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
  }
  return sections;
}

/// `KEY=value` lines, as `/etc/os-release` writes them, unquoted.
Map<String, String> parseKeyValues(Iterable<String> lines) {
  final values = <String, String>{};
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    var value = trimmed.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[trimmed.substring(0, eq).trim()] = value.replaceAll(r'\"', '"');
  }
  return values;
}

/// `name: value` lines, as `sysctl` and `sw_vers` write them.
Map<String, String> parseColonValues(Iterable<String> lines) {
  final values = <String, String>{};
  for (final line in lines) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    values[line.substring(0, colon).trim()] = line.substring(colon + 1).trim();
  }
  return values;
}

/// The first non-empty line of [lines], trimmed, or null.
String? firstLine(List<String>? lines) {
  if (lines == null) return null;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
