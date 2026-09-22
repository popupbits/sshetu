import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/tmux_install.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/sessions/tmux_install_assistant.dart';

import '../support/tmux_probe_fixture.dart';
import '../server_info/fake_server_exec.dart';

/// The consent flow, against fakes: what runs, what is typed, what is saved
/// — and that nothing ever handles a password.
void main() {
  late FakeServerExec exec;
  late List<String> typed;
  late int nevers;
  late int snoozes;
  late int restarts;
  late String probeOutput;
  late ExecResult Function(String command) installResult;

  TmuxInstallAssistant build() {
    exec = FakeServerExec((command, _) {
      if (command == tmuxInstallProbeCommand()) {
        return ExecResult(stdout: probeOutput, exitCode: 0);
      }
      return installResult(command);
    });
    final assistant = TmuxInstallAssistant(
      exec: exec,
      typeIntoTerminal: typed.add,
      setNever: () async => nevers++,
      snooze: () => snoozes++,
      restartInTmux: () async => restarts++,
    );
    addTearDown(assistant.dispose);
    return assistant;
  }

  setUp(() {
    typed = [];
    nevers = 0;
    snoozes = 0;
    restarts = 0;
    probeOutput = probe(managers: ['apt-get'], osId: 'debian');
    installResult = (_) => const ExecResult(stdout: 'done', exitCode: 0);
  });

  List<String> installsRun() => [
    for (final call in exec.calls)
      if (call.command != tmuxInstallProbeCommand()) call.command,
  ];

  test('detecting only asks; it installs nothing', () async {
    probeOutput = probe(uid: '0', sudo: 'root', managers: ['apt-get']);
    final assistant = build();
    await assistant.detect();
    expect(exec.calls.map((c) => c.command), [tmuxInstallProbeCommand()]);
    expect(assistant.stage, isA<TmuxInstallOffered>());
    // Asked once, however often it is called.
    await assistant.detect();
    expect(exec.calls, hasLength(1));
  });

  test('root: Install runs the command shown, as is', () async {
    probeOutput = probe(uid: '0', sudo: 'root', managers: ['apt-get']);
    final assistant = build();
    await assistant.detect();
    final offer = (assistant.stage as TmuxInstallOffered).offer as RunInstall;
    expect(
      offer.command,
      'env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
    );

    await assistant.install();

    expect(installsRun(), [offer.execCommand]);
    expect(installsRun().single, isNot(contains('sudo')));
    expect(assistant.stage, isA<TmuxInstallSucceeded>());
    expect(typed, isEmpty);
  });

  test('passwordless sudo: Install runs it with sudo -n', () async {
    probeOutput = probe(sudo: 'ok', managers: ['dnf'], osId: 'fedora');
    final assistant = build();
    await assistant.detect();
    await assistant.install();

    expect(installsRun(), ["sh -c 'sudo -n dnf install -y tmux 2>&1'"]);
    expect(assistant.stage, isA<TmuxInstallSucceeded>());
  });

  test('sudo wants a password: typed into the terminal and run — never '
      'over exec, and no password anywhere', () async {
    probeOutput = probe(sudo: 'password', managers: ['apt-get']);
    final assistant = build();
    await assistant.detect();
    final offer =
        (assistant.stage as TmuxInstallOffered).offer as TypeInstallInTerminal;

    await assistant.install();

    expect(installsRun(), isEmpty, reason: 'nothing ran over exec');
    // Line cleared, the exact command shown, then Enter.
    expect(typed, ['\x15${offer.command}\r']);
    expect(
      offer.command,
      'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
    );
    expect(offer.command, isNot(contains('-S')), reason: 'no stdin password');
    expect(assistant.stage, isA<TmuxInstallTyped>());
    // Nothing was ever written to an exec channel's stdin either.
    expect(exec.calls.every((c) => c.stdin == null), isTrue);
  });

  test('Not now: remembered for the run, nothing runs', () async {
    final assistant = build();
    await assistant.detect();
    assistant.notNow();
    expect(snoozes, 1);
    expect(nevers, 0);
    expect(assistant.stage, isA<TmuxInstallDismissed>());
    await assistant.install();
    expect(installsRun(), isEmpty);
    expect(typed, isEmpty);
  });

  test('Never: saved for the host, nothing runs', () async {
    final assistant = build();
    await assistant.detect();
    await assistant.never();
    expect(nevers, 1);
    expect(snoozes, 0);
    expect(assistant.stage, isA<TmuxInstallDismissed>());
    expect(installsRun(), isEmpty);
  });

  test('a failure shows its output', () async {
    probeOutput = probe(uid: '0', sudo: 'root', managers: ['apk']);
    installResult = (_) => const ExecResult(
      stdout: 'ERROR: unable to lock database',
      exitCode: 99,
    );
    final assistant = build();
    await assistant.detect();
    await assistant.install();
    final stage = assistant.stage as TmuxInstallFailed;
    expect(stage.output, contains('unable to lock database'));
    expect(stage.retry, isNull);
  });

  test(
    'stale apt lists: update is offered, and runs only when chosen',
    () async {
      probeOutput = probe(uid: '0', sudo: 'root', managers: ['apt-get']);
      installResult = (command) => command.contains('update')
          ? const ExecResult(stdout: 'ok', exitCode: 0)
          : const ExecResult(
              stdout: 'E: Unable to locate package tmux',
              exitCode: 100,
            );
      final assistant = build();
      await assistant.detect();
      await assistant.install();

      final failed = assistant.stage as TmuxInstallFailed;
      expect(failed.retry, isNotNull);
      expect(failed.retry!.command, contains('apt-get update && '));
      expect(installsRun(), hasLength(1), reason: 'no update by itself');

      await assistant.installWithUpdate();
      expect(installsRun(), hasLength(2));
      expect(installsRun().last, failed.retry!.execCommand);
      expect(assistant.stage, isA<TmuxInstallSucceeded>());
    },
  );

  test('success offers the restart; it runs only when chosen', () async {
    probeOutput = probe(uid: '0', sudo: 'root', managers: ['apt-get']);
    final assistant = build();
    await assistant.detect();
    await assistant.install();
    expect(restarts, 0);
    await assistant.restart();
    expect(restarts, 1);
  });

  test('no known manager: an explanation, nothing to run', () async {
    probeOutput = probe(uid: '0', sudo: 'root');
    final assistant = build();
    await assistant.detect();
    final offer = (assistant.stage as TmuxInstallOffered).offer;
    expect(
      (offer as InstallUnavailable).reason,
      InstallUnavailableReason.unknownPackageManager,
    );
    await assistant.install();
    expect(installsRun(), isEmpty);
    expect(typed, isEmpty);
  });

  test('tmux present after all: straight to the restart', () async {
    probeOutput = probe(tmux: true);
    final assistant = build();
    await assistant.detect();
    expect(assistant.stage, isA<TmuxInstallSucceeded>());
  });

  test('a probe that cannot run offers nothing', () async {
    probeOutput = 'sh: not found';
    final assistant = build();
    await assistant.detect();
    expect(assistant.stage, isA<TmuxInstallDismissed>());
  });
}
