import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../../files/domain/format.dart';
import '../domain/server_sample.dart';
import '../domain/stats_format.dart';
import '../domain/stats_parser.dart';
import '../server_stats_monitor.dart';
import 'sparkline.dart';
import 'usage_meter.dart';

/// The Overview tab: who the server is, and how hard it is working.
///
/// Built from whatever the monitor last knew. A drop or a failed poll keeps
/// the figures on screen under a banner that says they are stale, rather than
/// blanking a panel someone was reading.
class ServerOverview extends StatelessWidget {
  const ServerOverview({required this.monitor, super.key});

  final ServerStatsMonitor monitor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final stats = monitor.stats;
        final status = monitor.status;

        if (stats == null) {
          return switch (status) {
            MonitorStatus.offline => EmptyView(
              icon: PiconsRegular.plugs,
              title: l10n.serverInfoOffline,
              message: l10n.serverInfoOfflineBody,
            ),
            MonitorStatus.error => ErrorView(
              message: l10n.serverInfoError('${monitor.error}'),
              onRetry: monitor.poll,
              retryLabel: l10n.actionRetry,
            ),
            _ => const LoadingView(),
          };
        }

        final sample = stats.sample;
        return ListView(
          key: const Key('serverInfo.overview'),
          padding: const EdgeInsets.only(bottom: Spacing.xl),
          children: [
            if (status == MonitorStatus.offline)
              _Banner(
                icon: PiconsRegular.plugs,
                text: l10n.serverInfoOfflineBody,
              ),
            if (status == MonitorStatus.error)
              _Banner(
                icon: PiconsRegular.warningCircle,
                text: l10n.serverInfoError('${monitor.error}'),
                isError: true,
              ),
            _Identity(sample: sample),
            if (sample.isLimited)
              _Banner(
                icon: PiconsRegular.info,
                text:
                    '${l10n.serverInfoLimited}. ${l10n.serverInfoLimitedBody}',
              ),
            if (sample.cpu != null) ...[
              SectionLabel(l10n.serverInfoCpu),
              _Cpu(stats: stats, history: monitor.cpuHistory),
            ],
            if (sample.memory != null) ...[
              SectionLabel(l10n.serverInfoMemory),
              _Padded(child: _Memory(memory: sample.memory!)),
            ],
            if (_visibleFilesystems(sample).isNotEmpty) ...[
              SectionLabel(l10n.serverInfoFilesystems),
              for (final fs in _visibleFilesystems(sample))
                _Padded(
                  child: UsageMeter(
                    label: fs.mountPoint,
                    fraction: fs.usedFraction,
                    detail: l10n.serverInfoUsedOfTotal(
                      humanFileSize(fs.usedBytes),
                      humanFileSize(fs.totalBytes),
                    ),
                  ),
                ),
            ],
            if (sample.net != null) ...[
              SectionLabel(l10n.serverInfoNetwork),
              _Padded(child: _Network(stats: stats)),
            ],
          ],
        );
      },
    );
  }

  static List<FilesystemUsage> _visibleFilesystems(ServerSample sample) => [
    for (final fs in sample.filesystems ?? const <FilesystemUsage>[])
      if (!isPseudoFilesystem(fs)) fs,
  ];
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
    child: child,
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.isError = false});

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Container(
      margin: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hostname, OS, kernel, uptime and load, as label–value rows.
class _Identity extends StatelessWidget {
  const _Identity({required this.sample});

  final ServerSample sample;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = sample.identity;
    final load = sample.load;
    final kernel = [
      identity.kernelName,
      identity.kernelRelease,
    ].whereType<String>().join(' ');

    final rows = <(String, String)>[
      if (identity.hostname != null)
        (l10n.serverInfoHostname, identity.hostname!),
      if (identity.osName != null) (l10n.serverInfoSystem, identity.osName!),
      if (kernel.isNotEmpty) (l10n.serverInfoKernel, kernel),
      if (sample.uptime != null)
        (l10n.serverInfoUptime, formatUptime(sample.uptime)),
      if (load != null)
        (l10n.serverInfoLoad, formatLoad(load.one, load.five, load.fifteen)),
      if (sample.processCount != null)
        (
          l10n.serverInfoProcesses,
          l10n.serverInfoProcessCount(sample.processCount!),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
      child: Column(
        children: [for (final (label, value) in rows) _Row(label, value)],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cpu extends StatelessWidget {
  const _Cpu({required this.stats, required this.history});

  final ServerStats stats;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cores = stats.sample.identity.cpuCount;
    final percent = stats.cpuPercent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                percent == null
                    ? l10n.serverInfoWaiting
                    : formatPercent(percent),
                key: const Key('serverInfo.cpuPercent'),
                style: percent == null
                    ? theme.textTheme.bodySmall
                    : theme.textTheme.titleLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
              ),
              const Spacer(),
              if (cores != null)
                Text(
                  l10n.serverInfoCpuCores(cores),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Sparkline(
            values: history,
            semanticLabel: l10n.serverInfoCpuHistory(history.length),
          ),
        ],
      ),
    );
  }
}

class _Memory extends StatelessWidget {
  const _Memory({required this.memory});

  final MemoryInfo memory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final swapTotal = memory.swapTotalBytes;
    final swapUsed = memory.swapUsedBytes;
    return Column(
      children: [
        UsageMeter(
          label: l10n.serverInfoMemory,
          fraction: memory.usedFraction,
          detail: l10n.serverInfoUsedOfTotal(
            humanFileSize(memory.usedBytes),
            humanFileSize(memory.totalBytes),
          ),
        ),
        if (swapTotal != null && swapTotal > 0 && swapUsed != null)
          UsageMeter(
            label: l10n.serverInfoSwap,
            fraction: swapUsed / swapTotal,
            detail: l10n.serverInfoUsedOfTotal(
              humanFileSize(swapUsed),
              humanFileSize(swapTotal),
            ),
          )
        else if (swapTotal != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                l10n.serverInfoNoSwap,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Network extends StatelessWidget {
  const _Network({required this.stats});

  final ServerStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _Rate(
            icon: PiconsRegular.arrowDown,
            label: l10n.serverInfoNetDown,
            value: formatRate(stats.rxBytesPerSecond),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _Rate(
            icon: PiconsRegular.arrowUp,
            label: l10n.serverInfoNetUp,
            value: formatRate(stats.txBytesPerSecond),
          ),
        ),
      ],
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: label,
      value: value,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: Spacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
