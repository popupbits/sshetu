import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/router/navigation.dart';
import '../../../core/router/routes.dart';
import '../../../core/ssh/tunnel_runner.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/tunnel.dart';
import '../tunnel_connect.dart';
import '../tunnels_controller.dart';

/// One saved forward, as a row.
///
/// Shows what a `ssh -L/-R/-D` command line would: the kind, the
/// `listen → target` mapping in a tabular monospace so a column of them lines
/// up, and — the thing a static config file cannot show — whether it is
/// actually running right now.
class TunnelTile extends ConsumerWidget {
  const TunnelTile({required this.tunnel, super.key});

  final Tunnel tunnel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(
      tunnelRunnersProvider.select(
        (s) => s[tunnel.id] ?? const TunnelRunnerStatus.stopped(),
      ),
    );

    return ListTile(
      onTap: () => context.pushTo(Routes.tunnelEditFor(tunnel.id)),
      visualDensity: VisualDensity.compact,
      minVerticalPadding: Spacing.sm,
      leading: Icon(_kindIcon(tunnel.kind), color: scheme.onSurfaceVariant),
      title: Row(
        children: [
          Flexible(
            child: Text(
              tunnel.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!tunnel.isListenLoopback) ...[
            const SizedBox(width: Spacing.sm),
            Tooltip(
              message: l10n.tunnelEditorNotLoopback,
              child: Icon(
                PiconsRegular.shieldWarning,
                size: 13,
                color: scheme.error,
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              tunnel.mapping,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Mono.apply(theme.textTheme.bodySmall)
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          _StatusLabel(status: status),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(tunnel: tunnel, status: status),
          _TunnelMenu(tunnel: tunnel),
        ],
      ),
    );
  }

  static IconData _kindIcon(TunnelKind kind) => switch (kind) {
    TunnelKind.local => PiconsRegular.arrowRight,
    TunnelKind.remote => PiconsRegular.arrowLeft,
    TunnelKind.socks => PiconsRegular.globeSimple,
  };
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final TunnelRunnerStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (text, color) = switch (status.state) {
      TunnelRunState.stopped => (
        l10n.tunnelStatusStopped,
        scheme.onSurfaceVariant,
      ),
      TunnelRunState.starting => (
        l10n.tunnelStatusStarting,
        scheme.onSurfaceVariant,
      ),
      TunnelRunState.running => (l10n.tunnelStatusRunning, scheme.primary),
      TunnelRunState.failed => (l10n.tunnelStatusFailed, scheme.error),
    };
    final connections = status.connections;
    final label = status.isRunning && connections != null
        ? '$text · ${l10n.tunnelActiveConnections(connections)}'
        : text;

    return Tooltip(
      message: status.error ?? text,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _ToggleButton extends ConsumerWidget {
  const _ToggleButton({required this.tunnel, required this.status});

  final Tunnel tunnel;
  final TunnelRunnerStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = status.state == TunnelRunState.starting;

    if (status.isRunning) {
      return IconButton(
        tooltip: l10n.tunnelsStop,
        icon: const Icon(PiconsRegular.stopCircle),
        visualDensity: VisualDensity.compact,
        onPressed: () => stopTunnel(ref, tunnel),
      );
    }
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.sm),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: l10n.tunnelsStart,
      icon: const Icon(PiconsRegular.playCircle),
      visualDensity: VisualDensity.compact,
      onPressed: () => startTunnel(context, ref, tunnel),
    );
  }
}

class _TunnelMenu extends ConsumerWidget {
  const _TunnelMenu({required this.tunnel});

  final Tunnel tunnel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(PiconsRegular.pencilSimple),
          onPressed: () => context.pushTo(Routes.tunnelEditFor(tunnel.id)),
          child: Text(l10n.tunnelsEdit),
        ),
        MenuItemButton(
          leadingIcon: Icon(PiconsRegular.trash, color: scheme.error),
          onPressed: () async {
            final confirmed = await context.confirm(
              title: l10n.tunnelsDeleteConfirm,
              message: l10n.tunnelsDeleteBody,
              confirmLabel: l10n.tunnelsDelete,
              isDestructive: true,
            );
            if (confirmed) {
              await ref.read(tunnelsControllerProvider).delete(tunnel);
            }
          },
          child: Text(l10n.tunnelsDelete),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(PiconsRegular.dotsThreeVertical, size: 18),
        visualDensity: VisualDensity.compact,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
