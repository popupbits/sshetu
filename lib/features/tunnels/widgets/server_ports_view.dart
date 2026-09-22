import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/error/error_logger.dart';
import '../../../core/ssh/ssh_connection.dart';
import '../../../core/ssh/tunnel_runner.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../core/util/launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../server_info/data/server_exec.dart';
import '../../server_info/server_stats_monitor.dart' show MonitorStatus;
import '../ad_hoc_forwards.dart';
import '../domain/listening_ports.dart';
import '../ports_monitor.dart';
import '../tunnel_connect.dart';
import '../tunnels_controller.dart';

/// "Ports on this server": what the machine behind a terminal tab is
/// listening on, each with a one-tap forward to this device.
///
/// Polls while it is on screen and the app is in the foreground, and not
/// otherwise — see [PortsMonitor]. Nothing is ever forwarded without a tap.
class ServerPortsView extends ConsumerStatefulWidget {
  const ServerPortsView({
    required this.exec,
    required this.sessionId,
    required this.hostId,
    required this.connection,
    this.alsoIgnore = const {},
    this.monitorFactory,
    super.key,
  });

  final ServerExec exec;

  /// The tab whose connection forwards ride, and the host they belong to.
  final String sessionId;
  final String hostId;
  final SshConnection connection;

  /// Hidden besides the system ports: the sshd this connection uses.
  final Set<int> alsoIgnore;

  /// For tests: a monitor with another interval.
  final PortsMonitor Function(ServerExec exec)? monitorFactory;

  @override
  ConsumerState<ServerPortsView> createState() => _ServerPortsViewState();
}

class _ServerPortsViewState extends ConsumerState<ServerPortsView> {
  late final PortsMonitor _monitor =
      widget.monitorFactory?.call(widget.exec) ??
      PortsMonitor(widget.exec, alsoIgnore: widget.alsoIgnore);
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _foreground = false;
        _sync();
      },
      onShow: () {
        _foreground = true;
        _sync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  void _sync() {
    if (_foreground && _visible) {
      _monitor.start();
    } else {
      _monitor.stop();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _monitor,
      builder: (context, _) {
        final ports = _monitor.ports;
        final status = _monitor.status;
        if (ports.isEmpty) {
          return switch (status) {
            MonitorStatus.loading => const LoadingView(),
            MonitorStatus.offline => EmptyView(
              icon: PiconsRegular.plugs,
              title: l10n.serverInfoOffline,
              message: l10n.portsOfflineBody,
            ),
            MonitorStatus.error => ErrorView(
              message: l10n.portsError('${_monitor.error}'),
              onRetry: () => unawaited(_monitor.poll()),
              retryLabel: l10n.actionRetry,
            ),
            MonitorStatus.ready => EmptyView(
              icon: PiconsRegular.plugs,
              title: l10n.portsEmpty,
              message: l10n.portsEmptyBody,
            ),
          };
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status == MonitorStatus.offline ||
                status == MonitorStatus.error)
              _Banner(
                text: status == MonitorStatus.offline
                    ? l10n.portsOfflineBody
                    : l10n.portsError('${_monitor.error}'),
              ),
            Expanded(
              child: ListView.builder(
                key: const Key('ports.list'),
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                itemCount: ports.length,
                itemBuilder: (context, index) =>
                    _PortRow(port: ports[index], view: widget),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One listening port: its number, its program, and either Forward or the
/// forward it already has.
class _PortRow extends ConsumerWidget {
  const _PortRow({required this.port, required this.view});

  final ListeningPort port;
  final ServerPortsView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final forward = ref.watch(
      adHocForwardsProvider.select(
        (forwards) => forwards
            .where(
              (f) => f.sessionId == view.sessionId && f.remotePort == port.port,
            )
            .firstOrNull,
      ),
    );

    final reach = port.isLoopbackOnly
        ? l10n.portsLoopbackOnly
        : port.isWildcard
        ? l10n.portsAllInterfaces
        : port.addresses.join(', ');

    return ListTile(
      key: Key('ports.row.${port.port}'),
      visualDensity: VisualDensity.compact,
      title: Row(
        children: [
          Text(
            '${port.port}',
            style: Mono.apply(theme.textTheme.bodyMedium)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          if (port.process != null) ...[
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Text(
                port.process!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      // Once forwarded, the line under the port is where to point a client
      // — the one thing someone needs next, where there is room for it.
      subtitle: forward != null && forward.status.isRunning
          ? Text(
              forward.address,
              key: Key('ports.address.${forward.remotePort}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Mono.apply(theme.textTheme.labelMedium)
                  .copyWith(color: scheme.primary),
            )
          : Text(
              reach,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
      trailing: _trailing(context, ref, l10n, forward),
    );
  }

  Widget _trailing(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AdHocForward? forward,
  ) {
    if (forward != null && forward.status.state == TunnelRunState.starting) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.sm),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (forward != null && forward.status.isRunning) {
      return _ForwardedChip(forward: forward);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (forward != null && forward.status.state == TunnelRunState.failed)
          Tooltip(
            message: forward.status.error ?? l10n.tunnelStatusFailed,
            child: Icon(
              PiconsRegular.warningCircle,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        Tooltip(
          message: l10n.portsForwardTooltip(port.port),
          child: TextButton(
            key: Key('ports.forward.${port.port}'),
            onPressed: () => unawaited(_forward(context, ref)),
            child: Text(l10n.portsForward),
          ),
        ),
      ],
    );
  }

  Future<void> _forward(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final forward = await ref
          .read(adHocForwardsProvider.notifier)
          .forward(
            sessionId: view.sessionId,
            hostId: view.hostId,
            connection: view.connection,
            port: port,
          );
      if (!context.mounted) return;
      if (forward.status.state == TunnelRunState.failed) {
        context.toast(
          l10n.portsForwardFailed(port.port, forward.status.error ?? ''),
          isError: true,
        );
      }
    } on Object catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'tunnel');
      if (context.mounted) {
        context.toast(
          l10n.portsForwardFailed(port.port, '$error'),
          isError: true,
        );
      }
    }
  }
}

/// What can be done with a running ad-hoc forward.
class _ForwardedChip extends ConsumerWidget {
  const _ForwardedChip({required this.forward});

  final AdHocForward forward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuAnchor(
          menuChildren: [
            MenuItemButton(
              key: const Key('ports.openInBrowser'),
              leadingIcon: const Icon(PiconsRegular.globe),
              onPressed: () => unawaited(Launcher.openUrl(forward.url)),
              child: Text(l10n.portsOpenInBrowser),
            ),
            MenuItemButton(
              key: const Key('ports.copyAddress'),
              leadingIcon: const Icon(PiconsRegular.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: forward.address));
                if (context.mounted) {
                  context.toast(l10n.portsCopied(forward.address));
                }
              },
              child: Text(l10n.portsCopyAddress),
            ),
            MenuItemButton(
              key: const Key('ports.saveAsTunnel'),
              leadingIcon: const Icon(PiconsRegular.floppyDisk),
              onPressed: () =>
                  unawaited(saveAdHocAsTunnel(context, ref, forward)),
              child: Text(l10n.portsSaveAsTunnel),
            ),
            MenuItemButton(
              key: const Key('ports.stopForward'),
              leadingIcon: const Icon(PiconsRegular.stopCircle),
              onPressed: () => unawaited(
                ref.read(adHocForwardsProvider.notifier).stop(forward.id),
              ),
              child: Text(l10n.portsStopForward),
            ),
          ],
          builder: (context, controller, _) => IconButton(
            key: Key('ports.menu.${forward.remotePort}'),
            tooltip: l10n.portsForwardActions,
            icon: const Icon(PiconsRegular.dotsThreeVertical, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
      ],
    );
  }
}

final Random _random = Random.secure();

String _newTunnelId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(
    20,
    (_) => alphabet[_random.nextInt(alphabet.length)],
  ).join();
}

/// Turns [forward] into a saved tunnel on the same port: stops the ad-hoc
/// one to free the port, writes the row, and starts the saved one through
/// the standard [startTunnel] — which rides the tab's connection, so no
/// prompt is raised.
Future<void> saveAdHocAsTunnel(
  BuildContext context,
  WidgetRef ref,
  AdHocForward forward,
) async {
  final l10n = AppLocalizations.of(context);
  final tunnel = tunnelFromAdHoc(
    forward,
    id: _newTunnelId(),
    now: DateTime.now().toUtc(),
  );
  await ref.read(adHocForwardsProvider.notifier).stop(forward.id);
  await ref.read(tunnelsControllerProvider).save(tunnel);
  if (!context.mounted) return;
  await startTunnel(context, ref, tunnel);
  if (context.mounted) context.toast(l10n.portsSavedAsTunnel(tunnel.label));
}
