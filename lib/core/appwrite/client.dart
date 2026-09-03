import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Thin wrapper around the Appwrite SDK clients.
///
/// Sessions are the SDK's business: `createEmailPasswordSession` stores the
/// cookie (the IO client persists it to disk, so it survives cold starts) and
/// attaches it to every request. Nothing here persists a secret by hand — auth
/// *state* is derived from `account.get()` by AuthController.
class AppwriteService {
  AppwriteService() : client = Client() {
    client
        .setEndpoint(AppConfig.appwriteEndpoint)
        .setProject(AppConfig.appwriteProjectId);
    account = Account(client);
    tablesDB = TablesDB(client);
    storage = Storage(client);
    teams = Teams(client);
    realtime = Realtime(client);
  }

  final Client client;
  late final Account account;

  /// Appwrite 1.8+ data API. Collection ids are passed as `tableId` and
  /// document ids as `rowId`.
  late final TablesDB tablesDB;
  late final Storage storage;
  late final Teams teams;
  late final Realtime realtime;

  /// Flatten a [models.Row] into the loose map our models parse, so a model's
  /// `fromMap` sees `$id` alongside its own columns.
  static Map<String, dynamic> rowMap(models.Row row) => {
    ...row.data,
    r'$id': row.$id,
    r'$createdAt': row.$createdAt,
    r'$updatedAt': row.$updatedAt,
  };

  /// Raw bytes for a file, which works on every platform regardless of how
  /// auth is transported.
  Future<Uint8List> fileBytes(String bucketId, String fileId) =>
      storage.getFileView(bucketId: bucketId, fileId: fileId);
}

final appwriteProvider = Provider<AppwriteService>((ref) => AppwriteService());
