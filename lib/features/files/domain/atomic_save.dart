import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/ssh/sftp_service.dart';

/// How [saveRemoteFile] ended up writing the file.
enum SaveMethod {
  /// A temporary file beside the original, renamed over it in one step: a
  /// reader sees the old file or the new one, never half of each, and a
  /// dropped connection mid-save leaves the original untouched.
  atomic,

  /// Straight into the original. Used when the atomic route is not
  /// available or would change something the user did not ask to change —
  /// see [saveRemoteFile].
  direct,
}

/// Writes [bytes] to the remote [path], replacing it as safely as the
/// server allows.
///
/// **The atomic route**: write `.<name>.sshetu-<random>.tmp` beside the
/// original, give it the original's permissions (and owner, when that is
/// different and can be set), then `posix-rename@openssh.com` it over the
/// original.
///
/// **The direct route** — open the original truncated and write into it —
/// is taken instead when:
///
///  * the server has no posix-rename, since plain SFTP `rename` refuses to
///    replace an existing file;
///  * [path] is a symbolic link, which a rename would replace with a regular
///    file instead of writing through;
///  * the temporary file could not be written (a directory the user cannot
///    create files in, even though the file itself is writable);
///  * the original belongs to another owner or group and the temporary file
///    cannot be given the same — a rename would silently hand the file to
///    the user who saved it.
///
/// Whatever the atomic route leaves behind is removed before falling back.
/// A failure of the direct route itself is thrown to the caller.
///
/// [original] is the stat taken when the file was loaded (or just before
/// saving); its permissions and owner are what the replacement copies.
Future<SaveMethod> saveRemoteFile(
  SftpService sftp,
  String path,
  Uint8List bytes, {
  required RemoteFileStat original,
  String Function()? tempSuffix,
}) async {
  final atomic = await _tryAtomic(
    sftp,
    path,
    bytes,
    original: original,
    tempSuffix: tempSuffix ?? _randomSuffix,
  );
  if (atomic) return SaveMethod.atomic;
  await sftp.writeFile(path, bytes);
  return SaveMethod.direct;
}

/// The temporary name used for [path] — hidden, beside it, and recognisably
/// this app's if one is ever left behind.
String tempPathFor(String path, String suffix) {
  final dir = p.posix.dirname(path);
  final name = p.posix.basename(path);
  return p.posix.join(dir, '.$name.sshetu-$suffix.tmp');
}

Future<bool> _tryAtomic(
  SftpService sftp,
  String path,
  Uint8List bytes, {
  required RemoteFileStat original,
  required String Function() tempSuffix,
}) async {
  if (!await sftp.supportsAtomicRename()) return false;

  try {
    final link = await sftp.stat(path, followLink: false);
    if (link.isSymlink) return false;
  } on SftpException catch (e) {
    // Gone since it was opened: renaming into the empty name is still the
    // atomic way to recreate it. Any other refusal is a reason to write
    // directly and let that report the real problem.
    if (e.kind != SftpFailureKind.notFound) return false;
  }

  final temp = tempPathFor(path, tempSuffix());
  var created = false;
  try {
    await sftp.writeFile(temp, bytes, exclusive: true);
    created = true;

    final mode = original.permissions;
    if (mode != null) await sftp.setPermissions(temp, mode);

    final uid = original.userId;
    final gid = original.groupId;
    if (uid != null && gid != null) {
      final written = await sftp.stat(temp);
      if (written.userId != uid || written.groupId != gid) {
        // Throws when refused, which is the usual answer for anyone but
        // root — and exactly the case the direct route exists for.
        await sftp.setOwner(temp, userId: uid, groupId: gid);
      }
    }

    await sftp.atomicRename(temp, path);
    return true;
  } on SftpException {
    if (created) {
      try {
        await sftp.removeFile(temp);
      } on Object {
        // Best effort: a stray hidden temp file is litter, not damage, and
        // the save is about to be retried the direct way regardless.
      }
    }
    return false;
  }
}

String _randomSuffix() {
  final random = Random.secure();
  return List.generate(8, (_) => random.nextInt(36).toRadixString(36)).join();
}
