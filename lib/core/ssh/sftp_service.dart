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

  @override
  String toString() => 'RemoteEntry($path)';
}

/// Raised by every [SftpService] operation. The message is written to be
/// shown to a user directly — never a raw dartssh2 or platform exception,
/// whose text can include a handle, a byte offset, or the shape of a wire
/// packet.
class SftpException implements Exception {
  SftpException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SftpException: $message';
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
  /// indistinguishable from a hung connection.
  Future<void> download({
    required String remotePath,
    required String localPath,
    SftpProgress? onProgress,
  });

  /// Copies the local file at [localPath] to [remotePath], creating or
  /// replacing it.
  Future<void> upload({
    required String localPath,
    required String remotePath,
    SftpProgress? onProgress,
  });

  Future<void> rename(String fromPath, String toPath);

  /// Removes [entry]. Uses the directory or file removal request depending on
  /// [RemoteEntry.isDirectory] — SFTP refuses the wrong one outright.
  Future<void> delete(RemoteEntry entry);

  Future<void> mkdir(String path);

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
  }) async {
    RandomAccessFile? local;
    SftpFile? remote;
    try {
      final sftp = await _client();
      remote = await sftp.open(remotePath);
      final total = (await remote.stat()).size;
      local = await File(localPath).open(mode: FileMode.write);
      await remote.downloadToRandomAccess(
        local,
        length: total,
        onProgress: (n) => onProgress?.call(n, total),
      );
    } on Object catch (e) {
      throw _wrap(e, 'Could not download ${_basename(remotePath)}');
    } finally {
      await remote?.close();
      await local?.close();
    }
  }

  @override
  Future<void> upload({
    required String localPath,
    required String remotePath,
    SftpProgress? onProgress,
  }) async {
    SftpFile? remote;
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
      final stream = localFile.openRead().map(
        (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
      );
      await remote
          .write(stream, onProgress: (n) => onProgress?.call(n, total))
          .done;
    } on Object catch (e) {
      throw _wrap(e, 'Could not upload ${_basename(localPath)}');
    } finally {
      await remote?.close();
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
          return SftpException('$action: no such file.', cause: error);
        case SftpStatusCode.permissionDenied:
          return SftpException('$action: permission denied.', cause: error);
        default:
          return SftpException('$action.', cause: error);
      }
    }
    return SftpException('$action.', cause: error);
  }
}
