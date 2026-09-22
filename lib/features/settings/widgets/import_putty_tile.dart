import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../l10n/app_localizations.dart';
import '../../import/putty/putty_import.dart';
import '../../import/putty/putty_import_dialog.dart';

/// Settings → Hosts → Import from PuTTY.
///
/// Reads the registry on Windows, where PuTTY keeps its sessions; elsewhere
/// it asks for a `.reg` file exported from a Windows machine.
class ImportPuttyTile extends ConsumerWidget {
  const ImportPuttyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final registry = PuttyRegistryReader.isSupported;
    return ListTile(
      leading: const Icon(PiconsRegular.terminalWindow),
      title: Text(registry ? l10n.puttyImportTitle : l10n.puttyImportFile),
      subtitle: Text(
        registry
            ? l10n.puttyImportSubtitleWindows
            : l10n.puttyImportSubtitleFile,
      ),
      onTap: () => importPutty(context, ref),
    );
  }
}
