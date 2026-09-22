import 'dart:convert';

import '../../../core/terminal/tmux_commands.dart' show isValidEnvName;

/// What is wrong with one environment variable in the editor.
enum EnvVarProblem {
  /// A value with no name.
  missingName,

  /// Not `^[A-Za-z_][A-Za-z0-9_]*$` — a name becomes shell syntax.
  invalidName,

  /// The same name twice; only one of them could win.
  duplicateName,

  /// A line break or a NUL in the value. See [HostEnv.isValidValue].
  invalidValue,
}

/// A host's environment variables, and how they are stored.
///
/// Stored as a JSON object in `hosts.env_vars` (see the v6 migration): one
/// reading, whatever a value contains. Order is kept — a Dart map and
/// `jsonEncode` both preserve insertion order — so the editor shows them the
/// way they were typed.
abstract final class HostEnv {
  /// Reads a stored column. Tolerant on purpose: a row from a hand edit or a
  /// newer build must not stop a host from connecting, so anything that is
  /// not a valid name with a string value is dropped rather than thrown.
  static Map<String, String> parse(String? stored) {
    if (stored == null || stored.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String &&
              entry.value is String &&
              isValidEnvName(entry.key as String) &&
              isValidValue(entry.value as String))
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return const {};
    }
  }

  /// The column value for [env]: null when there are none, so a host without
  /// variables looks exactly like one from before they existed.
  static String? encode(Map<String, String> env) =>
      env.isEmpty ? null : jsonEncode(env);

  /// Whether [value] can be passed to a shell on every account.
  ///
  /// A line break is refused: the command that sets it is run by the
  /// account's login shell before `sh` takes over, and csh — still the login
  /// shell on some BSD systems — rejects a newline inside quotes. A NUL
  /// cannot be in a C string at all.
  static bool isValidValue(String value) =>
      !value.contains('\n') && !value.contains('\r') && !value.contains('\x00');

  /// The problem with the pair at [index] in [pairs], if any.
  ///
  /// A row with neither a name nor a value is not a problem — it is an empty
  /// row, and saving drops it.
  static EnvVarProblem? problemAt(
    List<(String name, String value)> pairs,
    int index,
  ) {
    final (rawName, value) = pairs[index];
    final name = rawName.trim();
    if (name.isEmpty) {
      return value.isEmpty ? null : EnvVarProblem.missingName;
    }
    if (!isValidEnvName(name)) return EnvVarProblem.invalidName;
    for (var i = 0; i < index; i++) {
      if (pairs[i].$1.trim() == name) return EnvVarProblem.duplicateName;
    }
    if (!isValidValue(value)) return EnvVarProblem.invalidValue;
    return null;
  }

  /// The map to save from the editor's [pairs]: empty rows dropped, names
  /// trimmed, values exactly as typed. Call only once every [problemAt] is
  /// null.
  static Map<String, String> fromPairs(List<(String, String)> pairs) => {
    for (final (name, value) in pairs)
      if (name.trim().isNotEmpty) name.trim(): value,
  };
}
