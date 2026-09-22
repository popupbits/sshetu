import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/keys/keys_palette.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  test('generate and paste a key', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final items = container.read(keyPaletteItemsProvider(l10n));
    expect(
      [for (final i in items) i.id],
      ['action:generateKey', 'action:pasteKey'],
    );
    expect(items.first.title, l10n.keysGenerate);
    expect(items.last.title, l10n.keysPaste);
  });
}
