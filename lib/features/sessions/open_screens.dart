import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/routes.dart';
import '../files/file_browser_screen.dart';
import '../hosts/host_editor_screen.dart';
import '../import/import_screen.dart';
import '../settings/about_screen.dart';
import '../settings/diagnostics_screen.dart';
import '../settings/known_hosts_screen.dart';
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
      title: (l10n) =>
          hostId == null ? l10n.hostEditorNew : l10n.hostEditorEdit,
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
  title: (l10n) =>
      tunnelId == null ? l10n.tunnelEditorNew : l10n.tunnelEditorEdit,
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
  title: (l10n) =>
      focus == ImportFocus.keys ? l10n.keysImport : l10n.importTitle,
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
      title: (l10n) => l10n.filesTitle,
      icon: PiconsRegular.folderOpen,
      route: Routes.filesFor(sessionId),
      builder: (_) => FileBrowserScreen(sessionId: sessionId, embedded: true),
    );

/// The read-only pages under Settings. Tabs too, for the same reason: reading
/// a fingerprint or a diagnostic beside a terminal beats replacing it.
void openKnownHosts(BuildContext context, WidgetRef ref) => openInWorkspace(
  context,
  ref,
  id: 'known-hosts',
  title: (l10n) => l10n.knownHostsTitle,
  icon: PiconsRegular.shieldCheck,
  route: Routes.knownHosts,
  builder: (_) => const KnownHostsScreen(embedded: true),
);

void openDiagnostics(BuildContext context, WidgetRef ref) => openInWorkspace(
  context,
  ref,
  id: 'diagnostics',
  title: (l10n) => l10n.settingsDiagnostics,
  icon: PiconsRegular.bug,
  route: Routes.diagnostics,
  builder: (_) => const DiagnosticsScreen(embedded: true),
);

void openAbout(BuildContext context, WidgetRef ref) => openInWorkspace(
  context,
  ref,
  id: 'about',
  title: (l10n) => l10n.aboutTitle,
  icon: PiconsRegular.info,
  route: Routes.about,
  builder: (_) => const AboutScreen(embedded: true),
);
