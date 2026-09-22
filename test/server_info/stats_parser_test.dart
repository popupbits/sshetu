import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/server_info/domain/sections.dart';
import 'package:sshetu/features/server_info/domain/server_sample.dart';
import 'package:sshetu/features/server_info/domain/stats_parser.dart';

import 'fixtures.dart';

void main() {
  List<FilesystemUsage> visible(ServerSample sample) => [
    for (final fs in sample.filesystems ?? const <FilesystemUsage>[])
      if (!isPseudoFilesystem(fs)) fs,
  ];

  group('sections', () {
    test('ignores a banner before the first marker and handles CRLF', () {
      final sections = splitSections(
        'motd line\r\n@@sshetu:a\r\none\r\ntwo\r\n\r\n@@sshetu:b\r\n',
      );
      expect(sections.keys, ['a', 'b']);
      expect(sections['a'], ['one', 'two']);
      expect(sections['b'], isEmpty);
    });

    test('key=value unquotes and skips comments', () {
      expect(parseKeyValues(['# c', 'A="x y"', "B='z'", 'C=plain', 'junk']), {
        'A': 'x y',
        'B': 'z',
        'C': 'plain',
      });
    });
  });

  group('Ubuntu', () {
    final sample = parseStatsOutput(ubuntuStats);

    test('identity', () {
      expect(sample.identity.hostname, 'web-1');
      expect(sample.identity.osName, 'Ubuntu 24.04.1 LTS');
      expect(sample.identity.kernelName, 'Linux');
      expect(sample.identity.kernelRelease, '6.8.0-45-generic');
      expect(sample.identity.cpuCount, 2);
    });

    test('cpu counters sum the first eight fields; idle includes iowait', () {
      expect(sample.cpu!.total, 10000 + 500 + 3000 + 80000 + 1500 + 200);
      expect(sample.cpu!.idle, 81500);
    });

    test('memory from MemAvailable, swap from SwapTotal/SwapFree', () {
      final memory = sample.memory!;
      expect(memory.totalBytes, 4015192 * 1024);
      expect(memory.availableBytes, 2007596 * 1024);
      expect(memory.usedFraction, closeTo(0.5, 0.0001));
      expect(memory.swapUsedBytes, 524288 * 1024);
    });

    test('load, process count and uptime', () {
      expect(sample.load!.one, 0.52);
      expect(sample.load!.fifteen, 0.59);
      expect(sample.processCount, 467);
      expect(sample.uptime, const Duration(seconds: 350000, milliseconds: 250));
    });

    test(
      'df keeps a mount point with a space and hides pseudo filesystems',
      () {
        expect(sample.filesystems, hasLength(8));
        final shown = visible(sample);
        expect(shown.map((fs) => fs.mountPoint), [
          '/',
          '/boot/efi',
          '/mnt/backup disk',
        ]);
        final backup = shown.last;
        expect(backup.source, '/dev/vdb1');
        expect(backup.totalBytes, 103081248 * 1024);
        expect(backup.usedFraction, closeTo(0.948, 0.001));
      },
    );

    test('network sums real interfaces, not lo, docker or veth', () {
      expect(sample.net!.rxBytes, 5000000);
      expect(sample.net!.txBytes, 2000000);
    });

    test('is not limited', () => expect(sample.isLimited, isFalse));
  });

  group('Arch under WSL2 (captured from a real sshd)', () {
    final sample = parseStatsOutput(archWslStats);

    test('every section parsed', () {
      expect(sample.identity.osName, 'Arch Linux');
      expect(sample.identity.kernelRelease, contains('WSL2'));
      expect(sample.identity.cpuCount, 32);
      expect(sample.cpu, isNotNull);
      expect(sample.memory!.totalBytes, 32724672 * 1024);
      expect(sample.memory!.swapUsedBytes, 0);
      expect(sample.load!.one, 0.33);
      expect(sample.processCount, 780);
      expect(sample.net!.rxBytes, 199943738, reason: 'eth0 only, not lo');
    });

    test('shows the disks, not WSL plumbing', () {
      expect(visible(sample).map((fs) => fs.mountPoint), [
        '/',
        '/mnt/c',
        '/mnt/f',
      ]);
      expect(visible(sample)[1].source, r'C:\');
    });
  });

  group('Alpine / busybox', () {
    final sample = parseStatsOutput(alpineStats);

    test('no MemAvailable: free + buffers + cached + reclaimable', () {
      expect(sample.memory!.availableBytes, 710000 * 1024);
      expect(sample.memory!.swapTotalBytes, 0);
    });

    test('overlay at / is the disk; container file mounts are hidden', () {
      expect(visible(sample).map((fs) => fs.mountPoint), ['/']);
    });

    test('a counter glued to the interface name still parses', () {
      expect(sample.net!.rxBytes, 4294967000);
    });

    test('single core, pretty name', () {
      expect(sample.identity.cpuCount, 1);
      expect(sample.identity.osName, 'Alpine Linux v3.20');
    });
  });

  group('macOS', () {
    final sample = parseStatsOutput(macStats);

    test('identity from uname, sw_vers and sysctl', () {
      expect(sample.identity.kernelName, 'Darwin');
      expect(sample.identity.osName, 'macOS 14.5');
      expect(sample.identity.cpuCount, 10);
      expect(sample.identity.hostname, 'Studio.local');
    });

    test('memory from hw.memsize and vm_stat pages', () {
      final memory = sample.memory!;
      expect(memory.totalBytes, 17179869184);
      expect(memory.usedBytes, (300000 + 100000 + 50000) * 16384);
      expect(memory.swapTotalBytes, 2048 * 1024 * 1024);
      expect(memory.swapFreeBytes, 1536 * 1024 * 1024);
    });

    test('load from vm.loadavg, uptime from boottime against server clock', () {
      expect(sample.load!.one, 1.52);
      expect(sample.uptime, const Duration(days: 1));
    });

    test('no CPU counters, no network', () {
      expect(sample.cpu, isNull);
      expect(sample.net, isNull);
    });

    test('hides devfs, VM, Preboot and autofs; keeps Data and a volume with '
        'a space', () {
      expect(visible(sample).map((fs) => fs.mountPoint), [
        '/',
        '/System/Volumes/Data',
        '/Volumes/My Passport',
      ]);
      expect(
        sample.filesystems!.any((fs) => fs.source == 'map auto_home'),
        isTrue,
      );
    });
  });

  group('router with no /proc/net/dev and no df', () {
    final sample = parseStatsOutput(routerStats);

    test('what there is parses; what is missing is null', () {
      expect(sample.cpu, isNotNull);
      expect(sample.identity.cpuCount, 2);
      expect(sample.memory!.availableBytes, 140000 * 1024);
      expect(sample.net, isNull);
      expect(sample.filesystems, isNull);
      expect(sample.identity.osName, isNull);
      expect(sample.isLimited, isFalse);
    });
  });

  group('nothing at all', () {
    test('a Windows server with no sh is limited, not an error', () {
      final sample = parseStatsOutput(windowsStats);
      expect(sample.isLimited, isTrue);
      expect(sample.identity.kernelName, isNull);
    });

    test('garbage does not throw', () {
      final sample = parseStatsOutput(
        '@@sshetu:stat\ncpu x y z\n@@sshetu:meminfo\nMemTotal: nope\n'
        '@@sshetu:loadavg\n1 2\n@@sshetu:uptime\n-\n@@sshetu:df\n'
        'Filesystem 1 2\n@@sshetu:netdev\nx: 1 2',
      );
      expect(sample.cpu, isNull);
      expect(sample.memory, isNull);
      expect(sample.load, isNull);
      expect(sample.uptime, isNull);
      expect(sample.filesystems, isNull);
      expect(sample.net, isNull);
    });
  });

  group('individual parsers', () {
    test('an old kernel with four cpu fields', () {
      final cpu = parseProcStatCpu(['cpu 1 2 3 4']);
      expect(cpu!.total, 10);
      expect(cpu.idle, 4);
    });

    test('df with a dash for capacity (a zero-size filesystem)', () {
      final rows = parseDf(['none 0 0 0 - /sys/fs/bpf']);
      expect(rows.single.mountPoint, '/sys/fs/bpf');
      expect(isPseudoFilesystem(rows.single), isTrue);
    });

    test('an NFS export is kept', () {
      final rows = parseDf(['nas:/export/home 1000 500 500 50% /home']);
      expect(rows.single.source, 'nas:/export/home');
      expect(isPseudoFilesystem(rows.single), isFalse);
    });
  });
}
