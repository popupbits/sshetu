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

  /// Set by a test to make the next [download] fail after recording the
  /// attempt, the way a dropped connection mid-transfer would.
  Object? downloadError;

  final List<String> downloadedRemotePaths = [];
  final List<String> uploadedRemotePaths = [];
  final List<String> deletedPaths = [];
  var closeCallCount = 0;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    if (failListPath == path) {
      throw SftpException('Could not read $path: no such file.');
    }
    return directories[path] ?? const [];
  }

  @override
  Future<void> download({
    required String remotePath,
    required String localPath,
    SftpProgress? onProgress,
  }) async {
    downloadedRemotePaths.add(remotePath);
    final error = downloadError;
    if (error != null) throw error;
    onProgress?.call(5, 10);
    onProgress?.call(10, 10);
    await File(localPath).writeAsString('downloaded');
  }

  @override
  Future<void> upload({
    required String localPath,
    required String remotePath,
    SftpProgress? onProgress,
  }) async {
    uploadedRemotePaths.add(remotePath);
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
    deletedPaths.add(entry.path);
    final dir = p.posix.dirname(entry.path);
    directories[dir]?.removeWhere((e) => e.path == entry.path);
  }

  @override
  Future<void> mkdir(String path) async {}

  @override
  Future<void> close() async {
    closeCallCount++;
  }
}
