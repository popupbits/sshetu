import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/util/sort_entries.dart';

class _Entry {
  const _Entry(this.name, this.isDirectory, {this.size, this.modified});
  final String name;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;
}

List<String> _names(List<_Entry> entries) =>
    entries.map((e) => e.name).toList();

List<_Entry> _sortBy(
  List<_Entry> entries, {
  required SortField field,
  bool ascending = true,
}) => sortFileEntries(
  entries,
  isDirectory: (e) => e.isDirectory,
  name: (e) => e.name,
  size: (e) => e.size,
  modified: (e) => e.modified,
  field: field,
  ascending: ascending,
);

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

  group('sort by size', () {
    test('smallest first ascending, directories still pinned first', () {
      // The bug this guards against: sorting "by size" naively would
      // interleave directories (which have no size) among files, instead of
      // keeping the directories-first rule that holds for every sort mode.
      final sorted = _sortBy([
        const _Entry('big.bin', false, size: 3000),
        const _Entry('Projects', true),
        const _Entry('small.txt', false, size: 10),
        const _Entry('mid.log', false, size: 500),
      ], field: SortField.size);

      expect(_names(sorted), ['Projects', 'small.txt', 'mid.log', 'big.bin']);
    });

    test(
      'descending reverses the files but not the directories-first rule',
      () {
        final sorted = _sortBy(
          [
            const _Entry('small.txt', false, size: 10),
            const _Entry('Projects', true),
            const _Entry('big.bin', false, size: 3000),
          ],
          field: SortField.size,
          ascending: false,
        );

        expect(_names(sorted), ['Projects', 'big.bin', 'small.txt']);
      },
    );

    test('a file with no reported size sorts after every sized file', () {
      // The bug this guards against: treating a null size as 0 would put an
      // unknown-size file first under ascending order, claiming it is the
      // smallest when nothing is actually known about it.
      final sorted = _sortBy([
        const _Entry('known.txt', false, size: 10),
        const _Entry('unknown.dat', false),
      ], field: SortField.size);

      expect(_names(sorted), ['known.txt', 'unknown.dat']);

      final descending = _sortBy(
        [
          const _Entry('known.txt', false, size: 10),
          const _Entry('unknown.dat', false),
        ],
        field: SortField.size,
        ascending: false,
      );
      // Still last, even reversed — an unknown size is not "biggest" either.
      expect(_names(descending), ['known.txt', 'unknown.dat']);
    });
  });

  group('sort by modified', () {
    test('oldest first ascending, directories pinned first', () {
      final now = DateTime.utc(2024);
      final sorted = _sortBy([
        _Entry('new.txt', false, modified: now),
        const _Entry('Archive', true),
        _Entry(
          'old.txt',
          false,
          modified: now.subtract(const Duration(days: 30)),
        ),
      ], field: SortField.modified);

      expect(_names(sorted), ['Archive', 'old.txt', 'new.txt']);
    });

    test('newest first descending', () {
      final now = DateTime.utc(2024);
      final sorted = _sortBy(
        [
          _Entry(
            'old.txt',
            false,
            modified: now.subtract(const Duration(days: 30)),
          ),
          _Entry('new.txt', false, modified: now),
        ],
        field: SortField.modified,
        ascending: false,
      );

      expect(_names(sorted), ['new.txt', 'old.txt']);
    });
  });
}
