import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';

import '../../support/fake_shell.dart';

/// A tab opened to pick up a session kept on the server — reopened at launch
/// or attached from the server's list.
void main() {
  TerminalSession build(
    FakeLauncher launcher, {
    bool resuming = true,
    String? startupCommand,
  }) {
    final session = TerminalSession(
      id: 'host-0',
      title: 'test',
      hostId: 'host',
      keepOnServer: true,
      tmuxName: 'sshetu-dev001-aaaaaaaa',
      resuming: resuming,
      startupCommand: startupCommand,
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

  String screen(TerminalSession session) => session.terminal.buffer.getText();

  test('the name it was given is the one it keeps', () {
    final session = build(FakeLauncher());
    expect(session.tmuxName, 'sshetu-dev001-aaaaaaaa');
  });

  test('reattached: no notice, and the startup command does not run', () async {
    final launcher = FakeLauncher()..origins = [ShellOrigin.tmuxReattached];
    final session = build(launcher, startupCommand: 'make watch');
    await session.start();

    expect(session.resumeFailed, isFalse);
    expect(screen(session), isNot(contains('has ended')));
    expect(launcher.shells.single.written, isEmpty);
  });

  test('gone on the server: a new shell that says so', () async {
    final launcher = FakeLauncher()..origins = [ShellOrigin.tmuxCreated];
    final session = build(launcher, startupCommand: 'make watch');
    await session.start();

    expect(session.resumeFailed, isTrue);
    expect(
      screen(session),
      contains('the session kept on the server has ended'),
    );
    // A new shell is a new shell: what it would have run, it runs.
    expect(launcher.shells.single.written, ['make watch\n']);
  });

  test('an ordinary new tab says nothing', () async {
    final launcher = FakeLauncher()..origins = [ShellOrigin.tmuxCreated];
    final session = build(launcher, resuming: false);
    await session.start();
    expect(session.resumeFailed, isFalse);
    expect(screen(session), isNot(contains('has ended')));
  });
}
