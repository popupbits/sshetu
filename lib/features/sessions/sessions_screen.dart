import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'session_manager.dart';
import 'widgets/host_sidebar.dart';
import 'widgets/session_tab_strip.dart';
import 'widgets/terminal_pane.dart';

/// The Sessions destination.
///
/// Two shapes, because the two form factors want genuinely different things:
///
///  * **Desktop** — a workspace. Hosts down the left, open sessions as tabs
///    across the top, the live terminal filling the rest. Starting a second
///    connection never costs you sight of the first, which is the entire
///    reason anyone keeps an SSH client open all day.
///  * **Phone** — a list. There is not room for a sidebar, a tab strip and a
///    terminal at once, and a terminal squeezed into what is left of a phone
///    screen is not a terminal. Tapping a row opens it full-screen instead.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return context.useRail ? const _Workspace() : const _SessionList();
  }
}

class _Workspace extends ConsumerWidget {
  const _Workspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);
    final active = ref.read(sessionManagerProvider.notifier).active;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        const HostSidebar(),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(
          child: sessions.isEmpty
              ? EmptyView(
                  icon: PiconsRegular.terminalWindow,
                  title: l10n.sessionsEmptyTitle,
                  message: l10n.sessionsEmptyPickHost,
                )
              : Column(
                  children: [
                    const SessionTabStrip(),
                    Expanded(
                      child: active == null
                          ? const SizedBox.shrink()
                          // Keyed by session, so switching tabs builds a new
                          // pane rather than re-pointing the old one at a
                          // different terminal — which would carry one
                          // session's scroll position and selection onto
                          // another's buffer.
                          : TerminalPane(
                              key: ValueKey(active.id),
                              session: active,
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);

    if (sessions.isEmpty) {
      return EmptyView(
        icon: PiconsRegular.terminalWindow,
        title: l10n.sessionsEmptyTitle,
        message: l10n.sessionsEmptyBody,
        action: FilledButton.icon(
          onPressed: () => context.goTo(Routes.hosts),
          icon: const Icon(PiconsRegular.hardDrives),
          label: Text(l10n.sessionsGoToHosts),
        ),
      );
    }

    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return ListenableBuilder(
          listenable: session,
          builder: (context, _) => ListTile(
            leading: _StatusDot(status: session.status),
            title: Text(session.title),
            subtitle: Text(
              session.error ?? session.target.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: l10n.terminalCloseTab,
              icon: const Icon(PiconsRegular.x),
              onPressed: () =>
                  ref.read(sessionManagerProvider.notifier).close(session.id),
            ),
            onTap: () {
              ref.read(sessionManagerProvider.notifier).select(session.id);
              context.pushTo(Routes.terminalFor(session.id));
            },
          ),
        );
      },
    );
  }
}

/// A session's state at a glance, so the list is scannable without reading.
///
/// Filled for live, hollow for not — a shape rather than a colour, so it does
/// not depend on being able to tell green from grey.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final TerminalSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (status == TerminalSessionStatus.connecting) {
      return const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final live = status == TerminalSessionStatus.running;
    final failed = status == TerminalSessionStatus.failed;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: live ? scheme.primary : Colors.transparent,
        border: live
            ? null
            : Border.all(
                color: failed ? scheme.error : scheme.outline,
                width: 2,
              ),
      ),
    );
  }
}
