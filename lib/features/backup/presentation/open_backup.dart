import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../sessions/open_in_workspace.dart';
import 'export_screen.dart';
import 'import_screen.dart';

/// A tab on a desktop, a page on a phone — the same rule as everything else.
void openBackupExport(BuildContext context, WidgetRef ref) => openInWorkspace(
  context,
  ref,
  id: 'backup/export',
  title: AppLocalizations.of(context).backupTitle,
  icon: PiconsRegular.archive,
  route: Routes.backupExport,
  builder: (_) => const BackupExportScreen(embedded: true),
);

void openBackupImport(BuildContext context, WidgetRef ref) => openInWorkspace(
  context,
  ref,
  id: 'backup/import',
  title: AppLocalizations.of(context).backupRestoreTitle,
  icon: PiconsRegular.clockCounterClockwise,
  route: Routes.backupImport,
  builder: (_) => const BackupImportScreen(embedded: true),
);
