import 'sections.dart';
import 'server_sample.dart';

/// The one script a poll runs.
///
/// Fed to `sh -s` on stdin rather than passed as the exec command: the exec
/// command is run by the user's *login* shell, and a fish or csh user would
/// otherwise get a syntax error on the first line. `sh` is the one shell every
/// Unix-like server has — including busybox routers.
///
/// Each section is independent and silenced on failure, so a missing file or
/// tool costs only its own section. The BSD/macOS block runs only where there
/// is no `/proc/stat`, which keeps a Linux poll to cheap file reads.
const String statsScript = r'''
LC_ALL=C
export LC_ALL
s() { echo "@@sshetu:$1"; }
s uname
uname -s 2>/dev/null
uname -r 2>/dev/null
s hostname
hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null
s osrelease
cat /etc/os-release 2>/dev/null || cat /usr/lib/os-release 2>/dev/null
s stat
grep '^cpu' /proc/stat 2>/dev/null
s meminfo
cat /proc/meminfo 2>/dev/null
s loadavg
cat /proc/loadavg 2>/dev/null
s uptime
cat /proc/uptime 2>/dev/null
s df
df -P -k 2>/dev/null
s netdev
cat /proc/net/dev 2>/dev/null
if [ ! -r /proc/stat ]; then
  s sysctl
  sysctl hw.ncpu hw.memsize hw.physmem vm.loadavg kern.boottime vm.swapusage 2>/dev/null
  s vmstat
  vm_stat 2>/dev/null
  s swvers
  sw_vers 2>/dev/null
  s now
  date +%s 2>/dev/null
fi
s end
''';

/// Parses what [statsScript] printed. Never throws: a section that does not
/// parse is simply absent from the result.
ServerSample parseStatsOutput(String output) {
  final sections = splitSections(output);

  final uname = sections['uname'] ?? const [];
  final kernelName = uname.isNotEmpty ? _nonEmpty(uname[0]) : null;
  final kernelRelease = uname.length > 1 ? _nonEmpty(uname[1]) : null;

  final osRelease = parseKeyValues(sections['osrelease'] ?? const []);
  final sysctl = parseColonValues(sections['sysctl'] ?? const []);
  final swVers = parseColonValues(sections['swvers'] ?? const []);

  final cpuLines = sections['stat'] ?? const [];
  final perCore = cpuLines
      .where((line) => RegExp(r'^cpu\d+\s').hasMatch(line))
      .length;

  final loadLines = sections['loadavg'];
  final now = int.tryParse(firstLine(sections['now']) ?? '');

  return ServerSample(
    identity: SystemIdentity(
      hostname: firstLine(sections['hostname']),
      osName:
          _nonEmpty(osRelease['PRETTY_NAME']) ??
          _nonEmpty(osRelease['NAME']) ??
          _macOsName(swVers),
      kernelName: kernelName,
      kernelRelease: kernelRelease,
      cpuCount: perCore > 0 ? perCore : int.tryParse(sysctl['hw.ncpu'] ?? ''),
    ),
    cpu: parseProcStatCpu(cpuLines),
    memory:
        parseMeminfo(sections['meminfo'] ?? const []) ??
        parseDarwinMemory(
          sysctl: sysctl,
          vmStat: sections['vmstat'] ?? const [],
        ),
    load:
        parseLoadavg(firstLine(loadLines)) ??
        parseSysctlLoad(sysctl['vm.loadavg']),
    uptime:
        parseProcUptime(firstLine(sections['uptime'])) ??
        parseBoottimeUptime(sysctl['kern.boottime'], now),
    filesystems: sections.containsKey('df')
        ? _orNull(parseDf(sections['df']!))
        : null,
    net: parseNetDev(sections['netdev'] ?? const []),
    processCount: parseLoadavgProcesses(firstLine(loadLines)),
  );
}

/// The aggregate `cpu ` line of `/proc/stat`.
///
/// Fields: user nice system idle iowait irq softirq steal guest guest_nice.
/// Guest time is already counted inside user and nice, so only the first
/// eight are summed; an old kernel with only four still works.
CpuTimes? parseProcStatCpu(List<String> lines) {
  for (final line in lines) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first != 'cpu') continue;
    final values = <int>[];
    for (final part in parts.skip(1).take(8)) {
      final value = int.tryParse(part);
      if (value == null) return null;
      values.add(value);
    }
    if (values.length < 4) return null;
    final idle = values[3] + (values.length > 4 ? values[4] : 0);
    return CpuTimes(total: values.fold(0, (a, b) => a + b), idle: idle);
  }
  return null;
}

/// `/proc/meminfo`, in kB.
///
/// `MemAvailable` is the kernel's own estimate and the honest one. Kernels
/// before 3.14 — still found on routers and old appliances — lack it, and
/// there free plus buffers plus page cache is the long-standing estimate.
MemoryInfo? parseMeminfo(List<String> lines) {
  final kb = <String, int>{};
  for (final line in lines) {
    final match = RegExp(r'^(\w+(?:\(\w+\))?):\s+(\d+)').firstMatch(line);
    if (match != null) kb[match[1]!] = int.parse(match[2]!);
  }
  final total = kb['MemTotal'];
  if (total == null || total <= 0) return null;
  final available =
      kb['MemAvailable'] ??
      (kb['MemFree'] ?? 0) +
          (kb['Buffers'] ?? 0) +
          (kb['Cached'] ?? 0) +
          (kb['SReclaimable'] ?? 0);
  final swapTotal = kb['SwapTotal'];
  return MemoryInfo(
    totalBytes: total * 1024,
    availableBytes: available.clamp(0, total) * 1024,
    swapTotalBytes: swapTotal == null ? null : swapTotal * 1024,
    swapFreeBytes: kb['SwapFree'] == null ? null : kb['SwapFree']! * 1024,
  );
}

/// macOS memory from `sysctl hw.memsize` and `vm_stat`.
///
/// Used is active + wired + compressed pages, which is close to what Activity
/// Monitor calls memory used. Best effort: FreeBSD has neither `hw.memsize`
/// nor `vm_stat`, and gets no memory figure rather than a wrong one.
MemoryInfo? parseDarwinMemory({
  required Map<String, String> sysctl,
  required List<String> vmStat,
}) {
  final total = int.tryParse(sysctl['hw.memsize'] ?? '');
  if (total == null || total <= 0 || vmStat.isEmpty) return null;
  final pageSize =
      int.tryParse(
        RegExp(r'page size of (\d+) bytes').firstMatch(vmStat.first)?[1] ?? '',
      ) ??
      4096;
  final pages = <String, int>{};
  for (final line in vmStat.skip(1)) {
    final match = RegExp(r'^"?([^:"]+)"?:\s+(\d+)').firstMatch(line.trim());
    if (match != null) pages[match[1]!] = int.parse(match[2]!);
  }
  final active = pages['Pages active'];
  final wired = pages['Pages wired down'];
  if (active == null || wired == null) return null;
  final used =
      (active + wired + (pages['Pages occupied by compressor'] ?? 0)) *
      pageSize;
  final swap = _parseSwapUsage(sysctl['vm.swapusage']);
  return MemoryInfo(
    totalBytes: total,
    availableBytes: (total - used).clamp(0, total).toInt(),
    swapTotalBytes: swap?.$1,
    swapFreeBytes: swap?.$2,
  );
}

/// `total = 2048.00M  used = 1024.00M  free = 1024.00M  (encrypted)`.
(int, int)? _parseSwapUsage(String? value) {
  if (value == null) return null;
  int? read(String name) {
    final match = RegExp('$name = ([\\d.]+)([KMGT])').firstMatch(value);
    if (match == null) return null;
    final number = double.tryParse(match[1]!);
    if (number == null) return null;
    const scale = {'K': 1 << 10, 'M': 1 << 20, 'G': 1 << 30, 'T': 1 << 40};
    return (number * scale[match[2]!]!).round();
  }

  final total = read('total');
  final free = read('free');
  if (total == null || free == null) return null;
  return (total, free);
}

/// `0.52 0.58 0.59 1/467 12345`.
LoadAverage? parseLoadavg(String? line) {
  if (line == null) return null;
  final parts = line.split(RegExp(r'\s+'));
  if (parts.length < 3) return null;
  final one = double.tryParse(parts[0]);
  final five = double.tryParse(parts[1]);
  final fifteen = double.tryParse(parts[2]);
  if (one == null || five == null || fifteen == null) return null;
  return LoadAverage(one, five, fifteen);
}

/// The total after the slash in `/proc/loadavg`'s fourth field.
int? parseLoadavgProcesses(String? line) {
  if (line == null) return null;
  final match = RegExp(r'\s\d+/(\d+)\s').firstMatch(' $line ');
  return match == null ? null : int.tryParse(match[1]!);
}

/// `{ 1.52 1.63 1.70 }`, from `sysctl vm.loadavg`.
LoadAverage? parseSysctlLoad(String? value) {
  if (value == null) return null;
  return parseLoadavg(value.replaceAll(RegExp(r'[{}]'), ' ').trim());
}

/// `/proc/uptime`: seconds since boot, then idle seconds.
Duration? parseProcUptime(String? line) {
  if (line == null) return null;
  final seconds = double.tryParse(line.split(RegExp(r'\s+')).first);
  if (seconds == null || seconds < 0) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// `{ sec = 1700000000, usec = 0 } Tue Nov 14 ...` against the server's own
/// `date +%s`, so the phone's clock never enters into it.
Duration? parseBoottimeUptime(String? boottime, int? nowSeconds) {
  if (boottime == null || nowSeconds == null) return null;
  final sec = int.tryParse(
    RegExp(r'sec = (\d+)').firstMatch(boottime)?[1] ?? '',
  );
  if (sec == null || nowSeconds < sec) return null;
  return Duration(seconds: nowSeconds - sec);
}

/// A `df -P -k` row: source, blocks, used, available, capacity, mount point.
///
/// Anchored on the four numbers and the percentage rather than split on
/// whitespace, because both ends may contain spaces — a mount point like
/// `/media/usb disk`, or macOS's `map auto_home` source.
final _dfRow = RegExp(r'^(.+?)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+%|-)\s+(/.*)$');

/// Every row of `df -P -k`, pseudo filesystems included; see
/// [isPseudoFilesystem] for the filter the panel applies.
List<FilesystemUsage> parseDf(List<String> lines) {
  final result = <FilesystemUsage>[];
  for (final line in lines) {
    final match = _dfRow.firstMatch(line.trimRight());
    if (match == null) continue; // The header, or a row we cannot read.
    result.add(
      FilesystemUsage(
        source: match[1]!.trim(),
        mountPoint: match[6]!,
        totalBytes: int.parse(match[2]!) * 1024,
        usedBytes: int.parse(match[3]!) * 1024,
        availableBytes: int.parse(match[4]!) * 1024,
      ),
    );
  }
  return result;
}

const _pseudoSources = {
  'tmpfs',
  'devtmpfs',
  'udev',
  'devfs',
  'none',
  'shm',
  'proc',
  'sysfs',
  'cgroup',
  'cgroup2',
  'efivarfs',
  'securityfs',
  'pstore',
  'debugfs',
  'tracefs',
  'ramfs',
  'mqueue',
  'hugetlbfs',
  'fusectl',
  'configfs',
  'binfmt_misc',
  'run',
  'fdescfs',
  'linprocfs',
  'nullfs',
  'rootfs',
};

const _containerFileMounts = {
  '/etc/hosts',
  '/etc/hostname',
  '/etc/resolv.conf',
};

const _pseudoMountPrefixes = [
  '/proc',
  '/sys',
  '/dev',
  '/run',
  '/snap/',
  '/System/Volumes/VM',
  '/System/Volumes/Preboot',
  '/System/Volumes/Update',
  '/System/Volumes/xarts',
  '/System/Volumes/iSCPreboot',
  '/System/Volumes/Hardware',
  '/private/var/vm',
  // WSL's view of the Windows driver store: the C: drive again.
  '/usr/lib/wsl',
];

/// Whether a `df` row is kernel plumbing rather than storage someone fills.
///
/// Memory-backed and virtual filesystems, snap's read-only loop images, the
/// macOS system sub-volumes and autofs maps. An overlay is kept only at `/`,
/// where it *is* a container's disk; elsewhere it is one of Docker's layers.
bool isPseudoFilesystem(FilesystemUsage fs) {
  if (fs.totalBytes <= 0) return true;
  final source = fs.source;
  if (_pseudoSources.contains(source)) return true;
  if (source.startsWith('/dev/loop')) return true;
  if (source.startsWith('map ')) return true;
  if (source == 'overlay' && fs.mountPoint != '/') return true;
  // A container's bind-mounted files: the host's disk, seen through a file.
  if (_containerFileMounts.contains(fs.mountPoint)) return true;
  for (final prefix in _pseudoMountPrefixes) {
    if (fs.mountPoint == prefix || fs.mountPoint.startsWith('$prefix/')) {
      return true;
    }
    if (prefix.endsWith('/') && fs.mountPoint.startsWith(prefix)) return true;
  }
  return false;
}

/// Interfaces whose traffic is already counted on a real one — loopback, and
/// the bridge and veth pairs containers hang off.
bool _isVirtualInterface(String name) =>
    name == 'lo' ||
    name.startsWith('veth') ||
    name.startsWith('docker') ||
    name.startsWith('br-') ||
    name.startsWith('virbr') ||
    name.startsWith('cni') ||
    name.startsWith('flannel');

/// `/proc/net/dev`, summed over the real interfaces.
///
/// Split on the first colon, not on whitespace: old kernels glue a large
/// counter to the name (`eth0:123456789`).
NetCounters? parseNetDev(List<String> lines) {
  var rx = 0;
  var tx = 0;
  var seen = false;
  for (final line in lines) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final name = line.substring(0, colon).trim();
    if (name.isEmpty || name.contains(' ') || name.contains('|')) continue;
    final fields = line.substring(colon + 1).trim().split(RegExp(r'\s+'));
    if (fields.length < 9) continue;
    final r = int.tryParse(fields[0]);
    final t = int.tryParse(fields[8]);
    if (r == null || t == null) continue;
    if (_isVirtualInterface(name)) continue;
    rx += r;
    tx += t;
    seen = true;
  }
  return seen ? NetCounters(rxBytes: rx, txBytes: tx) : null;
}

String? _macOsName(Map<String, String> swVers) {
  final name = _nonEmpty(swVers['ProductName']);
  if (name == null) return null;
  final version = _nonEmpty(swVers['ProductVersion']);
  return version == null ? name : '$name $version';
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<T>? _orNull<T>(List<T> list) => list.isEmpty ? null : list;
