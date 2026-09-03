import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ssh_navigator/core/ssh/sftp_service.dart';

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

  final List<String> downloadedRemotePaths = [];
  final List<String> uploadedRemotePaths = [];
  final List<String> deletedPaths = [];
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
    return directories[path] ?? const [];
  }

  @override
  Future<void> download({
    required String remotePath,
    required String localPath,
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) async {
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
    list.add(
      RemoteEntry(
        name: p.posix.basename(remotePath),
        path: remotePath,
        isDirectory: false,
        size: 10,
      ),
    );
  }

  @override
  Future<void> rename(String fromPath, String toPath) async {}

  @override
  Future<void> delete(RemoteEntry entry) async {
    if (deleteFailPath == entry.path) throw deleteError;
    deletedPaths.add(entry.path);
    final dir = p.posix.dirname(entry.path);
    directories[dir]?.removeWhere((e) => e.path == entry.path);
  }

  @override
  Future<void> mkdir(String path) async {}

  @override
  Future<void> setPermissions(String path, int mode) async {
    chmodCalls[path] = mode;
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

  @override
  Future<void> close() async {
    closeCallCount++;
  }
}
