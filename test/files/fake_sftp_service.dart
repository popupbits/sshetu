import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sshetu/core/ssh/sftp_service.dart';

/// An in-memory [SftpService] for `FileBrowserController` tests — no socket,
/// no server, just a map of directory listings the test sets up.
///
/// [download] and [upload] still touch the real local filesystem: the
/// controller's job is to move bytes to and from wherever the local pane is
/// pointed, and a fake that skipped that step could not catch a bug in how
/// the controller computes that path.
class FakeSftpService implements SftpService {
  FakeSftpService({Map<String, List<RemoteEntry>>? directories})
    : directories = directories ?? {};

  /// Directory path -> its listing. Tests seed this directly; [list] never
  /// re-sorts it, so a test can also use this to pin the exact order the
  /// controller is expected to show.
  final Map<String, List<RemoteEntry>> directories;

  /// Set by a test to make [list] on this one path fail, the way a
  /// permission error or a deleted directory would.
  String? failListPath;

  /// What kind of [SftpException] [failListPath] raises — permission denied
  /// by default, since that is the state exercised most: a directory that
  /// exists but this account cannot read.
  SftpFailureKind failListKind = SftpFailureKind.permissionDenied;

  /// Set by a test to make the next [download] fail after recording the
  /// attempt, the way a dropped connection mid-transfer would.
  Object? downloadError;

  /// Set by a test to make the next [upload] fail after recording the
  /// attempt.
  Object? uploadError;

  /// Set by a test that needs a download to still be "in flight" at a known
  /// point — e.g. to prove `FileBrowserController.cancelTransfer` reaches a
  /// running job's own token. [download] awaits this before doing anything
  /// else, so the controller has already created the `TransferJob` and
  /// returned control to the test by the time it matters.
  Future<void>? downloadGate;

  /// Path that fails [delete] with [deleteError] — a test's way to prove a
  /// batch delete keeps going after one entry refuses, instead of a raw
  /// exception escaping the loop and abandoning the rest of the batch.
  String? deleteFailPath;
  Object deleteError = SftpException(
    'Could not delete: simulated failure.',
    kind: SftpFailureKind.permissionDenied,
  );

  /// `~`/relative-input -> the path [resolveRemotePath] should report for it
  /// — the fake's stand-in for the server-side `realpath` a test cannot
  /// otherwise observe. Anything not listed here resolves to itself.
  final Map<String, String> resolveOverrides = {};

  /// Explicit [statPath] answers for a test that wants to force "missing" or
  /// "file" for a path that is not naturally derivable from [directories]
  /// (e.g. a path nobody has listed yet).
  final Map<String, RemotePathKind> statOverrides = {};

  /// Runs at the start of every [download], with the remote path, before
  /// anything else — a folder-transfer test's way to cancel partway through
  /// (cancel the job, then let this file proceed and see the token) or to fail
  /// one specific file of many.
  Future<void> Function(String remotePath)? beforeDownload;

  /// The same, for [upload].
  Future<void> Function(String remotePath)? beforeUpload;

  /// Set by a test to make [rename] / [mkdir] fail.
  Object? renameError;
  Object? mkdirError;

  final List<String> downloadedRemotePaths = [];
  final List<String> uploadedRemotePaths = [];
  final List<String> deletedPaths = [];
  final List<(String, String)> renameCalls = [];
  final List<String> mkdirPaths = [];
  final Map<String, int> chmodCalls = {};
  var closeCallCount = 0;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    if (failListPath == path) {
      throw SftpException(
        'Could not read $path: simulated failure.',
        kind: failListKind,
      );
    }
    final listing = directories[path];
    if (listing == null && missingDirectoriesFail) {
      throw SftpException(
        'Could not read $path: no such file.',
        kind: SftpFailureKind.notFound,
      );
    }
    return listing ?? const [];
  }

  /// When true, [list] on a path that is not in [directories] fails with
  /// "not found" the way a real server does, instead of the lenient empty
  /// listing most tests rely on. A folder upload's destination scan needs the
  /// real behaviour to tell a folder that exists from one it must create.
  bool missingDirectoriesFail = false;

  @override
  Future<void> download({
    required String remotePath,
    required String localPath,
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) async {
    await beforeDownload?.call(remotePath);
    downloadedRemotePaths.add(remotePath);
    final gate = downloadGate;
    if (gate != null) await gate;
    final error = downloadError;
    if (error != null) throw error;
    if (cancelToken?.isCancelled ?? false) {
      throw const SftpCancelledException();
    }
    onProgress?.call(5, 10);
    onProgress?.call(10, 10);
    await File(localPath).writeAsString('downloaded');
  }

  @override
  Future<void> upload({
    required String localPath,
    required String remotePath,
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) async {
    await beforeUpload?.call(remotePath);
    uploadedRemotePaths.add(remotePath);
    final error = uploadError;
    if (error != null) throw error;
    if (cancelToken?.isCancelled ?? false) {
      throw const SftpCancelledException();
    }
    onProgress?.call(5, 10);
    onProgress?.call(10, 10);
    // A real server would show the new file on the next listing; reflecting
    // that here is what lets a test prove the controller actually reloads
    // the remote pane after an upload, instead of just trusting it did.
    final dir = p.posix.dirname(remotePath);
    final list = directories.putIfAbsent(dir, () => []);
    // Replacing, not appending: an overwrite on a real server leaves one
    // file under the name, not two.
    list
      ..removeWhere((e) => e.path == remotePath)
      ..add(
        RemoteEntry(
          name: p.posix.basename(remotePath),
          path: remotePath,
          isDirectory: false,
          size: 10,
        ),
      );
  }

  /// Moves the entry within its listing, the way the next `list()` on a real
  /// server would show it.
  @override
  Future<void> rename(String fromPath, String toPath) async {
    renameCalls.add((fromPath, toPath));
    final error = renameError;
    if (error != null) throw error;
    final list = directories[p.posix.dirname(fromPath)];
    final index = list?.indexWhere((e) => e.path == fromPath) ?? -1;
    if (list == null || index < 0) {
      throw SftpException(
        'Could not rename: no such file.',
        kind: SftpFailureKind.notFound,
      );
    }
    final old = list[index];
    list[index] = RemoteEntry(
      name: p.posix.basename(toPath),
      path: toPath,
      isDirectory: old.isDirectory,
      size: old.size,
      modified: old.modified,
      permissions: old.permissions,
      isSymlink: old.isSymlink,
    );
    final children = directories.remove(fromPath);
    if (children != null) directories[toPath] = children;
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    if (deleteFailPath == entry.path) throw deleteError;
    deletedPaths.add(entry.path);
    final dir = p.posix.dirname(entry.path);
    directories[dir]?.removeWhere((e) => e.path == entry.path);
  }

  /// Like a real server, refuses a path that is already a directory —
  /// with the protocol's generic failure, since SFTP v3 has no "exists"
  /// status — so a test sees the controller cope with that.
  @override
  Future<void> mkdir(String path) async {
    final error = mkdirError;
    if (error != null) throw error;
    if (directories.containsKey(path)) {
      throw SftpException('Could not create: failure.');
    }
    mkdirPaths.add(path);
    directories[path] = [];
    directories
        .putIfAbsent(p.posix.dirname(path), () => [])
        .add(
          RemoteEntry(
            name: p.posix.basename(path),
            path: path,
            isDirectory: true,
          ),
        );
  }

  @override
  Future<void> setPermissions(String path, int mode) async {
    chmodCalls[path] = mode;
    fileOps.add('chmod $path ${mode.toRadixString(8)}');
    final stat = fileStats[path];
    if (stat != null) {
      fileStats[path] = RemoteFileStat(
        isDirectory: false,
        size: stat.size,
        modified: stat.modified,
        permissions: mode,
        userId: stat.userId,
        groupId: stat.groupId,
      );
    }
    // Reflect the change into whatever listing already carries this entry,
    // the same way a real server's next `list()` would — otherwise a
    // controller test could never observe the `drwx...` string it just
    // asked to change.
    for (final entry in directories.values) {
      final index = entry.indexWhere((e) => e.path == path);
      if (index < 0) continue;
      final old = entry[index];
      entry[index] = RemoteEntry(
        name: old.name,
        path: old.path,
        isDirectory: old.isDirectory,
        size: old.size,
        modified: old.modified,
        permissions: mode,
        isSymlink: old.isSymlink,
      );
    }
  }

  final List<String> resolveCalls = [];

  @override
  Future<String> resolveRemotePath(String path) async {
    resolveCalls.add(path);
    return resolveOverrides[path] ?? path;
  }

  @override
  Future<RemotePathKind> statPath(String path) async {
    final override = statOverrides[path];
    if (override != null) return override;
    if (directories.containsKey(path)) return RemotePathKind.directory;
    for (final entry in directories.values) {
      if (entry.any((e) => e.path == path)) {
        final match = entry.firstWhere((e) => e.path == path);
        return match.isDirectory
            ? RemotePathKind.directory
            : RemotePathKind.file;
      }
    }
    return RemotePathKind.missing;
  }

  // --- File contents, for the editor -------------------------------------
  //
  // A small model of a real server's files: bytes, a modification time, a
  // mode and an owner per path. Every call is logged to [fileOps] in order,
  // so a test can assert the exact save sequence (temp, chmod, rename).

  /// Path -> contents.
  final Map<String, Uint8List> files = {};

  /// Path -> (mtime, mode, uid, gid). Filled in by [putFile] and by writes.
  final Map<String, RemoteFileStat> fileStats = {};

  /// Paths that are symbolic links (to a file also in [files]).
  final Set<String> symlinks = {};

  /// Whether the server advertises posix-rename.
  bool atomicRenameSupported = true;

  /// Fails [writeFile] for any path this matches, the way a directory the
  /// user cannot create files in would.
  bool Function(String path)? failWriteFor;

  /// Fails [atomicRename].
  Object? atomicRenameError;

  /// Fails [setOwner] — the ordinary answer for anyone but root.
  bool setOwnerRefused = false;

  /// Fails [readFile] with this.
  Object? readError;

  /// The owner a file created by this account gets.
  int ownUid = 1000;
  int ownGid = 1000;

  /// The clock for modification times — a test moves it to make a later
  /// write distinguishable from an earlier one.
  DateTime now = DateTime.utc(2026, 1, 1, 12);

  final List<String> fileOps = [];

  /// Seeds [path] with [text] as UTF-8 (or [bytes] verbatim).
  void putFile(
    String path, {
    String? text,
    List<int>? bytes,
    int mode = 420, // 0644
    int? uid,
    int? gid,
    DateTime? modified,
  }) {
    final data = Uint8List.fromList(bytes ?? utf8.encode(text ?? ''));
    files[path] = data;
    fileStats[path] = RemoteFileStat(
      isDirectory: false,
      size: data.length,
      modified: modified ?? now,
      permissions: mode,
      userId: uid ?? ownUid,
      groupId: gid ?? ownGid,
    );
  }

  /// Someone else editing [path] on the server behind the editor's back.
  void changeBehindTheScenes(String path, String text) {
    final old = fileStats[path]!;
    now = now.add(const Duration(seconds: 5));
    putFile(
      path,
      text: text,
      mode: old.permissions ?? 420,
      uid: old.userId,
      gid: old.groupId,
    );
  }

  String textOf(String path) => utf8.decode(files[path]!);

  @override
  Future<RemoteFileStat> stat(String path, {bool followLink = true}) async {
    fileOps.add(followLink ? 'stat $path' : 'lstat $path');
    final stat = fileStats[path];
    if (stat == null) {
      if (directories.containsKey(path)) {
        return const RemoteFileStat(isDirectory: true);
      }
      throw SftpException(
        'Could not read $path: no such file.',
        kind: SftpFailureKind.notFound,
      );
    }
    if (!followLink && symlinks.contains(path)) {
      return const RemoteFileStat(isDirectory: false, isSymlink: true);
    }
    return stat;
  }

  @override
  Future<Uint8List> readFile(String path, {required int maxBytes}) async {
    fileOps.add('read $path');
    final error = readError;
    if (error != null) throw error;
    final data = files[path];
    if (data == null) {
      throw SftpException(
        'Could not open $path: no such file.',
        kind: SftpFailureKind.notFound,
      );
    }
    if (data.length > maxBytes) {
      throw SftpException('Could not open $path: larger than allowed.');
    }
    return Uint8List.fromList(data);
  }

  @override
  Future<void> writeFile(
    String path,
    Uint8List bytes, {
    bool exclusive = false,
  }) async {
    fileOps.add(exclusive ? 'create $path' : 'write $path');
    if (failWriteFor?.call(path) ?? false) {
      throw SftpException(
        'Could not save $path: permission denied.',
        kind: SftpFailureKind.permissionDenied,
      );
    }
    if (exclusive && files.containsKey(path)) {
      throw SftpException('Could not save $path: failure.');
    }
    final old = fileStats[path];
    now = now.add(const Duration(seconds: 1));
    files[path] = Uint8List.fromList(bytes);
    fileStats[path] = RemoteFileStat(
      isDirectory: false,
      size: bytes.length,
      modified: now,
      // Writing into an existing file keeps its mode and owner; a new one
      // gets this account's defaults, the way a real umask would.
      permissions: old?.permissions ?? 420,
      userId: old?.userId ?? ownUid,
      groupId: old?.groupId ?? ownGid,
    );
  }

  @override
  Future<bool> supportsAtomicRename() async => atomicRenameSupported;

  @override
  Future<void> atomicRename(String fromPath, String toPath) async {
    fileOps.add('rename $fromPath -> $toPath');
    final error = atomicRenameError;
    if (error != null) throw error;
    files[toPath] = files.remove(fromPath)!;
    fileStats[toPath] = fileStats.remove(fromPath)!;
    symlinks.remove(toPath);
  }

  @override
  Future<void> removeFile(String path) async {
    fileOps.add('remove $path');
    files.remove(path);
    fileStats.remove(path);
  }

  @override
  Future<void> setOwner(
    String path, {
    required int userId,
    required int groupId,
  }) async {
    fileOps.add('chown $path $userId:$groupId');
    if (setOwnerRefused) {
      throw SftpException(
        'Could not change the owner of $path: permission denied.',
        kind: SftpFailureKind.permissionDenied,
      );
    }
    final old = fileStats[path]!;
    fileStats[path] = RemoteFileStat(
      isDirectory: false,
      size: old.size,
      modified: old.modified,
      permissions: old.permissions,
      userId: userId,
      groupId: groupId,
    );
  }

  @override
  Future<void> close() async {
    closeCallCount++;
  }
}
