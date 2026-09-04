import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/routes.dart';
import '../../l10n/app_localizations.dart';
import '../files/file_browser_screen.dart';
import '../hosts/host_editor_screen.dart';
import '../import/import_screen.dart';
import '../tunnels/tunnel_editor_screen.dart';
import 'open_in_workspace.dart';

/// Where each screen opens, in one place.
///
/// Every one of these was a full-screen route, which on a desktop meant that
/// adding a tunnel or editing a host took the shell you were working in off
/// the screen. They are all things you do beside a terminal, so on a window
/// wide enough for both they open as tabs; on a phone they stay routes.
///
/// Gathered here rather than left at the call sites so the rule is stated
/// once. A screen that opened the wrong way would otherwise be a detail
/// somebody forgot in one of the nine places that push a route.

void openHostEditor(BuildContext context, WidgetRef ref, {String? hostId}) =>
    openInWorkspace(
      context,
      ref,
      // Keyed by host, so editing two servers gives two tabs, and editing the
      // same one twice returns to the tab already open.
      id: 'host/${hostId ?? 'new'}',
      title: hostId == null
          ? AppLocalizations.of(context).hostEditorNew
          : AppLocalizations.of(context).hostEditorEdit,
      icon: PiconsRegular.hardDrives,
      route: hostId == null ? Routes.hostNew : Routes.hostEditFor(hostId),
      builder: (_) => HostEditorScreen(hostId: hostId, embedded: true),
    );

void openTunnelEditor(
  BuildContext context,
  WidgetRef ref, {
  String? tunnelId,
  String? hostId,
}) => openInWorkspace(
  context,
  ref,
  id: 'tunnel/${tunnelId ?? 'new'}',
  title: tunnelId == null
      ? AppLocalizations.of(context).tunnelEditorNew
      : AppLocalizations.of(context).tunnelEditorEdit,
  icon: PiconsRegular.arrowsLeftRight,
  route: tunnelId == null
      ? (hostId == null ? Routes.tunnelNew : Routes.tunnelNewFor(hostId))
      : Routes.tunnelEditFor(tunnelId),
  builder: (_) =>
      TunnelEditorScreen(tunnelId: tunnelId, hostId: hostId, embedded: true),
);

void openImport(
  BuildContext context,
  WidgetRef ref, {
  ImportFocus focus = ImportFocus.all,
}) => openInWorkspace(
  context,
  ref,
  id: 'import/${focus.name}',
  title: focus == ImportFocus.keys
      ? AppLocalizations.of(context).keysImport
      : AppLocalizations.of(context).importTitle,
  icon: PiconsRegular.downloadSimple,
  route: focus == ImportFocus.all
      ? Routes.importOpenSsh
      : Routes.importFocused(focus.name),
  builder: (_) => ImportScreen(focus: focus, embedded: true),
);

/// The SFTP browser, which belongs beside its own terminal more than anything
/// else here: the whole point is looking at the machine you are logged into.
void openFiles(BuildContext context, WidgetRef ref, String sessionId) =>
    openInWorkspace(
      context,
      ref,
      id: 'files/$sessionId',
      title: AppLocalizations.of(context).filesTitle,
      icon: PiconsRegular.folderOpen,
      route: Routes.filesFor(sessionId),
      builder: (_) => FileBrowserScreen(sessionId: sessionId, embedded: true),
    );
