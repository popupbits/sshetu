import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../l10n/app_localizations.dart';
import '../../export/presentation/json_import_dialog.dart';

/// Settings → Hosts → Import from JSON.
class ImportJsonTile extends ConsumerWidget {
  const ImportJsonTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(PiconsRegular.fileArrowDown),
      title: Text(l10n.importJsonTitle),
      subtitle: Text(l10n.importJsonSubtitle),
      onTap: () => importJson(context, ref),
    );
  }
}
