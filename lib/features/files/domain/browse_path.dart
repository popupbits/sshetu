import 'package:path/path.dart' as p;

/// Path arithmetic for one pane of the file browser.
///
/// Takes an explicit [p.Context] rather than reaching for `dart:io`'s
/// `Platform` itself, for two reasons: the remote pane's paths are always
/// POSIX — that is what SFTP is — regardless of what OS this app happens to
/// be running on, so it always gets [p.posix]; and a fixed context is what
/// lets the navigation edge cases (root, `..` past root) be pinned down in a
/// test without the result depending on the machine running it.
class BrowsePath {
  const BrowsePath(this.context);

  final p.Context context;

  /// The root this path lives under — `/` for POSIX, `C:\` for a Windows
  /// drive. Not necessarily the *browser's* starting directory: a local pane
  /// that opens in `~/Documents` can still be walked up to `/`.
  String rootOf(String path) {
    final prefix = context.rootPrefix(path);
    return prefix.isEmpty ? path : prefix;
  }

  bool isRoot(String path) =>
      context.equals(context.normalize(path), rootOf(path));

  /// The parent of [path]. Idempotent at the root: going up from `/` returns
  /// `/` rather than throwing or wandering above the one directory a
  /// filesystem actually has — the caller does not have to special-case "am I
  /// at the top" before calling this.
  String up(String path) {
    final normalized = context.normalize(path);
    final root = rootOf(normalized);
    if (context.equals(normalized, root)) return root;
    final parent = context.dirname(normalized);
    return parent.isEmpty ? root : parent;
  }

  String join(String base, String name) => context.join(base, name);

  /// Every ancestor of [path] from the root down to (and including) [path]
  /// itself — what a breadcrumb bar renders, each entry paired with the path
  /// a tap on it navigates to.
  List<String> ancestry(String path) {
    final normalized = context.normalize(path);
    final root = rootOf(normalized);
    if (context.equals(normalized, root)) return [root];

    final relative = context.relative(normalized, from: root);
    final parts = context.split(relative);
    final result = <String>[root];
    var current = root;
    for (final part in parts) {
      if (part == '.') continue;
      current = context.join(current, part);
      result.add(current);
    }
    return result;
  }

  /// The label a breadcrumb chip shows for one entry of [ancestry] — the
  /// basename, or the root itself when there is no basename to show.
  String label(String path) {
    if (isRoot(path)) return rootOf(path);
    return context.basename(path);
  }
}
