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

/// The open sessions, as a list.
///
/// A phone has no room for a tab strip that stays useful past three tabs, so
/// the tabs get a destination of their own instead. Tapping one reopens its
/// terminal with its scrollback intact — the session never stopped running.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);

    if (sessions.isEmpty) {
      return EmptyView(
        icon: PiconsRegular.terminalWindow,
        title: l10n.sessionsEmptyTitle,
        message: l10n.sessionsEmptyBody,
      );
    }

    return ContentWidth(
      child: ListView.builder(
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
                icon: const Icon(PiconsRegular.x),
                onPressed: () =>
                    ref.read(sessionManagerProvider.notifier).close(session.id),
              ),
              onTap: () => context.pushTo(Routes.terminalFor(session.id)),
            ),
          );
        },
      ),
    );
  }
}

/// A session's state at a glance, so the list is scannable without reading.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final TerminalSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      TerminalSessionStatus.running => Colors.green,
      TerminalSessionStatus.connecting => scheme.primary,
      TerminalSessionStatus.failed => scheme.error,
      TerminalSessionStatus.closed => scheme.outline,
    };

    if (status == TerminalSessionStatus.connecting) {
      return const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
