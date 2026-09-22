import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/input_tracking_terminal.dart';
import 'package:xterm2/xterm.dart';

/// Typed input and the terminal's own replies share `onOutput`; broadcast
/// depends on telling them apart.
void main() {
  late InputTrackingTerminal terminal;
  late List<(String, bool)> sent;

  setUp(() {
    terminal = InputTrackingTerminal();
    sent = [];
    terminal.onOutput = (data) => sent.add((data, terminal.isUserInput));
  });

  test('typed text, keys, control chords and pastes are user input', () {
    terminal
      ..textInput('ls')
      ..keyInput(TerminalKey.enter)
      ..charInput(0x63, ctrl: true)
      ..paste('echo hi');
    expect(sent.map((s) => s.$2), everyElement(isTrue));
    expect(sent, hasLength(4));
  });

  test("the terminal's answers to the program are not", () {
    terminal.write('\x1b[6n'); // cursor position report
    terminal.write('\x1b[c'); // device attributes
    expect(sent, hasLength(2));
    expect(sent.map((s) => s.$2), everyElement(isFalse));
    expect(terminal.isUserInput, isFalse);
  });
}
