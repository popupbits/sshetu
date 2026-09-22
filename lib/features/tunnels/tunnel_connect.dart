import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/background/keep_alive_service.dart';
import '../../core/error/error_logger.dart';
import '../../core/providers.dart';
import '../../core/ssh/host_key.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/tunnel_runner.dart';
import '../../core/ui/feedback.dart';
import '../../l10n/app_localizations.dart';
import '../hosts/widgets/host_key_dialog.dart';
import '../hosts/widgets/keyboard_interactive_dialog.dart';
import '../hosts/widgets/secret_dialog.dart';
import 'domain/tunnel.dart';
import 'tunnels_controller.dart';

/// Starts [tunnel], wiring the same host-key and secret dialogs a terminal
/// connection uses.
///
/// One entry point for every place a tunnel can be started — a list row, its
/// menu — so a connection's dialogs are never wired up differently in two
/// places, and host key verification is never something a second call site
/// forgets to pass through.
Future<void> startTunnel(
  BuildContext context,
  WidgetRef ref,
  Tunnel tunnel,
) async {
  final l10n = AppLocalizations.of(context);
  final host = await ref.read(hostRepositoryProvider).byId(tunnel.hostId);
  if (host == null) {
    if (context.mounted) context.toast(l10n.tunnelsHostMissing, isError: true);
    return;
  }

  try {
    await ref
        .read(tunnelRunnersProvider.notifier)
        .start(
          tunnel,
          host: host,
          onUnknownHostKey: (presentation) async {
            if (!context.mounted) return false;
            return showHostKeyDialog(context, presentation);
          },
          prompt: (request) async {
            if (!context.mounted) return null;
            final outcome = await showSecretDialog(context, request);
            return switch (outcome) {
              SecretSupplied(:final response) => response,
              // A tunnel has no open shell to retry into the way a terminal
              // connection does, so "use a key instead" here just cancels —
              // the host editor is where that choice actually belongs.
              SecretUseIdentity() || null => null,
            };
          },
          interactivePrompt: (request) async {
            if (!context.mounted) return null;
            return showKeyboardInteractiveDialog(context, request);
          },
        );
  } on SshConnectionException catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'tunnel');
    if (!context.mounted) return;
    final cause = error.cause;
    if (cause is HostKeyRejected && cause.verdict == HostKeyVerdict.changed) {
      await showHostKeyChangedDialog(context, cause.presentation);
      return;
    }
    context.toast(error.message, isError: true);
    return;
  } on Object catch (error, stackTrace) {
    // Everything that can fail before the runner even has a status to report
    // lands here — resolving the host, opening the connection. Without this
    // the failure is invisible and the toggle just looks stuck.
    ErrorLogger.instance.record(error, stackTrace, source: 'tunnel');
    if (context.mounted) context.toast('$error', isError: true);
    return;
  }

  if (!context.mounted) return;
  final status = ref.read(tunnelRunnersProvider)[tunnel.id];
  if (status != null && status.state == TunnelRunState.failed) {
    context.toast(status.error ?? l10n.tunnelsStartFailed, isError: true);
  } else {
    // After the handshake's dialogs, never on top of them (Android only).
    unawaited(ref.read(keepAliveControllerProvider).askForNotificationsOnce());
  }
}

/// Stops [tunnel]. Symmetric with [startTunnel] mostly so call sites never
/// have to remember which layer owns which half.
Future<void> stopTunnel(WidgetRef ref, Tunnel tunnel) =>
    ref.read(tunnelRunnersProvider.notifier).stop(tunnel);
