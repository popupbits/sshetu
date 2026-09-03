import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/ssh/sftp_service.dart';
import '../../../core/util/sort_entries.dart';

/// One entry in a local directory listing. Mirrors [RemoteEntry]'s shape so
/// the two panes can share a row widget, without pretending they are the same
/// type — a local file has no SFTP permission bits, and a remote one has no
/// `dart:io` [FileSystemEntity] behind it.
class LocalEntry {
  const LocalEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;

  @override
  String toString() => 'LocalEntry($path)';
}

/// What kind of failure a [LocalFsException] wraps — mirrors
/// [SftpFailureKind] so the local and remote panes can render the same three
/// states (permission denied / not found / other) from the same switch
/// shape, even though the two exceptions come from entirely different stacks.
enum LocalFsFailureKind { notFound, permissionDenied, other }

/// Raised by [LocalFsService]. Like [SftpException], the message is written
/// to be shown to a user directly.
class LocalFsException implements Exception {
  LocalFsException(
    this.message, {
    this.cause,
    this.kind = LocalFsFailureKind.other,
  });

  final String message;
  final Object? cause;
  final LocalFsFailureKind kind;

  @override
  String toString() => 'LocalFsException: $message';
}

/// What is at a local path — mirrors [RemotePathKind]. See
/// [LocalFsService.statPath].
enum LocalPathKind { missing, file, directory }

/// The local half of the file browser, over `dart:io`.
///
/// Not behind an interface the way [SftpService] is: there is no server to
/// fake here, `dart:io` already works against a real temporary directory in a
/// `flutter test` run, and testing against the real filesystem is what
/// `test/import/import_controller_test.dart` already does for the same
/// reason.
class LocalFsService {
  const LocalFsService();

  /// Lists [path], sorted the same way [SftpService.list] sorts the remote
  /// pane — see [sortFileEntries].
  Future<List<LocalEntry>> list(String path) async {
    try {
      final entries = <LocalEntry>[];
      await for (final entity in Directory(path).list(followLinks: false)) {
        final stat = await entity.stat();
        final isDirectory = stat.type == FileSystemEntityType.directory;
        entries.add(
          LocalEntry(
            name: p.basename(entity.path),
            path: entity.path,
            isDirectory: isDirectory,
            size: isDirectory ? null : stat.size,
            modified: stat.modified,
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

  Future<void> delete(LocalEntry entry) async {
    try {
      if (entry.isDirectory) {
        // Deliberately not `recursive: true`: a folder that turns out to
        // hold other people's files is exactly the case where "delete
        // everything inside, silently" is the wrong default. `dart:io`
        // raises here with `ENOTEMPTY` when that happens, and `_wrap` turns
        // that into a message that says so rather than a bare "failed".
        await Directory(entry.path).delete();
      } else {
        await File(entry.path).delete();
      }
    } on Object catch (e) {
      throw _wrap(e, 'Could not delete ${entry.name}');
    }
  }

  /// Expands the one shorthand `dart:io` knows nothing about. Pure string
  /// substitution, no I/O: `~` and `~/rest` become [homeDir] and
  /// `$homeDir/rest`; anything else passes through unchanged, since
  /// `BrowsePath.looksNavigable` has already rejected a relative path before
  /// this is ever called.
  String resolveLocalPath(String input, {String? homeDir}) {
    final trimmed = input.trim();
    final home =
        homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (trimmed == '~') return home;
    if (trimmed.startsWith('~/')) return p.join(home, trimmed.substring(2));
    return trimmed;
  }

  /// What is at [path] right now — see [LocalPathKind]. A dedicated check
  /// rather than trying `list()` and inspecting the failure, for the same
  /// reason `SftpService.statPath` exists: `FileSystemEntityType.notFound`
  /// tells the caller "missing" directly, instead of asking it to infer that
  /// from an exception meant for display.
  Future<LocalPathKind> statPath(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: true);
    return switch (type) {
      FileSystemEntityType.notFound => LocalPathKind.missing,
      FileSystemEntityType.directory => LocalPathKind.directory,
      _ => LocalPathKind.file,
    };
  }

  /// Turns a raw [FileSystemException] into one safe to show a user, the
  /// same contract [SftpService]'s `_wrap` keeps for the remote side.
  ///
  /// `errno` is platform-specific — POSIX's `EACCES`/`ENOENT` are not
  /// Windows' `ERROR_ACCESS_DENIED`/`ERROR_FILE_NOT_FOUND` — so which
  /// numbers mean "permission denied" and "not found" depends on
  /// [Platform.isWindows]. There is no portable errno to switch on instead;
  /// this is the price of `dart:io` passing the OS's own error code through
  /// unchanged.
  static LocalFsException _wrap(Object error, String action) {
    if (error is LocalFsException) return error;
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      final kind = _kindOfErrorCode(code);
      final detail = switch (kind) {
        LocalFsFailureKind.notFound => 'no such file or directory',
        LocalFsFailureKind.permissionDenied => 'permission denied',
        LocalFsFailureKind.other => error.osError?.message ?? 'failed',
      };
      return LocalFsException('$action: $detail.', cause: error, kind: kind);
    }
    return LocalFsException('$action.', cause: error);
  }

  static LocalFsFailureKind _kindOfErrorCode(int? code) {
    if (code == null) return LocalFsFailureKind.other;
    if (Platform.isWindows) {
      // ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND, ERROR_ACCESS_DENIED.
      if (code == 2 || code == 3) return LocalFsFailureKind.notFound;
      if (code == 5) return LocalFsFailureKind.permissionDenied;
      return LocalFsFailureKind.other;
    }
    // POSIX (Linux, macOS, and Android/iOS underneath): ENOENT, EACCES.
    if (code == 2) return LocalFsFailureKind.notFound;
    if (code == 13) return LocalFsFailureKind.permissionDenied;
    return LocalFsFailureKind.other;
  }
}
