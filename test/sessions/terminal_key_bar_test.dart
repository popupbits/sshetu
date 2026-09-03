import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/terminal/terminal_modifiers.dart';
import 'package:sshetu/features/sessions/widgets/terminal_key_bar.dart';
import 'package:xterm2/xterm.dart';

/// The bar above a phone keyboard, and the two things it must never do:
/// hide the keys people need, or take focus away from the terminal.
void main() {
  late Terminal terminal;
  late TerminalModifiers modifiers;
  late List<String> output;

  setUp(() {
    terminal = Terminal();
    modifiers = TerminalModifiers();
    terminal.inputHandler = LatchedModifierInputHandler(modifiers);
    output = [];
    terminal.onOutput = output.add;
  });

  tearDown(() => modifiers.dispose());

  /// A narrow phone: 320pt is the smallest anyone still ships, and the width
  /// where a row that does not fit stops being reachable.
  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand()),
              TerminalKeyBar(terminal: terminal, modifiers: modifiers),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the arrows are on the first row, not behind a scroll', (
    tester,
  ) async {
    // The previous bar put fourteen keys in one scrolling strip, and on a
    // phone `←` and `→` fell off the right edge — the two keys most needed
    // to edit a command line were the two you had to go looking for.
    await pump(tester);

    for (final arrow in ['←', '↑', '↓', '→']) {
      expect(
        find.text(arrow),
        findsOneWidget,
        reason: '$arrow must be visible',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('an arrow sends what the terminal says it should', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('↑'));
    await tester.pump();
    expect(output, ['\x1b[A']);

    output.clear();
    terminal.write('\x1b[?1h'); // application cursor keys, as vim sets
    await tester.tap(find.text('↑'));
    await tester.pump();
    expect(output, ['\x1bOA'], reason: 'the terminal knows its own mode');
  });

  testWidgets('groups open in place, and come back', (tester) async {
    await pump(tester);

    await tester.tap(find.text('⋯'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('esc'), findsNothing, reason: 'the row was replaced');

    // Function keys are one level deeper, and are the only scrolling row.
    await tester.tap(find.text('F1-12'));
    await tester.pumpAndSettle();
    expect(find.text('F1'), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget, reason: 'back to the group');

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('esc'), findsOneWidget, reason: 'back to the main row');
  });

  testWidgets('the function row gives its keys the room, not the chevron', (
    tester,
  ) async {
    // The back cell is Expanded in every other row. In this one the scroller
    // beside it is Expanded too, and two Expanded siblings split the row
    // evenly — which gave a single chevron half the bar.
    await pump(tester);

    await tester.tap(find.text('⋯'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F1-12'));
    await tester.pumpAndSettle();

    final back = tester.getSize(
      find.ancestor(of: find.text('‹'), matching: find.byType(SizedBox)).first,
    );
    expect(back.width, lessThan(80), reason: 'a chevron is not half a row');
  });

  testWidgets('symbols a phone keyboard buries are one tap away', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('#⌄'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('|'));
    await tester.pump();
    expect(output, ['|']);
  });

  testWidgets('the bar never takes focus from the terminal', (tester) async {
    // Focus leaving the terminal closes the keyboard this bar is pinned
    // above, and the next keystroke goes nowhere.
    await pump(tester);

    expect(find.byType(TextFieldTapRegion), findsAtLeastNWidgets(1));

    final focus = tester.widget<Focus>(
      find
          .descendant(
            of: find.byType(TerminalKeyBar),
            matching: find.byType(Focus),
          )
          .first,
    );
    expect(focus.canRequestFocus, isFalse);
    expect(focus.descendantsAreFocusable, isFalse);
  });

  testWidgets('a latched modifier reads as held', (tester) async {
    await pump(tester);

    await tester.tap(find.text('ctrl'));
    await tester.pumpAndSettle();
    expect(modifiers.ctrl, isTrue);

    // And it reaches a key pressed on the bar itself.
    await tester.tap(find.text('#⌄'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'\'));
    await tester.pump();
    expect(output, ['\x1c'], reason: r'ctrl-\ is FS');
  });
}
