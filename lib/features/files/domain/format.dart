/// "1.4 MB", "512 B" — never localized, the way every file manager on every
/// platform already writes it. Null (a directory, or a server that sent no
/// size) renders as an em dash rather than "0 B", which would claim to know
/// something nobody reported.
String humanFileSize(int? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  // One decimal below 10 of a unit ("1.4 MB"), none above ("14 MB") — enough
  // precision to matter, not so much that a listing of forty files turns into
  // a column of noise.
  final decimals = value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

/// A short relative age — `2h`, `3d`, `1y` — for a file's modified time.
///
/// [nowLabel] and [now] are passed in rather than read from `DateTime.now()`
/// and a localization lookup here, so this stays a pure function a test can
/// pin exactly and a widget can feed real values into.
String relativeModified(
  DateTime? at, {
  required DateTime now,
  String nowLabel = 'now',
}) {
  if (at == null) return '—';
  final elapsed = now.difference(at);
  // A modified time in the future is clock skew between this device and the
  // remote host, not a file from tomorrow — showing that as "-3m" would read
  // as a bug, so it is treated the same as "unknown".
  if (elapsed.isNegative) return '—';
  if (elapsed.inMinutes < 1) return nowLabel;
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h';
  if (elapsed.inDays < 365) return '${elapsed.inDays}d';
  return '${(elapsed.inDays / 365).floor()}y';
}
