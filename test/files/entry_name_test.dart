import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/files/domain/entry_name.dart';

void main() {
  const siblings = {'notes.txt', 'projects', '.env'};

  EntryNameError? check(String input, {String? current, Set<String>? seps}) =>
      validateEntryName(
        input,
        siblings: siblings,
        current: current,
        separators: seps ?? const {'/'},
      );

  test('a fresh name is accepted', () {
    expect(check('report.pdf'), isNull);
  });

  test('empty and whitespace-only names are rejected', () {
    expect(check(''), EntryNameError.empty);
    expect(check('   '), EntryNameError.empty);
  });

  test('a name containing a slash is rejected', () {
    // `a/b` reaches into another folder rather than naming one here.
    expect(check('a/b'), EntryNameError.containsSeparator);
    expect(check('/'), EntryNameError.containsSeparator);
  });

  test('a backslash is only a separator where the caller says so', () {
    // Legal in a POSIX filename, a separator on Windows.
    expect(check(r'a\b'), isNull);
    expect(check(r'a\b', seps: {'/', r'\'}), EntryNameError.containsSeparator);
  });

  test('. and .. are reserved', () {
    expect(check('.'), EntryNameError.reserved);
    expect(check('..'), EntryNameError.reserved);
    // Dotfiles and names that merely start with dots are fine.
    expect(check('.bashrc'), isNull);
    expect(check('...'), isNull);
  });

  test('a name an existing sibling already has is rejected', () {
    expect(check('notes.txt'), EntryNameError.exists);
    expect(check('projects'), EntryNameError.exists);
  });

  test('a hidden sibling still occupies its name', () {
    expect(check('.env'), EntryNameError.exists);
  });

  test('surrounding whitespace is ignored when comparing', () {
    expect(check('  notes.txt '), EntryNameError.exists);
  });

  test('renaming an entry does not collide with its own name', () {
    expect(check('notes.txt', current: 'notes.txt'), isNull);
    expect(check('projects', current: 'notes.txt'), EntryNameError.exists);
  });

  test('a case-only change is not a collision with a different sibling', () {
    expect(check('Notes.txt', current: 'notes.txt'), isNull);
  });

  test('isUnchangedName ignores surrounding whitespace', () {
    expect(isUnchangedName(' notes.txt ', 'notes.txt'), isTrue);
    expect(isUnchangedName('notes.md', 'notes.txt'), isFalse);
  });
}
