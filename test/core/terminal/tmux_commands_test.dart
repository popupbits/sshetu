import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/tmux_commands.dart';

/// The commands that keep a tab alive in tmux. They run on someone's server
/// under their account, so what they say is pinned exactly.
void main() {
  group('shellQuote', () {
    test('wraps in single quotes and escapes embedded ones', () {
      expect(shellQuote('plain'), "'plain'");
      expect(shellQuote("it's"), r"'it'\''s'");
      expect(shellQuote(''), "''");
    });

    test('leaves nothing for sh to expand', () {
      const nasty = r"""a b;$(rm -rf ~)`id`$HOME"'\
&& echo pwned""";
      final quoted = shellQuote(nasty);
      // Every character outside the quoting is part of an escaped quote.
      final outside = quoted
          .replaceAll(r"'\''", '')
          .replaceAll(RegExp("'[^']*'"), '');
      expect(outside, isEmpty);
    });

    final sh = _findSh();
    test('round-trips through a real sh', () async {
      for (final value in [
        "it's",
        r'$HOME `id` $(whoami)',
        'two\nlines',
        r'back\slash',
        '"double"',
        '*?[glob]',
      ]) {
        final result = await Process.run(sh!, [
          '-c',
          'printf %s ${shellQuote(value)}',
        ]);
        expect(result.stdout, value, reason: value);
      }
    }, skip: sh == null ? 'no sh on this machine' : null);
  });

  group('probe', () {
    test('runs under sh and uses the private socket with an exact target', () {
      final command = tmuxProbeCommand('sshetu-h-1');
      expect(command, startsWith("sh -c '"));
      expect(command, contains('command -v tmux'));
      expect(command, contains('tmux -L sshetu has-session'));
      // The `=` is what stops `sshetu-h-1` matching `sshetu-h-12`.
      expect(command, contains(r"-t '\''=sshetu-h-1'\''"));
    });

    test('is parsed from its marker line', () {
      expect(parseTmuxProbe('SSHETU:tmux-new\n'), TmuxProbe.willCreate);
      expect(
        parseTmuxProbe('Welcome to Ubuntu\nSSHETU:tmux-existing\n'),
        TmuxProbe.willReattach,
      );
      expect(parseTmuxProbe('SSHETU:tmux-absent\n'), TmuxProbe.unavailable);
    });

    test('anything unrecognised means no tmux', () {
      expect(parseTmuxProbe(''), TmuxProbe.unavailable);
      expect(parseTmuxProbe('% Invalid input detected'), TmuxProbe.unavailable);
    });
  });

  group('attach', () {
    final command = tmuxAttachCommand('sshetu-h-1', columns: 120, rows: 40);

    test('is one line, so csh accepts it as well as sh', () {
      expect(command, isNot(contains('\n')));
      expect(command, startsWith("sh -c '"));
    });

    test('creates detached at the tab size, then attaches exactly', () {
      expect(command, contains('new-session -d'));
      expect(command, contains('-x 120 -y 40'));
      expect(command, contains('attach-session -t'));
      expect(command, contains('=sshetu-h-1'));
    });

    test('uses its own tmux server, never the user default one', () {
      final invocations = RegExp(r'tmux (?!-)').allMatches(command);
      expect(invocations, isEmpty, reason: 'every tmux call names a socket');
      expect(command, contains('-L sshetu'));
    });

    test('clears TMUX so a tmux inside still starts', () {
      expect(command, contains('unset TMUX TMUX_PANE'));
    });

    test('forces UTF-8, whatever the locale the exec channel has', () {
      expect(command, contains('tmux -u -L sshetu -f'));
      expect(command, contains('tmux -u -L sshetu attach-session'));
    });

    test('falls back to a login shell if the session cannot be found', () {
      expect(command, endsWith(r'''exec "${SHELL:-/bin/sh}" -l' '''.trim()));
    });

    test('never falls back to a guessable path in /tmp', () {
      expect(command, isNot(contains('/tmp/')));
      expect(command, contains('mktemp'));
    });

    test('degenerate sizes become 80×24', () {
      expect(
        tmuxAttachCommand('n', columns: 0, rows: -1),
        contains('-x 80 -y 24'),
      );
    });
  });

  group('server options', () {
    test('hide tmux: no status line, no prefix, no Esc delay', () {
      expect(kTmuxServerOptions, contains('set -g status off'));
      expect(kTmuxServerOptions, contains('set -g prefix None'));
      expect(kTmuxServerOptions, contains('set -g prefix2 None'));
      expect(kTmuxServerOptions, contains('set -g escape-time 0'));
    });

    test('keep output in the app scrollback', () {
      expect(
        kTmuxServerOptions.any((o) => o.contains('smcup@:rmcup@')),
        isTrue,
      );
    });
  });

  test('history reads the scrollback above the screen, joined, coloured', () {
    final command = tmuxHistoryCommand('sshetu-h-1');
    expect(command, contains('tmux -L sshetu capture-pane -p -e -J'));
    expect(command, contains('-S -$kTmuxHistoryLines -E -1'));
    // A pane target: the exact session, then its current window and pane.
    expect(command, contains(r"-t '\''=sshetu-h-1:'\''"));
  });

  test('tmux keeps as much history as a tab does', () {
    expect(
      kTmuxServerOptions,
      contains('set -g history-limit $kTmuxHistoryLines'),
    );
  });

  test('kill targets exactly this session and never fails', () {
    final command = tmuxKillCommand('sshetu-h-1');
    expect(command, contains('tmux -L sshetu kill-session'));
    expect(command, contains('=sshetu-h-1'));
    expect(command, contains('; true'));
  });
  group('environment', () {
    test('names are checked, values quoted', () {
      expect(
        envExports({'EDITOR': 'vim', 'GREETING': "it's \$HOME"}),
        r"export EDITOR='vim'; export GREETING='it'\''s $HOME'; ",
      );
      expect(envExports(const {}), '');
    });

    test('a name that is not an identifier is refused, not escaped', () {
      for (final bad in ['1ABC', 'A-B', 'A B', r'$(id)', 'A=B', '']) {
        expect(isValidEnvName(bad), isFalse, reason: bad);
        expect(() => envExports({bad: 'x'}), throwsArgumentError);
      }
      for (final good in ['A', '_', 'a_1', 'PATH', '_X9']) {
        expect(isValidEnvName(good), isTrue, reason: good);
      }
    });

    test('without variables, attach is exactly what it was', () {
      final plain = tmuxAttachCommand('n', columns: 80, rows: 24);
      expect(plain, contains('-y 24 2>/dev/null'));
      expect(plain, isNot(contains('export')));
    });

    test('a new session runs the login shell with the exports in front', () {
      final command = tmuxAttachCommand(
        'n',
        columns: 80,
        rows: 24,
        env: {'FOO': 'a b'},
      );
      expect(command, isNot(contains('\n')));
      // Not `-e`, which tmux before 3.2 does not have.
      expect(command, isNot(contains(' -e ')));
      expect(command, contains('export FOO='));
      // The fallback shell gets them too.
      expect(command, contains('exec "\${SHELL:-/bin/sh}" -l'));
      expect('export FOO='.allMatches(command), hasLength(2));
    });

    test('a plain shell is an exec of the login shell', () {
      final command = plainShellCommand({'FOO': 'bar'});
      expect(command, startsWith("sh -c '"));
      expect(command, contains('exec "\${SHELL:-/bin/sh}" -l'));
    });

    final sh = _findSh();
    const tricky = {
      'SPACES': 'two  words',
      'QUOTES': 'it\'s "quoted"',
      'DOLLAR': r'$HOME $(id) `id` \n',
      'EMPTY': '',
    };

    test('values arrive exactly as typed, through a real sh', () async {
      final script = [
        envExports(tricky),
        for (final name in tricky.keys) 'printf "%s|" "\$$name";',
      ].join();
      final result = await Process.run(sh!, ['-c', script]);
      expect(result.stdout, '${tricky.values.join('|')}|');
    }, skip: sh == null ? 'no sh on this machine' : null);

    test('the plain shell command hands them to the login shell', () async {
      final dir = Directory.systemTemp.createTempSync('sshetu-env');
      addTearDown(() => dir.deleteSync(recursive: true));
      // Stands in for the user's shell: prints what it was given.
      final fake = File('${dir.path}/fakeshell')
        ..writeAsStringSync(
          '#!/bin/sh\nprintf "%s|" "\$1" "\$SPACES" "\$QUOTES" "\$DOLLAR"\n',
        );
      await Process.run(sh!, ['-c', 'chmod +x "\$0"', fake.path]);
      // The command as the server's login shell would run it: `sh -c '…'`
      // is itself a command line, so it goes through one more sh.
      //
      // PATH first, because Git's sh on Windows starts without its own
      // /usr/bin on it and the inner `sh` would not be found.
      final result = await Process.run(
        sh,
        [
          '-c',
          'PATH="/usr/bin:/bin:\$PATH"; export PATH; '
              '${plainShellCommand(tricky)}',
        ],
        environment: {'SHELL': fake.path.replaceAll(r'\', '/')},
      );
      expect(
        result.stdout,
        '-l|${tricky['SPACES']}|${tricky['QUOTES']}|${tricky['DOLLAR']}|',
        reason: '${result.stderr}',
      );
    }, skip: sh == null ? 'no sh on this machine' : null);
  });

  group('listing', () {
    test('runs under sh on the private socket', () {
      final command = tmuxListCommand();
      expect(command, startsWith("sh -c '"));
      expect(command, contains('tmux -L sshetu list-sessions -F'));
      expect(command, contains('#{session_name}'));
      expect(command, contains('#{session_attached}'));
      expect(command, contains('#{session_activity}'));
    });

    test('parses tmux -F output, newest activity first', () {
      final listing = parseTmuxListing(
        'Welcome!\n'
        'SSHETU:tmux-list\n'
        'sshetu-abc123-k3j9x0qa|1767225600|0|1767225900|1|bash\n'
        'sshetu-zzz999-00000000|1767225000|2|1767229200|1|vim\n'
        'sshetu-h1-0|1767220000|0||1|\n'
        'mine|1767225600|0|1767225600|1|zsh\n'
        'garbage line\n',
      );
      expect(listing.tmuxAvailable, isTrue);
      expect(listing.sessions.map((s) => s.name), [
        'sshetu-zzz999-00000000',
        'sshetu-abc123-k3j9x0qa',
        'sshetu-h1-0',
      ]);
      final vim = listing.sessions.first;
      expect(vim.attachedClients, 2);
      expect(vim.isAttached, isTrue);
      expect(vim.command, 'vim');
      expect(vim.created, DateTime.utc(2025, 12, 31, 23, 50));
      expect(vim.lastActivity, DateTime.utc(2026, 1, 1, 1));
      final old = listing.sessions.last;
      expect(old.lastActivity, isNull);
      expect(old.command, isNull);
      expect(old.isAttached, isFalse);
    });

    test('a | in the command does not shift the fields', () {
      final listing = parseTmuxListing(
        'SSHETU:tmux-list\nsshetu-abc123-k3j9x0qa|1|1|2|1|a|b\n',
      );
      expect(listing.sessions.single.command, 'a|b');
      expect(listing.sessions.single.attachedClients, 1);
    });

    test('no tmux, and no server running, are told apart', () {
      expect(parseTmuxListing('SSHETU:tmux-absent\n').tmuxAvailable, isFalse);
      final none = parseTmuxListing('SSHETU:tmux-list\n');
      expect(none.tmuxAvailable, isTrue);
      expect(none.sessions, isEmpty);
    });
  });
}

String? _findSh() {
  for (final candidate in ['sh', r'C:\Program Files\Git\usr\bin\sh.exe']) {
    try {
      final result = Process.runSync(candidate, ['-c', 'printf ok']);
      if (result.exitCode == 0 && result.stdout == 'ok') return candidate;
    } on Object {
      // Not here; try the next.
    }
  }
  return null;
}
