import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/hosts/host_editor_screen.dart';
import '../../features/files/file_browser_screen.dart';
import '../../features/hosts/hosts_screen.dart';
import '../../features/import/import_screen.dart';
import '../../features/sessions/terminal_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/keys/keys_screen.dart';
import '../../features/tunnels/tunnel_editor_screen.dart';
import '../../features/tunnels/tunnels_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/diagnostics_screen.dart';
import '../../features/settings/known_hosts_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../ui/views.dart';
import 'routes.dart';

/// Root navigator key. Routes that should cover the shell (full-screen forms,
/// detail pages) set `parentNavigatorKey: rootNavigatorKey`.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.initial,
    // No auth gate, and no account at all. An SSH client has to work on a
    // plane, on a locked-down network, and for someone who would never make
    // an account — the servers and keys are on the device, and nothing about
    // connecting to them needs a backend. Moving them to another device is a
    // direct, one-shot transfer between the two; see `features/transfer`.
    redirect: (context, state) {
      if (state.matchedLocation == Routes.splash) return Routes.initial;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(
        path: Routes.hostNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const HostEditorScreen(),
      ),
      GoRoute(
        path: '${Routes.hostEdit}/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            HostEditorScreen(hostId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '${Routes.terminal}/:sessionId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            TerminalScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '${Routes.files}/:sessionId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            FileBrowserScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: Routes.tunnelNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            TunnelEditorScreen(hostId: state.uri.queryParameters['host']),
      ),
      GoRoute(
        path: '${Routes.tunnelEdit}/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            TunnelEditorScreen(tunnelId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.importOpenSsh,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ImportScreen(
          focus: ImportFocus.parse(state.uri.queryParameters['focus']),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.hosts,
                builder: (_, _) => const HostsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.sessions,
                builder: (_, _) => const SessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.keys, builder: (_, _) => const KeysScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tunnels,
                builder: (_, _) => const TunnelsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    // Over the shell, not inside it: About is a leaf page, and
                    // keeping the nav bar under it invites tapping away
                    // mid-read.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'known-hosts',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const KnownHostsScreen(),
                  ),
                  GoRoute(
                    path: 'diagnostics',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const DiagnosticsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
