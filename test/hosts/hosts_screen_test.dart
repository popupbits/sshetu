import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/features/hosts/domain/host_group.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/hosts/hosts_screen.dart';
import 'package:sshetu/features/hosts/widgets/host_group_header.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The host list: search, groups, tags and notes.
void main() {
  final now = DateTime.utc(2026, 1, 1);

  SshHost host(
    String label, {
    String? group,
    List<String> tags = const [],
    String? notes,
  }) => SshHost(
    id: label,
    label: label,
    hostname: '$label.example.com',
    username: 'root',
    groupId: group,
    tags: tags,
    notes: notes,
    createdAt: now,
    updatedAt: now,
  );

  HostGroup folder(String id, String name) =>
      HostGroup(id: id, name: name, createdAt: now, updatedAt: now);

  Future<void> pump(
    WidgetTester tester,
    List<SshHost> hosts, {
    List<HostGroup> groups = const [],
    Size size = const Size(800, 600),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostsProvider.overrideWith((ref) => hosts),
          hostGroupsProvider.overrideWith((ref) => groups),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: HostsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('search', () {
    // A field for narrowing an empty list can do nothing but sit there, and
    // on an otherwise empty screen it is the heaviest element present.
    testWidgets('no search field when there are no hosts at all', (
      tester,
    ) async {
      await pump(tester, []);

      expect(find.byType(SearchBar), findsNothing);
      // The way out of the empty state is still there.
      expect(find.text('Import from OpenSSH'), findsOneWidget);
    });

    testWidgets('a search field as soon as there is a host', (tester) async {
      await pump(tester, [host('bastion')]);

      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.text('bastion'), findsOneWidget);
    });

    testWidgets('the field survives a query that matches nothing', (
      tester,
    ) async {
      // Otherwise the field disappears along with the results, taking the
      // only way to clear the query with it.
      await pump(tester, [host('bastion')]);

      await tester.enterText(find.byType(SearchBar), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.text('bastion'), findsNothing);
    });

    testWidgets('search reaches into notes', (tester) async {
      await pump(tester, [
        host('web', notes: 'restart nginx after deploy'),
        host('db'),
      ]);

      await tester.enterText(find.byType(SearchBar), 'nginx');
      await tester.pumpAndSettle();

      expect(find.text('web'), findsOneWidget);
      expect(find.text('db'), findsNothing);
    });
  });

  group('groups', () {
    final hosts = [
      host('web', group: 'prod'),
      host('db', group: 'prod'),
      host('laptop'),
    ];
    final groups = [folder('prod', 'Production'), folder('empty', 'Archive')];

    testWidgets('no groups means no headers — the list is unchanged', (
      tester,
    ) async {
      await pump(tester, [host('web'), host('db')]);

      expect(find.byType(HostGroupHeader), findsNothing);
      expect(find.text('Ungrouped'), findsNothing);
    });

    for (final (name, size) in [
      ('compact', const Size(390, 800)),
      ('expanded', const Size(1400, 900)),
    ]) {
      testWidgets('sections with headers at $name width', (tester) async {
        await pump(tester, hosts, groups: groups, size: size);

        expect(find.text('Production'), findsOneWidget);
        expect(find.text('Archive'), findsOneWidget);
        expect(find.text('Ungrouped'), findsOneWidget);
        // An empty group says so rather than looking like a broken header.
        expect(
          find.text(
            'No hosts in this group yet. Choose it in a host\'s editor.',
          ),
          findsOneWidget,
        );
        expect(find.text('web'), findsOneWidget);
        expect(find.text('laptop'), findsOneWidget);

        // Order: Production's hosts under its header, Ungrouped last.
        final prodY = tester.getTopLeft(find.text('Production')).dy;
        final webY = tester.getTopLeft(find.text('web')).dy;
        final ungroupedY = tester.getTopLeft(find.text('Ungrouped')).dy;
        final laptopY = tester.getTopLeft(find.text('laptop')).dy;
        expect(prodY, lessThan(webY));
        expect(webY, lessThan(ungroupedY));
        expect(ungroupedY, lessThan(laptopY));

        // Headers are comfortable touch targets.
        final header = tester.getSize(find.byType(HostGroupHeader).first);
        expect(header.height, greaterThanOrEqualTo(HostGroupHeader.height));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tapping a header folds its hosts away and back', (
      tester,
    ) async {
      await pump(tester, hosts, groups: groups);

      await tester.tap(find.text('Production'));
      await tester.pumpAndSettle();
      expect(find.text('web'), findsNothing);
      expect(find.text('db'), findsNothing);
      expect(find.text('laptop'), findsOneWidget);

      await tester.tap(find.text('Production'));
      await tester.pumpAndSettle();
      expect(find.text('web'), findsOneWidget);
    });

    testWidgets('a search hides groups it found nothing in', (tester) async {
      await pump(tester, hosts, groups: groups);

      await tester.enterText(find.byType(SearchBar), 'laptop');
      await tester.pumpAndSettle();

      expect(find.text('Production'), findsNothing);
      expect(find.text('Archive'), findsNothing);
      // One in the list; the other is the query in the search field.
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('laptop'),
        ),
        findsOneWidget,
      );
    });
  });

  group('tags', () {
    final hosts = [
      host('web', tags: const ['prod', 'eu']),
      host('db', tags: const ['prod']),
      host('laptop'),
    ];

    testWidgets('no tag row when nothing is tagged', (tester) async {
      await pump(tester, [host('web')]);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('a tag chip narrows the list, and clears', (tester) async {
      await pump(tester, hosts);

      expect(find.widgetWithText(FilterChip, 'prod'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'eu'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'eu'));
      await tester.pumpAndSettle();
      expect(find.text('web'), findsOneWidget);
      expect(find.text('db'), findsNothing);
      expect(find.text('laptop'), findsNothing);

      await tester.tap(find.byTooltip('Clear tag filter'));
      await tester.pumpAndSettle();
      expect(find.text('laptop'), findsOneWidget);
    });

    for (final (name, size) in [
      ('compact', const Size(360, 700)),
      ('expanded', const Size(1400, 900)),
    ]) {
      testWidgets('rows with many tags do not overflow at $name width', (
        tester,
      ) async {
        await pump(tester, [
          host(
            'a-server-with-a-rather-long-descriptive-name',
            tags: const ['production', 'eu-west-1', 'database', 'critical'],
            notes: 'note',
          ),
        ], size: size);

        expect(tester.takeException(), isNull);
        // Two pills on the row, the rest counted.
        expect(find.text('+2'), findsOneWidget);
      });
    }
  });

  testWidgets('a host with notes offers them from its menu', (tester) async {
    await pump(tester, [host('web', notes: 'VPN first, then port 2222')]);

    await tester.tap(find.byIcon(PiconsRegular.dotsThreeVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    expect(find.text('VPN first, then port 2222'), findsOneWidget);
  });
}
