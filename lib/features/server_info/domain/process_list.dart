import 'sections.dart';

/// Lists processes, trying the richest `ps` first.
///
/// procps (`--sort`) on Linux, then BSD/macOS (`-r` sorts by CPU), then plain
/// `ps` — which is all a busybox router has, and which prints whatever columns
/// it likes. The section name says which one answered; the parser reads the
/// header either way. Fed to `sh -s`, like the stats script, so the user's
/// login shell never has to parse it.
const String processScript = r'''
LC_ALL=C
export LC_ALL
if out=$(ps -eo pid,user,pcpu,pmem,etime,comm --sort=-pcpu 2>/dev/null); then
  echo "@@sshetu:ps"
  printf '%s\n' "$out" | head -n 101
elif out=$(ps -Aro pid,user,pcpu,pmem,etime,comm 2>/dev/null); then
  echo "@@sshetu:ps"
  printf '%s\n' "$out" | head -n 101
else
  echo "@@sshetu:ps"
  ps 2>/dev/null | head -n 101
fi
''';

/// The two signals the panel sends. Numbers rather than names: `kill -15`
/// means the same thing to every `kill` — procps, busybox, BSD, and the
/// builtins of bash, zsh, fish and csh.
enum KillSignal {
  term(15),
  kill(9);

  const KillSignal(this.number);
  final int number;
}

/// The exec command for sending [signal] to [pid].
///
/// [pid] is an int, so nothing that reaches the shell here came from text.
/// Never `sudo`: the panel acts with exactly the rights of the logged-in
/// user, and a refusal is reported as the refusal it is.
String killCommand(int pid, KillSignal signal) {
  if (pid <= 0) throw ArgumentError.value(pid, 'pid', 'must be positive');
  return 'kill -${signal.number} $pid';
}

class ProcessInfo {
  const ProcessInfo({
    required this.pid,
    required this.command,
    this.user,
    this.cpuPercent,
    this.memPercent,
    this.time,
  });

  final int pid;
  final String command;
  final String? user;
  final double? cpuPercent;
  final double? memPercent;

  /// Elapsed time (`etime`), or CPU time from a plain busybox `ps`.
  final String? time;
}

/// What `ps` answered, and which columns it had.
class ProcessListing {
  const ProcessListing({
    required this.processes,
    this.hasCpu = false,
    this.hasMem = false,
  });

  final List<ProcessInfo> processes;

  /// Whether this `ps` reported CPU and memory shares at all — a busybox one
  /// does not, and sorting by a column that is not there would be a lie.
  final bool hasCpu;
  final bool hasMem;
}

enum ProcessSort { cpu, mem, pid }

/// Parses the `ps` section of [output], whichever `ps` produced it.
///
/// The header names the columns. The command column is always last and runs
/// to the end of the line, because a process name may contain spaces
/// (`Google Chrome Helper`, `kworker/0:1 H`).
ProcessListing parsePsOutput(String output) {
  final sections = splitSections(output);
  final lines = (sections['ps'] ?? output.split('\n'))
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const ProcessListing(processes: []);

  final header = lines.first.trim().split(RegExp(r'\s+'));
  int col(Set<String> names) =>
      header.indexWhere((h) => names.contains(h.toUpperCase()));
  final pidCol = col({'PID'});
  if (pidCol < 0) return const ProcessListing(processes: []);
  final userCol = col({'USER', 'UID', 'RUSER'});
  final cpuCol = col({'%CPU', 'PCPU', 'CPU'});
  final memCol = col({'%MEM', 'PMEM'});
  final timeCol = col({'ELAPSED', 'ETIME', 'TIME'});
  final commandIndex = header.length - 1;

  final processes = <ProcessInfo>[];
  for (final line in lines.skip(1)) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < header.length) continue;
    // Everything from the command column on is the command.
    final head = fields.sublist(0, commandIndex);
    final command = fields.sublist(commandIndex).join(' ');
    final pid = int.tryParse(head.elementAtOrNull(pidCol) ?? '');
    if (pid == null) continue;
    processes.add(
      ProcessInfo(
        pid: pid,
        command: command,
        user: userCol < 0 || userCol >= commandIndex ? null : head[userCol],
        cpuPercent: cpuCol < 0 || cpuCol >= commandIndex
            ? null
            : double.tryParse(head[cpuCol].replaceAll(',', '.')),
        memPercent: memCol < 0 || memCol >= commandIndex
            ? null
            : double.tryParse(head[memCol].replaceAll(',', '.')),
        time: timeCol < 0 || timeCol >= commandIndex ? null : head[timeCol],
      ),
    );
  }
  return ProcessListing(
    processes: processes,
    hasCpu: cpuCol >= 0 && cpuCol < commandIndex,
    hasMem: memCol >= 0 && memCol < commandIndex,
  );
}

/// [processes] filtered by [query] — a substring of the command or user, or a
/// pid prefix — and sorted by [sort], highest first for CPU and memory.
List<ProcessInfo> sortAndFilterProcesses(
  List<ProcessInfo> processes, {
  required ProcessSort sort,
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  final result = [
    for (final process in processes)
      if (needle.isEmpty ||
          process.command.toLowerCase().contains(needle) ||
          (process.user?.toLowerCase().contains(needle) ?? false) ||
          process.pid.toString().startsWith(needle))
        process,
  ];
  int byPid(ProcessInfo a, ProcessInfo b) => a.pid.compareTo(b.pid);
  switch (sort) {
    case ProcessSort.cpu:
      result.sort((a, b) {
        final c = (b.cpuPercent ?? -1).compareTo(a.cpuPercent ?? -1);
        return c != 0 ? c : byPid(a, b);
      });
    case ProcessSort.mem:
      result.sort((a, b) {
        final c = (b.memPercent ?? -1).compareTo(a.memPercent ?? -1);
        return c != 0 ? c : byPid(a, b);
      });
    case ProcessSort.pid:
      result.sort(byPid);
  }
  return result;
}
