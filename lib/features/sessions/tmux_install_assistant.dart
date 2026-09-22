import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/error_logger.dart';
import '../../core/providers.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/terminal/tmux_install.dart';
import '../hosts/domain/ssh_host.dart';
import '../hosts/hosts_controller.dart';
import '../server_info/data/server_exec.dart';
import 'session_manager.dart';

/// Where one tab's offer to install tmux stands.
sealed class TmuxInstallStage {
  const TmuxInstallStage();
}

/// Nothing asked yet.
class TmuxInstallIdle extends TmuxInstallStage {
  const TmuxInstallIdle();
}

/// Asking the server what an install would need. Shown as nothing: the
/// terminal's own one-line notice already says tmux is missing.
class TmuxInstallDetecting extends TmuxInstallStage {
  const TmuxInstallDetecting();
}

/// The question, with [offer]: a command to run, one to type into the
/// terminal, or an explanation of why there is nothing to run.
class TmuxInstallOffered extends TmuxInstallStage {
  const TmuxInstallOffered(this.offer);

  final TmuxInstallOffer offer;
}

/// [offer] is running over exec.
class TmuxInstallRunning extends TmuxInstallStage {
  const TmuxInstallRunning(this.offer);

  final RunInstall offer;
}

/// tmux is installed (or turned out to be there already). Offers the
/// restart.
class TmuxInstallSucceeded extends TmuxInstallStage {
  const TmuxInstallSucceeded();
}

/// [offer] failed with [output]. [retry], when set, is the same install
/// with `apt-get update` first — offered, never run by itself.
class TmuxInstallFailed extends TmuxInstallStage {
  const TmuxInstallFailed(this.offer, this.output, {this.retry});

  final RunInstall offer;
  final String output;
  final RunInstall? retry;
}

/// [offer] was typed into the terminal and run; sudo is asking for the
/// password there.
class TmuxInstallTyped extends TmuxInstallStage {
  const TmuxInstallTyped(this.offer);

  final TypeInstallInTerminal offer;
}

/// Closed — Not now, Never, a restart, or nothing to offer.
class TmuxInstallDismissed extends TmuxInstallStage {
  const TmuxInstallDismissed();
}

/// Offers to install tmux on a server that lacks it, for one tab — always
/// with the user's consent, never by itself.
///
/// Every dependency is a function, so the whole flow runs in a test against
/// fakes. What it never has is a way to read a password: where sudo needs
/// one, the command is typed into the tab's own terminal and sudo asks for
/// it there, between the user and the server.
class TmuxInstallAssistant extends ChangeNotifier {
  TmuxInstallAssistant({
    required this.exec,
    ServerExec? installExec,
    required this.typeIntoTerminal,
    required this.setNever,
    required this.snooze,
    required this.restartInTmux,
  }) : installExec = installExec ?? exec;

  /// For the probe: short, read-only questions.
  final ServerExec exec;

  /// For the install itself, which can take minutes.
  final ServerExec installExec;

  /// Types text into the tab's terminal, as if from the keyboard.
  final void Function(String text) typeIntoTerminal;

  /// Saves "never" as this host's tmux choice.
  final Future<void> Function() setNever;

  /// Remembers "Not now" for this host, for this run of the app.
  final void Function() snooze;

  /// Reopens the tab's shell inside tmux.
  final Future<void> Function() restartInTmux;

  TmuxInstallStage _stage = const TmuxInstallIdle();
  TmuxInstallStage get stage => _stage;

  bool _disposed = false;

  void _set(TmuxInstallStage stage) {
    if (_disposed) return;
    _stage = stage;
    notifyListeners();
  }

  /// Asks the server what an install would need. Once: a later call does
  /// nothing.
  Future<void> detect() async {
    if (_stage is! TmuxInstallIdle) return;
    _set(const TmuxInstallDetecting());
    ServerInstallFacts? facts;
    try {
      final result = await exec.run(tmuxInstallProbeCommand());
      facts = parseTmuxInstallProbe(result.stdout);
    } on Object {
      facts = null;
    }
    if (facts == null) {
      // No answer — no exec channel, no `sh`. The notice in the terminal
      // already says tmux is missing; there is nothing useful to add.
      _set(const TmuxInstallDismissed());
      return;
    }
    final offer = planTmuxInstall(facts);
    _set(
      offer is TmuxAlreadyPresent
          ? const TmuxInstallSucceeded()
          : TmuxInstallOffered(offer),
    );
  }

  /// The user chose Install.
  ///
  /// A [RunInstall] runs over exec — as root, or with `sudo -n`, which fails
  /// rather than asks. A [TypeInstallInTerminal] is typed into the terminal
  /// and run there, so sudo can ask for the password itself. Either way the
  /// command is the one the prompt showed, word for word.
  Future<void> install() async {
    switch (_stage) {
      case TmuxInstallOffered(offer: final RunInstall offer):
        await _run(offer);
      case TmuxInstallOffered(offer: final TypeInstallInTerminal offer):
        // Ctrl-U first: the tty's line-kill character, so anything half
        // typed at the prompt is cleared instead of prefixed to the command.
        // Then the command and Enter — the user agreed to exactly this.
        typeIntoTerminal('\x15${offer.command}\r');
        _set(TmuxInstallTyped(offer));
      default:
        return;
    }
  }

  /// The user agreed to update the package lists and try again.
  Future<void> installWithUpdate() async {
    final stage = _stage;
    if (stage is! TmuxInstallFailed) return;
    final retry = stage.retry;
    if (retry == null) return;
    await _run(retry);
  }

  Future<void> _run(RunInstall offer) async {
    _set(TmuxInstallRunning(offer));
    ExecResult result;
    try {
      result = await installExec.run(offer.execCommand);
    } on Object catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'tmux-install');
      _set(TmuxInstallFailed(offer, '$error'));
      return;
    }
    final output = [
      result.stdout,
      result.stderr,
    ].where((s) => s.trim().isNotEmpty).join('\n');
    if (result.succeeded) {
      _set(const TmuxInstallSucceeded());
      return;
    }
    final canUpdate =
        !offer.withUpdate && needsPackageListUpdate(offer.manager, output);
    _set(
      TmuxInstallFailed(
        offer,
        output,
        retry: canUpdate
            ? RunInstall(
                manager: offer.manager,
                elevation: offer.elevation,
                withUpdate: true,
              )
            : null,
      ),
    );
  }

  /// Not now: for this host, until the app is next started.
  void notNow() {
    snooze();
    _set(const TmuxInstallDismissed());
  }

  /// Never for this host: saved, so no tab to it tries tmux or offers this
  /// again.
  Future<void> never() async {
    _set(const TmuxInstallDismissed());
    await setNever();
  }

  /// Reopens the tab's shell in tmux. The prompt has said what that closes.
  Future<void> restart() async {
    _set(const TmuxInstallDismissed());
    await restartInTmux();
  }

  /// Closes the prompt without deciding anything.
  void dismiss() => _set(const TmuxInstallDismissed());

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The hosts whose install offer was answered "Not now" in this run of the
/// app. Never saved: the next launch asks again.
class TmuxInstallSnooze extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void snooze(String hostId) => state = {...state, hostId};
}

final tmuxInstallSnoozeProvider =
    NotifierProvider<TmuxInstallSnooze, Set<String>>(TmuxInstallSnooze.new);

/// How long an install may run before it is given up on.
const Duration kTmuxInstallTimeout = Duration(minutes: 10);

/// One [TmuxInstallAssistant] per open tab, made on first use and kept for
/// the tab's life — so switching away mid-install and back finds it still
/// running rather than asking again.
class TmuxInstallAssistants {
  TmuxInstallAssistants(this._ref, {this._exec});

  final Ref _ref;

  /// Stands in for the tab's own connection in a test.
  final ServerExec Function(TerminalSession)? _exec;

  final _bySession = Expando<TmuxInstallAssistant>('tmux install');

  /// Whether [session] has an assistant yet — whether it was ever offered.
  bool has(TerminalSession session) => _bySession[session] != null;

  TmuxInstallAssistant forSession(
    TerminalSession session,
  ) => _bySession[session] ??= TmuxInstallAssistant(
    exec: _exec?.call(session) ?? ConnectionExec(session.connection),
    installExec:
        _exec?.call(session) ??
        ConnectionExec(session.connection, timeout: kTmuxInstallTimeout),
    typeIntoTerminal: session.send,
    setNever: () => setHostTmuxNever(_ref, session.hostId),
    snooze: () =>
        _ref.read(tmuxInstallSnoozeProvider.notifier).snooze(session.hostId),
    restartInTmux: () =>
        _ref.read(sessionManagerProvider.notifier).restartInTmux(session.id),
  );
}

final tmuxInstallAssistantsProvider = Provider<TmuxInstallAssistants>(
  TmuxInstallAssistants.new,
);

/// Saves "never use tmux" for [hostId].
Future<void> setHostTmuxNever(Ref ref, String hostId) async {
  final host = await ref.read(hostRepositoryProvider).byId(hostId);
  if (host == null) return;
  await ref
      .read(hostsControllerProvider)
      .save(
        host.copyWith(
          tmuxMode: HostTmuxMode.never,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
}
