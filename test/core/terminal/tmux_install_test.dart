import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/tmux_install.dart';

import '../../support/tmux_probe_fixture.dart';

void main() {
  group('the probe command', () {
    final command = tmuxInstallProbeCommand();

    test('runs under sh, whatever the login shell', () {
      expect(command, startsWith("sh -c '"));
    });

    test('asks for every manager, os-release, id -u and sudo -n', () {
      for (final manager in PackageManager.values) {
        expect(command, contains(manager.executable));
      }
      expect(command, contains('/etc/os-release'));
      expect(command, contains('id -u'));
      expect(command, contains('uname -s'));
      // -n: sudo fails instead of prompting. stdin closed besides.
      expect(command, contains('sudo -n true </dev/null'));
    });

    test('never installs, updates or runs sudo without -n', () {
      for (final manager in PackageManager.values) {
        expect(command, isNot(contains(tmuxInstallWords(manager).join(' '))));
      }
      expect(command, isNot(contains('update')));
      // `command -v sudo` and the answer's marker are not invocations; every
      // other mention runs sudo, and must carry -n.
      final invocations = command
          .replaceAll('command -v sudo', '')
          .replaceAll(TmuxInstallMarkers.sudo, '');
      expect(RegExp(r'sudo(?! -n )').hasMatch(invocations), isFalse);
      expect('sudo -n '.allMatches(invocations), hasLength(1));
    });
  });

  group('parsing the probe', () {
    test('no marker — no sh, a router — is no answer', () {
      expect(parseTmuxInstallProbe(''), isNull);
      expect(parseTmuxInstallProbe('% Invalid input detected'), isNull);
    });

    test('Debian: apt-get, os-release, needs a password', () {
      final facts = parseTmuxInstallProbe(
        probe(managers: ['apt-get'], osId: 'debian'),
      )!;
      expect(facts.managers, [PackageManager.aptGet]);
      expect(facts.osId, 'debian');
      expect(facts.uid, 1000);
      expect(facts.access, RootAccess.sudoNeedsPassword);
      expect(facts.tmuxPresent, isFalse);
    });

    test('quoted os-release values and ID_LIKE words', () {
      final facts = parseTmuxInstallProbe(
        probe(
          managers: ['apt-get'],
          osId: '"linuxmint"',
          osLike: '"ubuntu debian"',
        ),
      )!;
      expect(facts.osId, 'linuxmint');
      expect(facts.osLike, ['ubuntu', 'debian']);
    });

    test('single-quoted and bare values', () {
      final facts = parseTmuxInstallProbe(
        probe(managers: ['dnf'], osId: "'rocky'", osLike: 'rhel centos fedora'),
      )!;
      expect(facts.osId, 'rocky');
      expect(facts.osLike, ['rhel', 'centos', 'fedora']);
    });

    test('id -u 0 is root, whatever else is said', () {
      final facts = parseTmuxInstallProbe(probe(uid: '0', sudo: 'root'))!;
      expect(facts.access, RootAccess.root);
      expect(facts.isRoot, isTrue);
    });

    test('non-zero uid with sudo -n true succeeding is passwordless', () {
      final facts = parseTmuxInstallProbe(probe(uid: '1000', sudo: 'ok'))!;
      expect(facts.access, RootAccess.passwordlessSudo);
      expect(facts.isRoot, isFalse);
    });

    test('non-zero uid with sudo -n true failing needs a password', () {
      final facts = parseTmuxInstallProbe(probe(sudo: 'password'))!;
      expect(facts.access, RootAccess.sudoNeedsPassword);
    });

    test('no sudo at all', () {
      final facts = parseTmuxInstallProbe(probe(sudo: 'absent'))!;
      expect(facts.access, RootAccess.none);
    });

    test('tmux there after all', () {
      expect(parseTmuxInstallProbe(probe(tmux: true))!.tmuxPresent, isTrue);
    });

    test('managers come back in a fixed order; unknown names are ignored', () {
      final facts = parseTmuxInstallProbe(
        probe(managers: ['brew', 'snap', 'apt-get', 'dnf']),
      )!;
      expect(facts.managers, [
        PackageManager.aptGet,
        PackageManager.dnf,
        PackageManager.brew,
      ]);
    });
  });

  group('choosing a package manager', () {
    ServerInstallFacts facts({
      List<PackageManager> managers = const [],
      String? osId,
      List<String> osLike = const [],
      String? kernel = 'Linux',
    }) => ServerInstallFacts(
      managers: managers,
      access: RootAccess.root,
      osId: osId,
      osLike: osLike,
      kernel: kernel,
    );

    final fixtures = <String, (ServerInstallFacts, PackageManager?)>{
      'Debian': (
        facts(managers: [PackageManager.aptGet], osId: 'debian'),
        PackageManager.aptGet,
      ),
      'Ubuntu with Homebrew on the side': (
        facts(
          managers: [PackageManager.aptGet, PackageManager.brew],
          osId: 'ubuntu',
        ),
        PackageManager.aptGet,
      ),
      'Fedora': (
        facts(
          managers: [PackageManager.dnf, PackageManager.yum],
          osId: 'fedora',
        ),
        PackageManager.dnf,
      ),
      'CentOS 7 (yum only)': (
        facts(managers: [PackageManager.yum], osId: 'centos'),
        PackageManager.yum,
      ),
      'Rocky, by ID_LIKE': (
        facts(
          managers: [PackageManager.dnf],
          osId: 'rocky-custom',
          osLike: ['rhel', 'centos', 'fedora'],
        ),
        PackageManager.dnf,
      ),
      'Arch': (
        facts(managers: [PackageManager.pacman], osId: 'arch'),
        PackageManager.pacman,
      ),
      'Alpine': (
        facts(managers: [PackageManager.apk], osId: 'alpine'),
        PackageManager.apk,
      ),
      'openSUSE Leap': (
        facts(managers: [PackageManager.zypper], osId: 'opensuse-leap'),
        PackageManager.zypper,
      ),
      'FreeBSD, by kernel': (
        facts(managers: [PackageManager.pkg], kernel: 'FreeBSD'),
        PackageManager.pkg,
      ),
      'macOS': (
        facts(managers: [PackageManager.brew], kernel: 'Darwin'),
        PackageManager.brew,
      ),
      'no os-release: the first one present': (
        facts(managers: [PackageManager.apk]),
        PackageManager.apk,
      ),
      'the distribution names one that is missing': (
        facts(managers: [PackageManager.pacman], osId: 'debian'),
        PackageManager.pacman,
      ),
      'none known': (facts(), null),
    };
    for (final MapEntry(key: name, value: (input, expected))
        in fixtures.entries) {
      test(name, () => expect(choosePackageManager(input), expected));
    }
  });

  group('the install command', () {
    const expected = {
      PackageManager.aptGet:
          'env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
      PackageManager.dnf: 'dnf install -y tmux',
      PackageManager.yum: 'yum install -y tmux',
      PackageManager.pacman: 'pacman -S --noconfirm tmux',
      PackageManager.apk: 'apk add tmux',
      PackageManager.zypper: 'zypper -n install tmux',
      PackageManager.brew: 'brew install tmux',
      PackageManager.pkg: 'pkg install -y tmux',
    };
    for (final MapEntry(key: manager, value: command) in expected.entries) {
      test(manager.executable, () {
        expect(
          renderInstallCommand([tmuxInstallWords(manager)], Elevation.none),
          command,
        );
      });
    }

    test('sudo -n for an exec channel, plain sudo for the terminal', () {
      final words = [tmuxInstallWords(PackageManager.dnf)];
      expect(
        renderInstallCommand(words, Elevation.sudoNonInteractive),
        'sudo -n dnf install -y tmux',
      );
      expect(
        renderInstallCommand(words, Elevation.sudoInTerminal),
        'sudo dnf install -y tmux',
      );
    });

    test('update and install: each step elevated, joined with &&', () {
      const offer = RunInstall(
        manager: PackageManager.aptGet,
        elevation: Elevation.sudoNonInteractive,
        withUpdate: true,
      );
      expect(
        offer.command,
        'sudo -n env DEBIAN_FRONTEND=noninteractive apt-get update && '
        'sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
      );
    });

    test('over exec: under sh, with stderr folded in', () {
      const offer = RunInstall(
        manager: PackageManager.apk,
        elevation: Elevation.none,
      );
      expect(offer.execCommand, "sh -c 'apk add tmux 2>&1'");
    });

    test('a word that is not plain is quoted', () {
      expect(shellWord('tmux'), 'tmux');
      expect(shellWord('--noconfirm'), '--noconfirm');
      expect(shellWord('a b'), "'a b'");
      expect(shellWord(r"it's $HOME"), r"'it'\''s $HOME'");
    });

    test('stale apt lists are recognised; other failures are not', () {
      expect(
        needsPackageListUpdate(
          PackageManager.aptGet,
          'E: Unable to locate package tmux',
        ),
        isTrue,
      );
      expect(
        needsPackageListUpdate(
          PackageManager.aptGet,
          'E: Package tmux has no installation candidate',
        ),
        isTrue,
      );
      expect(
        needsPackageListUpdate(
          PackageManager.aptGet,
          'E: Could not open lock file',
        ),
        isFalse,
      );
      expect(
        needsPackageListUpdate(
          PackageManager.dnf,
          'Unable to locate package tmux',
        ),
        isFalse,
      );
    });
  });

  group('what to offer', () {
    ServerInstallFacts facts(
      RootAccess access, {
      List<PackageManager> managers = const [PackageManager.aptGet],
      bool tmux = false,
    }) => ServerInstallFacts(
      managers: managers,
      access: access,
      osId: 'debian',
      tmuxPresent: tmux,
    );

    test('root: run it as is', () {
      final offer = planTmuxInstall(facts(RootAccess.root));
      expect(offer, isA<RunInstall>());
      expect(
        (offer as RunInstall).command,
        'env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
      );
    });

    test('passwordless sudo: run it with sudo -n', () {
      final offer = planTmuxInstall(facts(RootAccess.passwordlessSudo));
      expect((offer as RunInstall).command, startsWith('sudo -n '));
    });

    test('sudo wants a password: type it into the terminal', () {
      final offer = planTmuxInstall(facts(RootAccess.sudoNeedsPassword));
      expect(offer, isA<TypeInstallInTerminal>());
      expect(
        (offer as TypeInstallInTerminal).command,
        'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
      );
    });

    test('no root and no sudo: nothing to run', () {
      final offer = planTmuxInstall(facts(RootAccess.none));
      expect(
        (offer as InstallUnavailable).reason,
        InstallUnavailableReason.noPrivilege,
      );
    });

    test('no known package manager: nothing to run', () {
      final offer = planTmuxInstall(facts(RootAccess.root, managers: const []));
      expect(
        (offer as InstallUnavailable).reason,
        InstallUnavailableReason.unknownPackageManager,
      );
    });

    test('Homebrew never gets sudo, even without root', () {
      final offer = planTmuxInstall(
        facts(RootAccess.none, managers: const [PackageManager.brew]),
      );
      expect((offer as RunInstall).command, 'brew install tmux');
    });

    test('tmux present after all: nothing to install', () {
      expect(
        planTmuxInstall(facts(RootAccess.none, tmux: true)),
        isA<TmuxAlreadyPresent>(),
      );
    });
  });
}
