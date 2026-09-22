import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../l10n/app_localizations.dart';
import '../../export/presentation/export_json_dialog.dart';

/// Settings → Hosts → Export as JSON (no secrets).
class ExportJsonTile extends ConsumerWidget {
  const ExportJsonTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(PiconsRegular.fileText),
      title: Text(l10n.exportJsonTitle),
      subtitle: Text(l10n.exportJsonSubtitle),
      isThreeLine: true,
      onTap: () => exportJson(context, ref),
    );
  }
}
