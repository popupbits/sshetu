import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../palette/domain/palette_item.dart';
import 'session_manager.dart';
import 'terminal_find_request.dart';
import 'workspace_pages.dart';

/// The open terminal tabs, and find — which only means something while one
/// is open.
final sessionPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>((ref, l10n) {
      final sessions = ref.watch(sessionManagerProvider);
      return [
        for (final session in sessions)
          PaletteItem(
            id: 'session:${session.id}',
            title: session.title,
            subtitle: '${session.target.username}@${session.target.hostname}',
            category: PaletteCategory.session,
            icon: PiconsRegular.terminalWindow,
            actions: [
              PaletteAction(
                id: 'switch',
                label: l10n.paletteSwitchTo,
                icon: PiconsRegular.arrowSquareOut,
                run: (context, ref) =>
                    switchToSession(context, ref, session.id),
              ),
            ],
          ),
        if (sessions.isNotEmpty)
          PaletteItem(
            id: 'action:findInTerminal',
            title: l10n.terminalFind,
            category: PaletteCategory.action,
            icon: PiconsRegular.magnifyingGlass,
            keywords: [l10n.menuFind],
            actions: [
              PaletteAction(
                id: 'open',
                label: l10n.terminalFind,
                icon: PiconsRegular.magnifyingGlass,
                run: (context, ref) => openTerminalFind(ref),
              ),
            ],
          ),
      ];
    });

/// Brings session [id] to the front: the selected tab, with any page that was
/// covering it set aside, and — on a phone, where the terminal is a page of
/// its own — on screen.
void switchToSession(BuildContext context, WidgetRef ref, String id) {
  ref.read(workspacePagesProvider.notifier).deselect();
  ref.read(sessionManagerProvider.notifier).select(id);
  if (!context.useRail) context.pushTo(Routes.terminalFor(id));
}
