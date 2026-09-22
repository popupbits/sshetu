/// What one poll of a server says, parsed and nothing more.
///
/// Every field is nullable because every field can be missing: a router with
/// no `/proc/net/dev`, a Mac with no `/proc` at all, a busybox `df` that
/// refuses `-P`. A section that did not arrive is null, never a zero that
/// would claim to know something nobody reported.
library;

/// Aggregate CPU time counters from the `cpu` line of `/proc/stat`.
///
/// Counters, not a percentage: a percentage exists only between two samples,
/// which is what [cpuPercentBetween] computes.
class CpuTimes {
  const CpuTimes({required this.total, required this.idle});

  /// Every jiffy counted, in any state.
  final int total;

  /// Idle plus iowait — time the CPU had nothing it could run.
  final int idle;
}

/// Memory and swap, in bytes.
class MemoryInfo {
  const MemoryInfo({
    required this.totalBytes,
    required this.availableBytes,
    this.swapTotalBytes,
    this.swapFreeBytes,
  });

  final int totalBytes;
  final int availableBytes;
  final int? swapTotalBytes;
  final int? swapFreeBytes;

  int get usedBytes =>
      (totalBytes - availableBytes).clamp(0, totalBytes).toInt();

  double get usedFraction => totalBytes <= 0 ? 0 : usedBytes / totalBytes;

  int? get swapUsedBytes {
    final total = swapTotalBytes;
    final free = swapFreeBytes;
    if (total == null || free == null) return null;
    return (total - free).clamp(0, total).toInt();
  }
}

/// The 1, 5 and 15 minute load averages.
class LoadAverage {
  const LoadAverage(this.one, this.five, this.fifteen);

  final double one;
  final double five;
  final double fifteen;
}

/// One mounted filesystem, from `df -P -k`.
class FilesystemUsage {
  const FilesystemUsage({
    required this.source,
    required this.mountPoint,
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
  });

  /// The device or source column: `/dev/sda1`, `tmpfs`, `server:/export`.
  final String source;

  /// Where it is mounted. May contain spaces.
  final String mountPoint;
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;

  /// Used as a share of what the user can actually have — the same figure
  /// `df` prints as Capacity, which counts root-reserved blocks as used.
  double get usedFraction {
    final usable = usedBytes + availableBytes;
    return usable <= 0 ? 0 : usedBytes / usable;
  }
}

/// Byte counters summed over the real network interfaces.
class NetCounters {
  const NetCounters({required this.rxBytes, required this.txBytes});

  final int rxBytes;
  final int txBytes;
}

/// Who and what the server is.
class SystemIdentity {
  const SystemIdentity({
    this.hostname,
    this.osName,
    this.kernelName,
    this.kernelRelease,
    this.cpuCount,
  });

  final String? hostname;

  /// The friendly name: `PRETTY_NAME`, or `macOS 14.5`.
  final String? osName;

  /// `uname -s`: Linux, Darwin, FreeBSD.
  final String? kernelName;

  /// `uname -r`.
  final String? kernelRelease;
  final int? cpuCount;
}

/// One poll, parsed.
class ServerSample {
  const ServerSample({
    this.identity = const SystemIdentity(),
    this.cpu,
    this.memory,
    this.load,
    this.uptime,
    this.filesystems,
    this.net,
    this.processCount,
  });

  final SystemIdentity identity;
  final CpuTimes? cpu;
  final MemoryInfo? memory;
  final LoadAverage? load;

  /// How long the server has been up. On Linux this is also the monotonic
  /// clock rates are computed against — see [elapsedBetween].
  final Duration? uptime;
  final List<FilesystemUsage>? filesystems;
  final NetCounters? net;

  /// Total processes, from the fourth field of `/proc/loadavg`.
  final int? processCount;

  /// True when the server told us close to nothing about its resources —
  /// the case the panel calls "Limited information on this system".
  bool get isLimited => cpu == null && memory == null && load == null;
}

/// Derived, display-ready figures: a sample plus what only a pair of samples
/// can say.
class ServerStats {
  const ServerStats({
    required this.sample,
    this.cpuPercent,
    this.rxBytesPerSecond,
    this.txBytesPerSecond,
  });

  final ServerSample sample;

  /// 0–100, or null on the first sample and after a counter reset.
  final double? cpuPercent;
  final double? rxBytesPerSecond;
  final double? txBytesPerSecond;
}
