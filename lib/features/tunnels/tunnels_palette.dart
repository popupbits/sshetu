import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picons/picons.dart';

import '../../core/ssh/tunnel_runner.dart';
import '../../l10n/app_localizations.dart';
import '../palette/domain/palette_item.dart';
import '../sessions/open_screens.dart';
import 'domain/tunnel.dart';
import 'tunnel_connect.dart';
import 'tunnels_controller.dart';

/// Every saved forward, started or stopped from wherever you are.
///
/// The primary action follows the tunnel's state, the way the row's toggle
/// does: Start when it is stopped or failed, Stop while it is starting or
/// running.
final tunnelPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>((ref, l10n) {
      final tunnels = ref.watch(tunnelsProvider).value ?? const <Tunnel>[];
      final statuses = ref.watch(tunnelRunnersProvider);
      return [
        for (final tunnel in tunnels)
          PaletteItem(
            id: 'tunnel:${tunnel.id}',
            title: tunnel.label,
            subtitle: tunnel.mapping,
            category: PaletteCategory.tunnel,
            icon: PiconsRegular.arrowsLeftRight,
            actions: [
              switch (statuses[tunnel.id]?.state ?? TunnelRunState.stopped) {
                TunnelRunState.starting ||
                TunnelRunState.running => PaletteAction(
                  id: 'stop',
                  label: l10n.paletteTunnelStop,
                  icon: PiconsRegular.stop,
                  run: (context, ref) => stopTunnel(ref, tunnel),
                ),
                TunnelRunState.stopped ||
                TunnelRunState.failed => PaletteAction(
                  id: 'start',
                  label: l10n.paletteTunnelStart,
                  icon: PiconsRegular.play,
                  run: (context, ref) => startTunnel(context, ref, tunnel),
                ),
              },
              PaletteAction(
                id: 'edit',
                label: l10n.tunnelsEdit,
                icon: PiconsRegular.pencilSimple,
                run: (context, ref) =>
                    openTunnelEditor(context, ref, tunnelId: tunnel.id),
              ),
            ],
          ),
        PaletteItem(
          id: 'action:newTunnel',
          title: l10n.tunnelsAdd,
          category: PaletteCategory.action,
          icon: PiconsRegular.plus,
          actions: [
            PaletteAction(
              id: 'open',
              label: l10n.tunnelsAdd,
              icon: PiconsRegular.plus,
              run: (context, ref) => openTunnelEditor(context, ref),
            ),
          ],
        ),
      ];
    });
