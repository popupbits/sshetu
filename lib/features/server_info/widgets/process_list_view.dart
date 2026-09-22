import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/server_exec.dart';
import '../data/server_info_service.dart';
import '../domain/process_list.dart';
import '../domain/stats_format.dart';

/// The Processes tab: the top hundred by CPU, filterable, with Kill.
///
/// Refreshed on open, on demand and after a signal — not on a timer. A list
/// that reshuffles every three seconds is a list where the row under your
/// finger turns into a different process just as you tap Kill.
class ProcessListView extends StatefulWidget {
  const ProcessListView({required this.exec, super.key});

  final ServerExec exec;

  @override
  State<ProcessListView> createState() => _ProcessListViewState();
}

class _ProcessListViewState extends State<ProcessListView> {
  late final ServerInfoService _service = ServerInfoService(widget.exec);
  final _filter = TextEditingController();

  ProcessListing? _listing;
  Object? _error;
  bool _loading = false;
  ProcessSort _sort = ProcessSort.cpu;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final listing = await _service.processes();
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _error = null;
        // A busybox ps has no CPU column; sorting by it would be a lie.
        if (!listing.hasCpu && _sort == ProcessSort.cpu) {
          _sort = listing.hasMem ? ProcessSort.mem : ProcessSort.pid;
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signal(ProcessInfo process, KillSignal signal) async {
    final l10n = AppLocalizations.of(context);
    final name = process.command;
    final force = signal == KillSignal.kill;
    final confirmed = await context.confirm(
      title: force
          ? l10n.processesForceKillTitle(name)
          : l10n.processesKillTitle(name),
      message: force
          ? l10n.processesForceKillBody(name, process.pid)
          : l10n.processesKillBody(name, process.pid),
      confirmLabel: force
          ? l10n.processesForceKillConfirm
          : l10n.processesKillConfirm,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _service.kill(process.pid, signal);
      if (!mounted) return;
      context.toast(
        l10n.processesSignalSent(
          force ? 'SIGKILL' : 'SIGTERM',
          name,
          process.pid,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      context.toast(
        l10n.processesSignalFailed(name, process.pid, '$e'),
        isError: true,
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final listing = _listing;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('processes.filter'),
                  controller: _filter,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.processesFilter,
                    prefixIcon: const Icon(
                      PiconsRegular.magnifyingGlass,
                      size: 16,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                key: const Key('processes.refresh'),
                tooltip: l10n.processesRefresh,
                onPressed: _loading ? null : _load,
                icon: const Icon(PiconsRegular.arrowsClockwise, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<ProcessSort>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                  value: ProcessSort.cpu,
                  label: Text(l10n.processesSortCpu),
                  enabled: listing?.hasCpu ?? true,
                ),
                ButtonSegment(
                  value: ProcessSort.mem,
                  label: Text(l10n.processesSortMem),
                  enabled: listing?.hasMem ?? true,
                ),
                ButtonSegment(
                  value: ProcessSort.pid,
                  label: Text(l10n.processesSortPid),
                ),
              ],
              selected: {_sort},
              onSelectionChanged: (value) =>
                  setState(() => _sort = value.first),
            ),
          ),
        ),
        if (listing != null && !listing.hasCpu && !listing.hasMem)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              0,
            ),
            child: Text(
              l10n.processesNoUsage,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_loading && listing != null)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(child: _body(context, listing)),
      ],
    );
  }

  Widget _body(BuildContext context, ProcessListing? listing) {
    final l10n = AppLocalizations.of(context);
    if (listing == null) {
      if (_error != null) {
        return ErrorView(
          message: _errorText(l10n, _error!),
          onRetry: _load,
          retryLabel: l10n.actionRetry,
        );
      }
      return const LoadingView();
    }
    final rows = sortAndFilterProcesses(
      listing.processes,
      sort: _sort,
      query: _filter.text,
    );
    if (rows.isEmpty) {
      return EmptyView(
        icon: PiconsRegular.listBullets,
        title: l10n.processesEmpty,
      );
    }
    return ListView.builder(
      key: const Key('processes.list'),
      itemCount: rows.length,
      itemBuilder: (context, index) => _ProcessRow(
        process: rows[index],
        onSignal: (signal) => _signal(rows[index], signal),
      ),
    );
  }

  static String _errorText(AppLocalizations l10n, Object error) =>
      error is ServerOfflineException
      ? l10n.serverInfoOfflineBody
      : l10n.processesLoadFailed('$error');
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.process, required this.onSignal});

  final ProcessInfo process;
  final void Function(KillSignal signal) onSignal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final meta = ['${process.pid}', ?process.user, ?process.time].join(' · ');
    final usage = [
      if (process.cpuPercent != null)
        '${l10n.processesSortCpu} ${formatPercent(process.cpuPercent)}',
      if (process.memPercent != null)
        '${l10n.processesSortMem} ${formatPercent(process.memPercent)}',
    ];

    return ListTile(
      key: ValueKey('process.${process.pid}'),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(
        left: Spacing.lg,
        right: Spacing.xs,
      ),
      title: Text(
        process.command,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(meta, maxLines: 1, style: muted),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (usage.isNotEmpty)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final line in usage) Text(line, style: muted)],
            ),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                key: const Key('process.term'),
                leadingIcon: const Icon(PiconsRegular.stopCircle),
                onPressed: () => onSignal(KillSignal.term),
                child: Text(l10n.processesKill),
              ),
              MenuItemButton(
                key: const Key('process.kill'),
                leadingIcon: Icon(PiconsRegular.skull, color: scheme.error),
                onPressed: () => onSignal(KillSignal.kill),
                child: Text(l10n.processesForceKill),
              ),
            ],
            builder: (context, controller, _) => IconButton(
              tooltip: l10n.processesActions(process.command),
              icon: const Icon(PiconsRegular.dotsThreeVertical, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ],
      ),
    );
  }
}
