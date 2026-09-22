import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/server_info/domain/process_list.dart';

import 'fixtures.dart';

void main() {
  group('parsePsOutput', () {
    test('procps: every column, a command with a space', () {
      final listing = parsePsOutput(psProcps);
      expect(listing.hasCpu, isTrue);
      expect(listing.hasMem, isTrue);
      expect(listing.processes, hasLength(4));
      final nginx = listing.processes.first;
      expect(nginx.pid, 1234);
      expect(nginx.user, 'www-data');
      expect(nginx.cpuPercent, 12.5);
      expect(nginx.memPercent, 3.2);
      expect(nginx.time, '02:13:44');
      expect(nginx.command, 'nginx');
      expect(listing.processes.last.command, 'kworker/0:1 H');
    });

    test('macOS: a path with spaces, decimal commas', () {
      final listing = parsePsOutput(psMac);
      expect(
        listing.processes.first.command,
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      );
      expect(listing.processes.last.cpuPercent, 1.5);
      expect(listing.processes.last.memPercent, 0.2);
    });

    test('busybox: no CPU or memory columns, TIME kept', () {
      final listing = parsePsOutput(psBusybox);
      expect(listing.hasCpu, isFalse);
      expect(listing.hasMem, isFalse);
      expect(listing.processes.map((p) => p.pid), [1, 512, 777]);
      expect(listing.processes[1].command, 'dropbear -p 22');
      expect(listing.processes[1].user, 'admin');
      expect(listing.processes[2].time, '1:20');
      expect(listing.processes.first.cpuPercent, isNull);
    });

    test('empty or headerless output is an empty listing', () {
      expect(parsePsOutput('').processes, isEmpty);
      expect(parsePsOutput('@@sshetu:ps\n').processes, isEmpty);
      expect(parsePsOutput('ps: command not found').processes, isEmpty);
    });
  });

  group('sortAndFilterProcesses', () {
    final processes = parsePsOutput(psProcps).processes;

    test('by CPU, highest first', () {
      expect(
        sortAndFilterProcesses(
          processes,
          sort: ProcessSort.cpu,
        ).map((p) => p.pid),
        [1234, 987, 2345, 1],
      );
    });

    test('by memory, highest first', () {
      expect(
        sortAndFilterProcesses(
          processes,
          sort: ProcessSort.mem,
        ).map((p) => p.pid),
        [987, 1234, 1, 2345],
      );
    });

    test('by pid', () {
      expect(
        sortAndFilterProcesses(
          processes,
          sort: ProcessSort.pid,
        ).map((p) => p.pid),
        [1, 987, 1234, 2345],
      );
    });

    test('filter matches command, user or pid prefix, case-insensitively', () {
      List<int> find(String q) => sortAndFilterProcesses(
        processes,
        sort: ProcessSort.pid,
        query: q,
      ).map((p) => p.pid).toList();
      expect(find('NGINX'), [1234]);
      expect(find('postgres'), [987]);
      expect(find('ubuntu'), [2345]);
      expect(find('98'), [987]);
      expect(find('  '), [1, 987, 1234, 2345]);
      expect(find('nothing'), isEmpty);
    });
  });

  group('killCommand', () {
    test('numeric signals, no sudo', () {
      expect(killCommand(1234, KillSignal.term), 'kill -15 1234');
      expect(killCommand(1234, KillSignal.kill), 'kill -9 1234');
    });

    test('refuses pid 0 and negatives — they signal process groups', () {
      expect(() => killCommand(0, KillSignal.term), throwsArgumentError);
      expect(() => killCommand(-1, KillSignal.kill), throwsArgumentError);
    });
  });
}
