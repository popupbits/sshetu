import '../domain/host_os.dart';
import '../domain/process_list.dart';
import '../domain/server_sample.dart';
import '../domain/stats_parser.dart';
import 'server_exec.dart';

/// Raised when a signal could not be sent, carrying the server's own words
/// ("Operation not permitted") so the user reads the real reason.
class KillFailedException implements Exception {
  const KillFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The questions the server-info panel asks, each one exec.
class ServerInfoService {
  const ServerInfoService(this.exec);

  final ServerExec exec;

  /// One poll: every stats section in a single exec.
  Future<ServerSample> sample() async {
    final result = await exec.run('sh -s', stdin: statsScript);
    return parseStatsOutput(result.stdout);
  }

  Future<ProcessListing> processes() async {
    final result = await exec.run('sh -s', stdin: processScript);
    return parsePsOutput(result.stdout);
  }

  /// Sends [signal] to [pid]. Throws [KillFailedException] with the server's
  /// message when `kill` refuses — permission denied, no such process.
  Future<void> kill(int pid, KillSignal signal) async {
    final result = await exec.run(killCommand(pid, signal));
    if (result.succeeded) return;
    final message = [
      result.stderr.trim(),
      result.stdout.trim(),
    ].firstWhere((text) => text.isNotEmpty, orElse: () => '');
    throw KillFailedException(
      message.isEmpty ? 'kill exited with ${result.exitCode}' : message,
    );
  }

  /// Which operating system the host runs. Two execs only for a host with
  /// no `sh` at all, which is how a Windows server is recognised.
  Future<HostOsInfo> detectOs() async {
    final result = await exec.run('sh -s', stdin: osDetectScript);
    if (!osDetectionFoundNothing(result.stdout)) {
      return parseOsDetection(result.stdout);
    }
    final windows = await exec.run(windowsDetectCommand);
    return parseOsDetection(result.stdout, windowsOutput: windows.stdout);
  }
}
