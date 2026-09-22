import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;

import '../../l10n/app_localizations.dart';
import '../hosts/hosts_palette.dart';
import '../keys/keys_palette.dart';
import '../sessions/sessions_palette.dart';
import '../settings/settings_palette.dart';
import '../snippets/snippets_palette.dart';
import '../tunnels/tunnels_palette.dart';
import 'domain/palette_item.dart';

/// A feature's contribution to the palette: its items, in its user's words.
typedef PaletteSource = ProviderFamily<List<PaletteItem>, AppLocalizations>;

/// Every source the palette searches, in the order their items appear when
/// nothing has been typed.  ← REGISTRY
///
/// A feature adds itself here — a provider in its own folder, one line in
/// this list — and the palette picks it up without being edited. The order
/// is the empty-query order: what you open most (servers, then open tabs)
/// before what you run, before what you configure.
final paletteSourcesProvider = Provider<List<PaletteSource>>(
  (ref) => [
    hostPaletteItemsProvider,
    sessionPaletteItemsProvider,
    snippetPaletteItemsProvider,
    tunnelPaletteItemsProvider,
    keyPaletteItemsProvider,
    settingsPaletteItemsProvider,
  ],
);

/// Every item from every source, for [AppLocalizations].
final paletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>(
      (ref, l10n) => [
        for (final source in ref.watch(paletteSourcesProvider))
          ...ref.watch(source(l10n)),
      ],
    );
