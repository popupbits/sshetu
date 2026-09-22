import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/palette/palette_registry.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  PaletteItem item(String id) => PaletteItem(
    id: id,
    title: id,
    category: PaletteCategory.action,
    icon: PiconsRegular.play,
    actions: [
      PaletteAction(
        id: 'go',
        label: 'go',
        icon: PiconsRegular.play,
        run: (_, _) {},
      ),
    ],
  );

  test('items from every source, in registry order', () {
    final first = Provider.family<List<PaletteItem>, AppLocalizations>(
      (ref, _) => [item('a'), item('b')],
    );
    final second = Provider.family<List<PaletteItem>, AppLocalizations>(
      (ref, _) => [item('c')],
    );
    final container = ProviderContainer(
      overrides: [
        paletteSourcesProvider.overrideWithValue([first, second]),
      ],
    );
    addTearDown(container.dispose);

    expect(
      [for (final i in container.read(paletteItemsProvider(l10n))) i.id],
      ['a', 'b', 'c'],
    );
  });

  test('the real registry lists every feature once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sources = container.read(paletteSourcesProvider);
    expect(sources, hasLength(8));
    expect(sources.toSet(), hasLength(sources.length));
  });
}
