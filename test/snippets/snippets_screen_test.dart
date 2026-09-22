import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';
import 'package:sshetu/features/snippets/snippets_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_snippets_controller.dart';

/// The Snippets destination: search, the empty states, and copying a
/// command — at a phone width and a desktop width.
void main() {
  final now = DateTime.utc(2026, 1, 1);

  Snippet snippet(
    String id,
    String label,
    String body, {
    List<String> tags = const [],
  }) => Snippet(
    id: id,
    label: label,
    body: body,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );

  final saved = [
    snippet('a', 'Restart nginx', 'sudo systemctl restart nginx'),
    snippet('b', 'Disk usage', 'df -h', tags: ['ops']),
    snippet('c', 'Follow logs', 'journalctl -f -u {{unit}}'),
  ];

  const compact = Size(400, 800);
  const expanded = Size(1400, 900);

  Future<void> pump(
    WidgetTester tester,
    List<Snippet> snippets, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [snippetsProvider.overrideWith((ref) => snippets)],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: SnippetsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [('compact', compact), ('expanded', expanded)]) {
    group('at $name width', () {
      testWidgets('an empty list explains itself and offers to add one', (
        tester,
      ) async {
        await pump(tester, const [], size: size);

        expect(find.text('No snippets yet'), findsOneWidget);
        expect(find.byKey(const Key('snippets.emptyAdd')), findsOneWidget);
        // Nothing to search, so no search field.
        expect(find.byType(SearchBar), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('lists every snippet with its command', (tester) async {
        await pump(tester, saved, size: size);

        expect(find.byType(SearchBar), findsOneWidget);
        expect(find.text('Restart nginx'), findsOneWidget);
        expect(find.text('df -h'), findsOneWidget);
        expect(find.text('ops'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('search matches the label, the body and the tags', (
        tester,
      ) async {
        await pump(tester, saved, size: size);
        final search = find.byKey(const Key('snippets.search'));

        await tester.enterText(search, 'restart');
        await tester.pumpAndSettle();
        expect(find.text('Restart nginx'), findsOneWidget);
        expect(find.text('Disk usage'), findsNothing);

        await tester.enterText(search, 'journalctl');
        await tester.pumpAndSettle();
        expect(find.text('Follow logs'), findsOneWidget);
        expect(find.text('Restart nginx'), findsNothing);

        await tester.enterText(search, 'OPS');
        await tester.pumpAndSettle();
        expect(find.text('Disk usage'), findsOneWidget);
        expect(find.text('Follow logs'), findsNothing);
      });

      testWidgets('a search that matches nothing keeps the field', (
        tester,
      ) async {
        await pump(tester, saved, size: size);

        await tester.enterText(
          find.byKey(const Key('snippets.search')),
          'kubectl',
        );
        await tester.pumpAndSettle();

        expect(find.text('No snippets match'), findsOneWidget);
        // Not the first-run empty state: offering "add" here would be noise.
        expect(find.byKey(const Key('snippets.emptyAdd')), findsNothing);
        expect(find.byType(SearchBar), findsOneWidget);
      });
    });
  }

  testWidgets('delete asks first, and only a yes deletes', (tester) async {
    final controller = FakeSnippetsController();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = compact;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snippetsProvider.overrideWith((ref) => saved),
          snippetsControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: SnippetsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openDelete() async {
      await tester.tap(find.byKey(const Key('snippet.menu.b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('snippet.delete.b')));
      await tester.pumpAndSettle();
    }

    await openDelete();
    expect(find.text('Delete this snippet?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.deleted, isEmpty);

    await openDelete();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(controller.deleted.map((s) => s.id), ['b']);
  });

  testWidgets('copy puts the raw body on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester, saved, size: compact);
    await tester.tap(find.byKey(const Key('snippet.copy.c')));
    await tester.pumpAndSettle();

    // The body as saved, placeholders and all — not a rendering of it.
    expect(copied, 'journalctl -f -u {{unit}}');
    expect(find.text('Command copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });
}
