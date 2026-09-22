import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/terminal_find.dart';
import 'package:xterm2/xterm.dart';

/// Find-in-scrollback state: counting, order, wrapping, options, and keeping
/// up with output that arrives while the bar is open.
void main() {
  late Terminal terminal;
  late TerminalController controller;
  late TerminalFind find;

  setUp(() {
    terminal = Terminal(maxLines: 1000);
    controller = TerminalController();
    find = TerminalFind(terminal: terminal, controller: controller);
    terminal.write('error one\r\nok\r\nERROR two\r\nfine\r\nerror three\r\n');
  });

  tearDown(() {
    find.dispose();
    controller.dispose();
  });

  test('an empty query finds nothing and highlights nothing', () {
    expect(find.matchCount, 0);
    expect(find.currentPosition, 0);
    expect(controller.searchHighlights, isEmpty);
  });

  test('counts matches, case-insensitively by default', () {
    find.query = 'error';
    expect(find.matchCount, 3);
    expect(controller.searchHighlights, hasLength(3));
  });

  test('starts on the newest match, counted as 1', () {
    find.query = 'error';
    expect(find.currentPosition, 1);
    expect(find.currentRange!.begin.y, 4, reason: '"error three" is row 4');
  });

  test('next goes back in history and wraps', () {
    find.query = 'error';
    find.next();
    expect(find.currentPosition, 2);
    expect(find.currentRange!.begin.y, 2);
    find.next();
    expect(find.currentPosition, 3);
    expect(find.currentRange!.begin.y, 0);
    find.next();
    expect(find.currentPosition, 1, reason: 'wraps to the newest');
  });

  test('previous comes forward and wraps', () {
    find.query = 'error';
    find.previous();
    expect(find.currentPosition, 3, reason: 'wraps to the oldest');
    find.previous();
    expect(find.currentPosition, 2);
  });

  test('the controller is told which match is current', () {
    find.query = 'error';
    find.next();
    // xterm2 indexes top to bottom; position 2 from the bottom is index 1.
    expect(controller.currentSearchHighlight, 1);
  });

  test('match case narrows the results', () {
    find.query = 'error';
    find.caseSensitive = true;
    expect(find.matchCount, 2);
    find.query = 'ERROR';
    expect(find.matchCount, 1);
  });

  test('regex mode matches a pattern', () {
    find.useRegex = true;
    find.query = r'error (one|three)';
    expect(find.matchCount, 2);
    expect(find.invalidPattern, isFalse);
  });

  test('without regex mode, pattern characters are literal', () {
    find.query = 'e.r';
    expect(find.matchCount, 0);
  });

  test('an invalid regex is reported, not thrown', () {
    find.useRegex = true;
    find.query = 'error (';
    expect(find.invalidPattern, isTrue);
    expect(find.matchCount, 0);
    expect(controller.searchHighlights, isEmpty);
    find.query = 'error';
    expect(find.invalidPattern, isFalse);
    expect(find.matchCount, 3);
  });

  test('stepping with no matches does nothing', () {
    find.query = 'absent';
    find.next();
    find.previous();
    expect(find.currentPosition, 0);
  });

  test('clear drops the highlights but keeps the query', () {
    find.query = 'error';
    find.clear();
    expect(controller.searchHighlights, isEmpty);
    expect(find.matchCount, 0);
    expect(find.query, 'error');
    find.refresh();
    expect(find.matchCount, 3);
  });

  test('output after a search is picked up on the next step', () {
    find.query = 'error';
    find.next(); // on "ERROR two"
    terminal.write('error four\r\n');
    find.next();
    expect(find.matchCount, 4, reason: 'the new line was searched');
    // Stayed anchored: one step back from "ERROR two" is "error one".
    expect(find.currentRange!.begin.y, 0);
  });

  test('notifies listeners when the result changes', () {
    var notified = 0;
    find.addListener(() => notified++);
    find.query = 'error';
    find.next();
    expect(notified, 2);
  });

  test('stops at the result cap and says so', () {
    final big = Terminal(maxLines: 3000);
    final bigController = TerminalController();
    final bigFind = TerminalFind(terminal: big, controller: bigController);
    addTearDown(() {
      bigFind.dispose();
      bigController.dispose();
    });
    for (var i = 0; i < 1200; i++) {
      big.write('x\r\n');
    }
    bigFind.query = 'x';
    expect(bigFind.matchCount, TerminalFind.maxResults);
    expect(bigFind.capped, isTrue);
  });
}
