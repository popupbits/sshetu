import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

        final close = shortcutFor('Close Tab');
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
        expect(itemFor('Close Tab')?.onSelected, isNull);
        expect(itemFor('Find…'), isNotNull);
        expect(itemFor('Find…')?.onSelected, isNull);
        final findShortcut = itemFor('Find…')!.shortcut! as SingleActivator;
        expect(findShortcut.trigger, LogicalKeyboardKey.keyF);
        expect(findShortcut.meta, isTrue, reason: 'Command+F on macOS');
        expect(itemFor('New Server…')?.onSelected, isNotNull);

        // The picker needs a session to type into, so it waits for one too,
        // and it shows the same chord the keyboard answers to.
        expect(itemFor('Snippets…'), isNotNull);
        expect(itemFor('Snippets…')?.onSelected, isNull);
        final snippets = itemFor('Snippets…')!.shortcut! as SingleActivator;
        expect(snippets.trigger, LogicalKeyboardKey.keyS);
        expect(snippets.meta, isTrue);
        expect(snippets.shift, isTrue);
        // The destination itself is always reachable.
        expect(itemFor('Snippets')?.onSelected, isNotNull);
      });
    });

    testWidgets('the standard macOS menus are still there', (tester) async {
      await asPlatform(TargetPlatform.macOS, () async {
        // Supplying any menus replaces the whole system bar, so everything
        // macOS normally provides — Quit above all — has to be asked for.
        // Without this the app had no Cmd-Q, no Cmd-M and no Cmd-H.
        final bar = await pump(tester);

        final provided = <PlatformProvidedMenuItemType>{};
        void walk(List<PlatformMenuItem> items) {
          for (final item in items) {
            if (item is PlatformProvidedMenuItem) provided.add(item.type);
            if (item is PlatformMenu) walk(item.menus);
            if (item is PlatformMenuItemGroup) walk(item.members);
          }
        }

        walk(bar!.menus);

        expect(
          provided,
          containsAll([
            PlatformProvidedMenuItemType.quit,
            PlatformProvidedMenuItemType.hide,
            PlatformProvidedMenuItemType.hideOtherApplications,
            PlatformProvidedMenuItemType.servicesSubmenu,
            PlatformProvidedMenuItemType.minimizeWindow,
            PlatformProvidedMenuItemType.zoomWindow,
            PlatformProvidedMenuItemType.toggleFullScreen,
          ]),
        );
        expect(labelsOf(bar.menus), contains('Window'));
      });
    });

    testWidgets('the app menu comes first, as macOS requires', (tester) async {
      await asPlatform(TargetPlatform.macOS, () async {
        final bar = await pump(tester);

        // macOS takes the first menu as the application menu whatever it
        // holds, so File in that slot would put New Server… under the app
        // name and hide Quit somewhere it cannot be found.
        expect(bar!.menus.first.label, 'SSHetu');
      });
    });
  });

  testWidgets('a phone gets no menu bar at all', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      expect(await pump(tester), isNull);
    });
  });
}
