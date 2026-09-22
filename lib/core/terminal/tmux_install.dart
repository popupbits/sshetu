/// Finding out whether tmux can be installed on a server, and the exact
/// command that would do it.
///
/// Pure string construction and parsing, kept apart from the code that runs
/// it for the same reason `tmux_commands.dart` is: these go to someone's
/// server — one of them as root — and the thing worth reviewing is exactly
/// what they say.
///
/// **Nothing here installs anything by itself.** The probe only asks
/// questions (which package managers exist, who we are, whether `sudo -n`
/// works — which never prompts), and the install command is shown to the
/// user, word for word, before anything runs. See `TmuxInstallAssistant`.
library;

import 'tmux_commands.dart';

/// The package managers SSHetu knows how to install tmux with.
enum PackageManager {
  aptGet('apt-get'),
  dnf('dnf'),
  yum('yum'),
  pacman('pacman'),
  apk('apk'),
  zypper('zypper'),
  brew('brew'),

  /// FreeBSD's `pkg`.
  pkg('pkg');

  const PackageManager(this.executable);

  /// The command's name, as `command -v` looks it up.
  final String executable;

  /// Whether it runs as the user rather than as root. Homebrew refuses to
  /// run as root, so it never gets `sudo`.
  bool get runsAsUser => this == PackageManager.brew;

  static PackageManager? byExecutable(String name) {
    for (final manager in values) {
      if (manager.executable == name) return manager;
    }
    return null;
  }
}

/// How this account can get root for an install.
enum RootAccess {
  /// The account is root (`id -u` is 0).
  root,

  /// `sudo -n true` succeeded: sudo works without a password.
  passwordlessSudo,

  /// sudo exists, and `sudo -n true` failed — it wants a password (or a tty).
  sudoNeedsPassword,

  /// Not root, and there is no sudo.
  none,
}

/// Markers the probe prints, so every answer is read from an exact line
/// rather than inferred from a login banner or a broken shell.
abstract final class TmuxInstallMarkers {
  static const String begin = 'SSHETU:install-probe';
  static const String uid = 'SSHETU:uid=';
  static const String kernel = 'SSHETU:kernel=';
  static const String manager = 'SSHETU:pm=';
  static const String osId = 'SSHETU:os-id=';
  static const String osLike = 'SSHETU:os-like=';
  static const String sudo = 'SSHETU:sudo=';
  static const String tmux = 'SSHETU:tmux=';
}

/// Asks the server, over an exec channel (never a PTY, never interactive),
/// what an install of tmux would need.
///
/// - which of [PackageManager] exist (`command -v`),
/// - `/etc/os-release`'s `ID` and `ID_LIKE`, and `uname -s`,
/// - `id -u`, and whether `sudo -n true` succeeds — `-n` makes sudo fail
///   instead of prompting, and stdin is `/dev/null` besides,
/// - whether tmux has turned up since the tab opened.
String tmuxInstallProbeCommand() {
  final managers = PackageManager.values.map((m) => m.executable).join(' ');
  return posixShell(
    'echo ${TmuxInstallMarkers.begin}; '
    'echo "${TmuxInstallMarkers.uid}\$(id -u 2>/dev/null)"; '
    'echo "${TmuxInstallMarkers.kernel}\$(uname -s 2>/dev/null)"; '
    'for m in $managers; do '
    'if command -v "\$m" >/dev/null 2>&1; then '
    'echo "${TmuxInstallMarkers.manager}\$m"; fi; done; '
    'if [ -r /etc/os-release ]; then '
    "sed -n 's/^ID=/${TmuxInstallMarkers.osId}/p' /etc/os-release; "
    "sed -n 's/^ID_LIKE=/${TmuxInstallMarkers.osLike}/p' /etc/os-release; "
    'fi; '
    'if [ "\$(id -u 2>/dev/null)" = 0 ]; then '
    'echo ${TmuxInstallMarkers.sudo}root; '
    'elif command -v sudo >/dev/null 2>&1; then '
    'if sudo -n true </dev/null >/dev/null 2>&1; then '
    'echo ${TmuxInstallMarkers.sudo}ok; '
    'else echo ${TmuxInstallMarkers.sudo}password; fi; '
    'else echo ${TmuxInstallMarkers.sudo}absent; fi; '
    'if command -v tmux >/dev/null 2>&1; then '
    'echo ${TmuxInstallMarkers.tmux}yes; '
    'else echo ${TmuxInstallMarkers.tmux}no; fi',
  );
}

/// What [tmuxInstallProbeCommand] found.
class ServerInstallFacts {
  const ServerInstallFacts({
    required this.managers,
    required this.access,
    this.uid,
    this.kernel,
    this.osId,
    this.osLike = const [],
    this.tmuxPresent = false,
  });

  /// The package managers present, in [PackageManager] order.
  final List<PackageManager> managers;

  final RootAccess access;

  /// `id -u`, when it answered.
  final int? uid;

  /// `uname -s`: `Linux`, `Darwin`, `FreeBSD`…
  final String? kernel;

  /// `/etc/os-release`'s `ID`, lower case and unquoted.
  final String? osId;

  /// `/etc/os-release`'s `ID_LIKE`, split into words.
  final List<String> osLike;

  /// tmux is there after all — installed since the tab opened, perhaps.
  final bool tmuxPresent;

  bool get isRoot => access == RootAccess.root;
}

/// Reads [tmuxInstallProbeCommand]'s output. Null when the probe did not run
/// at all — no marker, as on a router with no `sh`.
ServerInstallFacts? parseTmuxInstallProbe(String output) {
  final lines = output.replaceAll('\r', '').split('\n').map((l) => l.trim());
  if (!lines.contains(TmuxInstallMarkers.begin)) return null;

  final managers = <PackageManager>{};
  int? uid;
  String? kernel;
  String? osId;
  var osLike = const <String>[];
  String? sudo;
  var tmux = false;

  for (final line in lines) {
    String? after(String marker) =>
        line.startsWith(marker) ? line.substring(marker.length).trim() : null;

    if (after(TmuxInstallMarkers.uid) case final value?) {
      uid = int.tryParse(value);
    } else if (after(TmuxInstallMarkers.kernel) case final value?) {
      kernel = value.isEmpty ? null : value;
    } else if (after(TmuxInstallMarkers.manager) case final value?) {
      final manager = PackageManager.byExecutable(value);
      if (manager != null) managers.add(manager);
    } else if (after(TmuxInstallMarkers.osId) case final value?) {
      final id = _unquote(value).toLowerCase();
      osId = id.isEmpty ? null : id;
    } else if (after(TmuxInstallMarkers.osLike) case final value?) {
      osLike = _unquote(value)
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
    } else if (after(TmuxInstallMarkers.sudo) case final value?) {
      sudo = value;
    } else if (after(TmuxInstallMarkers.tmux) case final value?) {
      tmux = value == 'yes';
    }
  }

  // `id -u` is the authority on root; the sudo line agrees with it whenever
  // both answered, and fills in when `id` did not.
  final access = uid == 0
      ? RootAccess.root
      : switch (sudo) {
          'root' when uid == null => RootAccess.root,
          'ok' => RootAccess.passwordlessSudo,
          'password' => RootAccess.sudoNeedsPassword,
          _ => RootAccess.none,
        };

  return ServerInstallFacts(
    managers: [
      for (final manager in PackageManager.values)
        if (managers.contains(manager)) manager,
    ],
    access: access,
    uid: uid,
    kernel: kernel,
    osId: osId,
    osLike: osLike,
    tmuxPresent: tmux,
  );
}

/// `"ubuntu debian"` → `ubuntu debian`. os-release values may be quoted with
/// either kind of quote, or not at all.
String _unquote(String value) {
  if (value.length >= 2 &&
      (value.startsWith('"') && value.endsWith('"') ||
          value.startsWith("'") && value.endsWith("'"))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

/// The package manager a distribution is known to use, by os-release word.
const Map<String, List<PackageManager>> _byDistribution = {
  'debian': [PackageManager.aptGet],
  'ubuntu': [PackageManager.aptGet],
  'raspbian': [PackageManager.aptGet],
  'linuxmint': [PackageManager.aptGet],
  'pop': [PackageManager.aptGet],
  'kali': [PackageManager.aptGet],
  'fedora': [PackageManager.dnf, PackageManager.yum],
  'rhel': [PackageManager.dnf, PackageManager.yum],
  'centos': [PackageManager.dnf, PackageManager.yum],
  'rocky': [PackageManager.dnf, PackageManager.yum],
  'almalinux': [PackageManager.dnf, PackageManager.yum],
  'amzn': [PackageManager.dnf, PackageManager.yum],
  'ol': [PackageManager.dnf, PackageManager.yum],
  'arch': [PackageManager.pacman],
  'manjaro': [PackageManager.pacman],
  'endeavouros': [PackageManager.pacman],
  'alpine': [PackageManager.apk],
  'opensuse': [PackageManager.zypper],
  'opensuse-leap': [PackageManager.zypper],
  'opensuse-tumbleweed': [PackageManager.zypper],
  'suse': [PackageManager.zypper],
  'sles': [PackageManager.zypper],
  'freebsd': [PackageManager.pkg],
};

/// Which package manager to install with, or null when none SSHetu knows is
/// present.
///
/// The distribution's own manager first (by `ID`, then `ID_LIKE`, then the
/// kernel), and only one that is actually there: a Debian box with Homebrew
/// installed on the side still gets `apt-get`. Failing that, the first one
/// present, with Homebrew last — on Linux it is a user's extra, not the
/// system's.
PackageManager? choosePackageManager(ServerInstallFacts facts) {
  final present = facts.managers.toSet();
  final words = [
    ?facts.osId,
    ...facts.osLike,
    if (facts.kernel?.toLowerCase() == 'freebsd') 'freebsd',
  ];
  for (final word in words) {
    for (final manager in _byDistribution[word] ?? const <PackageManager>[]) {
      if (present.contains(manager)) return manager;
    }
  }
  if (facts.kernel == 'Darwin' && present.contains(PackageManager.brew)) {
    return PackageManager.brew;
  }
  for (final manager in PackageManager.values) {
    if (present.contains(manager)) return manager;
  }
  return null;
}

/// One command, as words. Rendered with [shellWord], so a word that is not
/// plain is quoted; none of these come from user input.
typedef CommandWords = List<String>;

/// The words that install tmux with [manager], without any `sudo`.
///
/// Non-interactive for every manager, because a question nobody sees on an
/// exec channel is a hang. `apt-get` also gets `DEBIAN_FRONTEND=noninteractive`
/// through `env` — a word `sudo` passes on whatever its `env_reset` policy,
/// where a bare `VAR=value` in front of the command may be refused.
CommandWords tmuxInstallWords(PackageManager manager) => switch (manager) {
  PackageManager.aptGet => [
    'env',
    'DEBIAN_FRONTEND=noninteractive',
    'apt-get',
    'install',
    '-y',
    'tmux',
  ],
  PackageManager.dnf => ['dnf', 'install', '-y', 'tmux'],
  PackageManager.yum => ['yum', 'install', '-y', 'tmux'],
  PackageManager.pacman => ['pacman', '-S', '--noconfirm', 'tmux'],
  PackageManager.apk => ['apk', 'add', 'tmux'],
  PackageManager.zypper => ['zypper', '-n', 'install', 'tmux'],
  PackageManager.brew => ['brew', 'install', 'tmux'],
  PackageManager.pkg => ['pkg', 'install', '-y', 'tmux'],
};

/// `apt-get update`, for when the install failed because the package lists
/// are stale — never run unless that happened and the user agreed.
const CommandWords aptUpdateWords = [
  'env',
  'DEBIAN_FRONTEND=noninteractive',
  'apt-get',
  'update',
];

/// Whether [output] from a failed apt install says the package lists are too
/// old to know tmux — the one failure `apt-get update` fixes.
bool needsPackageListUpdate(PackageManager manager, String output) =>
    manager == PackageManager.aptGet &&
    (output.contains('Unable to locate package') ||
        output.contains('has no installation candidate'));

/// [word] as a shell word: as-is when it holds nothing a shell would read
/// as syntax, otherwise through [shellQuote].
String shellWord(String word) =>
    RegExp(r'^[A-Za-z0-9_./=:+,@%-]+$').hasMatch(word)
    ? word
    : shellQuote(word);

/// How an install command gets root.
enum Elevation {
  /// Run as is: the account is root, or the manager runs as the user.
  none,

  /// `sudo -n`: sudo works without a password, and must never be allowed to
  /// stop and ask for one on an exec channel.
  sudoNonInteractive,

  /// `sudo`: typed into the user's own terminal, where sudo asks for the
  /// password itself. SSHetu never sees it.
  sudoInTerminal,
}

/// [steps] as one command line, each step elevated as [elevation] says and
/// joined with `&&`, so a failed step stops the rest.
String renderInstallCommand(List<CommandWords> steps, Elevation elevation) {
  final prefix = switch (elevation) {
    Elevation.none => const <String>[],
    Elevation.sudoNonInteractive => const ['sudo', '-n'],
    Elevation.sudoInTerminal => const ['sudo'],
  };
  return steps
      .map((step) => [...prefix, ...step].map(shellWord).join(' '))
      .join(' && ');
}

/// What SSHetu can offer for a server without tmux.
sealed class TmuxInstallOffer {
  const TmuxInstallOffer();
}

/// A command SSHetu can run itself, over exec, once the user agrees.
class RunInstall extends TmuxInstallOffer {
  const RunInstall({
    required this.manager,
    required this.elevation,
    this.withUpdate = false,
  });

  final PackageManager manager;

  /// [Elevation.none] or [Elevation.sudoNonInteractive].
  final Elevation elevation;

  /// Whether `apt-get update` runs first.
  final bool withUpdate;

  List<CommandWords> get steps => [
    if (withUpdate) aptUpdateWords,
    tmuxInstallWords(manager),
  ];

  /// Exactly what the user is shown, and exactly what runs.
  String get command => renderInstallCommand(steps, elevation);

  /// [command] for an exec channel: under `sh` whatever the login shell,
  /// with stderr folded into the output the user is shown.
  String get execCommand => posixShell('$command 2>&1');
}

/// A command SSHetu types into the tab's terminal and runs, so that sudo can
/// ask for the password there — in the user's own terminal, never through
/// SSHetu.
class TypeInstallInTerminal extends TmuxInstallOffer {
  const TypeInstallInTerminal({required this.manager});

  final PackageManager manager;

  /// Exactly what the user is shown, and exactly what is typed.
  String get command => renderInstallCommand([
    tmuxInstallWords(manager),
  ], Elevation.sudoInTerminal);
}

/// Why nothing can be offered.
enum InstallUnavailableReason {
  /// No package manager SSHetu knows.
  unknownPackageManager,

  /// Not root, and no sudo to become it.
  noPrivilege,
}

/// Nothing to run; explain instead.
class InstallUnavailable extends TmuxInstallOffer {
  const InstallUnavailable(this.reason);

  final InstallUnavailableReason reason;
}

/// tmux is there after all; nothing needs installing.
class TmuxAlreadyPresent extends TmuxInstallOffer {
  const TmuxAlreadyPresent();
}

/// What to offer a server described by [facts].
TmuxInstallOffer planTmuxInstall(ServerInstallFacts facts) {
  if (facts.tmuxPresent) return const TmuxAlreadyPresent();
  final manager = choosePackageManager(facts);
  if (manager == null) {
    return const InstallUnavailable(
      InstallUnavailableReason.unknownPackageManager,
    );
  }
  if (manager.runsAsUser) {
    return RunInstall(manager: manager, elevation: Elevation.none);
  }
  return switch (facts.access) {
    RootAccess.root => RunInstall(manager: manager, elevation: Elevation.none),
    RootAccess.passwordlessSudo => RunInstall(
      manager: manager,
      elevation: Elevation.sudoNonInteractive,
    ),
    RootAccess.sudoNeedsPassword => TypeInstallInTerminal(manager: manager),
    RootAccess.none => const InstallUnavailable(
      InstallUnavailableReason.noPrivilege,
    ),
  };
}
