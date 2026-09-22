/// How a session log is written.
///
/// The persisted [id]s are our own names, so reordering the enum cannot
/// repoint a stored preference.
enum SessionLogFormat {
  /// Readable text: escape sequences removed, progress bars collapsed to
  /// their final state. For reading, searching and pasting into a ticket.
  plain('plain', 'log'),

  /// The bytes exactly as the server sent them. `cat` replays it with its
  /// colours; `less -R` pages it.
  raw('raw', 'log'),

  /// asciicast v2: a JSON header and one timestamped line per chunk of
  /// output. `asciinema play` replays it at the speed it happened, and it is
  /// what asciinema.org and its web player take.
  asciicast('asciicast', 'cast');

  const SessionLogFormat(this.id, this.extension);

  final String id;

  /// Without the dot.
  final String extension;

  static SessionLogFormat fromId(String? id) => values.firstWhere(
    (f) => f.id == id,
    orElse: () => SessionLogFormat.plain,
  );
}

/// `<host>-<yyyyMMdd-HHmmss>.<ext>`, with anything a file system might
/// object to in the host's label replaced.
///
/// Local time, because it is what the person will look for; seconds, so two
/// logs of the same host started in one minute do not collide.
String sessionLogFileName(String host, DateTime when, SessionLogFormat format) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${when.year.toString().padLeft(4, '0')}${two(when.month)}'
      '${two(when.day)}-${two(when.hour)}${two(when.minute)}${two(when.second)}';
  var safe = host
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f\s]+'), '_')
      .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
  if (safe.isEmpty) safe = 'session';
  if (safe.length > 64) safe = safe.substring(0, 64);
  return '$safe-$stamp.${format.extension}';
}
