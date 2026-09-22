import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../l10n/app_localizations.dart';
import '../import/import_screen.dart';
import '../palette/domain/palette_item.dart';
import '../sessions/connect.dart';
import '../sessions/open_screens.dart';
import '../sessions/server_sessions.dart';
import '../sessions/session_manager.dart';
import 'domain/ssh_host.dart';
import 'hosts_controller.dart';

/// Every saved server, and the two things you do to the list itself.
///
/// Connect is the row's own action, as it is in the host list; edit, files
/// and the server's running sessions are the same entry points the row's
/// context menu uses.
final hostPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>((ref, l10n) {
      final hosts = ref.watch(hostsProvider).value ?? const <SshHost>[];
      return [
        for (final host in hosts)
          PaletteItem(
            id: 'host:${host.id}',
            title: host.label,
            subtitle: host.address,
            category: PaletteCategory.host,
            icon: PiconsRegular.hardDrives,
            keywords: [host.hostname, ...host.tags],
            actions: [
              PaletteAction(
                id: 'connect',
                label: l10n.hostsConnect,
                icon: PiconsRegular.terminalWindow,
                run: (context, ref) => connectToHost(context, ref, host),
              ),
              PaletteAction(
                id: 'edit',
                label: l10n.hostsEdit,
                icon: PiconsRegular.pencilSimple,
                run: (context, ref) =>
                    openHostEditor(context, ref, hostId: host.id),
              ),
              PaletteAction(
                id: 'files',
                label: l10n.paletteOpenFiles,
                icon: PiconsRegular.folderOpen,
                run: (context, ref) => openFilesForHost(context, ref, host),
              ),
              PaletteAction(
                id: 'running',
                label: l10n.hostsRunningSessions,
                icon: PiconsRegular.stack,
                run: (context, ref) => openRunningSessions(context, ref, host),
              ),
            ],
          ),
        PaletteItem(
          id: 'action:newHost',
          title: l10n.hostsAdd,
          category: PaletteCategory.action,
          icon: PiconsRegular.plus,
          keywords: [l10n.menuNewHost],
          actions: [
            PaletteAction(
              id: 'open',
              label: l10n.hostsAdd,
              icon: PiconsRegular.plus,
              run: (context, ref) => openHostEditor(context, ref),
            ),
          ],
        ),
        PaletteItem(
          id: 'action:importOpenSsh',
          title: l10n.hostsImport,
          category: PaletteCategory.action,
          icon: PiconsRegular.downloadSimple,
          keywords: [l10n.menuImport],
          actions: [
            PaletteAction(
              id: 'open',
              label: l10n.hostsImport,
              icon: PiconsRegular.downloadSimple,
              run: (context, ref) =>
                  openImport(context, ref, focus: ImportFocus.all),
            ),
          ],
        ),
      ];
    });

/// The file browser for [host]: over a tab already open to it when there is
/// one, otherwise after opening one.
///
/// The browser works over a session's connection, so there is no browsing a
/// server without being connected to it. Reusing an open tab means asking for
/// files never dials a second connection for no reason.
Future<void> openFilesForHost(
  BuildContext context,
  WidgetRef ref,
  SshHost host,
) async {
  final manager = ref.read(sessionManagerProvider.notifier);
  final existing = ref
      .read(sessionManagerProvider)
      .where((s) => s.hostId == host.id && s.isLive)
      .firstOrNull;
  final session =
      existing ?? await connectToHost(context, ref, host, navigate: false);
  if (session == null || !context.mounted) return;
  manager.select(session.id);
  openFiles(context, ref, session.id);
}
