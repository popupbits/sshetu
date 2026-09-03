/// One `Host` block from an OpenSSH config file.
class SshConfigBlock {
  const SshConfigBlock({required this.patterns, required this.options});

  /// The patterns on the `Host` line. `Host web1 web2` is one block matching
  /// two names.
  final List<String> patterns;

  /// Keyword → value, keywords lower-cased. First occurrence wins, matching
  /// OpenSSH.
  final Map<String, String> options;

  /// Whether [alias] matches any pattern in this block, honouring `*`, `?`
  /// and `!` negation.
  bool matches(String alias) {
    var matched = false;
    for (final pattern in patterns) {
      final negated = pattern.startsWith('!');
      final body = negated ? pattern.substring(1) : pattern;
      if (OpenSshConfig._globMatches(body, alias)) {
        // A negation anywhere in the list vetoes the whole block, which is
        // what `Host * !bastion` is for.
        if (negated) return false;
        matched = true;
      }
    }
    return matched;
  }

  /// Whether this block names one concrete host rather than a pattern.
  ///
  /// `Host *` and `Host web-*` configure other entries; they are not servers
  /// anyone can connect to, so they are never offered as importable.
  bool get isConcrete =>
      patterns.length == 1 &&
      !patterns.single.contains('*') &&
      !patterns.single.contains('?') &&
      !patterns.single.startsWith('!');
}

/// A parsed OpenSSH client configuration.
///
/// Deliberately a *reader*, not an emulator: it understands enough of the file
/// to import hosts the user has already written down, and it ignores what it
/// does not understand rather than guessing. An option we cannot honour is
/// better reported as unsupported than silently applied wrongly to somebody's
/// production access.
class OpenSshConfig {
  const OpenSshConfig(this.blocks);

  final List<SshConfigBlock> blocks;

  /// Parses [text]. Never throws: a malformed line is skipped, because a
  /// config that has grown over ten years will contain something odd and
  /// refusing to import any of it over one bad line is useless behaviour.
  ///
  /// `Include` is **not** followed — see [includePaths].
  factory OpenSshConfig.parse(String text) {
    final blocks = <SshConfigBlock>[];
    List<String>? patterns;
    var options = <String, String>{};
    // Set while inside a `Match` body, whose options are skipped entirely.
    var inMatch = false;

    void flush() {
      if (patterns != null) {
        blocks.add(SshConfigBlock(patterns: patterns!, options: options));
      }
      patterns = null;
      options = <String, String>{};
    }

    for (final raw in text.split('\n')) {
      final line = _stripComment(raw).trim();
      if (line.isEmpty) continue;

      final (keyword, value) = _splitOption(line);
      if (keyword == null) continue;

      if (keyword == 'host') {
        flush();
        inMatch = false;
        patterns = _splitTokens(value);
        continue;
      }

      // `Match` blocks are conditional on things we cannot evaluate here
      // (exec, originalhost, the local user, the final destination). Its body
      // is therefore skipped until the next `Host`.
      //
      // Skipping is not the same as ending the block, and the difference is
      // the whole point: with the block merely ended, the next option line
      // finds no open `Host` and falls into the `Host *` case below — so a
      // `Match host db / User root` would quietly become the default username
      // for EVERY imported host. Under-applying a condition we cannot read is
      // acceptable; silently rewriting every other host is not.
      if (keyword == 'match') {
        flush();
        inMatch = true;
        continue;
      }

      if (inMatch) continue;

      // Options before any Host line apply to everything, exactly as
      // `Host *` would.
      patterns ??= ['*'];
      // First one wins, per ssh_config(5).
      options.putIfAbsent(keyword, () => value);
    }
    flush();
    return OpenSshConfig(blocks);
  }

  /// Resolved options for [alias], applying blocks in file order.
  ///
  /// OpenSSH's rule is *first obtained value wins*, so a `Host *` block at the
  /// bottom supplies defaults and a specific block at the top overrides them.
  /// Reversing this is the classic way to import a config that connects to the
  /// wrong machine.
  Map<String, String> resolve(String alias) {
    final resolved = <String, String>{};
    for (final block in blocks) {
      if (!block.matches(alias)) continue;
      for (final entry in block.options.entries) {
        resolved.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return resolved;
  }

  /// Aliases that name a real host and can be offered for import.
  List<String> get importableAliases => [
    for (final block in blocks)
      if (block.isConcrete) block.patterns.single,
  ];

  /// Paths named by `Include` directives, in the order they appear.
  ///
  /// Surfaced rather than followed: an include can reach anywhere on the
  /// filesystem, and reading files the user did not point us at — inside an
  /// import they may run out of curiosity — is not a decision this parser
  /// should take on its own. The caller decides, and can show the user what
  /// it is about to read.
  List<String> get includePaths => [
    for (final block in blocks)
      if (block.options['include'] != null)
        ..._splitTokens(block.options['include']!),
  ];

  /// Strips a `#` comment, respecting double quotes.
  static String _stripComment(String line) {
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') inQuotes = !inQuotes;
      if (char == '#' && !inQuotes) return line.substring(0, i);
    }
    return line;
  }

  /// Splits `Keyword value` or `Keyword=value` into a lower-cased keyword and
  /// its value. Returns a null keyword for a line that is neither.
  static (String?, String) _splitOption(String line) {
    final equals = line.indexOf('=');
    final space = line.indexOf(RegExp(r'\s'));

    int split;
    if (equals >= 0 && (space < 0 || equals < space)) {
      split = equals;
    } else if (space >= 0) {
      split = space;
    } else {
      return (null, '');
    }

    final keyword = line.substring(0, split).trim().toLowerCase();
    var value = line.substring(split + 1).trim();
    // A leading `=` after whitespace: `Port = 22`.
    if (value.startsWith('=')) value = value.substring(1).trim();
    if (keyword.isEmpty) return (null, '');
    return (keyword, _unquote(value));
  }

  static String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  /// Splits a value into whitespace-separated tokens, keeping quoted runs
  /// together so a path with a space survives.
  static List<String> _splitTokens(String value) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && (char == ' ' || char == '\t' || char == ',')) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(char);
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  /// OpenSSH pattern matching: `*` any run, `?` one character.
  static bool _globMatches(String pattern, String value) {
    final escaped = RegExp.escape(pattern)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    return RegExp('^$escaped\$', caseSensitive: false).hasMatch(value);
  }
}
