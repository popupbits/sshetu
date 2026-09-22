import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/app.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ui/views.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/keys/keys_controller.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';

/// Every destination, at the smallest phone anyone still ships.
///
/// Overflow is the characteristic mobile bug: a row that fits a 430pt iPhone
/// Pro Max and blows out on a 360pt Android, discovered by a user rather than
/// by us. Flutter reports it as an exception during layout, which means it can
/// simply be asserted on — and a screen that overflows in a test is a screen
/// with a yellow-and-black bar in someone's hand.
///
/// 320x568 is a small iPhone SE; 360x640 is the low end of Android. Both are
/// checked with real content rather than empty lists, because an empty state
/// is exactly the layout that never overflows.
void main() {
  const phones = {'iPhone SE': Size(320, 568), 'small Android': Size(360, 640)};

  final now = DateTime.utc(2026, 1, 1);

  /// Hosts with the awkward shapes: a very long label, a long address, tags,
  /// and the badges that share the title row.
  final hosts = [
    SshHost(
      id: 'h1',
      label: 'production-database-cluster-eu-west-1-primary',
      hostname: 'db-primary.internal.very-long-domain.example.com',
      username: 'postgres-service-account',
      port: 54321,
      allowLegacyAlgorithms: true,
      jumpHostId: 'h2',
      lastConnectedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    SshHost(
      id: 'h2',
      label: 'bastion',
      hostname: '10.0.0.4',
      username: 'root',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final tunnels = [
    Tunnel(
      id: 't1',
      hostId: 'h1',
      label: 'postgres on the primary, forwarded for local tooling',
      kind: TunnelKind.local,
      listenPort: 54320,
      targetHost: 'db-primary.internal.very-long-domain.example.com',
      targetPort: 5432,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final identities = [
    SshIdentity(
      id: 'k1',
      label: 'id_ed25519_work_laptop_2026',
      keyType: 'ssh-ed25519',
      fingerprint: 'SHA256:QGev/kcaxIwQ61sQgi+pgRq6NC2G0zoQaGMz5C+17Mg',
      hasPassphrase: true,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final snippets = [
    Snippet(
      id: 's1',
      label: 'restart every worker on the primary cluster and tail the log',
      body: 'sudo systemctl restart worker@{{n:1}}.service && journalctl -fu worker',
      tags: const ['production', 'workers', 'on-call'],
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          hostsProvider.overrideWith((ref) => hosts),
          identitiesProvider.overrideWith((ref) => identities),
          // Stubbed like the rest: unstubbed it reads a database this harness
          // has none of, and the screen renders its error state — which tests
          // the error view rather than the screen.
          tunnelsProvider.overrideWith((ref) => tunnels),
          snippetsProvider.overrideWith((ref) => snippets),
        ],
        child: const SshetuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in phones.entries) {
    group('on a ${entry.key}', () {
      testWidgets('the host list renders without overflowing', (tester) async {
        await pumpApp(tester, entry.value);
        expect(tester.takeException(), isNull);
        // The content is really there — an empty list cannot overflow, so a
        // pass with nothing rendered would prove nothing.
        expect(find.text('bastion'), findsOneWidget);
      });

      testWidgets('every destination renders without overflowing', (
        tester,
      ) async {
        await pumpApp(tester, entry.value);

        // Walk the bottom bar rather than driving the router directly: this is
        // the path a user takes, and it exercises the shell's own switching.
        for (final destination in const [
          'Sessions',
          'Keys',
          'Tunnels',
          'Settings',
        ]) {
          final tab = find.text(destination);
          if (tab.evaluate().isEmpty) continue;
          await tester.tap(tab.first);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$destination overflowed on a ${entry.key}',
          );
        }
      });
    });
  }

  testWidgets('the bottom bar holds five destinations, and Snippets is '
      'reached from Sessions', (tester) async {
    // Six labels do not fit a 320pt bar. Snippets is the one left off it,
    // because it is used from a terminal and managed from Sessions.
    await pumpApp(tester, const Size(320, 568));

    final bar = find.byType(NavigationBar);
    expect(tester.widget<NavigationBar>(bar).destinations, hasLength(5));
    expect(
      find.descendant(of: bar, matching: find.text('Snippets')),
      findsNothing,
    );

    await tester.tap(find.descendant(of: bar, matching: find.text('Sessions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell.openSnippets')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The app bar names it, and the bar keeps Sessions lit — where it is
    // reached from.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Snippets')),
      findsOneWidget,
    );
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 1);
    expect(find.textContaining('restart every worker'), findsOneWidget);
  });

  testWidgets('an error view survives a message longer than the screen', (
    tester,
  ) async {
    // Found by this file: an unstubbed provider produced a very long error and
    // the view reporting it overflowed by 120,000 pixels. Reporting a failure
    // is the worst moment to run out of room, and the messages that do it are
    // ordinary ones — a Riverpod error carries its whole provider chain.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(
            message: List.generate(
              200,
              (i) => 'a long line of failure detail number $i',
            ).join('\n'),
            onRetry: () {},
            retryLabel: 'Retry',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone gets the bottom bar, never the desktop workspace', (
    tester,
  ) async {
    // The workspace puts a 320px panel and a terminal side by side. On a
    // 320pt phone that leaves nothing for the terminal, which is why the
    // breakpoint exists — and why it is worth asserting rather than assuming.
    await pumpApp(tester, const Size(320, 568));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
