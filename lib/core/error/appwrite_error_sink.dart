import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../appwrite/client.dart';
import '../config/app_config.dart';
import 'error_logger.dart';
import 'error_record.dart';

/// Sends captured errors to an Appwrite table.
///
/// Create the table before switching this on. Columns, all optional except
/// where noted, in the database `AppConfig.appwriteDatabaseId`:
///
/// | column        | type     |
/// |---------------|----------|
/// | `fingerprint` | string   |
/// | `type`        | string   |
/// | `message`     | string (long) |
/// | `stack`       | string (long) |
/// | `source`      | string   |
/// | `count`       | integer  |
/// | `platform`    | string   |
/// | `occurredAt`  | datetime |
///
/// Give the table create-only permission for the role you expect to report —
/// `Role.users()` for a signed-in app, `Role.any()` if crashes must be
/// reportable before sign-in. Do **not** grant read to that same role: an
/// error log is readable by whoever can read the table, and stack traces leak
/// more about a user's session than they look like they do.
class AppwriteErrorSink implements ErrorSink {
  AppwriteErrorSink(this._appwrite);

  static const String tableId = 'error_logs';

  /// Off in debug. Otherwise every hot reload with a mistake in it writes a
  /// row, and the table fills with errors nobody shipped.
  static const bool enabledInDebug = false;

  final AppwriteService _appwrite;

  /// One upload per fingerprint per session. A crash loop should cost one
  /// row, not one row per iteration.
  final Set<String> _sent = <String>{};

  @override
  Future<void> send(ErrorRecord record) async {
    if (kDebugMode && !enabledInDebug) return;
    if (!_sent.add(record.fingerprint)) return;

    try {
      await _appwrite.tablesDB.createRow(
        databaseId: AppConfig.appwriteDatabaseId,
        tableId: tableId,
        rowId: ID.unique(),
        data: {
          'fingerprint': record.fingerprint,
          'type': record.type,
          'message': record.message,
          'stack': record.stack,
          'source': record.source,
          'count': record.count,
          'platform': defaultTargetPlatform.name,
          'occurredAt': record.lastSeen.toUtc().toIso8601String(),
        },
      );
    } catch (_) {
      // Offline, unauthorised, or the table does not exist yet. The record is
      // already on the device either way, and a reporting failure must never
      // surface to the user. Allow a retry next session.
      _sent.remove(record.fingerprint);
    }
  }
}

/// Wire this up in `main` with
/// `ErrorLogger.instance.attachSink(AppwriteErrorSink(service))`, or leave it
/// alone to keep every error on the device.
final appwriteErrorSinkProvider = Provider<AppwriteErrorSink>(
  (ref) => AppwriteErrorSink(ref.watch(appwriteProvider)),
);
