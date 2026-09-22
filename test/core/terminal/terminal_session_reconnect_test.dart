import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/reconnect_loop.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';

import '../../support/fake_shell.dart';
import '../../support/fake_timers.dart';

/// A dropped session coming back by itself — and the cases where it must
/// not — driven with a fake server and a hand-cranked clock.
void main() {
  late FakeTimers timers;
  late FakeLauncher launcher;
  late int probes;
  late bool probeResult;

  TerminalSession build({String? startupCommand}) {
    final session = TerminalSession(
      id: 'host-0',
      title: 'test',
      hostId: 'host',
      startupCommand: startupCommand,
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: () async {
        probes++;
        return probeResult;
      },
      reconnectTimer: timers.create,
      clock: timers.now,
    );
    addTearDown(session.dispose);
    return session;
  }

  /// Output reaches the terminal through the coalescer's idle timer, which
  /// is a real one.
  Future<String> screen(TerminalSession session) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return session.terminal.buffer.getText();
  }

  setUp(() {
    timers = FakeTimers();
    launcher = FakeLauncher();
    probes = 0;
    probeResult = true;
  });

  test('starts, and runs the startup command in a new shell', () async {
    final session = build(startupCommand: 'cd /srv');
    await session.start();
    expect(session.status, TerminalSessionStatus.running);
    expect(launcher.shells.single.written, ['cd /srv\n']);
  });

  test(
    'drop → waiting → retry → connected, in the same tab and buffer',
    () async {
      final session = build();
      await session.start();
      final terminal = session.terminal;
      launcher.shells.single.emit('before the drop\r\n');
      expect(await screen(session), contains('before the drop'));

      launcher.shells.single.drop();
      await pumpEventQueue();
      expect(session.status, TerminalSessionStatus.closed);
      expect(session.reconnect.phase, ReconnectPhase.waiting);
      expect(session.reconnect.nextAttemptAt, isNotNull);

      timers.elapse(const Duration(milliseconds: 1500));
      await pumpEventQueue();
      expect(launcher.opens, 2);
      expect(session.status, TerminalSessionStatus.running);
      expect(session.reconnect.phase, ReconnectPhase.idle);
      expect(identical(session.terminal, terminal), isTrue);

      final text = await screen(session);
      expect(text, contains('before the drop'));
      expect(text, contains('[connection lost — reconnecting]'));
      expect(text, contains('[reconnected]'));
    },
  );

  test('keystrokes go to the new shell after a reconnect', () async {
    final session = build();
    await session.start();
    launcher.shells.single.drop();
    await pumpEventQueue();
    session.reconnect.retryNow();
    await pumpEventQueue();
    session.send('ls\r');
    expect(launcher.shells.first.written, isEmpty);
    expect(launcher.shells.last.written, ['ls\r']);
  });

  test(
    'a failed attempt goes back to waiting, with the next wait longer',
    () async {
      final session = build();
      await session.start();
      launcher.shells.single.drop();
      await pumpEventQueue();

      launcher.failWith = SshConnectionException(
        'Cannot reach example.invalid:22',
        cause: const SocketException('unreachable'),
        retryable: true,
      );
      timers.elapse(const Duration(milliseconds: 1500));
      await pumpEventQueue();
      expect(session.status, TerminalSessionStatus.closed);
      expect(session.reconnect.phase, ReconnectPhase.waiting);
      expect(session.reconnect.attemptsMade, 1);
      expect(
        session.reconnect.nextAttemptAt!.difference(timers.now()),
        const Duration(seconds: 3),
      );
    },
  );

  test('Stop leaves the tab ended, with nothing scheduled', () async {
    final session = build();
    await session.start();
    launcher.shells.single.drop();
    await pumpEventQueue();

    session.stopReconnecting();
    expect(session.reconnect.phase, ReconnectPhase.idle);
    expect(session.status, TerminalSessionStatus.closed);
    timers.elapse(const Duration(minutes: 5));
    await pumpEventQueue();
    expect(launcher.opens, 1);

    // The manual Reconnect still works.
    await session.start();
    expect(session.status, TerminalSessionStatus.running);
  });

  test('coming back to the foreground retries a waiting tab at once', () async {
    final session = build();
    await session.start();
    launcher.shells.single.drop();
    await pumpEventQueue();

    await session.nudge();
    await pumpEventQueue();
    expect(launcher.opens, 2);
    expect(session.status, TerminalSessionStatus.running);
  });

  test('a nudge probes a tab that believes it is connected', () async {
    final session = build();
    await session.start();
    await session.nudge();
    expect(probes, 1);
    expect(launcher.opens, 1);
  });

  test('a nudge does nothing to a tab the user ended', () async {
    final session = build();
    await session.start();
    await session.disconnect();
    await session.nudge();
    expect(probes, 0);
    expect(launcher.opens, 1);
  });

  test('a shell that exited cleanly says so and does not reconnect', () async {
    final session = build();
    await session.start();
    launcher.shells.single.emit('\$ exit\r\n');
    await screen(session);
    launcher.shells.single.exit();
    await pumpEventQueue();

    expect(session.status, TerminalSessionStatus.closed);
    expect(session.reconnect.phase, ReconnectPhase.idle);
    expect(timers.pending, 0);
    expect(await screen(session), contains('[session ended]'));
  });

  test('an auth failure while reconnecting stops and shows why', () async {
    final session = build();
    await session.start();
    launcher.shells.single.drop();
    await pumpEventQueue();

    launcher.failWith = SshConnectionException(
      'Authentication as me@example.invalid was rejected.',
      cause: SSHAuthFailError('denied'),
    );
    session.reconnect.retryNow();
    await pumpEventQueue();
    expect(session.status, TerminalSessionStatus.failed);
    expect(session.error, contains('rejected'));
    expect(session.reconnect.phase, ReconnectPhase.idle);
    expect(timers.pending, 0);
  });

  test('a first connection that fails does not start reconnecting', () async {
    launcher.failWith = SshConnectionException(
      'Cannot reach example.invalid:22',
      retryable: true,
    );
    final session = build();
    await session.start();
    expect(session.status, TerminalSessionStatus.failed);
    expect(session.reconnect.phase, ReconnectPhase.idle);
  });

  group('kept in tmux', () {
    test('the startup command runs when the session is created, never on '
        'reattach', () async {
      launcher.origins = [ShellOrigin.tmuxCreated, ShellOrigin.tmuxReattached];
      final session = build(startupCommand: 'htop');
      await session.start();
      expect(launcher.shells.first.written, ['htop\n']);

      launcher.shells.first.drop();
      await pumpEventQueue();
      session.reconnect.retryNow();
      await pumpEventQueue();
      expect(session.status, TerminalSessionStatus.running);
      expect(launcher.shells.last.written, isEmpty);
    });

    test('a reattach keeps what was on screen in the scrollback', () async {
      launcher.origins = [ShellOrigin.tmuxCreated, ShellOrigin.tmuxReattached];
      final session = build();
      await session.start();
      launcher.shells.first.emit('long-running job output\r\n');
      await screen(session);
      launcher.shells.first.drop();
      await pumpEventQueue();
      session.reconnect.retryNow();
      await pumpEventQueue();
      // tmux clears the screen as it attaches; simulate it.
      launcher.shells.last.emit('\x1b[H\x1b[2Jredrawn pane\r\n');
      final text = await screen(session);
      expect(text, contains('long-running job output'));
      expect(text, contains('redrawn pane'));
    });

    test('closing the tab ends the server-side session', () async {
      final session = build();
      await session.start();
      session.end();
      await pumpEventQueue();
      expect(launcher.discards, 1);
    });

    test('Disconnect ends the server-side session too', () async {
      final session = build();
      await session.start();
      await session.disconnect();
      expect(launcher.discards, 1);
      expect(session.reconnect.phase, ReconnectPhase.idle);
    });

    test('a mere drop leaves it running', () async {
      final session = build();
      await session.start();
      launcher.shells.single.drop();
      await pumpEventQueue();
      expect(launcher.discards, 0);
    });

    test('the app exiting leaves it running to be reattached', () async {
      final session = build();
      await session.start();
      session.dispose();
      await pumpEventQueue();
      expect(launcher.discards, 0);
    });

    test('a reattach replaces the buffer with tmux history, once, with no '
        'duplicates', () async {
      launcher
        ..origins = [ShellOrigin.tmuxCreated, ShellOrigin.tmuxReattached]
        ..histories = [
          // What tmux kept: the whole burst, including what it never drew
          // here, and what ran while the link was down.
          '${List.generate(300, (i) => '${i + 1}').join('\n')}'
              '\nwhile you were away\n\n',
        ];
      final session = build();
      await session.start();
      // What the app saw: only the burst's last screen.
      launcher.shells.first.emit('298\r\n299\r\n300\r\n');
      await screen(session);
      launcher.shells.first.drop();
      await pumpEventQueue();
      session.reconnect.retryNow();
      await pumpEventQueue();

      final lines = (await screen(session))
          .split('\n')
          .map((l) => l.trim())
          .toList();
      expect(lines, contains('1'));
      expect(lines, contains('while you were away'));
      expect(lines.where((l) => l == '300'), hasLength(1));
      expect(lines, contains('[reconnected]'));
    });

    test('an empty history on a fresh tab leaves the buffer alone', () async {
      launcher
        ..origins = [ShellOrigin.tmuxReattached]
        ..histories = ['\n'];
      final session = build();
      session.terminal.write('kept\r\n');
      await session.start();
      expect(await screen(session), contains('kept'));
    });

    test(
      'a server without tmux gets one dim notice, not one per reconnect',
      () async {
        launcher.origins = [
          ShellOrigin.plainWithoutTmux,
          ShellOrigin.plainWithoutTmux,
        ];
        final session = build();
        await session.start();
        launcher.shells.first.emit('prompt\$ ');
        await screen(session);
        launcher.shells.first.drop();
        await pumpEventQueue();
        session.reconnect.retryNow();
        await pumpEventQueue();
        final text = await screen(session);
        expect('tmux is not installed'.allMatches(text), hasLength(1));
      },
    );
  });
}
