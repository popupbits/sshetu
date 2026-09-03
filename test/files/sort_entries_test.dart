import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/util/sort_entries.dart';

class _Entry {
  const _Entry(this.name, this.isDirectory);
  final String name;
  final bool isDirectory;
}

List<String> _names(List<_Entry> entries) =>
    entries.map((e) => e.name).toList();

void main() {
  List<_Entry> sort(List<_Entry> entries) => sortFileEntries(
    entries,
    isDirectory: (e) => e.isDirectory,
    name: (e) => e.name,
  );

  test('directories sort before files regardless of name', () {
    // The bug this guards against: a naive alphabetical sort would put
    // "Archive" (a directory) after "notes.txt" (a file), which is not how
    // any desktop file manager orders a folder.
    final sorted = sort([
      const _Entry('notes.txt', false),
      const _Entry('Archive', true),
      const _Entry('bin', true),
      const _Entry('README', false),
    ]);

    expect(_names(sorted), ['Archive', 'bin', 'notes.txt', 'README']);
  });

  test('within a group, names sort alphabetically ignoring case', () {
    // A pure ASCII sort would put every capitalized name before every
    // lowercase one ('Config' before 'app'), which reads as broken to a user
    // who has no idea the sort is case-sensitive.
    final sorted = sort([
      const _Entry('banana', false),
      const _Entry('Apple', false),
      const _Entry('cherry', false),
    ]);

    expect(_names(sorted), ['Apple', 'banana', 'cherry']);
  });

  test('does not mutate the input list', () {
    final input = [const _Entry('b', false), const _Entry('a', false)];
    final original = List.of(input);
    sortFileEntries(
      input,
      isDirectory: (e) => e.isDirectory,
      name: (e) => e.name,
    );
    expect(_names(input), _names(original));
  });

  test('an empty listing sorts to an empty listing', () {
    expect(sort(const []), isEmpty);
  });
}
