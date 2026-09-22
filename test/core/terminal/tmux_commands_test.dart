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

  group('tmuxSessionName', () {
    test('is stable and prefixed', () {
      expect(tmuxSessionName('abc-1'), 'sshetu-abc-1');
      expect(tmuxSessionName('abc-1'), tmuxSessionName('abc-1'));
    });

    test('replaces what tmux would read as a target separator', () {
      expect(tmuxSessionName('host.example:22 x'), 'sshetu-host_example_22_x');
      expect(tmuxSessionName("a'b;c"), 'sshetu-a_b_c');
    });
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
