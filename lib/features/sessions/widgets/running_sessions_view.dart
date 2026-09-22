import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/tmux_commands.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';

/// The sessions SSHetu keeps on one server, from every device.
///
/// Pops with the name of the session to attach, or nothing. Loading and
/// ending go through [load] and [end], so the widget is testable without a
/// server — and so it never holds a connection of its own.
class RunningSessionsView extends StatefulWidget {
  const RunningSessionsView({
    required this.hostLabel,
    required this.deviceId,
    required this.load,
    required this.end,
    required this.isOpenHere,
    this.clock,
    super.key,
  });

  final String hostLabel;

  /// This install's id, to tell its sessions from other devices'.
  final String deviceId;

  final Future<TmuxListing> Function() load;
  final Future<void> Function(String name) end;

  /// Whether a tab here is already showing session [name].
  final bool Function(String name) isOpenHere;

  /// For tests: what "now" is when ages are shown.
  final DateTime Function()? clock;

  @override
  State<RunningSessionsView> createState() => _RunningSessionsViewState();
}

class _RunningSessionsViewState extends State<RunningSessionsView> {
  late Future<TmuxListing> _listing;

  @override
  void initState() {
    super.initState();
    _listing = widget.load();
  }

  // `ignore` marks a failure as handled until the FutureBuilder, which only
  // subscribes on the next frame, picks it up — otherwise a quick failure
  // lands in between and is reported as uncaught.
  void _refresh() => setState(() {
    _listing = widget.load()..ignore();
  });

  Future<void> _end(TmuxSessionInfo session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await context.confirm(
      title: l10n.runningSessionsEndTitle,
      message: l10n.runningSessionsEndBody(widget.hostLabel),
      confirmLabel: l10n.runningSessionsEnd,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.end(session.name);
    } on Object catch (error) {
      if (mounted) {
        context.toast(l10n.runningSessionsEndFailed('$error'), isError: true);
      }
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.lg,
            Spacing.sm,
            Spacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.runningSessionsTitle(widget.hostLabel),
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: const Key('runningSessions.refresh'),
                tooltip: l10n.runningSessionsRefresh,
                icon: const Icon(PiconsRegular.arrowClockwise),
                onPressed: _refresh,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Text(
            l10n.runningSessionsIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Expanded(
          child: FutureBuilder<TmuxListing>(
            future: _listing,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return EmptyView(
                  icon: PiconsRegular.warning,
                  title: l10n.runningSessionsError,
                  message: '${snapshot.error}',
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: Text(l10n.runningSessionsRefresh),
                  ),
                );
              }
              final listing = snapshot.data!;
              if (!listing.tmuxAvailable) {
                return EmptyView(
                  icon: PiconsRegular.stack,
                  title: l10n.runningSessionsNoTmux,
                );
              }
              if (listing.sessions.isEmpty) {
                return EmptyView(
                  icon: PiconsRegular.stack,
                  title: l10n.runningSessionsEmpty,
                  message: l10n.runningSessionsEmptyBody,
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: Spacing.lg),
                children: [
                  for (final session in listing.sessions)
                    _SessionRow(
                      session: session,
                      deviceId: widget.deviceId,
                      openHere: widget.isOpenHere(session.name),
                      now: (widget.clock ?? DateTime.now)().toUtc(),
                      onAttach: () => Navigator.of(context).pop(session.name),
                      onEnd: () => _end(session),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.xl,
                      Spacing.md,
                      Spacing.xl,
                      0,
                    ),
                    child: Text(
                      l10n.runningSessionsSharedNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.deviceId,
    required this.openHere,
    required this.now,
    required this.onAttach,
    required this.onEnd,
  });

  final TmuxSessionInfo session;
  final String deviceId;
  final bool openHere;
  final DateTime now;
  final VoidCallback onAttach;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final origin = parseTmuxSessionName(session.name);
    final (icon, who) = switch (origin) {
      TmuxFromDevice(deviceId: final id) when id == deviceId => (
        PiconsRegular.deviceMobile,
        l10n.runningSessionsThisDevice,
      ),
      TmuxFromDevice(deviceId: final id) => (
        PiconsRegular.devices,
        l10n.runningSessionsOtherDevice(id),
      ),
      _ => (PiconsRegular.clockCounterClockwise, l10n.runningSessionsOlder),
    };

    final details = [
      l10n.runningSessionsStarted(_age(session.created)),
      if (session.lastActivity case final activity?)
        l10n.runningSessionsActive(_age(activity)),
      if (session.command case final command?)
        l10n.runningSessionsRunning(command),
    ].join(' · ');

    final badge = openHere
        ? l10n.runningSessionsOpenHere
        : session.isAttached
        ? l10n.runningSessionsAttached
        : null;

    return ListTile(
      key: ValueKey('runningSession.${session.name}'),
      leading: Icon(icon),
      title: Text(who, maxLines: 1, overflow: TextOverflow.ellipsis),
      // The badge under the name, not beside it: beside it, a phone-width row
      // has no room for both once the buttons have theirs.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: Spacing.xxs),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          Text(details, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: ValueKey('runningSession.attach.${session.name}'),
            onPressed: onAttach,
            child: Text(
              openHere ? l10n.runningSessionsShow : l10n.runningSessionsAttach,
            ),
          ),
          IconButton(
            key: ValueKey('runningSession.end.${session.name}'),
            tooltip: l10n.runningSessionsEnd,
            icon: Icon(PiconsRegular.power, color: scheme.error),
            onPressed: onEnd,
          ),
        ],
      ),
    );
  }

  /// `5m`, `2h`, `3d` — short, because a row carries two of them.
  String _age(DateTime at) {
    final elapsed = now.difference(at);
    if (elapsed.inMinutes < 1) return '<1m';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h';
    return '${elapsed.inDays}d';
  }
}

/// Shows [view] the way the width wants it: a tall sheet on a phone, a
/// dialog where there is room. Completes with the session to attach.
Future<String?> showRunningSessionsView(
  BuildContext context,
  RunningSessionsView view,
) => context.isCompact
    ? showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: view),
      )
    : showDialog<String>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
            child: view,
          ),
        ),
      );
