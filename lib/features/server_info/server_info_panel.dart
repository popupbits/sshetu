import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'data/server_exec.dart';
import 'server_stats_monitor.dart';
import 'widgets/process_list_view.dart';
import 'widgets/server_overview.dart';

/// Server info for one host: Overview and Processes.
///
/// The same widget on both form factors — beside the terminal on a desktop,
/// in a sheet on a phone — so the two cannot drift apart.
///
/// Polling is tied to being seen. It starts when this is built, stops when it
/// is disposed (the panel closed, the sheet dismissed), pauses while the app
/// is in the background, and pauses on the Processes tab, where nothing reads
/// the figures.
class ServerInfoPanel extends StatefulWidget {
  const ServerInfoPanel({
    required this.title,
    required this.exec,
    this.onClose,
    this.monitorFactory,
    this.portsBuilder,
    this.initialTab = 0,
    super.key,
  });

  /// Builds a third tab, Ports, when given — "Ports on this server". Built
  /// only while that tab is on screen, so it polls only then.
  final WidgetBuilder? portsBuilder;

  /// The tab to open on: 0 Overview, 1 Processes, 2 Ports.
  final int initialTab;

  /// The index of the Ports tab, when there is one.
  static const int portsTab = 2;

  /// The host's label, shown in the header.
  final String title;
  final ServerExec exec;

  /// Shown as a close button when given.
  final VoidCallback? onClose;

  /// For tests: a monitor with a different interval or clock.
  final ServerStatsMonitor Function(ServerExec exec)? monitorFactory;

  @override
  State<ServerInfoPanel> createState() => _ServerInfoPanelState();
}

class _ServerInfoPanelState extends State<ServerInfoPanel>
    with SingleTickerProviderStateMixin {
  late final ServerStatsMonitor _monitor =
      widget.monitorFactory?.call(widget.exec) ??
      ServerStatsMonitor(widget.exec);
  late final int _tabCount = widget.portsBuilder == null ? 2 : 3;
  late final TabController _tabs = TabController(
    length: _tabCount,
    initialIndex: widget.initialTab.clamp(0, _tabCount - 1),
    vsync: this,
  );
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_sync);
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _foreground = false;
        _sync();
      },
      onShow: () {
        _foreground = true;
        _sync();
      },
    );
    _sync();
  }

  /// Polls exactly while the Overview is on screen.
  void _sync() {
    if (_foreground && _tabs.index == 0) {
      _monitor.start();
    } else {
      _monitor.stop();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _tabs.dispose();
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          Container(
            height: Chrome.tabStrip,
            padding: const EdgeInsets.only(left: Spacing.lg, right: Spacing.xs),
            color: scheme.surfaceContainerLow,
            child: Row(
              children: [
                Icon(PiconsRegular.gauge, size: 14, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    '${l10n.serverInfoTitle} · ${widget.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    key: const Key('serverInfo.close'),
                    tooltip: l10n.serverInfoClose,
                    onPressed: widget.onClose,
                    icon: const Icon(PiconsRegular.x, size: 14),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: l10n.serverInfoOverview, height: Chrome.tabStrip),
              Tab(text: l10n.serverInfoProcesses, height: Chrome.tabStrip),
              if (widget.portsBuilder != null)
                Tab(
                  key: const Key('serverInfo.portsTab'),
                  text: l10n.portsTab,
                  height: Chrome.tabStrip,
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ServerOverview(monitor: _monitor),
                ProcessListView(exec: widget.exec),
                if (widget.portsBuilder case final ports?)
                  Builder(builder: ports),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
