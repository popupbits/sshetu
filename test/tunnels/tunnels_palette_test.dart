import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/tunnel_runner.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';
import 'package:sshetu/features/tunnels/tunnels_palette.dart';
import 'package:sshetu/l10n/app_localizations.dart';

class _Runners extends TunnelRunnerManager {
  _Runners(this.initial);

  final Map<String, TunnelRunnerStatus> initial;

  @override
  Map<String, TunnelRunnerStatus> build() => initial;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime.utc(2026);

  Tunnel tunnel(String id) => Tunnel(
    id: id,
    hostId: 'h',
    label: 'Grafana $id',
    kind: TunnelKind.local,
    listenPort: 3000,
    targetHost: 'grafana',
    targetPort: 3000,
    createdAt: now,
    updatedAt: now,
  );

  Future<List<PaletteItem>> itemsFor(
    Map<String, TunnelRunnerStatus> statuses,
  ) async {
    final container = ProviderContainer(
      overrides: [
        tunnelsProvider.overrideWith((ref) => [tunnel('a'), tunnel('b')]),
        tunnelRunnersProvider.overrideWith(() => _Runners(statuses)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(tunnelsProvider.future);
    return container.read(tunnelPaletteItemsProvider(l10n));
  }

  test('a stopped tunnel starts; a running one stops', () async {
    final items = await itemsFor({
      'b': const TunnelRunnerStatus(state: TunnelRunState.running),
    });
    final a = items.firstWhere((i) => i.id == 'tunnel:a');
    final b = items.firstWhere((i) => i.id == 'tunnel:b');

    expect(a.category, PaletteCategory.tunnel);
    expect(a.subtitle, tunnel('a').mapping);
    expect([for (final x in a.actions) x.id], ['start', 'edit']);
    expect([for (final x in b.actions) x.id], ['stop', 'edit']);
  });

  test('starting counts as running, failed as stopped', () async {
    final items = await itemsFor({
      'a': const TunnelRunnerStatus(state: TunnelRunState.starting),
      'b': const TunnelRunnerStatus(state: TunnelRunState.failed),
    });
    expect(items.firstWhere((i) => i.id == 'tunnel:a').primary.id, 'stop');
    expect(items.firstWhere((i) => i.id == 'tunnel:b').primary.id, 'start');
  });

  test('adding a tunnel is offered too', () async {
    final items = await itemsFor(const {});
    expect(items.last.id, 'action:newTunnel');
  });
}
