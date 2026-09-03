import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../hosts/domain/ssh_host.dart';
import '../hosts/hosts_controller.dart';
import 'domain/tunnel.dart';
import 'tunnels_controller.dart';
import 'widgets/tunnel_tile.dart';

/// The Tunnels destination: every saved port forward, grouped by host.
class TunnelsScreen extends ConsumerWidget {
  const TunnelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tunnelsAsync = ref.watch(tunnelsProvider);
    final hostsAsync = ref.watch(hostsProvider);

    if (tunnelsAsync.isLoading || hostsAsync.isLoading) {
      return const LoadingView();
    }
    final tunnelsError = tunnelsAsync.error;
    if (tunnelsError != null) {
      return ErrorView(
        message: '$tunnelsError',
        onRetry: () => ref.invalidate(tunnelsProvider),
        retryLabel: l10n.actionRetry,
      );
    }
    final hostsError = hostsAsync.error;
    if (hostsError != null) {
      return ErrorView(
        message: '$hostsError',
        onRetry: () => ref.invalidate(hostsProvider),
        retryLabel: l10n.actionRetry,
      );
    }

    final tunnels = tunnelsAsync.value ?? const [];
    final hosts = hostsAsync.value ?? const [];

    return tunnels.isEmpty
        ? _Empty(hasHosts: hosts.isNotEmpty)
        : _TunnelList(tunnels: tunnels, hosts: hosts);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hasHosts});

  final bool hasHosts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyView(
      icon: PiconsRegular.plugs,
      title: l10n.tunnelsEmptyTitle,
      message: l10n.tunnelsEmptyBody,
      // A forward always belongs to a host, so with none saved yet the useful
      // next step is adding one, not opening an editor whose host picker
      // would have nothing in it.
      action: hasHosts
          ? FilledButton.icon(
              onPressed: () => context.pushTo(Routes.tunnelNew),
              icon: const Icon(PiconsRegular.plus),
              label: Text(l10n.tunnelsAdd),
            )
          : FilledButton.icon(
              onPressed: () => context.pushTo(Routes.hostNew),
              icon: const Icon(PiconsRegular.plus),
              label: Text(l10n.hostsAdd),
            ),
    );
  }
}

class _TunnelList extends StatelessWidget {
  const _TunnelList({required this.tunnels, required this.hosts});

  final List<Tunnel> tunnels;
  final List<SshHost> hosts;

  @override
  Widget build(BuildContext context) {
    final byHost = <String, List<Tunnel>>{};
    for (final tunnel in tunnels) {
      (byHost[tunnel.hostId] ??= []).add(tunnel);
    }

    // Ordered the same way the Hosts screen is — most recently used first —
    // so a host's place in this list matches where it is everywhere else.
    // A tunnel whose host was itself deleted has nothing to group under; the
    // database cascades that delete away, so this is defensive, not expected.
    final sections = [
      for (final host in hosts)
        if (byHost[host.id] case final forwards? when forwards.isNotEmpty)
          (host: host, forwards: forwards),
    ];

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.fabClearance),
        children: [
          for (final section in sections) ...[
            SectionLabel(
              section.host.label,
              trailing: IconButton(
                icon: const Icon(PiconsRegular.plus, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: AppLocalizations.of(context).tunnelsAdd,
                onPressed: () =>
                    context.pushTo(Routes.tunnelNewFor(section.host.id)),
              ),
            ),
            for (final tunnel in section.forwards) TunnelTile(tunnel: tunnel),
          ],
        ],
      ),
    );
  }
}
