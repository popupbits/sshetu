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

// Session names are made in `tmux_names.dart`; re-exported so the commands
// and the names that go into them can be imported together.
export 'tmux_names.dart';

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
///
/// [env] is set in a *new* session's shell — see [envExports]. A reattached
/// session keeps the environment it was created with.
String tmuxAttachCommand(
  String name, {
  required int columns,
  required int rows,
  Map<String, String> env = const {},
}) {
  // printf rather than a heredoc, so the whole script is one line: csh, still
  // the login shell on some BSD accounts, rejects a newline inside quotes.
  final options = kTmuxServerOptions.map(shellQuote).join(' ');
  final width = columns < 1 ? 80 : columns;
  final height = rows < 1 ? 24 : rows;
  final target = _target(name);
  final exports = envExports(env);
  // With variables, the first window runs an explicit command instead of the
  // server's default-command — the same command, with the exports in front.
  // tmux runs it through default-shell, which the options file sets to
  // /bin/sh, so it is POSIX whatever the login shell is.
  //
  // Not `new-session -e`: that flag arrived in tmux 3.2, and telling its
  // failure apart from "duplicate session" (also exit 1), or sniffing
  // `tmux -V` (which says things like `next-3.4` and `3.3a`), is more
  // machinery than an explicit command that works on every tmux there is.
  // Nothing is typed into the terminal either way, so nothing lands in the
  // scrollback or the shell's history.
  final firstWindow = exports.isEmpty
      ? ''
      : ' ${shellQuote('$exports$_loginShell')}';
  return posixShell(
    'unset TMUX TMUX_PANE; '
    // No mktemp, no options — never a guessable path in /tmp, which another
    // account could have pointed somewhere with a symlink.
    'cfg=\$(mktemp 2>/dev/null) || cfg=/dev/null; '
    'if [ "\$cfg" != /dev/null ]; then printf \'%s\\n\' $options > "\$cfg"; fi; '
    'tmux -u -L $kTmuxSocket -f "\$cfg" new-session -d '
    '-s ${shellQuote(name)} -x $width -y $height$firstWindow 2>/dev/null; '
    'if [ "\$cfg" != /dev/null ]; then rm -f "\$cfg"; fi; '
    'if tmux -L $kTmuxSocket has-session -t $target 2>/dev/null; then '
    'exec tmux -u -L $kTmuxSocket attach-session -t $target; fi; '
    '${exports}exec "\${SHELL:-/bin/sh}" -l',
  );
}

/// What a tmux window runs by default, spelled out so a window with
/// variables can run the same thing. Matches `default-command` in
/// [kTmuxServerOptions].
const String _loginShell = 'unset TMUX TMUX_PANE; exec "\${SHELL:-/bin/sh}" -l';

/// `export NAME='value'; ` for each of [env], for a POSIX shell.
///
/// Names are checked, not quoted — a name is syntax, and one that is not a
/// valid identifier is refused outright ([ArgumentError]) rather than
/// escaped into something else. Values go through [shellQuote], so a space,
/// a quote, a `$` or a backtick arrives exactly as typed.
String envExports(Map<String, String> env) {
  final out = StringBuffer();
  for (final MapEntry(:key, :value) in env.entries) {
    if (!isValidEnvName(key)) {
      throw ArgumentError.value(key, 'env', 'not a variable name');
    }
    out.write('export $key=${shellQuote(value)}; ');
  }
  return out.toString();
}

/// A POSIX variable name: a letter or underscore, then letters, digits and
/// underscores.
bool isValidEnvName(String name) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name);

/// An ordinary login shell with [env] set, for an exec request with a PTY.
///
/// The way a plain (non-tmux) tab gets its variables. The SSH `env` request
/// would be the obvious route, but OpenSSH accepts only what the server's
/// `AcceptEnv` lists — `LANG` and `LC_*` by default — and ignores the rest
/// in silence. Typing an `export` line into the shell would work, and would
/// also print it in the terminal and save it in the shell's history. So the
/// shell is started *with* the variables instead: `sh` exports them, then
/// replaces itself with the user's own shell as a login shell (`-l`), which
/// reads the same profile files the `shell` request's login shell does.
///
/// What differs from a `shell` request: sshd prints no message of the day
/// for a command. That, and needing a POSIX `sh` — which a switch or a router
/// does not have — is why this is used only when a host has variables.
String plainShellCommand(Map<String, String> env) =>
    posixShell('${envExports(env)}exec "\${SHELL:-/bin/sh}" -l');

/// Markers [tmuxListCommand] prints around its answer.
abstract final class TmuxListMarkers {
  static const String absent = TmuxProbeMarkers.absent;
  static const String begin = 'SSHETU:tmux-list';
}

/// Fields [tmuxListCommand] asks tmux for, in order. `|` separates them:
/// session names are restricted to characters that exclude it, and the one
/// free-text field — the running command — is last, so a `|` in it cannot
/// shift the others.
const String _listFormat =
    '#{session_name}|#{session_created}|#{session_attached}|'
    '#{session_activity}|#{session_windows}|#{pane_current_command}';

/// Lists the sessions on SSHetu's private tmux server — every device's,
/// since they all share the account's one socket.
///
/// No server running is not an error: `list-sessions` fails, prints nothing
/// after the marker, and the answer is "none".
String tmuxListCommand() => posixShell(
  'if ! command -v tmux >/dev/null 2>&1; then '
  'echo ${TmuxListMarkers.absent}; exit 0; fi; '
  'echo ${TmuxListMarkers.begin}; '
  'tmux -L $kTmuxSocket list-sessions -F ${shellQuote(_listFormat)} '
  '2>/dev/null; true',
);

/// One session [tmuxListCommand] found.
class TmuxSessionInfo {
  const TmuxSessionInfo({
    required this.name,
    required this.created,
    required this.attachedClients,
    this.lastActivity,
    this.windows = 1,
    this.command,
  });

  final String name;
  final DateTime created;

  /// How many clients are attached right now — any device, this one included.
  final int attachedClients;

  /// When anything last happened in it. Null on a tmux too old to say.
  final DateTime? lastActivity;

  final int windows;

  /// What its visible pane is running (`bash`, `vim`, `htop`), when known.
  final String? command;

  bool get isAttached => attachedClients > 0;
}

/// What [tmuxListCommand] found.
class TmuxListing {
  const TmuxListing({required this.tmuxAvailable, required this.sessions});

  final bool tmuxAvailable;

  /// Newest activity first.
  final List<TmuxSessionInfo> sessions;
}

/// Reads [tmuxListCommand]'s output. Lines that do not parse — a login
/// banner, a session someone named by hand without the prefix — are skipped.
TmuxListing parseTmuxListing(String output) {
  final lines = output.replaceAll('\r', '').split('\n');
  final start = lines.indexWhere((l) => l.trim() == TmuxListMarkers.begin);
  if (start < 0) {
    return const TmuxListing(tmuxAvailable: false, sessions: []);
  }
  final sessions = <TmuxSessionInfo>[];
  for (final line in lines.skip(start + 1)) {
    final parts = line.split('|');
    if (parts.length < 6) continue;
    final name = parts[0];
    if (!name.startsWith('sshetu-')) continue;
    final created = int.tryParse(parts[1]);
    if (created == null) continue;
    final activity = int.tryParse(parts[3]);
    final command = parts.sublist(5).join('|').trim();
    sessions.add(
      TmuxSessionInfo(
        name: name,
        created: _epoch(created),
        attachedClients: int.tryParse(parts[2]) ?? 0,
        lastActivity: activity == null ? null : _epoch(activity),
        windows: int.tryParse(parts[4]) ?? 1,
        command: command.isEmpty ? null : command,
      ),
    );
  }
  sessions.sort(
    (a, b) =>
        (b.lastActivity ?? b.created).compareTo(a.lastActivity ?? a.created),
  );
  return TmuxListing(tmuxAvailable: true, sessions: sessions);
}

DateTime _epoch(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

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
