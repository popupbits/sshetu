/// The commands that keep a terminal tab running on the server inside tmux.
///
/// Pure string construction, kept apart from the code that runs it for the
/// same reason `KeySetupScripts` is: these go to someone's server and run
/// under their account, and the one thing worth reviewing is exactly what
/// they say.
///
/// **A private tmux server.** Every command uses its own socket
/// (`tmux -L sshetu`) instead of the user's default one. That single choice
/// scopes everything that follows: the status bar is off, the prefix key is
/// disabled and the alternate screen is suppressed *on that server only*.
/// The user's own `~/.tmux.conf` is never read by it and never rewritten,
/// `tmux ls` still shows only the user's own sessions, and a tmux they start
/// themselves inside one of these tabs is an ordinary, fully-working tmux.
library;

/// The socket name of SSHetu's private tmux server (`tmux -L`).
const String kTmuxSocket = 'sshetu';

/// Markers the probe prints, so the answer is read from an exact line rather
/// than inferred from an exit status a login banner or a broken shell can
/// also produce.
abstract final class TmuxProbeMarkers {
  static const String absent = 'SSHETU:tmux-absent';
  static const String existing = 'SSHETU:tmux-existing';
  static const String fresh = 'SSHETU:tmux-new';
}

/// What the probe found.
enum TmuxProbe {
  /// No tmux on this server — or no POSIX shell to ask, as on a router.
  unavailable,

  /// tmux is there and this tab's session is not: attaching creates it.
  willCreate,

  /// tmux is there and this tab's session is still running.
  willReattach,
}

/// Quotes [value] for a POSIX shell: single quotes, with each embedded single
/// quote closed, escaped and reopened. Nothing inside single quotes is
/// special to `sh`, so no input can become syntax.
String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

/// Wraps [script] so it runs under `sh` whatever the account's login shell
/// is. An exec request is run by the user's shell, and fish or csh would read
/// POSIX syntax as an error; `sh -c '…'` means the same thing to all of them.
String posixShell(String script) => 'sh -c ${shellQuote(script)}';

/// The tmux session name for the tab with id [tabId].
///
/// tmux gives `.` and `:` meaning in a target, so anything outside a plain
/// set becomes `_`. Stable for the life of the tab, which is what lets a
/// reconnect find the same session again.
String tmuxSessionName(String tabId) =>
    'sshetu-${tabId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';

/// The exact-match target for [name]. Without the `=`, tmux falls back to
/// prefix matching, and `sshetu-host-1` would happily attach to
/// `sshetu-host-12`.
String _target(String name) => shellQuote('=$name');

/// Settings for SSHetu's private tmux server. Read only when that server
/// starts, from a file, because a config file tolerates an option an older
/// tmux does not know — a command line would abort on it and take the whole
/// session with it.
const List<String> kTmuxServerOptions = [
  // Invisible: no status line eating a row of the phone's screen, and no
  // prefix key, so every keystroke reaches the program — including a Ctrl-B
  // meant for a tmux the user runs inside this one.
  'set -g status off',
  'set -g prefix None',
  'set -g prefix2 None',
  // Esc is a key in vim, not the start of a chord. tmux waits half a second
  // by default to find out, which is the lag people blame on the network.
  'set -g escape-time 0',
  // As deep as the app's own scrollback, because on reattach tmux's history
  // replaces it. See [tmuxHistoryCommand].
  'set -g history-limit $kTmuxHistoryLines',
  // Output scrolls in the app's own terminal instead of an alternate screen,
  // so its scrollback, search and copy keep working. See [tmuxAttachCommand].
  "set -g terminal-overrides '*:smcup@:rmcup@:Tc'",
  "set -g default-terminal 'screen-256color'",
  // The user's own shell, as a login shell, with TMUX cleared: tmux sets it
  // in every pane, and a tmux started inside would otherwise refuse to run
  // ("sessions should be nested with care"). `/bin/sh` runs the command, so
  // this means the same thing whatever the login shell is.
  "set -g default-shell '/bin/sh'",
  "set -g default-command 'unset TMUX TMUX_PANE; exec \"\${SHELL:-/bin/sh}\" -l'",
];

/// Asks the server, over an exec channel, whether tmux exists and whether
/// session [name] is already running. Prints exactly one of
/// [TmuxProbeMarkers].
String tmuxProbeCommand(String name) => posixShell(
  'if ! command -v tmux >/dev/null 2>&1; then '
  'echo ${TmuxProbeMarkers.absent}; exit 0; fi; '
  'if tmux -L $kTmuxSocket has-session -t ${_target(name)} 2>/dev/null; then '
  'echo ${TmuxProbeMarkers.existing}; '
  'else echo ${TmuxProbeMarkers.fresh}; fi',
);

/// Reads [tmuxProbeCommand]'s output. Anything unrecognised — a server with
/// no `sh`, a probe that printed an error — means no tmux, and the tab falls
/// back to an ordinary shell.
TmuxProbe parseTmuxProbe(String output) {
  for (final line in output.split('\n')) {
    switch (line.trim()) {
      case TmuxProbeMarkers.fresh:
        return TmuxProbe.willCreate;
      case TmuxProbeMarkers.existing:
        return TmuxProbe.willReattach;
      case TmuxProbeMarkers.absent:
        return TmuxProbe.unavailable;
    }
  }
  return TmuxProbe.unavailable;
}

/// Attaches to session [name], creating it first if it is not running. Run
/// over an exec channel **with a PTY**; it becomes the tab's shell.
///
/// Attach-or-create in two steps rather than `new-session -A` so the server
/// options can be put in place before the first window's shell is started:
/// a detached `new-session` starts the private server (reading the options
/// file) and fails harmlessly when the session already exists, then
/// `attach-session` joins whichever is there. [columns] and [rows] size a new
/// session to the tab, so the first prompt is not drawn at 80×24 and
/// reflowed.
///
/// **Scrollback.** tmux normally draws in the alternate screen, and whatever
/// scrolls off the top lives only in tmux's own history — out of reach of
/// the app's scrollback, search and copy. Disabling `smcup`/`rmcup` for this
/// server's clients makes tmux scroll the main screen instead, so every line
/// still lands in the app's buffer, exactly as a plain shell's would.
///
/// If the session still cannot be found — tmux too old for an exact-match
/// target, a socket directory that is not writable — this falls back to an
/// ordinary login shell rather than leaving the tab with nothing.
String tmuxAttachCommand(
  String name, {
  required int columns,
  required int rows,
}) {
  // printf rather than a heredoc, so the whole script is one line: csh, still
  // the login shell on some BSD accounts, rejects a newline inside quotes.
  final options = kTmuxServerOptions.map(shellQuote).join(' ');
  final width = columns < 1 ? 80 : columns;
  final height = rows < 1 ? 24 : rows;
  final target = _target(name);
  return posixShell(
    'unset TMUX TMUX_PANE; '
    // No mktemp, no options — never a guessable path in /tmp, which another
    // account could have pointed somewhere with a symlink.
    'cfg=\$(mktemp 2>/dev/null) || cfg=/dev/null; '
    'if [ "\$cfg" != /dev/null ]; then printf \'%s\\n\' $options > "\$cfg"; fi; '
    'tmux -u -L $kTmuxSocket -f "\$cfg" new-session -d '
    '-s ${shellQuote(name)} -x $width -y $height 2>/dev/null; '
    'if [ "\$cfg" != /dev/null ]; then rm -f "\$cfg"; fi; '
    'if tmux -L $kTmuxSocket has-session -t $target 2>/dev/null; then '
    'exec tmux -u -L $kTmuxSocket attach-session -t $target; fi; '
    'exec "\${SHELL:-/bin/sh}" -l',
  );
}

/// How many lines of history SSHetu's tmux server keeps per session — the
/// same depth as a terminal tab's own scrollback.
const int kTmuxHistoryLines = 5000;

/// The scrollback of session [name], as tmux has it: history only, above
/// the visible screen (which attaching redraws anyway), with colours, and
/// wrapped lines joined so they reflow to the tab's width.
///
/// Read just before reattaching, and used to *replace* the tab's buffer.
/// The alternate-screen trick keeps ordinary output in the app's scrollback,
/// but tmux never sends lines that scroll past within a single burst — `cat`
/// of a long file draws only its last screenful — nor, of course, anything
/// printed while the connection was down. tmux's history has all of it.
String tmuxHistoryCommand(String name) => posixShell(
  'tmux -L $kTmuxSocket capture-pane -p -e -J '
  // A pane target, so the exact session name is followed by `:` — its
  // current window and pane. `=name` alone is not a pane tmux can find.
  '-S -$kTmuxHistoryLines -E -1 -t ${shellQuote('=$name:')} 2>/dev/null',
);

/// Ends session [name] and everything running in it. Best effort, and quiet:
/// a session that is already gone is the outcome wanted.
String tmuxKillCommand(String name) => posixShell(
  'tmux -L $kTmuxSocket kill-session -t ${_target(name)} 2>/dev/null; true',
);
