import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../l10n/app_localizations.dart';
import '../import/putty/putty_import.dart';
import '../import/putty/putty_import_dialog.dart';
import '../palette/domain/palette_item.dart';
import 'presentation/export_json_dialog.dart';
import 'presentation/json_import_dialog.dart';

/// Getting configuration out of SSHetu and in from elsewhere: the JSON
/// export, its import, and PuTTY.
final exportPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>((ref, l10n) {
      PaletteItem item(
        String id,
        String title,
        IconData icon,
        PaletteRun run, {
        List<String> keywords = const [],
      }) => PaletteItem(
        id: id,
        title: title,
        category: PaletteCategory.action,
        icon: icon,
        keywords: keywords,
        actions: [
          PaletteAction(id: 'open', label: title, icon: icon, run: run),
        ],
      );

      return [
        item(
          'action:exportJson',
          l10n.exportJsonTitle,
          PiconsRegular.fileText,
          exportJson,
          keywords: const ['json'],
        ),
        item(
          'action:importJson',
          l10n.importJsonTitle,
          PiconsRegular.fileArrowDown,
          importJson,
          keywords: const ['json'],
        ),
        item(
          'action:importPutty',
          PuttyRegistryReader.isSupported
              ? l10n.puttyImportTitle
              : l10n.puttyImportFile,
          PiconsRegular.terminalWindow,
          importPutty,
          keywords: const ['putty', '.reg'],
        ),
        // On Windows the row above reads the registry; a file from another
        // machine still needs its own way in.
        if (PuttyRegistryReader.isSupported)
          item(
            'action:importPuttyFile',
            l10n.puttyImportFile,
            PiconsRegular.terminalWindow,
            (context, ref) => importPutty(context, ref, fromFile: true),
            keywords: const ['putty', '.reg'],
          ),
      ];
    });
