import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/server_info/domain/host_os.dart';
import 'package:sshetu/features/server_info/host_os_controller.dart';

import 'fake_server_exec.dart';
import 'fixtures.dart';

void main() {
  group('parseOsDetection', () {
    test('ID picks the family, PRETTY_NAME the label', () {
      final info = parseOsDetection(osUbuntu);
      expect(info.family, OsFamily.ubuntu);
      expect(info.prettyName, 'Ubuntu 24.04.1 LTS');
    });

    test('an unknown ID falls back to ID_LIKE, in order', () {
      expect(parseOsDetection(osMint).family, OsFamily.ubuntu);
      expect(parseOsDetection(osRocky).family, OsFamily.rhel);
    });

    test('an unrecognised distribution is generic Linux, keeping its name', () {
      final info = parseOsDetection(osUnknownDistro);
      expect(info.family, OsFamily.linux);
      expect(info.prettyName, 'Obscure OS 1.0');
    });

    test('no os-release: uname decides', () {
      expect(parseOsDetection(osRouter).family, OsFamily.linux);
      final mac = parseOsDetection(osMac);
      expect(mac.family, OsFamily.macos);
      expect(mac.prettyName, 'macOS 14.5');
      expect(parseOsDetection(osFreeBsd).family, OsFamily.freebsd);
    });

    test('nothing from sh, but cmd answered: Windows', () {
      expect(osDetectionFoundNothing(''), isTrue);
      expect(osDetectionFoundNothing(osRouter), isFalse);
      final info = parseOsDetection('', windowsOutput: windowsVer);
      expect(info.family, OsFamily.windows);
      expect(info.prettyName, 'Microsoft Windows [Version 10.0.22631.4169]');
    });

    test('nothing at all is unknown', () {
      expect(parseOsDetection('').family, OsFamily.unknown);
      expect(
        parseOsDetection('', windowsOutput: 'not recognized').family,
        OsFamily.unknown,
      );
    });

    test('json round trip; junk reads as null', () {
      const info = HostOsInfo(family: OsFamily.arch, prettyName: 'Arch Linux');
      expect(HostOsInfo.fromJson(info.toJson()), info);
      expect(HostOsInfo.fromJson({'family': 'beos'}), isNull);
      expect(HostOsInfo.fromJson('x'), isNull);
    });
  });

  group('HostOsController', () {
    late SharedPreferences preferences;

    Future<ProviderContainer> container() async {
      preferences = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'detects over exec, caches in preferences, asks once per run',
      () async {
        SharedPreferences.setMockInitialValues({});
        final c = await container();
        final exec = FakeServerExec(
          (command, stdin) => const ExecResult(stdout: osUbuntu, exitCode: 0),
        );
        await c.read(hostOsProvider.notifier).detect('h1', exec);
        await c.read(hostOsProvider.notifier).detect('h1', exec);

        expect(exec.calls, hasLength(1));
        expect(exec.calls.single.command, 'sh -s');
        expect(c.read(hostOsProvider)['h1']?.family, OsFamily.ubuntu);
        expect(
          preferences.getString('${HostOsController.keyPrefix}h1'),
          contains('ubuntu'),
        );

        // A new run reads the cache back without asking.
        final fresh = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        );
        addTearDown(fresh.dispose);
        expect(
          fresh.read(hostOsProvider)['h1']?.prettyName,
          'Ubuntu 24.04.1 LTS',
        );
      },
    );

    test('asks cmd /c ver only when sh gave nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await container();
      final exec = FakeServerExec(
        (command, stdin) => ExecResult(
          stdout: command == windowsDetectCommand ? windowsVer : '',
          exitCode: command == windowsDetectCommand ? 0 : 1,
        ),
      );
      await c.read(hostOsProvider.notifier).detect('w', exec);
      expect(exec.calls.map((c) => c.command), ['sh -s', 'cmd /c ver']);
      expect(c.read(hostOsProvider)['w']?.family, OsFamily.windows);
    });

    test('unknown never overwrites a known answer', () async {
      SharedPreferences.setMockInitialValues({
        '${HostOsController.keyPrefix}h': '{"family":"debian"}',
      });
      final c = await container();
      await c
          .read(hostOsProvider.notifier)
          .detect('h', FakeServerExec((_, _) => const ExecResult(stdout: '')));
      expect(c.read(hostOsProvider)['h']?.family, OsFamily.debian);
    });

    test(
      'offline does not count as asked; a corrupt entry is skipped',
      () async {
        SharedPreferences.setMockInitialValues({
          '${HostOsController.keyPrefix}bad': '{not json',
        });
        final c = await container();
        expect(c.read(hostOsProvider), isEmpty);
        final exec = FakeServerExec(
          (_, _) => const ExecResult(stdout: osUbuntu),
          connected: false,
        );
        await c.read(hostOsProvider.notifier).detect('h', exec);
        expect(c.read(hostOsProvider), isEmpty);
        exec.connected = true;
        await c.read(hostOsProvider.notifier).detect('h', exec);
        expect(c.read(hostOsProvider)['h']?.family, OsFamily.ubuntu);
      },
    );

    test('works without preferences at all', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(hostOsProvider), isEmpty);
      await c
          .read(hostOsProvider.notifier)
          .remember('x', const HostOsInfo(family: OsFamily.alpine));
      expect(c.read(hostOsProvider)['x']?.family, OsFamily.alpine);
    });
  });
}
