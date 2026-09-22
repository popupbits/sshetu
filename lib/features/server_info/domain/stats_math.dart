import 'server_sample.dart';

/// CPU busy share between two samples of the aggregate counters, 0–100.
///
/// Null when there is nothing to compare: no time passed, or the counters went
/// backwards — a reboot between polls, or a container's view being reset —
/// which would otherwise come out as a negative or wildly high figure.
double? cpuPercentBetween(CpuTimes? previous, CpuTimes? current) {
  if (previous == null || current == null) return null;
  final total = current.total - previous.total;
  final idle = current.idle - previous.idle;
  if (total <= 0 || idle < 0 || idle > total) return null;
  return (total - idle) / total * 100;
}

/// Bytes per second from two readings of a counter over [elapsed].
///
/// Null for a non-positive interval or a counter that went backwards: a
/// 32-bit counter on an old router wraps at 4 GiB, and an interface that went
/// down and up starts again from zero. Guessing the wrap would be right only
/// for the first kind, so neither is guessed.
double? ratePerSecond(int? previous, int? current, Duration? elapsed) {
  if (previous == null || current == null || elapsed == null) return null;
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  if (seconds <= 0) return null;
  final delta = current - previous;
  if (delta < 0) return null;
  return delta / seconds;
}

/// The time between two samples.
///
/// The server's own uptime when both have it: it is monotonic and measured
/// where the counters are, so network latency between polls does not bend
/// the rate. Otherwise the local clock at which each sample arrived.
Duration? elapsedBetween({
  required ServerSample previous,
  required ServerSample current,
  required DateTime previousAt,
  required DateTime currentAt,
}) {
  final a = previous.uptime;
  final b = current.uptime;
  if (a != null && b != null && b > a) return b - a;
  final local = currentAt.difference(previousAt);
  return local > Duration.zero ? local : null;
}

/// Everything a pair of samples can say.
ServerStats deriveStats({
  required ServerSample current,
  required DateTime currentAt,
  ServerSample? previous,
  DateTime? previousAt,
}) {
  if (previous == null || previousAt == null) {
    return ServerStats(sample: current);
  }
  final elapsed = elapsedBetween(
    previous: previous,
    current: current,
    previousAt: previousAt,
    currentAt: currentAt,
  );
  return ServerStats(
    sample: current,
    cpuPercent: cpuPercentBetween(previous.cpu, current.cpu),
    rxBytesPerSecond: ratePerSecond(
      previous.net?.rxBytes,
      current.net?.rxBytes,
      elapsed,
    ),
    txBytesPerSecond: ratePerSecond(
      previous.net?.txBytes,
      current.net?.txBytes,
      elapsed,
    ),
  );
}
