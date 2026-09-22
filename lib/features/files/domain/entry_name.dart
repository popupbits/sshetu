/// Why a name typed into the rename or new-folder dialog cannot be used.
///
/// An enum rather than a message: the dialog localizes it, and a test can
/// assert on which rule tripped without matching display text.
enum EntryNameError {
  /// Nothing but whitespace.
  empty,

  /// Contains a path separator — `a/b` would not name an entry in this folder
  /// but reach into (or create) another one, which is not what "rename" or
  /// "new folder" means.
  containsSeparator,

  /// `.` or `..`, which already name this folder and its parent.
  reserved,

  /// Another entry in the same folder already has this name. Checked up front
  /// because the two sides disagree on what happens otherwise: a POSIX
  /// `rename()` silently replaces a file at the target, which is data loss
  /// nobody asked for, while SFTP servers mostly refuse with a generic
  /// failure that says nothing useful.
  exists,
}

/// Checks [input] as the name of an entry in a folder whose current entries
/// are [siblings].
///
/// Returns null when the name is usable. [current] is the entry's own name
/// when renaming, so it does not collide with itself; when [input] is
/// unchanged from it the name is reported valid, and the caller decides that
/// renaming to the same name is a no-op (see [isUnchangedName]).
///
/// [separators] are the characters that split a path on the filesystem this
/// name is for — `/` for a remote host, and on Windows `\` as well for the
/// local pane, where either one is a separator.
///
/// Leading and trailing whitespace is ignored, matching what the dialog
/// submits: a name that differs from an existing one only by a trailing space
/// is almost always a slip of the thumb, not a deliberate second file.
EntryNameError? validateEntryName(
  String input, {
  required Iterable<String> siblings,
  String? current,
  Set<String> separators = const {'/'},
}) {
  final name = input.trim();
  if (name.isEmpty) return EntryNameError.empty;
  if (separators.any(name.contains)) return EntryNameError.containsSeparator;
  if (name == '.' || name == '..') return EntryNameError.reserved;
  if (name == current) return null;
  if (siblings.contains(name)) return EntryNameError.exists;
  return null;
}

/// True when [input] names the entry it would rename — nothing to do, and
/// not an error either.
bool isUnchangedName(String input, String current) => input.trim() == current;

/// Raised by the controller when asked to use a name [validateEntryName]
/// rejects. The dialog validates before it ever submits, so reaching this
/// means a caller skipped that step — a bug, not a user mistake.
class InvalidEntryNameException implements Exception {
  const InvalidEntryNameException(this.error);

  final EntryNameError error;

  @override
  String toString() => 'InvalidEntryNameException(${error.name})';
}
