import '../../../core/ssh/sftp_service.dart';

/// How deep a folder transfer will walk before it stops descending.
///
/// Symlinks are never followed (see [planFolderTransfer]), so a genuine cycle
/// cannot happen through one — but a bind mount, a server-side loop the
/// listing does not flag, or simply a pathological tree can still go on far
/// longer than anyone meant to copy by tapping "Download" on a folder. Thirty
/// two levels is deeper than any real project tree and shallow enough that
/// hitting it is a clear signal, reported as skipped rather than silently
/// truncated.
const kMaxTransferDepth = 32;

/// One entry as the folder walk sees it — the common shape of a
/// [RemoteEntry] and a `LocalEntry`, so a single planner serves both
/// directions.
class WalkEntry {
  const WalkEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isSymlink = false,
    this.size,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isSymlink;
  final int? size;
}

/// Lists one directory for the walk. The remote side wraps
/// [SftpService.list], the local side `LocalFsService.list`.
typedef DirectoryLister = Future<List<WalkEntry>> Function(String path);

/// Joins a directory and a name on the *target* side, which may use a
/// different separator from the source — a remote host is always POSIX, the
/// local pane follows the platform.
typedef PathJoin = String Function(String dir, String name);

/// A directory the transfer has to exist on the target side.
class PlannedDirectory {
  const PlannedDirectory({required this.target, this.parent});

  final String target;

  /// The target path of the directory this one lives in, or null for the root
  /// of the transfer. Lets the conflict scan skip listing everything under a
  /// directory it already knows does not exist.
  final String? parent;
}

/// One file the transfer will copy.
class PlannedFile {
  const PlannedFile({
    required this.source,
    required this.targetDir,
    required this.target,
    required this.name,
    this.size,
  });

  final String source;

  /// The target directory this file is written into, as it appears in
  /// [TransferPlan.directories].
  final String targetDir;
  final String target;
  final String name;

  /// Null when the source did not report one; counts as zero toward the
  /// job's byte total, so the bar under-promises rather than stalling.
  final int? size;
}

/// Everything a folder transfer will do, worked out before a byte moves.
///
/// Planned up front rather than streamed file-by-file as the walk finds them
/// so the job can show "3 of 40 files" from the start, and so the conflict
/// question is asked once for the whole job rather than halfway through it.
class TransferPlan {
  const TransferPlan({
    required this.directories,
    required this.files,
    this.skippedSymlinks = 0,
    this.skippedTooDeep = 0,
  });

  /// Parents always before their children, starting with the transfer's own
  /// root — the order they have to be created in.
  final List<PlannedDirectory> directories;
  final List<PlannedFile> files;

  /// Symlinks met during the walk and left alone.
  final int skippedSymlinks;

  /// Directories deeper than the depth limit, not entered.
  final int skippedTooDeep;

  int get skipped => skippedSymlinks + skippedTooDeep;

  int get totalBytes => bytesOf(files);

  static int bytesOf(Iterable<PlannedFile> files) =>
      files.fold(0, (sum, f) => sum + (f.size ?? 0));
}

/// Walks [sourceRoot] and plans copying it to [targetRoot].
///
/// **Symlinks are skipped, never followed**, whichever way they point: a link
/// back up the tree turns a folder download into an infinite one, and a link
/// out of it copies something the user never chose. Directories deeper than
/// [maxDepth] below the root are skipped too. Both are counted on the plan so
/// the job can say what it left behind instead of quietly omitting it.
///
/// [isCancelled] is checked between listings; the walk throws
/// [SftpCancelledException] as soon as it sees it set, so cancelling a job
/// that is still being planned stops it promptly on a large tree.
Future<TransferPlan> planFolderTransfer({
  required String sourceRoot,
  required String targetRoot,
  required DirectoryLister listSource,
  required PathJoin joinTarget,
  int maxDepth = kMaxTransferDepth,
  bool Function()? isCancelled,
}) async {
  final directories = <PlannedDirectory>[];
  final files = <PlannedFile>[];
  var symlinks = 0;
  var tooDeep = 0;

  Future<void> walk(
    String source,
    String target,
    String? parent,
    int depth,
  ) async {
    if (isCancelled?.call() ?? false) throw const SftpCancelledException();
    directories.add(PlannedDirectory(target: target, parent: parent));
    final entries = await listSource(source);
    for (final entry in entries) {
      if (entry.isSymlink) {
        symlinks++;
        continue;
      }
      final entryTarget = joinTarget(target, entry.name);
      if (entry.isDirectory) {
        if (depth + 1 > maxDepth) {
          tooDeep++;
          continue;
        }
        await walk(entry.path, entryTarget, target, depth + 1);
      } else {
        files.add(
          PlannedFile(
            source: entry.path,
            targetDir: target,
            target: entryTarget,
            name: entry.name,
            size: entry.size,
          ),
        );
      }
    }
  }

  await walk(sourceRoot, targetRoot, null, 0);
  return TransferPlan(
    directories: directories,
    files: files,
    skippedSymlinks: symlinks,
    skippedTooDeep: tooDeep,
  );
}

/// What to do with files that already exist at the destination. Asked once
/// per job and applied to every conflicting file in it — a dialog per file
/// on a folder of hundreds is not a choice, it is a chore.
enum ConflictChoice { overwrite, skipExisting, cancel }

/// Lists every planned directory on the target side and returns the names
/// already in each, keyed by [PlannedDirectory.target].
///
/// A directory whose listing fails is treated as not existing, and nothing
/// under it is listed at all — a download into a fresh folder costs one failed
/// listing, not one per subdirectory. A failure for another reason (a file in
/// the way, no permission) surfaces when the transfer tries to create or
/// write there, with an error that names the actual problem.
Future<Map<String, Set<String>>> scanExistingNames(
  TransferPlan plan,
  DirectoryLister listTarget,
) async {
  final existing = <String, Set<String>>{};
  final missing = <String>{};
  for (final dir in plan.directories) {
    final parent = dir.parent;
    if (parent != null && missing.contains(parent)) {
      missing.add(dir.target);
      continue;
    }
    try {
      final entries = await listTarget(dir.target);
      existing[dir.target] = {for (final e in entries) e.name};
    } on Object {
      missing.add(dir.target);
    }
  }
  return existing;
}

/// The planned files whose target name is already taken, given what
/// [scanExistingNames] found.
List<PlannedFile> findConflicts(
  TransferPlan plan,
  Map<String, Set<String>> existingNames,
) => [
  for (final file in plan.files)
    if (existingNames[file.targetDir]?.contains(file.name) ?? false) file,
];

/// The files a job actually copies once [choice] has been applied to
/// [conflicts]. Nothing for [ConflictChoice.cancel]; everything for
/// [ConflictChoice.overwrite]; everything but the conflicts otherwise.
List<PlannedFile> applyConflictChoice(
  TransferPlan plan,
  List<PlannedFile> conflicts,
  ConflictChoice choice,
) {
  switch (choice) {
    case ConflictChoice.cancel:
      return const [];
    case ConflictChoice.overwrite:
      return plan.files;
    case ConflictChoice.skipExisting:
      final skip = {for (final f in conflicts) f.target};
      return [
        for (final f in plan.files)
          if (!skip.contains(f.target)) f,
      ];
  }
}
