import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ui/app_menu_bar.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The desktop menu bar's structure.
///
/// macOS renders this bar itself, outside the app's window, so no widget test
/// can see what a person sees — and on this machine even the accessibility
/// API is behind a permission prompt. What *is* checkable is the tree we hand
/// the platform, which is where an empty menu, a missing item or a shortcut
/// that disagrees with the keyboard would come from.
void main() {
  /// Runs [body] as though on [platform].
  ///
  /// The override is cleared inside the test body, not in `tearDown`: the
  /// framework asserts that no foundation debug variable is still set when the
  /// body returns, and it checks that *before* tearDown runs.
  Future<void> asPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<PlatformMenuBar?> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: AppMenuBar(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final found = find.byType(PlatformMenuBar);
    if (found.evaluate().isEmpty) return null;
    return tester.widget<PlatformMenuBar>(found);
  }

  /// Every label in the tree, flattened.
  List<String> labelsOf(List<PlatformMenuItem> menus) => [
    for (final item in menus) ...[
      item.label,
      if (item is PlatformMenu) ...labelsOf(item.menus),
      if (item is PlatformMenuItemGroup) ...labelsOf(item.members),
    ],
  ];

  group('on a desktop', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    testWidgets('there is a menu bar, and it is not empty', (tester) async {
      await asPlatform(TargetPlatform.macOS, () async {
        final bar = await pump(tester);

        expect(
          bar,
          isNotNull,
          reason:
              'a desktop app without menus is a phone '
              'app in a window',
        );
        expect(bar!.menus, isNotEmpty);
      });
    });

    testWidgets('it names the four menus and the things they do', (
      tester,
    ) async {
      await asPlatform(TargetPlatform.macOS, () async {
        final bar = await pump(tester);
        final labels = labelsOf(bar!.menus);

        expect(labels, containsAll(['File', 'Session', 'View', 'Help']));
        expect(
          labels,
          containsAll([
            'New Server…',
            'Import from OpenSSH…',
            'Send to a Device…',
            'Receive from a Device…',
            'Close Session',
            'Next Session',
            'Previous Session',
            'Settings',
          ]),
        );
      });
    });

    testWidgets('shortcuts use the platform modifier', (tester) async {
      await asPlatform(TargetPlatform.macOS, () async {
        // The menu is where people learn the shortcuts, so a menu that shows
        // Ctrl-W on a Mac teaches the wrong thing.
        final bar = await pump(tester);

        SingleActivator? shortcutFor(String label) {
          SingleActivator? found;
          void walk(List<PlatformMenuItem> items) {
            for (final item in items) {
              if (item.label == label && item.shortcut is SingleActivator) {
                found = item.shortcut! as SingleActivator;
              }
              if (item is PlatformMenu) walk(item.menus);
              if (item is PlatformMenuItemGroup) walk(item.members);
            }
          }

          walk(bar!.menus);
          return found;
        }

        final close = shortcutFor('Close Session');
        expect(close, isNotNull);
        expect(close!.meta, isTrue, reason: 'Command on macOS');
        expect(close.control, isFalse);
      });
    });

    testWidgets('session items are disabled with nothing open', (tester) async {
      await asPlatform(TargetPlatform.macOS, () async {
        // Disabled rather than absent: a menu whose items come and go is a menu
        // people stop reading.
        final bar = await pump(tester);

        PlatformMenuItem? itemFor(String label) {
          PlatformMenuItem? found;
          void walk(List<PlatformMenuItem> items) {
            for (final item in items) {
              if (item.label == label) found = item;
              if (item is PlatformMenu) walk(item.menus);
              if (item is PlatformMenuItemGroup) walk(item.members);
            }
          }

          walk(bar!.menus);
          return found;
        }

        expect(itemFor('Close Session')?.onSelected, isNull);
        expect(itemFor('New Server…')?.onSelected, isNotNull);
      });
    });
  });

  testWidgets('a phone gets no menu bar at all', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      expect(await pump(tester), isNull);
    });
  });
}
