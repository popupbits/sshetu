import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/sessions/open_in_workspace.dart';
import 'package:sshetu/features/sessions/open_screens.dart';
import 'package:sshetu/features/sessions/widgets/session_tab_strip.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// The desktop workspace's non-terminal tabs: they keep their state while
/// another tab is showing, and their titles follow the app's language.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = await openTestDatabase();
    _Probe.disposed.clear();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(InMemorySecretVault()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        settingsControllerProvider.overrideWith(
          () => SettingsController(initial: readSettings(preferences)),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async => database.raw.close());

  /// A context and ref from inside the app, for calling a real opener.
  late ({BuildContext context, WidgetRef ref}) opener;

  WorkspacePages pages() => container.read(workspacePagesProvider.notifier);

  /// The workspace at a desktop width, in [locale] (switchable afterwards).
  Future<ValueNotifier<Locale>> pumpWorkspace(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    final current = ValueNotifier(locale);
    addTearDown(current.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ValueListenableBuilder(
          valueListenable: current,
          builder: (_, locale, _) => MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  opener = (context: context, ref: ref);
                  return const TerminalWorkspace();
                },
              ),
            ),
          ),
        ),
      ),
    );
    return current;
  }

  WorkspacePage page(String id, WidgetBuilder builder) => WorkspacePage(
    id: id,
    title: id,
    icon: PiconsRegular.folderOpen,
    builder: builder,
  );

  group('keeps open pages alive', () {
    testWidgets('switching away and back keeps a page\'s state', (
      tester,
    ) async {
      await pumpWorkspace(tester);
      pages().open(page('a', (_) => const _Probe(label: 'a')));
      await tester.pump();
      pages().open(page('b', (_) => const _Probe(label: 'b')));
      await tester.pump();
      pages().select('a');
      await tester.pump();

      await tester.enterText(find.byKey(const Key('probe.a')), 'typed in a');
      final before = tester.state(find.byType(_Probe));

      pages().select('b');
      await tester.pump();
      expect(find.byKey(const Key('probe.a')), findsNothing);
      expect(find.byKey(const Key('probe.b')), findsOneWidget);

      // To the terminal, too: nothing selected.
      pages().deselect();
      await tester.pump();

      pages().select('a');
      await tester.pump();
      expect(find.text('typed in a'), findsOneWidget);
      expect(
        identical(tester.state(find.byType(_Probe)), before),
        isTrue,
        reason: 'the page was rebuilt from nothing',
      );
      expect(_Probe.disposed, isNot(contains('a')));
    });

    testWidgets('a hidden page is offstage, ticker-less and unfocusable', (
      tester,
    ) async {
      await pumpWorkspace(tester);
      pages().open(page('a', (_) => const _Probe(label: 'a')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('probe.a')));
      await tester.pump();
      final field = find.byKey(const Key('probe.a'), skipOffstage: false);
      final fieldFocus = tester
          .state<EditableTextState>(find.byType(EditableText))
          .widget
          .focusNode;
      expect(fieldFocus.hasPrimaryFocus, isTrue);

      pages().open(page('b', (_) => const _Probe(label: 'b')));
      await tester.pump();

      expect(field, findsOneWidget, reason: 'kept, just hidden');
      final hidden = tester.element(field);
      expect(TickerMode.valuesOf(hidden).enabled, isFalse);
      expect(
        fieldFocus.hasFocus,
        isFalse,
        reason: 'a key press must not land in a page nobody can see',
      );
      expect(fieldFocus.canRequestFocus, isFalse);
    });

    testWidgets('closing a tab disposes its page', (tester) async {
      await pumpWorkspace(tester);
      pages().open(page('gone', (_) => const _Probe(label: 'gone')));
      pages().open(page('stays', (_) => const _Probe(label: 'stays')));
      await tester.pump();
      pages().close('gone');
      await tester.pump();
      expect(_Probe.disposed, contains('gone'));
      expect(
        find.byKey(const Key('probe.gone'), skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('a page still closes itself, and still asks first', (
      tester,
    ) async {
      await pumpWorkspace(tester);
      var allow = false;
      pages().open(
        WorkspacePage(
          id: 'ask',
          title: 'ask',
          icon: PiconsRegular.fileText,
          builder: (_) => const _Probe(label: 'ask'),
          confirmClose: (_) async => allow,
        ),
      );
      pages().open(page('self', (_) => const _SelfClosing()));
      await tester.pump();

      // closeOpenedScreen from inside a kept page finds its own tab.
      await tester.tap(find.text('done'));
      await tester.pump();
      expect(container.read(workspacePagesProvider).map((p) => p.id), ['ask']);

      final context = tester.element(find.byType(TerminalWorkspace));
      await pages().requestClose(context, 'ask');
      await tester.pump();
      expect(container.read(workspacePagesProvider), hasLength(1));
      allow = true;
      await pages().requestClose(context, 'ask');
      await tester.pump();
      expect(container.read(workspacePagesProvider), isEmpty);
    });
  });

  group('tab titles follow the language', () {
    Finder inTabStrip(String text) => find.descendant(
      of: find.byType(SessionTabStrip),
      matching: find.text(text),
    );

    testWidgets('an app page\'s title is re-read; a file name is not', (
      tester,
    ) async {
      final en = lookupAppLocalizations(const Locale('en'));
      final ne = lookupAppLocalizations(const Locale('ne'));
      final locale = await pumpWorkspace(tester);

      // Opened through the real opener, the way the app does.
      openFiles(opener.context, opener.ref, 'no-such-session');
      pages().open(page('notes.txt', (_) => const SizedBox.shrink()));
      await tester.pump();
      expect(inTabStrip(en.filesTitle), findsOneWidget);

      locale.value = const Locale('ne');
      await tester.pumpAndSettle();
      expect(inTabStrip(ne.filesTitle), findsOneWidget);
      expect(inTabStrip(en.filesTitle), findsNothing);
      expect(inTabStrip('notes.txt'), findsOneWidget);
    });
  });
}

/// A page with state worth losing: a text field.
class _Probe extends StatefulWidget {
  const _Probe({required this.label});

  final String label;

  static final disposed = <String>[];

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _Probe.disposed.add(widget.label);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 300,
      child: TextField(key: Key('probe.${widget.label}'), controller: _text),
    ),
  );
}

/// A page that closes itself the way a saved form does.
class _SelfClosing extends ConsumerWidget {
  const _SelfClosing();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: TextButton(
      onPressed: () => closeOpenedScreen(context, ref),
      child: const Text('done'),
    ),
  );
}
