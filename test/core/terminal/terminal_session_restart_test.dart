import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/reconnect_loop.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';

import '../../support/fake_shell.dart';

/// "Restart in tmux": a plain tab's shell closed and reopened inside tmux,
/// after tmux was installed.
void main() {
  TerminalSession build(FakeLauncher launcher, {bool keepOnServer = true}) {
    final session = TerminalSession(
      id: 'host-0',
      title: 'test',
      hostId: 'host',
      keepOnServer: keepOnServer,
      tmuxName: 'sshetu-dev001-aaaaaaaa',
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: () async => true,
    );
    addTearDown(session.dispose);
    return session;
  }

  test(
    'a plain shell without tmux can be restarted; one in tmux cannot',
    () async {
      final launcher = FakeLauncher()..origins = [ShellOrigin.plainWithoutTmux];
      final session = build(launcher);
      await session.start();
      expect(session.canRestartInTmux, isTrue);

      final inTmux = FakeLauncher()..origins = [ShellOrigin.tmuxCreated];
      final other = build(inTmux);
      await other.start();
      expect(other.canRestartInTmux, isFalse);
    },
  );

  test(
    'closes the plain shell, opens one in tmux, and does not reconnect',
    () async {
      final launcher = FakeLauncher()
        ..origins = [ShellOrigin.plainWithoutTmux, ShellOrigin.tmuxCreated];
      final session = build(launcher);
      await session.start();
      launcher.shells.first.emit(r'$ ');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await session.restartInTmux();

      expect(launcher.tmuxEnabled, isTrue);
      expect(launcher.opens, 2);
      expect(session.shellOrigin, ShellOrigin.tmuxCreated);
      expect(session.isLive, isTrue);
      expect(session.keepOnServer, isTrue);
      // The old shell closing was the restart, not a drop.
      await pumpEventQueue();
      expect(session.reconnect.phase, ReconnectPhase.idle);
      expect(session.status, TerminalSessionStatus.running);
      expect(
        session.terminal.buffer.getText(),
        contains('[restarted in tmux]'),
      );
      expect(session.canRestartInTmux, isFalse);
    },
  );

  test('a tab that did not want tmux can be moved into it too', () async {
    final launcher = FakeLauncher()
      ..origins = [ShellOrigin.plain, ShellOrigin.tmuxCreated];
    final session = build(launcher, keepOnServer: false);
    await session.start();
    expect(session.keepOnServer, isFalse);
    expect(session.canRestartInTmux, isTrue);

    await session.restartInTmux();
    expect(session.keepOnServer, isTrue);
    expect(session.shellOrigin, ShellOrigin.tmuxCreated);
  });

  test('still no tmux: a plain shell again, which says so', () async {
    final launcher = FakeLauncher()
      ..origins = [ShellOrigin.plainWithoutTmux, ShellOrigin.plainWithoutTmux];
    final session = build(launcher);
    await session.start();
    await session.restartInTmux();
    expect(session.shellOrigin, ShellOrigin.plainWithoutTmux);
    expect(
      'tmux is not installed'.allMatches(session.terminal.buffer.getText()),
      hasLength(2),
    );
  });
}
