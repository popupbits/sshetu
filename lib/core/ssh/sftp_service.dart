import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../util/sort_entries.dart';
import 'ssh_connection.dart';

/// One entry in a remote directory listing.
///
/// A domain type rather than the raw `SftpName` dartssh2 hands back: the UI
/// should never learn the wire format, and a `longname` string meant for a
/// human terminal is not something to parse for size or permissions.
class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
    this.permissions,
    this.isSymlink = false,
  });

  final String name;

  /// The absolute remote path.
  final String path;

  final bool isDirectory;

  /// Null for a directory — SFTP reports one, but showing "4,096 bytes" next
  /// to every folder is noise nobody reads.
  final int? size;

  /// The server's modification time. Null when the server did not send one,
  /// which happens more often than the spec suggests.
  final DateTime? modified;

  /// POSIX mode bits (`SftpFileMode.value`), for a future permissions column.
  /// Null when the server sent no permissions flag.
  final int? permissions;

  /// True when the entry is a symbolic link itself. Listings report a link's
  /// own attributes rather than its target's (OpenSSH's `readdir` uses
  /// `lstat`), so a link to a directory is *not* [isDirectory] — and a folder
  /// transfer relies on that to skip links instead of following one back up
  /// the tree forever.
  final bool isSymlink;

  @override
  String toString() => 'RemoteEntry($path)';
}

/// What kind of failure an [SftpException] wraps, drawn only from the status
/// codes the SFTP protocol actually defines (`sftp_status_code.dart`) — never
/// from parsing the human-readable message a server chose to send, which
/// varies by implementation and is not something to branch on.
enum SftpFailureKind {
  /// `SSH_FX_NO_SUCH_FILE`.
  notFound,

  /// `SSH_FX_PERMISSION_DENIED`.
  permissionDenied,

  /// Every other status — including `SSH_FX_FAILURE`, the protocol's one
  /// catch-all, which is also what a non-empty `rmdir` comes back as on most
  /// servers. There is no dedicated status for that case to switch on, so it
  /// lands here with whatever text the server sent still attached to
  /// [SftpException.message].
  other,
}

/// Raised by every [SftpService] operation. The message is written to be
/// shown to a user directly — never a raw dartssh2 or platform exception,
/// whose text can include a handle, a byte offset, or the shape of a wire
/// packet.
class SftpException implements Exception {
  SftpException(this.message, {this.cause, this.kind = SftpFailureKind.other});

  final String message;
  final Object? cause;

  /// What a caller can safely switch on to render a distinct UI state (a
  /// "permission denied" pane vs. a "not found" one) without string-matching
  /// [message], which is written for reading, not parsing.
  final SftpFailureKind kind;

  @override
  String toString() => 'SftpException: $message';
}

/// What [SftpService.statPath] found at a path — or that there was nothing
/// there. A dedicated stat rather than inferring this from a failed
/// [SftpService.list] call: opening a file as a directory fails with
/// whatever status code a given server happens to use for "not a directory"
/// (there is no dedicated one in the SFTP spec), which is not reliable
/// enough to build a "you typed a file, not a folder" message on. Asking the
/// server what the path actually is, instead, is.
enum RemotePathKind { missing, file, directory }

/// What [SftpService.stat] reports about one path: enough to notice that a
/// file changed under an open editor, and to give a replacement file the
/// same permissions and owner as the one it replaces.
class RemoteFileStat {
  const RemoteFileStat({
    required this.isDirectory,
    this.isSymlink = false,
    this.size,
    this.modified,
    this.permissions,
    this.userId,
    this.groupId,
  });

  final bool isDirectory;

  /// Only ever true for a stat that did not follow links.
  final bool isSymlink;

  final int? size;

  /// Whole seconds — the resolution SFTP v3 carries.
  final DateTime? modified;

  /// The low permission bits (`mode & 0x1FF`), or null when not reported.
  final int? permissions;
  final int? userId;
  final int? groupId;

  @override
  String toString() =>
      'RemoteFileStat(size: $size, modified: $modified, '
      'permissions: ${permissions?.toRadixString(8)})';
}

/// A cooperative cancellation flag threaded through one transfer.
///
/// Not a wrapper around closing the SFTP file handle mid-flight: dartssh2
/// gives no guarantee that a server responds to requests already in flight
/// on a handle that gets closed out from under them, so that path risks a
/// hang instead of a clean stop. Checking a flag between chunks — the same
/// technique [SftpFileWriter.abort] already uses on the upload side — is
/// slower to react but always terminates.
class SftpCancelToken {
  var _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  /// Stops the transfer this token is attached to. Safe to call more than
  /// once, and safe to call before a transfer has attached its callback —
  /// [isCancelled] is checked independently of it.
  void cancel() {
    _cancelled = true;
    _onCancel?.call();
  }

  void attach(void Function() onCancel) => _onCancel = onCancel;
  void detach() => _onCancel = null;
}

/// Thrown by [SftpService.download]/[SftpService.upload] when
/// [SftpCancelToken.cancel] stopped the transfer partway. Distinct from
/// [SftpException] so a caller can tell "the user stopped this" from "this
/// failed" — the transfer list should not show a cancelled row as an error.
class SftpCancelledException implements Exception {
  const SftpCancelledException();

  @override
  String toString() => 'SftpCancelledException';
}

/// What a transfer reports as it runs. [total] is null when the server did
/// not report a size, which happens for some virtual filesystems — the UI
/// then shows bytes moved without a percentage rather than guessing one.
typedef SftpProgress = void Function(int transferred, int? total);

/// File operations over one host's filesystem, addressed by absolute path.
///
/// An interface rather than a single class so a controller can be tested
/// against a fake that never opens a socket — see `test/files/`.
abstract interface class SftpService {
  /// Lists [path], directories first then files, both alphabetical and
  /// case-insensitive — the order every desktop file manager already uses,
  /// so nothing about this screen has to be learned.
  Future<List<RemoteEntry>> list(String path);

  /// Copies the remote file at [remotePath] to [localPath].
  ///
  /// [onProgress] exists because a large file with no feedback is
  /// indistinguishable from a hung connection. Never leaves a truncated file
  /// at [localPath]: on failure or [SftpCancelToken.cancel], whatever was
  /// written so far is discarded rather than left in place under the
  /// destination's name.
  Future<void> download({
    required String remotePath,
    required String localPath,
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  });

  /// Copies the local file at [localPath] to [remotePath], creating or
  /// replacing it. Like [download], failure or cancellation removes whatever
  /// was written to [remotePath] rather than leaving a truncated file behind
  /// under the original name.
  Future<void> upload({
    required String localPath,
    required String remotePath,
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  });

  Future<void> rename(String fromPath, String toPath);

  /// Removes [entry]. Uses the directory or file removal request depending on
  /// [RemoteEntry.isDirectory] — SFTP refuses the wrong one outright.
  Future<void> delete(RemoteEntry entry);

  Future<void> mkdir(String path);

  /// Changes [path]'s POSIX permission bits to [mode] (the low 9 bits of a
  /// `chmod`-style value; see `domain/permissions.dart`). File-type bits are
  /// not settable this way and are not read from [mode] — a server that
  /// received them would simply ignore them, since permissions is the only
  /// thing `SSH_FXP_SETSTAT`'s mode field can change.
  Future<void> setPermissions(String path, int mode);

  /// Resolves [path] against the server's own notion of `~`, `.` and `..` —
  /// the client has no way to know a remote user's home directory or working
  /// directory on its own. Used before committing to a path someone typed in.
  Future<String> resolveRemotePath(String path);

  /// What is at [path] right now: missing, a file, or a directory. See
  /// [RemotePathKind] for why this is a dedicated call rather than inferred
  /// from a failed [list].
  Future<RemotePathKind> statPath(String path);

  /// The attributes of [path]. Follows a symlink unless [followLink] is
  /// false, in which case a link reports itself ([RemoteFileStat.isSymlink]).
  Future<RemoteFileStat> stat(String path, {bool followLink = true});

  /// Reads the whole file at [path] into memory — for the text editor, never
  /// for a transfer. Refuses with [SftpException] once more than [maxBytes]
  /// have arrived, so a file that grew since it was stat'ed, or a server
  /// that lied about its size, cannot fill memory.
  Future<Uint8List> readFile(String path, {required int maxBytes});

  /// Writes [bytes] to [path], creating it or truncating what is there.
  ///
  /// With [exclusive], refuses if [path] already exists — what a temporary
  /// file wants, so it never clobbers a stranger that happens to share its
  /// name.
  Future<void> writeFile(
    String path,
    Uint8List bytes, {
    bool exclusive = false,
  });

  /// Whether [atomicRename] can replace an existing file in one step — true
  /// when the server offers OpenSSH's `posix-rename@openssh.com`. Plain SFTP
  /// v3 `rename` refuses when the target exists, so without the extension
  /// there is no atomic replace to be had.
  Future<bool> supportsAtomicRename();

  /// Renames [fromPath] over [toPath], replacing it. Only meaningful when
  /// [supportsAtomicRename] said yes.
  Future<void> atomicRename(String fromPath, String toPath);

  /// Removes the file at [path].
  Future<void> removeFile(String path);

  /// Changes [path]'s owner and group. Usually refused unless the account is
  /// privileged — the caller treats a refusal as an answer, not an accident.
  Future<void> setOwner(
    String path, {
    required int userId,
    required int groupId,
  });

  /// Releases the SFTP channel. Does **not** touch the underlying
  /// [SshConnection] — a terminal session using the same connection must keep
  /// running after its file browser is closed.
  Future<void> close();
}

/// The real [SftpService], over one [SshConnection]'s existing session.
///
/// Deliberately does not open a new [SSHClient]: `client.sftp()` opens a
/// fresh *channel* on the transport already authenticated for this host, the
/// same way a second shell tab would. Opening a second [SshConnection]
/// instead would mean a second TCP connection, a second handshake and a
/// second round of host-key and credential prompts for something the user
/// already granted.
class SshSftpService implements SftpService {
  SshSftpService(this._connection);

  final SshConnection _connection;
  SftpClient? _sftp;

  Future<SftpClient> _client() async {
    final existing = _sftp;
    if (existing != null) return existing;
    try {
      final ssh = await _connection.client();
      final sftp = await ssh.sftp();
      _sftp = sftp;
      return sftp;
    } on SshConnectionException catch (e) {
      throw SftpException(e.message, cause: e);
    } on Object catch (e) {
      throw SftpException('Could not start an SFTP session.', cause: e);
    }
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    try {
      final sftp = await _client();
      final names = await sftp.listdir(path);
      final entries = <RemoteEntry>[];
      for (final name in names) {
        // Every listing repeats these two; a "directory" that cannot be
        // opened and a duplicate of the row already showing the path above it
        // are not useful rows, just clutter every folder pays.
        if (name.filename == '.' || name.filename == '..') continue;
        entries.add(
          RemoteEntry(
            name: name.filename,
            path: _join(path, name.filename),
            isDirectory: name.attr.isDirectory,
            size: name.attr.isDirectory ? null : name.attr.size,
            modified: _toDateTime(name.attr.modifyTime),
            permissions: name.attr.mode?.value,
            isSymlink: name.attr.isSymbolicLink,
          ),
        );
      }
      return sortFileEntries(
        entries,
        isDirectory: (e) => e.isDirectory,
        name: (e) => e.name,
      );
    } on Object catch (e) {
      throw _wrap(e, 'Could not read $path');
    }
  }

  @override
  Future<void> download({
    required String remotePath,
    required String localPath,
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) async {
    RandomAccessFile? local;
    SftpFile? remote;
    // Written to a sibling temp path and only renamed onto `localPath` once
    // every byte has arrived — the bug this guards against: the old
    // implementation opened `localPath` itself in `FileMode.write`, which
    // truncates it immediately, so a connection drop or a cancel partway
    // through left a half-downloaded file sitting under the real name,
    // indistinguishable from a complete one until something tried to read it.
    final tempPath = '$localPath.sftp-partial';
    var cancelled = false;
    try {
      final sftp = await _client();
      remote = await sftp.open(remotePath);
      final total = (await remote.stat()).size;
      local = await File(tempPath).open(mode: FileMode.write);
      final writer = local;
      final chunks = remote.read(
        length: total,
        onProgress: (n) => onProgress?.call(n, total),
      );
      await for (final chunk in chunks) {
        if (cancelToken?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
        await writer.writeFrom(chunk);
      }
      if (cancelled) throw const SftpCancelledException();
      await local.close();
      local = null;
      await File(tempPath).rename(localPath);
    } on Object catch (e) {
      if (e is SftpCancelledException) rethrow;
      throw _wrap(e, 'Could not download ${_basename(remotePath)}');
    } finally {
      await remote?.close();
      await local?.close();
      final temp = File(tempPath);
      if (await temp.exists()) await temp.delete();
    }
  }

  @override
  Future<void> upload({
    required String localPath,
    required String remotePath,
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) async {
    SftpFile? remote;
    // `truncate` below means opening the handle already discards whatever
    // was at `remotePath`, so a failure or cancel from here on has to remove
    // the file it just emptied rather than leave that half-written state
    // sitting under the original name — the same guarantee `download` gives
    // the local side, mirrored for the remote one.
    var wroteAnyBytes = false;
    try {
      final localFile = File(localPath);
      final total = await localFile.length();
      final sftp = await _client();
      remote = await sftp.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      wroteAnyBytes = true;
      final stream = localFile.openRead().map(
        (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
      );
      final writer = remote.write(
        stream,
        onProgress: (n) => onProgress?.call(n, total),
      );
      cancelToken?.attach(writer.abort);
      await writer.done;
      // `abort()` completes `writer.done` cleanly, with no error — so
      // "was cancel() ever called" is not enough to tell a genuine abort
      // from a cancel that arrived just as the last byte was acknowledged.
      // Comparing bytes actually written against the file's size is: a
      // completed transfer always reaches `total`, an aborted one never does.
      if ((cancelToken?.isCancelled ?? false) && writer.progress < total) {
        throw const SftpCancelledException();
      }
    } on Object catch (e) {
      if (wroteAnyBytes) await _cleanupPartialUpload(remotePath);
      if (e is SftpCancelledException) rethrow;
      throw _wrap(e, 'Could not upload ${_basename(localPath)}');
    } finally {
      cancelToken?.detach();
      await remote?.close();
    }
  }

  /// Best-effort removal of a remote file this upload truncated and then
  /// failed to finish writing. Swallows its own errors: the failure already
  /// being reported to the caller explains what went wrong, and a secondary
  /// "also could not clean up" error would only bury it.
  Future<void> _cleanupPartialUpload(String remotePath) async {
    try {
      final sftp = await _client();
      await sftp.remove(remotePath);
    } on Object {
      // Best effort, see above.
    }
  }

  @override
  Future<void> rename(String fromPath, String toPath) async {
    try {
      final sftp = await _client();
      await sftp.rename(fromPath, toPath);
    } on Object catch (e) {
      throw _wrap(e, 'Could not rename ${_basename(fromPath)}');
    }
  }

  @override
  Future<void> delete(RemoteEntry entry) async {
    try {
      final sftp = await _client();
      if (entry.isDirectory) {
        await sftp.rmdir(entry.path);
      } else {
        await sftp.remove(entry.path);
      }
    } on Object catch (e) {
      throw _wrap(e, 'Could not delete ${entry.name}');
    }
  }

  @override
  Future<void> mkdir(String path) async {
    try {
      final sftp = await _client();
      await sftp.mkdir(path);
    } on Object catch (e) {
      throw _wrap(e, 'Could not create ${_basename(path)}');
    }
  }

  @override
  Future<void> setPermissions(String path, int mode) async {
    try {
      final sftp = await _client();
      // Only the low 9 bits are permissions; masking here means a caller
      // that accidentally hands back a full `st_mode` (file-type bits and
      // all) still only changes what `chmod` would have changed.
      await sftp.setStat(
        path,
        SftpFileAttrs(mode: SftpFileMode.value(mode & 0x1FF)),
      );
    } on Object catch (e) {
      throw _wrap(e, 'Could not change permissions on ${_basename(path)}');
    }
  }

  @override
  Future<String> resolveRemotePath(String path) async {
    try {
      final sftp = await _client();
      return await sftp.absolute(path);
    } on Object catch (e) {
      throw _wrap(e, 'Could not resolve $path');
    }
  }

  @override
  Future<RemotePathKind> statPath(String path) async {
    try {
      final sftp = await _client();
      final attrs = await sftp.stat(path);
      return attrs.isDirectory ? RemotePathKind.directory : RemotePathKind.file;
    } on Object catch (e) {
      final wrapped = _wrap(e, 'Could not read $path');
      if (wrapped.kind == SftpFailureKind.notFound) {
        return RemotePathKind.missing;
      }
      throw wrapped;
    }
  }

  @override
  Future<RemoteFileStat> stat(String path, {bool followLink = true}) async {
    try {
      final sftp = await _client();
      final attrs = await sftp.stat(path, followLink: followLink);
      return RemoteFileStat(
        isDirectory: attrs.isDirectory,
        isSymlink: attrs.isSymbolicLink,
        size: attrs.size,
        modified: _toDateTime(attrs.modifyTime),
        permissions: attrs.mode == null ? null : attrs.mode!.value & 0x1FF,
        userId: attrs.userID,
        groupId: attrs.groupID,
      );
    } on Object catch (e) {
      throw _wrap(e, 'Could not read ${_basename(path)}');
    }
  }

  @override
  Future<Uint8List> readFile(String path, {required int maxBytes}) async {
    SftpFile? remote;
    try {
      final sftp = await _client();
      remote = await sftp.open(path);
      final builder = BytesBuilder(copy: false);
      // One byte past the cap is enough to know the file is over it, and
      // reading no further keeps a huge file from being pulled down at all.
      await for (final chunk in remote.read(length: maxBytes + 1)) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw SftpException(
            'Could not open ${_basename(path)}: larger than the editor allows.',
          );
        }
      }
      return builder.takeBytes();
    } on Object catch (e) {
      throw _wrap(e, 'Could not open ${_basename(path)}');
    } finally {
      await remote?.close();
    }
  }

  @override
  Future<void> writeFile(
    String path,
    Uint8List bytes, {
    bool exclusive = false,
  }) async {
    SftpFile? remote;
    try {
      final sftp = await _client();
      remote = await sftp.open(
        path,
        mode: exclusive
            ? SftpFileOpenMode.create |
                  SftpFileOpenMode.exclusive |
                  SftpFileOpenMode.write
            : SftpFileOpenMode.create |
                  SftpFileOpenMode.write |
                  SftpFileOpenMode.truncate,
      );
      await remote.writeBytes(bytes);
    } on Object catch (e) {
      throw _wrap(e, 'Could not save ${_basename(path)}');
    } finally {
      await remote?.close();
    }
  }

  @override
  Future<bool> supportsAtomicRename() async {
    try {
      final sftp = await _client();
      final handshake = await sftp.handshake;
      return handshake.extensions['posix-rename@openssh.com'] == '1';
    } on Object {
      return false;
    }
  }

  @override
  Future<void> atomicRename(String fromPath, String toPath) async {
    try {
      final sftp = await _client();
      // dartssh2's rename sends posix-rename@openssh.com whenever the server
      // advertised it, which is the only case this is called in.
      await sftp.rename(fromPath, toPath);
    } on Object catch (e) {
      throw _wrap(e, 'Could not save ${_basename(toPath)}');
    }
  }

  @override
  Future<void> removeFile(String path) async {
    try {
      final sftp = await _client();
      await sftp.remove(path);
    } on Object catch (e) {
      throw _wrap(e, 'Could not delete ${_basename(path)}');
    }
  }

  @override
  Future<void> setOwner(
    String path, {
    required int userId,
    required int groupId,
  }) async {
    try {
      final sftp = await _client();
      await sftp.setStat(path, SftpFileAttrs(userID: userId, groupID: groupId));
    } on Object catch (e) {
      throw _wrap(e, 'Could not change the owner of ${_basename(path)}');
    }
  }

  @override
  Future<void> close() async {
    final sftp = _sftp;
    _sftp = null;
    await sftp?.close();
  }

  static String _join(String dir, String name) =>
      dir.endsWith('/') ? '$dir$name' : '$dir/$name';

  static String _basename(String path) {
    final trimmed = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  static DateTime? _toDateTime(int? epochSeconds) => epochSeconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true);

  /// Turns whatever dartssh2 threw into a message safe to show a user —
  /// never the raw [SftpStatusError] text, which is written for a protocol
  /// log ("SftpStatusError: No such file(code 2)"), not a person.
  static SftpException _wrap(Object error, String action) {
    if (error is SftpException) return error;
    if (error is SshConnectionException) {
      return SftpException(error.message, cause: error);
    }
    if (error is SftpStatusError) {
      switch (error.code) {
        case SftpStatusCode.noSuchFile:
          return SftpException(
            '$action: no such file.',
            cause: error,
            kind: SftpFailureKind.notFound,
          );
        case SftpStatusCode.permissionDenied:
          return SftpException(
            '$action: permission denied.',
            cause: error,
            kind: SftpFailureKind.permissionDenied,
          );
        default:
          // SSH_FX_FAILURE (and everything else the spec leaves
          // unspecified) is the protocol's one catch-all — it is what a
          // non-empty `rmdir` comes back as on most servers, among other
          // things, and there is no dedicated status to switch on for that
          // case. The server's own message is the only diagnostic detail
          // available, so it is shown rather than discarded — this reports
          // it, it does not parse it, so `_wrap` still never *decides*
          // anything by matching the string.
          return SftpException('$action: ${error.message}.', cause: error);
      }
    }
    return SftpException('$action.', cause: error);
  }
}
