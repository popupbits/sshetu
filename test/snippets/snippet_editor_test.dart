import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/snippets/snippet_editor_screen.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_snippets_controller.dart';

/// Adding and editing a snippet: what is required, what is saved, and the
/// live summary of what the body will ask for.
void main() {
  final now = DateTime.utc(2026, 1, 1);
  late FakeSnippetsController controller;

  setUp(() => controller = FakeSnippetsController());

  Future<void> pump(
    WidgetTester tester, {
    String? snippetId,
    List<Snippet> existing = const [],
    Size size = const Size(400, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snippetsProvider.overrideWith((ref) => existing),
          snippetsControllerProvider.overrideWithValue(controller),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: SnippetEditorScreen(snippetId: snippetId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String name) => find.byKey(Key('snippetEditor.$name'));

  Future<void> save(WidgetTester tester) async {
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
  }

  testWidgets('label and command are both required', (tester) async {
    await pump(tester);

    await save(tester);
    expect(find.text('Required'), findsNWidgets(2));
    expect(controller.saved, isEmpty);

    await tester.enterText(field('label'), 'Uptime');
    await save(tester);
    expect(find.text('Required'), findsOneWidget);
    expect(controller.saved, isEmpty);
  });

  testWidgets('a command of only whitespace does not count', (tester) async {
    await pump(tester);

    await tester.enterText(field('label'), 'Nothing');
    await tester.enterText(field('body'), '   \n  ');
    await save(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(controller.saved, isEmpty);
  });

  testWidgets('saves the label trimmed and the command as typed', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(field('label'), '  Tail logs  ');
    await tester.enterText(field('body'), 'cd /var/log\n  tail -f syslog');
    await tester.enterText(field('description'), 'follow it');
    await save(tester);

    expect(controller.saved, hasLength(1));
    final saved = controller.saved.single;
    expect(saved.label, 'Tail logs');
    // Indentation inside a command can matter (a heredoc, YAML), so the
    // body is kept exactly.
    expect(saved.body, 'cd /var/log\n  tail -f syslog');
    expect(saved.description, 'follow it');
    expect(saved.id, isNotEmpty);
  });

  testWidgets('a tag typed but not committed is still saved', (tester) async {
    await pump(tester);

    await tester.enterText(field('label'), 'x');
    await tester.enterText(field('body'), 'uptime');
    await tester.enterText(find.byType(TextField).last, 'prod');
    await save(tester);

    expect(controller.saved.single.tags, ['prod']);
  });

  testWidgets('the summary says what the command asks for and fills in', (
    tester,
  ) async {
    await pump(tester);
    Text summary() =>
        tester.widget<Text>(find.byKey(const Key('snippetEditor.variables')));

    expect(summary().data, contains('{{name}}'));

    await tester.enterText(field('body'), 'ssh {{user}}@{{host}} {{cmd:ls}}');
    await tester.pumpAndSettle();
    expect(summary().data, 'Asks for: cmd · Fills in: user, host');
  });

  testWidgets('editing loads the snippet and keeps its id', (tester) async {
    await pump(
      tester,
      snippetId: 's1',
      existing: [
        Snippet(
          id: 's1',
          label: 'Old',
          body: 'uptime',
          description: 'gone soon',
          tags: const ['ops'],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(find.text('Old'), findsOneWidget);
    expect(find.text('uptime'), findsOneWidget);

    await tester.enterText(field('label'), 'New');
    await tester.enterText(field('description'), '');
    await save(tester);

    final saved = controller.saved.single;
    expect(saved.id, 's1');
    expect(saved.label, 'New');
    expect(saved.description, isNull);
    expect(saved.tags, ['ops']);
    expect(saved.createdAt, now);
  });

  testWidgets('fits a desktop width without overflowing', (tester) async {
    await pump(tester, size: const Size(1400, 900));
    expect(tester.takeException(), isNull);
    expect(field('body'), findsOneWidget);
  });
}
