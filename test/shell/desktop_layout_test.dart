import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/app.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/keys/keys_controller.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/features/shell/workspace_layout.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';

/// The desktop workspace as the window is resized.
///
/// Windows get dragged. The layout that only works at the size it was designed
/// at is the commonest desktop bug there is, so the sizes here are the awkward
/// ones: just wide enough for two panes, just too narrow, and very wide.
void main() {
  final now = DateTime.utc(2026, 1, 1);

  final hosts = [
    SshHost(
      id: 'h1',
      label: 'bastion',
      hostname: '10.0.0.4',
      username: 'root',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  // With keys, because several controls only exist when there are any — the
  // default-key picker in Settings among them — and a screen that renders
  // nothing cannot overflow.
  final identities = [
    SshIdentity(
      id: 'k1',
      label: 'an older RSA key kept for one legacy box',
      keyType: 'ssh-rsa',
      hasPassphrase: false,
      origin: IdentityOrigin.imported,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final handle = find.byKey(const Key('workspace.resizeHandle'));

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double? preferredPanel,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      // Null means "as a fresh install would start"; a value stands in for a
      // width the user had already dragged to in an earlier session.
      'settings.panelWidth': ?preferredPanel,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // main.dart installs the persisted settings this way; without it
          // the controller starts from defaults and a stored panel width is
          // never seen.
          settingsControllerProvider.overrideWith(
            () => SettingsController(initial: readSettings(preferences)),
          ),
          hostsProvider.overrideWith((ref) => hosts),
          identitiesProvider.overrideWith((ref) => identities),
          tunnelsProvider.overrideWith((ref) => const []),
        ],
        child: const SshetuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// How wide the panel actually ended up.
  double panelWidthOf(WidgetTester tester) {
    final header = find.byType(PanelHeader);
    expect(header, findsOneWidget);
    return tester.getSize(header).width;
  }

  testWidgets('a wide window shows the panel and the terminal', (tester) async {
    await pumpAt(tester, const Size(1600, 1000));

    expect(find.byType(TerminalWorkspace), findsOneWidget);
    expect(panelWidthOf(tester), WorkspaceLayout.defaultPanel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow window drops to one pane rather than two bad ones', (
    tester,
  ) async {
    // Below WorkspaceLayout's threshold there is not room beside the rail for
    // a readable list *and* a readable terminal, so it stops pretending.
    await pumpAt(tester, const Size(640, 900));

    expect(find.byType(TerminalWorkspace), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('and Sessions rejoins the rail so the terminal is reachable', (
    tester,
  ) async {
    await pumpAt(tester, const Size(640, 900));

    // Wide, the rail hides Sessions because the terminal is always on screen.
    // Narrow, hiding it would strand the terminal behind nothing.
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalWorkspace), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing the window does not overflow anything', (tester) async {
    await pumpAt(tester, const Size(1600, 1000));

    for (final width in [1400.0, 1100.0, 900.0, 780.0, 700.0, 640.0, 1600.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'the workspace overflowed at ${width}pt',
      );
    }
  });

  testWidgets('the panel gives up width before the terminal does', (
    tester,
  ) async {
    // Starts from a panel the user had widened, so there is something to
    // give up. At 1600 it fits; at 900 it cannot, and the terminal keeps its
    // floor while the panel takes the loss.
    await pumpAt(tester, const Size(1600, 1000), preferredPanel: 500);
    expect(panelWidthOf(tester), 500);

    tester.view.physicalSize = const Size(900, 1000);
    await tester.pumpAndSettle();

    expect(panelWidthOf(tester), lessThan(500));
    expect(find.byType(TerminalWorkspace), findsOneWidget);
  });

  testWidgets('dragging the divider resizes the panel, and sticks', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1600, 1000));
    final before = panelWidthOf(tester);

    // The handle sits on the seam between the two panes.
    // An explicit gesture rather than `tester.drag`, in two moves. The first
    // crosses the recogniser's slop — part of it is spent getting the drag
    // recognised at all — and the second is the one that must land pixel for
    // pixel, which is the property worth asserting: a divider that lags the
    // pointer feels broken even when it ends up in the right place.
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    final started = panelWidthOf(tester);

    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(panelWidthOf(tester) - started, closeTo(100, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();

    final after = panelWidthOf(tester);
    expect(after, greaterThan(before));

    // And it is a preference, not a one-off: it survives a resize away and
    // back, which is what "sticks" has to mean.
    tester.view.physicalSize = const Size(1200, 1000);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pumpAndSettle();

    expect(panelWidthOf(tester), after);
  });

  testWidgets('a drag cannot squeeze the terminal out', (tester) async {
    await pumpAt(tester, const Size(1600, 1000));

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(4000, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(panelWidthOf(tester), WorkspaceLayout.maxPanel);
    expect(find.byType(TerminalWorkspace), findsOneWidget);
  });

  testWidgets('every destination fits at every desktop width', (tester) async {
    // The desktop equivalent of the phone overflow sweep. Found a real one:
    // a window resized narrow while a destination other than Hosts was
    // showing overflowed by 112 points, and the overflow arrived during
    // paint — which the error logger then tried to record mid-frame.
    for (final width in [1600.0, 1100.0, 900.0, 760.0, 700.0, 640.0]) {
      await pumpAt(tester, Size(width, 900));

      for (final destination in const [
        'Keys',
        'Tunnels',
        'Settings',
        'Hosts',
      ]) {
        final tab = find.text(destination);
        if (tab.evaluate().isEmpty) continue;
        await tester.tap(tab.first, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$destination overflowed at ${width}pt',
        );
      }
    }
  });

  testWidgets('the rail actually switches destination, from any of them', (
    tester,
  ) async {
    // The sweep above only asserted that tapping a destination threw nothing.
    // A rail that silently stays put satisfies that and is still broken —
    // reported as "from Settings I cannot switch to Tunnels".
    await pumpAt(tester, const Size(1600, 1000));

    String panelTitle() =>
        tester.widget<PanelHeader>(find.byType(PanelHeader)).title;

    for (final width in [1600.0, 1100.0, 800.0, 700.0, 640.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpAndSettle();

      for (final from in const ['Settings', 'Keys', 'Tunnels', 'Hosts']) {
        for (final to in const ['Tunnels', 'Hosts', 'Settings', 'Keys']) {
          await tester.tap(find.text(from).first);
          await tester.pumpAndSettle();
          expect(panelTitle(), from, reason: 'could not reach $from @$width');

          await tester.tap(find.text(to).first);
          await tester.pumpAndSettle();
          expect(
            panelTitle(),
            to,
            reason: 'stuck on $from, could not reach $to @$width',
          );
        }
      }
    }
  });
}
