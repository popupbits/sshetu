import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../hosts/hosts_controller.dart';
import '../keys/keys_controller.dart';
import '../snippets/snippets_controller.dart';
import '../tunnels/tunnels_controller.dart';
import 'data/portable_export_store.dart';
import 'domain/json_import_plan.dart';
import 'domain/portable_export.dart';

/// Where a finished export went.
enum ExportDestination { saved, shared, cancelled }

typedef ExportResult = ({ExportDestination destination, String? path});

/// Files in and out for the plain JSON export, split from the widgets so a
/// test can swap the native panels for memory.
class PortableExportService {
  const PortableExportService();

  /// Dated like a backup, and plainly not one: `.json`, not `.sshetu-backup`.
  static String fileNameFor(DateTime when) {
    final date = when.toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return 'sshetu-export-${date.year}-$month-$day.json';
  }

  /// A save dialog on a desktop; the share sheet on a phone, which is the
  /// only way there to reach Files, Drive or another app.
  Future<ExportResult> save(String text, {DateTime? when}) async {
    final name = fileNameFor(when ?? DateTime.now());
    final bytes = Uint8List.fromList(utf8.encode(text));

    if (Platform.isAndroid || Platform.isIOS) {
      final file = File(p.join((await getTemporaryDirectory()).path, name));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], fileNameOverrides: [name]),
      );
      return (destination: ExportDestination.shared, path: null);
    }

    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [jsonTypeGroup],
    );
    if (location == null) {
      return (destination: ExportDestination.cancelled, path: null);
    }
    await File(location.path).writeAsBytes(bytes, flush: true);
    return (destination: ExportDestination.saved, path: location.path);
  }

  /// Asks for a file and returns its bytes, or null if none was picked.
  Future<({Uint8List bytes, String name})?> pick(XTypeGroup group) async {
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), name: file.name);
  }

  static const XTypeGroup jsonTypeGroup = XTypeGroup(
    label: 'JSON',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    uniformTypeIdentifiers: ['public.json'],
  );

  static Future<String> appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } on Object {
      return 'unknown';
    }
  }
}

final portableExportServiceProvider = Provider<PortableExportService>(
  (ref) => const PortableExportService(),
);

/// The device's configuration as a store for reading and writing exports.
final portableExportStoreProvider = FutureProvider<PortableExportStore>(
  (ref) async => PortableExportStore(
    database: ref.watch(databaseProvider).raw,
    hosts: ref.watch(hostRepositoryProvider),
    groups: ref.watch(hostGroupRepositoryProvider),
    identities: ref.watch(identityRepositoryProvider),
    tunnels: ref.watch(tunnelRepositoryProvider),
    snippets: ref.watch(snippetRepositoryProvider),
    knownHosts: await ref.watch(knownHostsProvider.future),
  ),
);

/// Export, preview and apply — the three things the screens ask for.
class PortableExportController {
  const PortableExportController(this._ref);

  final Ref _ref;

  /// This device's configuration as the export file's text.
  Future<String> exportText({String? appVersion, DateTime? now}) async {
    final store = await _ref.read(portableExportStoreProvider.future);
    final export = await store.read(
      now: now ?? DateTime.now().toUtc(),
      appVersion: appVersion ?? await PortableExportService.appVersion(),
    );
    return export.encode();
  }

  /// Reads [text] and plans importing it. Throws [PortableExportException].
  Future<JsonImportPlan> plan(String text) async {
    final source = PortableExport.decode(text);
    final store = await _ref.read(portableExportStoreProvider.future);
    final local = await store.read(now: DateTime.now().toUtc(), appVersion: '');
    return JsonImportPlan.build(source: source, local: local);
  }

  /// Writes [plan] under [rule], then refreshes every list it touched.
  Future<JsonImportChanges> apply(
    JsonImportPlan plan,
    ConflictRule rule,
  ) async {
    final changes = plan.resolve(rule);
    await PortableExportStore.apply(_ref.read(databaseProvider).raw, changes);
    _ref
      ..invalidate(hostsProvider)
      ..invalidate(hostGroupsProvider)
      ..invalidate(identitiesProvider)
      ..invalidate(tunnelsProvider)
      ..invalidate(snippetsProvider)
      ..invalidate(knownHostsProvider)
      ..invalidate(portableExportStoreProvider);
    return changes;
  }
}

final portableExportControllerProvider = Provider<PortableExportController>(
  PortableExportController.new,
);
