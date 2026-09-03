/// Sorts a list of file-system-shaped entries directories-first, then
/// alphabetically and case-insensitively within each group.
///
/// Shared by the remote (SFTP) and local (`dart:io`) panes of the file
/// browser so the two directory listings are never subtly different orders —
/// and so the ordering itself is one function a test can pin down, instead of
/// two copies that drift.
List<T> sortFileEntries<T>(
  List<T> entries, {
  required bool Function(T entry) isDirectory,
  required String Function(T entry) name,
}) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final aDir = isDirectory(a);
    final bDir = isDirectory(b);
    if (aDir != bDir) return aDir ? -1 : 1;
    return name(a).toLowerCase().compareTo(name(b).toLowerCase());
  });
  return sorted;
}
