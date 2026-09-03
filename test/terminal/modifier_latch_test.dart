import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/terminal_modifiers.dart';
import 'package:xterm2/xterm.dart';

/// Ctrl-C from a touch screen.
///
/// The bug this pins: the latch used to live inside the key bar's own State,
/// where it could only affect keys tapped on the bar. The letter in a chord is
/// typed on the *software keyboard*, which goes straight into the terminal and
/// never passes through the bar — so "tap ctrl, then C" sent a literal `c`,
/// and a command could not be interrupted from a phone at all. Verified on a
/// real emulator against a live shell before the fix: `sleep 60`, ctrl, c, and
/// the sleep kept running with a `c` echoed beside it.
///
/// So these tests drive the terminal the way the keyboard does — through
/// `keyInput`, with no Ctrl on the event — and assert on the bytes that reach
/// the far end.
void main() {
  late Terminal terminal;
  late TerminalModifiers modifiers;
  late List<String> output;

  setUp(() {
    modifiers = TerminalModifiers();
    terminal = Terminal();
    terminal.inputHandler = LatchedModifierInputHandler(modifiers);
    output = [];
    terminal.onOutput = output.add;
  });

  tearDown(() => modifiers.dispose());

  /// What the software keyboard does with one typed character.
  bool typeChar(String char, TerminalKey key) =>
      terminal.keyInput(key, text: char);

  test('a plain keystroke is untouched', () {
    typeChar('c', TerminalKey.keyC);
    expect(output, isEmpty, reason: 'plain text goes through textInput');
  });

  test('ctrl latched on the bar reaches a key typed on the keyboard', () {
    modifiers.toggleCtrl();
    final consumed = typeChar('c', TerminalKey.keyC);

    expect(consumed, isTrue);
    expect(output, ['\x03'], reason: 'Ctrl-C is ETX, not a literal c');
  });

  test('the latch releases after exactly one key', () {
    modifiers.toggleCtrl();
    typeChar('c', TerminalKey.keyC);
    expect(modifiers.isEmpty, isTrue);

    output.clear();
    typeChar('c', TerminalKey.keyC);
    expect(output, isEmpty, reason: 'a released Ctrl must not modify the next');
  });

  test('alt is transmitted as ESC before the key', () {
    modifiers.toggleAlt();
    terminal.keyInput(TerminalKey.keyB, text: 'b');
    expect(output, ['\x1bb']);
  });

  test('ctrl and alt together compose', () {
    modifiers
      ..toggleCtrl()
      ..toggleAlt();
    terminal.keyInput(TerminalKey.keyC, text: 'c');
    expect(output, ['\x1b\x03']);
  });

  test('ctrl-d, the other one nobody can do without', () {
    modifiers.toggleCtrl();
    terminal.keyInput(TerminalKey.keyD, text: 'd');
    expect(output, ['\x04']);
  });

  test('a key release does not consume the latch', () {
    modifiers.toggleCtrl();
    terminal.keyInput(
      TerminalKey.keyC,
      text: 'c',
      type: TerminalKeyEventType.release,
    );
    expect(
      modifiers.ctrl,
      isTrue,
      reason: 'the modifier must survive until the key it modifies arrives',
    );
  });

  test('arrows go through the terminal, which knows its own cursor mode', () {
    // The bar used to send a literal ESC [ A. In application cursor keys mode
    // — the mode vim and less set — that is the wrong sequence, and the cursor
    // went somewhere unintended in exactly the editor the bar exists to serve.
    terminal.keyInput(TerminalKey.arrowUp);
    expect(output, ['\x1b[A']);

    output.clear();
    terminal.write('\x1b[?1h'); // DECCKM: application cursor keys
    terminal.keyInput(TerminalKey.arrowUp);
    expect(output, ['\x1bOA']);
  });
}
