import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picons/picons.dart';

import '../../l10n/app_localizations.dart';
import '../palette/domain/palette_item.dart';
import 'widgets/generate_key_sheet.dart';
import 'widgets/paste_key_sheet.dart';

/// Making a key and bringing one in: the two actions on the Keys screen.
final keyPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>(
      (ref, l10n) => [
        PaletteItem(
          id: 'action:generateKey',
          title: l10n.keysGenerate,
          category: PaletteCategory.action,
          icon: PiconsRegular.key,
          keywords: [l10n.menuGenerateKey],
          actions: [
            PaletteAction(
              id: 'open',
              label: l10n.keysGenerate,
              icon: PiconsRegular.key,
              run: (context, ref) => showGenerateKeySheet(context),
            ),
          ],
        ),
        PaletteItem(
          id: 'action:pasteKey',
          title: l10n.keysPaste,
          category: PaletteCategory.action,
          icon: PiconsRegular.clipboardText,
          actions: [
            PaletteAction(
              id: 'open',
              label: l10n.keysPaste,
              icon: PiconsRegular.clipboardText,
              run: (context, ref) => showPasteKeySheet(context),
            ),
          ],
        ),
      ],
    );
