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

/// Raised by [LocalFsService]. Like [SftpException], the message is written
/// to be shown to a user directly.
class LocalFsException implements Exception {
  LocalFsException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'LocalFsException: $message';
}

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
      throw LocalFsException('Could not read $path.', cause: e);
    }
  }

  Future<void> delete(LocalEntry entry) async {
    try {
      if (entry.isDirectory) {
        await Directory(entry.path).delete();
      } else {
        await File(entry.path).delete();
      }
    } on Object catch (e) {
      throw LocalFsException('Could not delete ${entry.name}.', cause: e);
    }
  }
}
