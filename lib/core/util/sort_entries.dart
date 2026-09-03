/// What a file listing can be ordered by, once directories-first is applied.
/// `name` is the default — the one order every entry has a value for, so it
/// is also the fallback when [size] or [modified] is null (see
/// [sortFileEntries]).
enum SortField { name, size, modified }

/// Sorts a list of file-system-shaped entries directories-first, then by
/// [field] within each group — ascending unless [ascending] is false.
///
/// Shared by the remote (SFTP) and local (`dart:io`) panes of the file
/// browser so the two directory listings are never subtly different orders —
/// and so the ordering itself is one function a test can pin down, instead of
/// two copies that drift.
///
/// Directories sort before files under every [field]: a "biggest first"
/// listing that scatters folders through it defeats the one thing
/// directories-first exists for, which is a stable place to start scanning.
List<T> sortFileEntries<T>(
  List<T> entries, {
  required bool Function(T entry) isDirectory,
  required String Function(T entry) name,
  int? Function(T entry)? size,
  DateTime? Function(T entry)? modified,
  SortField field = SortField.name,
  bool ascending = true,
}) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final aDir = isDirectory(a);
    final bDir = isDirectory(b);
    if (aDir != bDir) return aDir ? -1 : 1;

    int byName() => name(a).toLowerCase().compareTo(name(b).toLowerCase());
    // A directory has no size on either backend (see `RemoteEntry.size`);
    // sorting a mixed listing by size with `size == null` for every
    // directory in the group would be comparing nothing to nothing, so
    // directories fall back to name order even when the pane is sorted by
    // size or date.
    return switch (field) {
      SortField.name => ascending ? byName() : -byName(),
      SortField.size when !aDir => _compareNullable(
        size?.call(a),
        size?.call(b),
        ascending: ascending,
      ),
      SortField.modified when !aDir => _compareNullable(
        modified?.call(a)?.microsecondsSinceEpoch,
        modified?.call(b)?.microsecondsSinceEpoch,
        ascending: ascending,
      ),
      _ => ascending ? byName() : -byName(),
    };
  });
  return sorted;
}

/// Null sorts last regardless of [ascending] — a file with no reported size
/// or date is "unknown", not "smallest"/"oldest", and flipping the sort
/// direction should not walk it from the bottom of the list to the top.
int _compareNullable<T extends Comparable<T>>(
  T? a,
  T? b, {
  required bool ascending,
}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return ascending ? cmp : -cmp;
}
