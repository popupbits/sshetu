import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';
import 'package:sshetu/features/snippets/snippets_palette.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime.utc(2026);

  test('one item per snippet: run first, insert on Tab', () async {
    final container = ProviderContainer(
      overrides: [
        snippetsProvider.overrideWith(
          (ref) => [
            Snippet(
              id: 's1',
              label: 'Tail logs',
              body: 'cd /var/log\ntail -f syslog',
              tags: const ['logs'],
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(snippetsProvider.future);

    final items = container.read(snippetPaletteItemsProvider(l10n));
    expect(items, hasLength(1));
    final item = items.single;
    expect(item.id, 'snippet:s1');
    expect(item.title, 'Tail logs');
    // The first line only: a multi-line body would not fit a row.
    expect(item.subtitle, 'cd /var/log');
    expect(item.category, PaletteCategory.snippet);
    expect(item.keywords, ['logs']);
    expect([for (final a in item.actions) a.id], ['run', 'insert']);
  });

  test('no snippets, no items', () async {
    final container = ProviderContainer(
      overrides: [snippetsProvider.overrideWith((ref) => const <Snippet>[])],
    );
    addTearDown(container.dispose);
    await container.read(snippetsProvider.future);
    expect(container.read(snippetPaletteItemsProvider(l10n)), isEmpty);
  });
}
