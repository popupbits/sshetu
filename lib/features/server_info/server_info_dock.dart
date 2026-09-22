import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/terminal/terminal_session.dart';
import '../../core/util/responsive.dart';
import '../sessions/session_manager.dart';
import '../sessions/workspace_pages.dart';
import '../shell/workspace_layout.dart';
import 'data/server_exec.dart';
import '../tunnels/widgets/server_ports_view.dart';
import 'server_info_panel.dart';

/// Whether the desktop's server-info panel is open.
///
/// One switch, not one per tab: the panel follows the selected session, the
/// way the file browser follows the machine you are looking at.
class ServerInfoDockController extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;
  void close() => state = false;
  void toggle() => state = !state;
}

final serverInfoDockProvider = NotifierProvider<ServerInfoDockController, bool>(
  ServerInfoDockController.new,
);

/// The terminal workspace with the server-info panel beside it.
///
/// Beside, when there is room for the panel *and* a usable terminal
/// ([WorkspaceLayout.minTerminal]); otherwise over the terminal's right edge,
/// raised, so a narrow window still gets the panel without the terminal
/// shrinking into uselessness.
class ServerInfoDock extends ConsumerWidget {
  const ServerInfoDock({required this.child, super.key});

  final Widget child;

  /// Wide enough for a filesystem path and its "12 GB of 50 GB" line.
  static const double width = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(serverInfoDockProvider);
    ref.watch(sessionManagerProvider);
    final session = ref.read(sessionManagerProvider.notifier).active;
    if (!open || session == null) return child;

    final panel = ServerInfoPanel(
      // A new panel per session: one host's CPU history must not run on into
      // another's.
      key: ValueKey('serverInfo/${session.id}'),
      title: session.title,
      exec: ConnectionExec(session.connection),
      onClose: () => ref.read(serverInfoDockProvider.notifier).close(),
      portsBuilder: (_) => serverPortsFor(session),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final room = constraints.maxWidth;
        if (room - width - 1 >= WorkspaceLayout.minTerminal) {
          return Row(
            children: [
              Expanded(child: child),
              VerticalDivider(width: 1, color: scheme.outlineVariant),
              SizedBox(width: width, child: panel),
            ],
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: child),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              width: room < width ? room : width,
              child: Material(elevation: 8, child: panel),
            ),
          ],
        );
      },
    );
  }
}

/// Opens server info for [session] where it belongs on this form factor: the
/// side panel on a desktop (toggled, and following [session]), a sheet on a
/// phone.
Future<void> openServerInfo(
  BuildContext context,
  WidgetRef ref,
  TerminalSession session,
) async {
  if (context.useRail) {
    final manager = ref.read(sessionManagerProvider.notifier);
    final dock = ref.read(serverInfoDockProvider.notifier);
    final showingThis =
        ref.read(serverInfoDockProvider) && manager.activeId == session.id;
    if (showingThis) {
      dock.close();
      return;
    }
    ref.read(workspacePagesProvider.notifier).deselect();
    manager.select(session.id);
    dock.open();
    return;
  }
  await showServerInfoSheet(context, session);
}

/// Whether the desktop panel is showing [session] right now — for a menu
/// label that says Hide instead of Show.
bool isServerInfoShowing(WidgetRef ref, TerminalSession session) =>
    ref.read(serverInfoDockProvider) &&
    ref.read(sessionManagerProvider.notifier).activeId == session.id;

/// The phone's presentation: a tall sheet over the terminal.
///
/// [initialTab] opens it on another tab — [ServerInfoPanel.portsTab] for
/// "Ports on this server" from the terminal's More menu.
Future<void> showServerInfoSheet(
  BuildContext context,
  TerminalSession session, {
  int initialTab = 0,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => FractionallySizedBox(
    heightFactor: 0.9,
    child: ServerInfoPanel(
      title: session.title,
      exec: ConnectionExec(session.connection),
      onClose: () => Navigator.of(sheetContext).pop(),
      portsBuilder: (_) => serverPortsFor(session),
      initialTab: initialTab,
    ),
  ),
);

/// "Ports on this server" for [session]'s tab, over its own connection.
Widget serverPortsFor(TerminalSession session) => ServerPortsView(
  key: ValueKey('ports/${session.id}'),
  exec: ConnectionExec(session.connection),
  sessionId: session.id,
  hostId: session.hostId,
  connection: session.connection,
  // The sshd this tab came in through, when it is not on 22 — already the
  // one port nobody needs forwarded.
  alsoIgnore: {session.target.port},
);
