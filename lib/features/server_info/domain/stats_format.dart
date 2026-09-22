import '../../files/domain/format.dart';

/// `1.4 MB/s`, `0 B/s`, `—` for unknown. Same unit ladder as file sizes, so a
/// transfer and the link it rides on read in the same language.
String formatRate(double? bytesPerSecond) {
  if (bytesPerSecond == null || bytesPerSecond.isNaN) return '—';
  return '${humanFileSize(bytesPerSecond.round())}/s';
}

/// `12d 4h`, `3h 12m`, `5m` — two units at most, like `uptime` itself.
String formatUptime(Duration? uptime) {
  if (uptime == null) return '—';
  final days = uptime.inDays;
  final hours = uptime.inHours % 24;
  final minutes = uptime.inMinutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (uptime.inHours > 0) return '${hours}h ${minutes}m';
  return '${uptime.inMinutes}m';
}

/// `42%`, one decimal below ten so an idle server does not read as dead.
String formatPercent(double? percent) {
  if (percent == null || percent.isNaN) return '—';
  return percent < 10
      ? '${percent.toStringAsFixed(1)}%'
      : '${percent.round()}%';
}

/// `0.52  0.58  0.59`.
String formatLoad(double one, double five, double fifteen) =>
    '${one.toStringAsFixed(2)}  ${five.toStringAsFixed(2)}  '
    '${fifteen.toStringAsFixed(2)}';
