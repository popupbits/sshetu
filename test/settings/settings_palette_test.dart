import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/mcp/mcp_settings.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/settings/settings_palette.dart';
import 'package:sshetu/features/settings/tiles.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('the common actions are all there', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ids = [
      for (final i in container.read(settingsPaletteItemsProvider(l10n))) i.id,
    ];

    expect(
      ids,
      containsAll([
        'action:toggleTheme',
        'action:sendToDevice',
        'action:receiveFromDevice',
        'action:backupExport',
        'action:backupRestore',
        'goto:hosts',
        'goto:keys',
        'goto:tunnels',
        'goto:snippets',
        'goto:settings',
      ]),
    );
    // Ids are unique: recents are keyed by them.
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('one item per Settings section', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sections = container
        .read(settingsPaletteItemsProvider(l10n))
        .where((i) => i.category == PaletteCategory.setting)
        .toList();

    expect(
      sections,
      hasLength(
        settingsSectionTitles(
          l10n,
          integrations: container.read(mcpSupportedProvider),
        ).length,
      ),
    );
    expect(
      sections.first.title,
      l10n.paletteSettingsSection(l10n.settingsAppearance),
    );
  });

  testWidgets('every section title names a real Settings section', (
    tester,
  ) async {
    late List<String> real;
    late bool integrations;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Consumer(
            builder: (context, ref, _) {
              real = [for (final s in settingsSections(context, ref)) s.title];
              integrations = ref.read(mcpSupportedProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final ours = [
      for (final (_, title) in settingsSectionTitles(
        l10n,
        integrations: integrations,
      ))
        title,
    ];
    // Same sections, same order: a section added to Settings without a
    // palette entry, or renamed, fails here.
    expect(ours, real);
  });
}
