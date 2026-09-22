import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/background/keep_alive_service.dart';
import '../../core/error/error_logger.dart';
import '../../core/providers.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/ssh/host_key.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/ui/feedback.dart';
import '../../core/util/responsive.dart';
import '../../core/ssh/ssh_target.dart';
import '../hosts/domain/ssh_host.dart';
import '../hosts/hosts_controller.dart';
import '../hosts/widgets/host_key_dialog.dart';
import '../hosts/widgets/keyboard_interactive_dialog.dart';
import '../hosts/widgets/secret_dialog.dart';
import '../tunnels/tunnel_connect.dart';
import 'session_manager.dart';

/// Opens a session to [host] and shows its terminal.
///
/// One function, called from every place that connects — the host list, a
/// row's menu, a keyboard shortcut — so the dialogs a connection can raise are
/// wired identically everywhere. Duplicating this per call site is how one
/// entry point ends up silently refusing unknown hosts because nobody
/// remembered to pass the handler.
///
/// [tmuxName], [resuming] and [ownsTmuxSession] open the tab on a session
/// kept on the server instead of a new one — see [SessionManager.connect].
/// [connection] hands over one already open to [host]. [navigate] false
/// leaves the screen where it is, for reopening several tabs in a row.
///
/// Returns the tab, or null when none was opened.
Future<TerminalSession?> connectToHost(
  BuildContext context,
  WidgetRef ref,
  SshHost host, {
  String? tmuxName,
  bool resuming = false,
  bool ownsTmuxSession = true,
  SshConnection? connection,
  bool navigate = true,
  bool activate = true,
}) async {
  final manager = ref.read(sessionManagerProvider.notifier);

  // Set when the user answers a password prompt with "use a key instead".
  // The running attempt cannot change its mind mid-handshake — dartssh2 was
  // given its identities before the socket opened — so the choice is recorded,
  // this attempt is cancelled, and the connection is made again with the key.
  SecretUseIdentity? keyChoice;

  final TerminalSession session;
  try {
    session = await manager.connect(
      host,
      onUnknownHostKey: (presentation) async {
        if (!context.mounted) return false;
        return showHostKeyDialog(context, presentation);
      },
      prompt: (request) async {
        if (!context.mounted) return null;
        final outcome = await showSecretDialog(context, request);
        return switch (outcome) {
          SecretSupplied(:final response) => response,
          // Cancels this attempt on purpose; the retry below carries the key.
          SecretUseIdentity() => () {
            keyChoice = outcome;
            return null;
          }(),
          null => null,
        };
      },
      interactivePrompt: (request) async {
        if (!context.mounted) return null;
        return showKeyboardInteractiveDialog(context, request);
      },
      tmuxName: tmuxName,
      resuming: resuming,
      ownsTmuxSession: ownsTmuxSession,
      connection: connection,
      activate: activate,
    );
  } on Object catch (error, stackTrace) {
    // Everything that can fail *before* a session exists lands here — reading
    // known hosts, resolving a jump chain, the first database touch. Without
    // this the future completes with an error nobody is listening to and the
    // tap simply does nothing, which is the single most confusing way for a
    // connection to fail.
    ErrorLogger.instance.record(error, stackTrace, source: 'connect');
    if (context.mounted) context.toast('$error');
    return null;
  }

  if (!context.mounted) return session;

  // Retry with the key the user reached for, rather than making them cancel,
  // find the host editor, change it, and start again.
  final choice = keyChoice;
  if (choice != null) {
    manager.close(session.id);
    final withKey = host.copyWith(
      identityId: choice.identityId,
      authMethod: SshAuthMethod.publicKey,
      updatedAt: DateTime.now().toUtc(),
    );
    // Saved by default, because being asked for a password when a key would
    // have worked means the host is configured wrong — fixing it for this
    // attempt only would raise the same dialog next time.
    if (choice.remember) {
      await ref.read(hostsControllerProvider).save(withKey);
    }
    if (!context.mounted) return null;
    // The same tab, asked for again — its handed-over connection went with
    // the attempt just closed, so this one dials its own.
    return connectToHost(
      context,
      ref,
      withKey,
      tmuxName: tmuxName,
      resuming: resuming,
      ownsTmuxSession: ownsTmuxSession,
      navigate: navigate,
      activate: activate,
    );
  }

  // A refused host key deserves its own explanation rather than a generic
  // failure line: for a *changed* key it is the most important thing this app
  // ever tells anyone, and it must not be mistaken for a network glitch.
  final rejection = session.hostKeyRejection;
  if (rejection != null && rejection.verdict == HostKeyVerdict.changed) {
    await showHostKeyChangedDialog(context, rejection.presentation);
    if (context.mounted) manager.close(session.id);
    return null;
  }

  if (session.status == TerminalSessionStatus.failed) {
    context.toast(session.error ?? 'Could not connect');
  } else {
    // Only now, with every dialog of the handshake behind us (Android only).
    unawaited(ref.read(keepAliveControllerProvider).askForNotificationsOnce());
    // Fire-and-forget: this reuses the connection that just succeeded, so it
    // raises no dialog of its own (the host key is already trusted, the
    // credential already worked) and must not hold up navigating to the
    // terminal on a slow bind.
    unawaited(_autoStartTunnels(context, ref, host));
  }

  if (!context.mounted) return session;

  // Desktop needs no navigation at all: the terminal occupies the right of
  // the window already, and the new session is the selected tab. Sending the
  // user somewhere would only take the panel they were working in away from
  // them. A phone has no room for both, so there the terminal is a page.
  if (navigate && !context.useRail) {
    context.pushTo(Routes.terminalFor(session.id));
  }
  return session;
}

/// Starts every saved forward for [host] marked to start automatically.
///
/// This is the only place `Tunnel.autoStart` is honoured — a forward is
/// otherwise inert until someone taps it. Reusing [startTunnel] rather than
/// dialing the connection directly means a forward that somehow does need a
/// prompt (the reused connection was not actually live) gets the exact same
/// dialogs a manual start would.
Future<void> _autoStartTunnels(
  BuildContext context,
  WidgetRef ref,
  SshHost host,
) async {
  final tunnels = await ref.read(tunnelRepositoryProvider).forHost(host.id);
  for (final tunnel in tunnels.where((t) => t.autoStart)) {
    if (!context.mounted) return;
    await startTunnel(context, ref, tunnel);
  }
}

/// A connection to [host] for asking the server something, outside any tab.
///
/// Reuses an open tab's live connection when there is one — no handshake and
/// no prompt — and otherwise dials a bare one through the same dialogs a tab
/// uses, the way port forwarding does. [owned] says whether the caller must
/// close it: never a tab's, always a bare one's.
///
/// Null when it could not be opened; the reason has been shown.
Future<({SshConnection connection, bool owned})?> connectForQuery(
  BuildContext context,
  WidgetRef ref,
  SshHost host,
) async {
  final manager = ref.read(sessionManagerProvider.notifier);
  final shared = manager.connectionForHost(host.id);
  if (shared != null) return (connection: shared, owned: false);

  try {
    final connection = await manager.openBareConnection(
      host,
      onUnknownHostKey: (presentation) async {
        if (!context.mounted) return false;
        return showHostKeyDialog(context, presentation);
      },
      prompt: (request) async {
        if (!context.mounted) return null;
        final outcome = await showSecretDialog(context, request);
        return switch (outcome) {
          SecretSupplied(:final response) => response,
          // Nothing to retry into here; the host editor is where that
          // choice belongs.
          SecretUseIdentity() || null => null,
        };
      },
      interactivePrompt: (request) async {
        if (!context.mounted) return null;
        return showKeyboardInteractiveDialog(context, request);
      },
    );
    return (connection: connection, owned: true);
  } on SshConnectionException catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'connect');
    if (!context.mounted) return null;
    final cause = error.cause;
    if (cause is HostKeyRejected && cause.verdict == HostKeyVerdict.changed) {
      await showHostKeyChangedDialog(context, cause.presentation);
      return null;
    }
    context.toast(error.message, isError: true);
    return null;
  } on Object catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'connect');
    if (context.mounted) context.toast('$error', isError: true);
    return null;
  }
}
