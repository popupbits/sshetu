import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/secrets/secret_vault.dart';
import 'crypto/passphrase_key.dart';
import '../transfer/domain/transfer_payload.dart';
import 'domain/backup_file.dart';

/// Where a finished backup went, so the screen can say so precisely.
enum BackupDestination {
  /// Written to a path the user chose.
  saved,

  /// Handed to the share sheet, which is how a phone saves a file.
  shared,

  /// The user backed out of the save dialog.
  cancelled,
}

typedef BackupResult = ({BackupDestination destination, String? path});

/// Writing and reading backup files.
///
/// Split from the screens so the interesting half — what goes in the file and
/// what comes out — is testable without a file picker in the way.
class BackupService {
  const BackupService({this.derive});

  /// How the passphrase becomes a key. Null means the real one, on its own
  /// isolate; a widget test passes [PassphraseKey.deriveHere] instead.
  final KeyDerivation? derive;

  /// The name a backup is offered under.
  ///
  /// Dated, because the first thing anyone wants to know about a backup they
  /// find is how old it is, and the second is whether it is newer than the
  /// other one next to it. Sorting by name sorts by date.
  static String fileNameFor(DateTime when) {
    final date = when.toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return 'sshetu-backup-${date.year}-$month-$day.${BackupFile.extension}';
  }

  /// Builds the encrypted bytes for everything on this device.
  Future<Uint8List> encode({
    required Database database,
    required SecretVault vault,
    required String passphrase,
    required bool includeSecrets,
  }) async {
    final payload = await TransferPayload.read(
      database,
      vault: vault,
      includeSecrets: includeSecrets,
    );
    return BackupFile.write(
      payload: payload,
      passphrase: passphrase,
      appVersion: await _appVersion(),
      derive: derive,
    );
  }

  /// Puts [bytes] somewhere the user can find them.
  ///
  /// Two paths because the platforms genuinely differ: a desktop has a file
  /// system and a save dialog, and a phone has a share sheet that is the only
  /// way to reach iCloud, Drive or Files. Writing to app storage on a phone
  /// would be a backup that dies with the app it is backing up.
  Future<BackupResult> save(Uint8List bytes, {DateTime? when}) async {
    final name = fileNameFor(when ?? DateTime.now());

    if (Platform.isAndroid || Platform.isIOS) {
      final file = File(p.join((await getTemporaryDirectory()).path, name));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], fileNameOverrides: [name]),
      );
      return (destination: BackupDestination.shared, path: null);
    }

    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [_typeGroup],
    );
    if (location == null) {
      return (destination: BackupDestination.cancelled, path: null);
    }

    await File(location.path).writeAsBytes(bytes, flush: true);
    return (destination: BackupDestination.saved, path: location.path);
  }

  /// Opens [bytes] with [passphrase], using this service's derivation.
  Future<({TransferPayload payload, BackupContents contents})> decode({
    required Uint8List bytes,
    required String passphrase,
  }) => BackupFile.read(
    bytes: bytes,
    passphrase: passphrase,
    derive: derive,
  );

  /// Asks for a backup file and returns its bytes, or null if none was picked.
  Future<({Uint8List bytes, String name})?> pick() async {
    final file = await openFile(acceptedTypeGroups: [_typeGroup]);
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), name: file.name);
  }

  /// Named without a UTI or MIME type on purpose: macOS and iOS reject a save
  /// panel whose type group declares an extension they do not recognise, and
  /// this one is ours alone.
  static const XTypeGroup _typeGroup = XTypeGroup(
    label: 'SSHetu backup',
    extensions: [BackupFile.extension],
  );

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } on Object {
      // Provenance is nice to have; failing to read it is not a reason to
      // refuse someone a backup.
      return 'unknown';
    }
  }
}
