import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/hosts/hosts_palette.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime.utc(2026);

  Future<List<PaletteItem>> itemsFor(List<SshHost> hosts) async {
    final container = ProviderContainer(
      overrides: [hostsProvider.overrideWith((ref) => hosts)],
    );
    addTearDown(container.dispose);
    await container.read(hostsProvider.future);
    return container.read(hostPaletteItemsProvider(l10n));
  }

  test('one item per host, connecting by default', () async {
    final items = await itemsFor([
      SshHost(
        id: 'h1',
        label: 'web-01',
        hostname: 'web-01.example.com',
        username: 'deploy',
        port: 2222,
        tags: const ['prod'],
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final host = items.firstWhere((i) => i.id == 'host:h1');
    expect(host.title, 'web-01');
    expect(host.subtitle, 'deploy@web-01.example.com:2222');
    expect(host.category, PaletteCategory.host);
    expect(host.keywords, containsAll(['web-01.example.com', 'prod']));
    expect(
      [for (final a in host.actions) a.id],
      ['connect', 'edit', 'files', 'running'],
    );
    expect(host.primary.label, l10n.hostsConnect);
  });

  test('new host and import are always there, even with no hosts', () async {
    final items = await itemsFor(const []);
    expect(
      [for (final i in items) i.id],
      ['action:newHost', 'action:importOpenSsh'],
    );
  });

  test('ids carry the row id and nothing else', () async {
    final items = await itemsFor([
      SshHost(
        id: 'row-7',
        label: 'secret-name',
        hostname: '10.0.0.7',
        username: 'root',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final id = items.first.id;
    expect(id, 'host:row-7');
    expect(id, isNot(contains('secret-name')));
    expect(id, isNot(contains('10.0.0.7')));
  });
}
