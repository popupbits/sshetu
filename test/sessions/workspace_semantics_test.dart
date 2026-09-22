import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/fake_shell.dart';
import '../support/semantics_tree_spy.dart';
import '../support/test_database.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// The desktop workspace keeps every open page built. What a screen reader
/// is told must still be one tree: every node the framework sends reachable
/// from the root (Windows logs "will not be in the tree and is not the new
/// root" for each one that is not), and nothing from a page nobody can see.
void main() {
  final spy = SemanticsTreeSpyBinding.ensureInitialized();
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    spy.resetSpy();
    database = await openTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final triggers = FakeTriggers();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(InMemorySecretVault()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(triggers),
        settingsControllerProvider.overrideWith(
          () => SettingsController(initial: readSettings(preferences)),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(triggers.dispose);
  });

  tearDown(() async => database.raw.close());

  WorkspacePages pages() => container.read(workspacePagesProvider.notifier);
  SessionManager sessions() => container.read(sessionManagerProvider.notifier);

  Future<void> pumpWorkspace(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(body: TerminalWorkspace()),
        ),
      ),
    );
  }

  Future<TerminalSession> openSession(String id) async {
    final session = TerminalSession(
      id: id,
      title: 'web-$id',
      hostId: 'host',
      connection: SshConnection(
        target: const SshTarget(
          hostname: 'example.invalid',
          username: 'me',
          port: 22,
        ),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: FakeLauncher(),
      probe: () async => true,
    );
    sessions().adopt(session);
    await session.start();
    session.terminal.write('me@web-$id:~\$ ');
    return session;
  }

  WorkspacePage page(String id) => WorkspacePage(
    id: id,
    title: 'Page $id',
    icon: PiconsRegular.folderOpen,
    builder: (_) => _ProbePage(id: id),
  );

  /// Fails with the orphaned node ids, and what the tree held, if any update
  /// so far carried a node the root cannot reach.
  void expectOneTree(String when) {
    expect(
      spy.orphans,
      isEmpty,
      reason: '$when: nodes sent outside the tree ${spy.orphans}',
    );
  }

  testWidgets('switching pages and tabs keeps one tree, hidden pages silent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWorkspace(tester);
    await openSession('a');
    await openSession('b');
    await tester.pumpAndSettle();
    expectOneTree('two sessions');

    for (final id in ['x', 'y', 'z']) {
      pages().open(page(id));
      await tester.pumpAndSettle();
      expectOneTree('opened $id');
    }
    expect(find.bySemanticsLabel('probe z'), findsOneWidget);
    expect(find.bySemanticsLabel('probe x'), findsNothing);
    expect(find.bySemanticsLabel('probe y'), findsNothing);

    for (final id in ['x', 'z', 'y', 'x']) {
      pages().select(id);
      await tester.pumpAndSettle();
      expectOneTree('selected $id');
      for (final other in ['x', 'y', 'z']) {
        expect(
          find.bySemanticsLabel('probe $other'),
          other == id ? findsOneWidget : findsNothing,
          reason: 'with $id showing',
        );
      }
    }

    // Back to the terminal, across its tabs, and back to a page.
    pages().deselect();
    await tester.pumpAndSettle();
    expectOneTree('terminal');
    for (final other in ['x', 'y', 'z']) {
      expect(find.bySemanticsLabel('probe $other'), findsNothing);
    }
    sessions().select('a');
    await tester.pumpAndSettle();
    sessions().select('b');
    await tester.pumpAndSettle();
    expectOneTree('session tabs');
    pages().select('y');
    await tester.pumpAndSettle();
    expectOneTree('back to y');

    // Closing the showing page and a hidden one.
    pages().close('y');
    await tester.pumpAndSettle();
    expectOneTree('closed y');
    pages().close('x');
    await tester.pumpAndSettle();
    expectOneTree('closed x');

    expect(spy.updates, greaterThan(5), reason: 'the spy saw the updates');
    handle.dispose();
  });

  testWidgets('a menu left open on a page goes with it when it hides', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWorkspace(tester);
    pages().open(page('x'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('probe.menu.x')));
    await tester.pumpAndSettle();
    expect(find.text('menu item x'), findsOneWidget);

    // Another tab comes forward while the menu is open (a shortcut, the
    // palette, a new connection), and the menu then changes.
    pages().open(page('y'));
    await tester.pumpAndSettle();
    expect(
      find.text('menu item x', skipOffstage: false).hitTestable(),
      findsNothing,
      reason: 'the hidden page\x27s menu floated over the showing one',
    );
    _ProbePageState.menuLabel.value = 'renamed';
    await tester.pumpAndSettle();
    expectOneTree('menu changed while its page was hidden');

    pages().select('x');
    await tester.pumpAndSettle();
    expectOneTree('back to x');
    expect(find.text('renamed x'), findsOneWidget, reason: 'still open');
    _ProbePageState.menuLabel.value = 'menu item';
    handle.dispose();
  });
}

/// A page with the kinds of semantics a real one has: a list of tiles, a
/// text field and a switch.
class _ProbePage extends StatefulWidget {
  const _ProbePage({required this.id});

  final String id;

  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  static final menuLabel = ValueNotifier('menu item');

  var _on = false;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Semantics(label: 'probe ${widget.id}', child: const SizedBox(height: 20)),
      const TextField(),
      MenuAnchor(
        menuChildren: [
          ValueListenableBuilder(
            valueListenable: menuLabel,
            builder: (_, label, _) => MenuItemButton(
              onPressed: () {},
              child: Text('$label ${widget.id}'),
            ),
          ),
        ],
        builder: (_, controller, _) => IconButton(
          key: Key('probe.menu.${widget.id}'),
          icon: const Icon(PiconsRegular.dotsThreeVertical),
          onPressed: controller.open,
        ),
      ),
      SwitchListTile(
        title: Text('switch ${widget.id}'),
        value: _on,
        onChanged: (value) => setState(() => _on = value),
      ),
      for (var i = 0; i < 10; i++)
        ListTile(title: Text('${widget.id} row $i'), onTap: () {}),
    ],
  );
}
