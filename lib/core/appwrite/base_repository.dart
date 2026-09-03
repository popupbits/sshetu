import 'package:appwrite/appwrite.dart';

import '../config/app_config.dart';
import 'client.dart';
import 'failures.dart';

/// CRUD over one Appwrite table, typed to a model.
///
/// Build one per feature rather than calling `tablesDB` directly from a
/// screen: the mapping between rows and models, and the error translation,
/// then live in exactly one place per collection.
///
/// ```dart
/// final vehicleRepositoryProvider = Provider(
///   (ref) => CollectionRepository<Vehicle>(
///     appwrite: ref.watch(appwriteProvider),
///     tableId: 'vehicles',
///     fromMap: Vehicle.fromMap,
///     toMap: (v) => v.toMap(),
///   ),
/// );
/// ```
class CollectionRepository<T> {
  const CollectionRepository({
    required this.appwrite,
    required this.tableId,
    required this.fromMap,
    required this.toMap,
    this.databaseId = AppConfig.appwriteDatabaseId,
  });

  final AppwriteService appwrite;
  final String tableId;
  final String databaseId;
  final T Function(Map<String, dynamic> map) fromMap;
  final Map<String, dynamic> Function(T item) toMap;

  /// Build queries with `Query.equal`, `Query.orderDesc`, `Query.limit`, … from
  /// `package:appwrite/appwrite.dart`.
  Future<List<T>> list({List<String>? queries}) async {
    return runAppwrite(() async {
      final result = await appwrite.tablesDB.listRows(
        databaseId: databaseId,
        tableId: tableId,
        queries: queries,
      );
      return result.rows.map(AppwriteService.rowMap).map(fromMap).toList();
    });
  }

  /// Total matching [queries], without fetching the rows.
  Future<int> count({List<String>? queries}) async {
    return runAppwrite(() async {
      final result = await appwrite.tablesDB.listRows(
        databaseId: databaseId,
        tableId: tableId,
        queries: [...?queries, Query.limit(1)],
        total: true,
      );
      return result.total;
    });
  }

  Future<T> get(String id) async {
    return runAppwrite(() async {
      final row = await appwrite.tablesDB.getRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: id,
      );
      return fromMap(AppwriteService.rowMap(row));
    });
  }

  /// Create a row. Omit [id] to let Appwrite assign one.
  Future<T> create(T item, {String? id, List<String>? permissions}) async {
    return runAppwrite(() async {
      final row = await appwrite.tablesDB.createRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: id ?? ID.unique(),
        data: toMap(item),
        permissions: permissions,
      );
      return fromMap(AppwriteService.rowMap(row));
    });
  }

  /// Patch a row. Pass only the columns that changed — a full [toMap] would
  /// overwrite concurrent edits to fields this caller never touched.
  Future<T> update(String id, Map<String, dynamic> changes) async {
    return runAppwrite(() async {
      final row = await appwrite.tablesDB.updateRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: id,
        data: changes,
      );
      return fromMap(AppwriteService.rowMap(row));
    });
  }

  Future<void> delete(String id) async {
    await runAppwrite(
      () => appwrite.tablesDB.deleteRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: id,
      ),
    );
  }
}
