import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/error/error_logger.dart';
import '../../core/providers.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/settings/device_identity.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/terminal/remote_shell.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/terminal/tmux_commands.dart';
import '../../core/ui/feedback.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../hosts/domain/ssh_host.dart';
import 'connect.dart';
import 'session_manager.dart';
import 'widgets/running_sessions_view.dart';

/// Asking one server about the sessions SSHetu keeps on it.
///
/// Over exec channels on a connection the caller already has — a tab's, or a
/// bare one — so listing and ending never type anything into a terminal.
class ServerSessions {
  const ServerSessions(
    this.connection, {
    this.timeout = const Duration(seconds: 15),
  });

  final SshConnection connection;
  final Duration timeout;

  /// Every SSHetu session on the server, from any device.
  Future<TmuxListing> list() async {
    final client = await connection.client();
    final output = await runRemoteCommand(
      client,
      tmuxListCommand(),
    ).timeout(timeout);
    return parseTmuxListing(output);
  }

  /// Ends session [name] and everything running in it.
  Future<void> end(String name) async {
    final client = await connection.client();
    await runRemoteCommand(client, tmuxKillCommand(name)).timeout(timeout);
  }
}

/// Shows the sessions SSHetu keeps on [host] — this device's and every other
/// device's — with Attach and End.
///
/// This is how something left running on the desktop is picked up on the
/// phone. Uses [connection] when given (the terminal tab's own); otherwise an
/// open tab's, or a bare connection dialled through the standard dialogs.
Future<void> openRunningSessions(
  BuildContext context,
  WidgetRef ref,
  SshHost host, {
  SshConnection? connection,
}) async {
  SshConnection transport;
  var owned = false;
  if (connection != null) {
    transport = connection;
  } else {
    final opened = await connectForQuery(context, ref, host);
    if (opened == null || !context.mounted) {
      if (opened?.owned ?? false) unawaited(opened!.connection.close());
      return;
    }
    transport = opened.connection;
    owned = opened.owned;
  }

  final backend = ServerSessions(transport);
  final manager = ref.read(sessionManagerProvider.notifier);
  final deviceId = ref.read(deviceIdProvider);

  final view = RunningSessionsView(
    hostLabel: host.label,
    deviceId: deviceId,
    load: backend.list,
    end: backend.end,
    isOpenHere: (name) => manager.tabForTmux(host.id, name) != null,
  );

  final chosen = await showRunningSessionsView(context, view);

  if (chosen == null || !context.mounted) {
    if (owned) unawaited(transport.close());
    return;
  }

  final existing = manager.tabForTmux(host.id, chosen);
  if (existing != null) {
    if (owned) unawaited(transport.close());
    manager.select(existing.id);
    // From a terminal, the screen already follows the selected tab.
    if (connection == null && !context.useRail) {
      context.pushTo(Routes.terminalFor(existing.id));
    }
    return;
  }

  try {
    await connectToHost(
      context,
      ref,
      host,
      tmuxName: chosen,
      resuming: true,
      // Borrowed: closing this tab lets go of the session, it does not end
      // it. It may be the desktop's, still wanted there.
      ownsTmuxSession: false,
      // A bare connection is handed to the tab rather than thrown away — no
      // second handshake, no second password prompt.
      connection: owned ? transport : null,
      // Opened from a terminal, the screen already follows the new tab.
      navigate: connection == null,
    );
  } on Object catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'running-sessions');
    if (context.mounted) {
      context.toast(
        AppLocalizations.of(context).runningSessionsAttachFailed('$error'),
        isError: true,
      );
    }
  }
}

/// [openRunningSessions] for the host behind an open tab, over the tab's own
/// connection while it is live.
Future<void> openRunningSessionsForTab(
  BuildContext context,
  WidgetRef ref,
  TerminalSession session,
) async {
  final host = await ref.read(hostRepositoryProvider).byId(session.hostId);
  if (host == null || !context.mounted) return;
  await openRunningSessions(
    context,
    ref,
    host,
    connection: session.connection.isConnected ? session.connection : null,
  );
}
