import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/palette/open_command_palette.dart';
import 'package:sshetu/features/palette/palette_recents.dart';
import 'package:sshetu/features/palette/palette_registry.dart';
import 'package:sshetu/features/palette/widgets/command_palette.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The palette driven the way a person drives it, over items whose actions
/// only record that they ran.
void main() {
  late List<String> ran;
  late ProviderContainer container;

  PaletteItem item(
    String id,
    String title, {
    List<String> actions = const ['go'],
  }) => PaletteItem(
    id: id,
    title: title,
    subtitle: '$id.example.com',
    category: PaletteCategory.host,
    icon: PiconsRegular.hardDrives,
    actions: [
      for (final action in actions)
        PaletteAction(
          id: action,
          label: action,
          icon: PiconsRegular.play,
          run: (_, _) => ran.add('$id/$action'),
        ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    List<PaletteItem>? items,
    List<String> recents = const [],
  }) async {
    ran = [];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({PaletteRecents.key: recents});
    final preferences = await SharedPreferences.getInstance();
    final all =
        items ??
        [
          item('web', 'web-01', actions: ['connect', 'edit', 'files']),
          item('db', 'database'),
          item('jump', 'bastion'),
        ];
    final source = Provider.family<List<PaletteItem>, AppLocalizations>(
      (ref, l10n) => all,
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        paletteSourcesProvider.overrideWithValue([source]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  TextButton(
                    onPressed: () => openCommandPalette(context, ref),
                    child: const Text('open'),
                  ),
                  const TextField(key: Key('elsewhere')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsOneWidget);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  bool highlighted(WidgetTester tester, String id) => tester
      .widget<ListTile>(
        find.descendant(
          of: find.byKey(Key('palette.item.$id')),
          matching: find.byType(ListTile),
        ),
      )
      .selected;

  group('keyboard', () {
    testWidgets('the field has focus and the first row is highlighted', (
      tester,
    ) async {
      await pump(tester);
      await open(tester);

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('palette.search')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(highlighted(tester, 'web'), isTrue);
      expect(highlighted(tester, 'db'), isFalse);
    });

    testWidgets('arrows move the highlight and stop at the ends', (
      tester,
    ) async {
      await pump(tester);
      await open(tester);

      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester, 'db'), isTrue);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester, 'jump'), isTrue);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(highlighted(tester, 'web'), isTrue);
    });

    testWidgets('Enter runs the highlighted item and closes', (tester) async {
      await pump(tester);
      await open(tester);

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.byType(CommandPalette), findsNothing);
      expect(ran, ['db/go']);
      expect(container.read(paletteRecentsProvider), ['db']);
    });

    testWidgets('Tab cycles the secondary actions, Shift+Tab goes back', (
      tester,
    ) async {
      await pump(tester);
      await open(tester);

      ChoiceChip chip(String id) =>
          tester.widget<ChoiceChip>(find.byKey(Key('palette.action.$id')));
      expect(chip('connect').selected, isTrue);

      await press(tester, LogicalKeyboardKey.tab);
      expect(chip('edit').selected, isTrue);
      await press(tester, LogicalKeyboardKey.tab);
      expect(chip('files').selected, isTrue);
      await press(tester, LogicalKeyboardKey.tab);
      expect(chip('connect').selected, isTrue, reason: 'wraps around');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(chip('files').selected, isTrue);

      // Focus stayed in the field: Tab did not move it.
      await press(tester, LogicalKeyboardKey.enter);
      expect(ran, ['web/files']);
    });

    testWidgets('moving the highlight resets the chosen action', (
      tester,
    ) async {
      await pump(tester);
      await open(tester);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.enter);
      expect(ran, ['web/connect']);
    });

    testWidgets('Esc closes without running anything', (tester) async {
      await pump(tester);
      await open(tester);
      await press(tester, LogicalKeyboardKey.escape);

      expect(find.byType(CommandPalette), findsNothing);
      expect(ran, isEmpty);
      expect(container.read(paletteRecentsProvider), isEmpty);
    });

    testWidgets('typing filters, highlights, and Enter runs the best match', (
      tester,
    ) async {
      await pump(tester);
      await open(tester);

      await tester.enterText(find.byKey(const Key('palette.search')), 'bas');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette.item.jump')), findsOneWidget);
      expect(find.byKey(const Key('palette.item.web')), findsNothing);
      expect(highlighted(tester, 'jump'), isTrue);

      await press(tester, LogicalKeyboardKey.enter);
      expect(ran, ['jump/go']);
    });
  });

  group('focus', () {
    testWidgets('returns to what had it before, closed or chosen', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('elsewhere')));
      await tester.pump();
      final before = FocusManager.instance.primaryFocus;

      await open(tester);
      expect(FocusManager.instance.primaryFocus, isNot(before));
      await press(tester, LogicalKeyboardKey.escape);
      expect(FocusManager.instance.primaryFocus, before);

      await open(tester);
      await press(tester, LogicalKeyboardKey.enter);
      expect(FocusManager.instance.primaryFocus, before);
    });
  });

  group('mouse and touch', () {
    testWidgets('a tap on a row runs its primary action', (tester) async {
      await pump(tester);
      await open(tester);
      await tester.tap(find.text('database'));
      await tester.pumpAndSettle();
      expect(ran, ['db/go']);
    });

    testWidgets('a tap on an action chip runs that action', (tester) async {
      await pump(tester);
      await open(tester);
      await tester.tap(find.byKey(const Key('palette.action.edit')));
      await tester.pumpAndSettle();
      expect(ran, ['web/edit']);
    });
  });

  group('recents', () {
    testWidgets('float to the top of an empty query, labelled', (tester) async {
      await pump(tester, recents: ['jump', 'db']);
      await open(tester);

      final top = tester.getTopLeft(find.byKey(const Key('palette.item.jump')));
      final next = tester.getTopLeft(find.byKey(const Key('palette.item.db')));
      final last = tester.getTopLeft(find.byKey(const Key('palette.item.web')));
      expect(top.dy, lessThan(next.dy));
      expect(next.dy, lessThan(last.dy));
      expect(find.text('Recent'), findsNWidgets(2));
      expect(highlighted(tester, 'jump'), isTrue);
    });

    testWidgets('choosing one records it first', (tester) async {
      await pump(tester, recents: ['jump']);
      await open(tester);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      expect(container.read(paletteRecentsProvider), ['web', 'jump']);
    });
  });

  group('states', () {
    testWidgets('no results says what was searched', (tester) async {
      await pump(tester);
      await open(tester);
      await tester.enterText(find.byKey(const Key('palette.search')), 'zzz');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette.noResults')), findsOneWidget);
      expect(find.textContaining('zzz'), findsWidgets);
      // Enter with nothing to run does nothing, and does not close.
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(CommandPalette), findsOneWidget);
      expect(ran, isEmpty);
    });

    testWidgets('nothing at all shows the empty state', (tester) async {
      await pump(tester, items: const []);
      await open(tester);
      expect(find.text('Nothing to search yet'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('a centred dialog no wider than 640 at 1280', (tester) async {
      // A desktop, so the keyboard hint is shown too.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pump(tester);
        await open(tester);

        final size = tester.getSize(find.byType(CommandPalette));
        expect(size.width, lessThanOrEqualTo(640));
        expect(size.width, greaterThan(400));
        final centre = tester.getCenter(find.byType(CommandPalette));
        expect(centre.dx, closeTo(640, 1));
        expect(find.byKey(const Key('palette.close')), findsNothing);
        expect(find.textContaining('Tab for other actions'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('the whole screen at 360, with a close button', (tester) async {
      await pump(tester, size: const Size(360, 740));
      await open(tester);

      final size = tester.getSize(find.byType(CommandPalette));
      expect(size.width, 360);
      expect(find.byKey(const Key('palette.close')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('palette.close')));
      await tester.pumpAndSettle();
      expect(find.byType(CommandPalette), findsNothing);
      expect(ran, isEmpty);
    });

    testWidgets('long labels do not overflow at 360', (tester) async {
      await pump(
        tester,
        size: const Size(360, 740),
        items: [
          item(
            'long',
            'production-database-eu-west-1-replica-with-a-very-long-name',
            actions: ['connect', 'edit', 'open files', 'running sessions'],
          ),
        ],
      );
      await open(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
