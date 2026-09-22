import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/terminal_session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../session_log/widgets/session_log_dot.dart';
import '../pane_commands.dart';
import '../pane_layouts.dart';
import '../pane_tree.dart';
import '../session_manager.dart';
import 'terminal_pane.dart';

/// The content of the selected terminal tab: one pane, or a split layout.
///
/// **Tiled only where panes can be read.** Side-by-side panes need a rail-
/// width window (medium and up, [ResponsiveContext.useRail]) *and* a terminal
/// area that holds every pane at [kMinPaneSize]. A phone, or a desktop window
/// squeezed until the panes would be slivers, shows one pane at a time with a
/// switcher above it instead — never squeezed panes. The two checks answer
/// different questions: the width class says what kind of device this is,
/// the fit says whether this particular layout, in this particular terminal
/// area beside the panel, still works.
class TabPanes extends ConsumerWidget {
  const TabPanes({required this.active, super.key});

  /// The active session. Its tab is what is shown.
  final TerminalSession active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref
        .watch(paneLayoutsProvider)
        .where((t) => t.contains(active.id))
        .firstOrNull;
    if (tree == null) {
      // Keyed by session, so switching tabs builds a new pane rather than
      // re-pointing the old one at a different terminal — which would carry
      // one session's scroll position and selection onto another's buffer.
      return TerminalPane(key: ValueKey(active.id), session: active);
    }
    final tileable = context.useRail;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        return tileable && tree.fits(size)
            ? SplitPaneView(tree: tree, activeId: active.id, size: size)
            : PaneSwitcherView(tree: tree, active: active);
      },
    );
  }
}

/// A split tab, tiled.
///
/// Every pane is a child of one [Stack], positioned from
/// [PaneTreeLayout.layout] and keyed by its session. Splitting or closing a
/// neighbour then moves a pane rather than rebuilding it, so its scroll
/// position, selection and find bar survive the layout changing around it.
class SplitPaneView extends ConsumerStatefulWidget {
  const SplitPaneView({
    required this.tree,
    required this.activeId,
    required this.size,
    super.key,
  });

  final PaneTree tree;
  final String activeId;
  final Size size;

  @override
  ConsumerState<SplitPaneView> createState() => _SplitPaneViewState();
}

class _SplitPaneViewState extends ConsumerState<SplitPaneView> {
  /// Ratios mid-drag, by divider path. Kept here until the drag ends so the
  /// saved workspace is written once per drag rather than once per frame.
  final _dragging = <String, double>{};

  PaneTree get _tree {
    var tree = widget.tree;
    for (final MapEntry(:key, :value) in _dragging.entries) {
      tree = tree.resize(key, value);
    }
    return tree;
  }

  void _commit(String path, double ratio) {
    setState(() => _dragging.remove(path));
    ref.read(paneLayoutsProvider.notifier).resize(widget.activeId, path, ratio);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionManagerProvider);
    final manager = ref.read(sessionManagerProvider.notifier);
    final tree = _tree;
    final geometry = tree.layout(widget.size);
    final tiled = geometry.panes.length > 1;

    return Stack(
      children: [
        for (final MapEntry(key: id, value: rect) in geometry.panes.entries)
          if (sessions.where((s) => s.id == id).firstOrNull case final session?)
            Positioned.fromRect(
              key: ValueKey(id),
              rect: rect,
              child: _PaneFrame(
                session: session,
                tree: tree,
                active: id == widget.activeId,
                outlined: tiled,
                broadcastCount: manager.broadcastCount(id),
              ),
            ),
        for (final divider in geometry.dividers)
          Positioned.fromRect(
            key: ValueKey('divider:${divider.path}'),
            rect: divider.axis == SplitAxis.horizontal
                ? Rect.fromCenter(
                    center: divider.rect.center,
                    width: _handleExtent,
                    height: divider.rect.height,
                  )
                : Rect.fromCenter(
                    center: divider.rect.center,
                    width: divider.rect.width,
                    height: _handleExtent,
                  ),
            child: _DividerHandle(
              divider: divider,
              onDrag: (ratio) =>
                  setState(() => _dragging[divider.path] = ratio),
              onEnd: (ratio) => _commit(divider.path, ratio),
            ),
          ),
      ],
    );
  }
}

/// How wide a divider is to the pointer: far wider than the one-point line
/// drawn, so it can be grabbed without hunting for it.
const double _handleExtent = 9;

/// A split tab on a screen too small to tile it: the active pane, and a row
/// to switch to the others.
class PaneSwitcherView extends ConsumerWidget {
  const PaneSwitcherView({required this.tree, required this.active, super.key});

  final PaneTree tree;
  final TerminalSession active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sessions = ref.watch(sessionManagerProvider);
    final manager = ref.read(sessionManagerProvider.notifier);
    final panes = [
      for (final id in tree.panes)
        ?sessions.where((s) => s.id == id).firstOrNull,
    ];
    final receiving = tree.receivesBroadcast(active.id);

    return Column(
      children: [
        Semantics(
          label: l10n.paneSwitcherLabel,
          container: true,
          child: Container(
            key: const Key('panes.switcher'),
            height: Chrome.tabStrip,
            color: scheme.surfaceContainerLow,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              children: [
                for (final (index, session) in panes.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xxs,
                    ),
                    // Centred and shrink-wrapped: a chip's default padded
                    // tap target is taller than the strip, which clipped the
                    // bottom of every chip on a phone.
                    child: Center(
                      child: ChoiceChip(
                        key: ValueKey('panes.switch.${session.id}'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        selected: session.id == active.id,
                        avatar: tree.receivesBroadcast(session.id)
                            ? Icon(
                                PiconsRegular.broadcast,
                                size: 14,
                                color: scheme.error,
                              )
                            : null,
                        label: Text('${index + 1} · ${session.title}'),
                        onSelected: (_) => manager.select(session.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (receiving)
          _BroadcastBanner(
            tree: tree,
            session: active,
            count: manager.broadcastCount(active.id),
          ),
        Expanded(
          child: TerminalPane(key: ValueKey(active.id), session: active),
        ),
      ],
    );
  }
}

/// One tiled pane: a header naming it, and its terminal.
class _PaneFrame extends ConsumerWidget {
  const _PaneFrame({
    required this.session,
    required this.tree,
    required this.active,
    required this.outlined,
    required this.broadcastCount,
  });

  final TerminalSession session;
  final PaneTree tree;
  final bool active;

  /// False for a maximized pane, which has no neighbour to be told from.
  final bool outlined;

  final int broadcastCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final manager = ref.read(sessionManagerProvider.notifier);
    final receiving = tree.receivesBroadcast(session.id);

    // The outline is painted *over* the pane, never around it: a border that
    // took layout space would resize the terminal every time focus moved,
    // and every resize is a SIGWINCH and a redraw on the server.
    final outline = receiving
        ? scheme.error
        : active && outlined
        ? scheme.primary
        : null;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: outline == null
            ? null
            : Border.all(color: outline, width: BorderWidths.emphasis),
      ),
      child: Column(
        children: [
          _PaneHeader(
            session: session,
            tree: tree,
            active: active,
            broadcastCount: broadcastCount,
          ),
          Expanded(
            child: TerminalPane(
              session: session,
              autofocus: active,
              onFocused: () => manager.select(session.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pane's name, its broadcast state, and its own actions.
///
/// When the tab is typing into every pane, this row *is* the warning: the
/// error colour on every pane that receives, with the count on the one being
/// typed into — so the state is visible wherever someone is looking.
class _PaneHeader extends ConsumerWidget {
  const _PaneHeader({
    required this.session,
    required this.tree,
    required this.active,
    required this.broadcastCount,
  });

  final TerminalSession session;
  final PaneTree tree;
  final bool active;
  final int broadcastCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final layouts = ref.read(paneLayoutsProvider.notifier);
    final manager = ref.read(sessionManagerProvider.notifier);
    final receiving = tree.receivesBroadcast(session.id);
    final excluded = tree.broadcast && !receiving;
    final background = receiving
        ? scheme.errorContainer
        : active
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;
    final foreground = receiving
        ? scheme.onErrorContainer
        : active
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final status = receiving
        ? (active
              ? l10n.paneBroadcastBanner(broadcastCount)
              : l10n.paneBroadcastReceiving)
        : excluded
        ? l10n.paneBroadcastExcluded
        : null;

    Widget action(
      String tooltip,
      IconData icon,
      VoidCallback onPressed, {
      Key? key,
    }) => IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 12, color: foreground),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 22, height: 22),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => manager.select(session.id),
      child: Container(
        key: ValueKey('pane.header.${session.id}'),
        height: Chrome.statusBar,
        color: background,
        padding: const EdgeInsets.only(left: Spacing.sm, right: Spacing.xxs),
        child: Row(
          children: [
            if (tree.broadcast) ...[
              Icon(
                PiconsRegular.broadcast,
                size: 12,
                color: receiving ? scheme.error : foreground,
              ),
              const SizedBox(width: Spacing.xs),
            ],
            Flexible(
              child: ListenableBuilder(
                listenable: session,
                builder: (context, _) => Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: active ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
            SessionLogDot(sessionId: session.id, leading: Spacing.xs),
            if (status != null) ...[
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  status,
                  key: ValueKey('pane.status.${session.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            if (tree.broadcast)
              action(
                receiving
                    ? l10n.paneBroadcastExclude
                    : l10n.paneBroadcastInclude,
                receiving
                    ? PiconsRegular.speakerSlash
                    : PiconsRegular.broadcast,
                () => layouts.toggleExcluded(session.id),
                key: ValueKey('pane.exclude.${session.id}'),
              ),
            if (tree.broadcast && active)
              TextButton(
                onPressed: () => toggleBroadcast(ref, session.id),
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.paneBroadcastStop),
              ),
            action(
              tree.maximized == session.id
                  ? l10n.paneRestore
                  : l10n.paneMaximize,
              tree.maximized == session.id
                  ? PiconsRegular.cornersIn
                  : PiconsRegular.cornersOut,
              () => layouts.toggleMaximize(session.id),
            ),
            action(
              l10n.paneClose,
              PiconsRegular.x,
              () => manager.close(session.id),
              key: ValueKey('pane.close.${session.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The warning row above the one visible pane on a narrow screen, where the
/// other panes receiving the same keystrokes are out of sight.
class _BroadcastBanner extends ConsumerWidget {
  const _BroadcastBanner({
    required this.tree,
    required this.session,
    required this.count,
  });

  final PaneTree tree;
  final TerminalSession session;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      key: const Key('panes.broadcastBanner'),
      height: Chrome.statusBar,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          Icon(PiconsRegular.broadcast, size: 14, color: scheme.error),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              l10n.paneBroadcastBanner(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => toggleBroadcast(ref, session.id),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onErrorContainer,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(l10n.paneBroadcastStop),
          ),
        ],
      ),
    );
  }
}

/// A draggable divider between two panes.
class _DividerHandle extends StatefulWidget {
  const _DividerHandle({
    required this.divider,
    required this.onDrag,
    required this.onEnd,
  });

  final PaneDivider divider;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onEnd;

  @override
  State<_DividerHandle> createState() => _DividerHandleState();
}

class _DividerHandleState extends State<_DividerHandle> {
  /// Where the divider is being dragged to, in the split's coordinates.
  /// Tracked from the drag's start rather than read back from the clamped
  /// layout, so pulling past a limit and back does not drift.
  double _position = 0;
  double _ratio = 0.5;
  var _hovering = false;
  var _dragging = false;

  bool get _horizontal => widget.divider.axis == SplitAxis.horizontal;

  void _start() => setState(() {
    _dragging = true;
    _position = _horizontal
        ? widget.divider.rect.left
        : widget.divider.rect.top;
  });

  void _update(double delta) {
    _position += delta;
    _ratio = widget.divider.ratioAt(_position);
    widget.onDrag(_ratio);
  }

  void _end() {
    setState(() => _dragging = false);
    widget.onEnd(_ratio);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = _hovering || _dragging;
    final line = AnimatedContainer(
      duration: Motion.fast,
      width: _horizontal ? (highlighted ? 3 : kPaneDivider) : null,
      height: _horizontal ? null : (highlighted ? 3 : kPaneDivider),
      color: highlighted ? scheme.primary : scheme.outlineVariant,
    );

    return MouseRegion(
      cursor: _horizontal
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        key: ValueKey('pane.divider.${widget.divider.path}'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _horizontal ? (_) => _start() : null,
        onHorizontalDragUpdate: _horizontal
            ? (details) => _update(details.delta.dx)
            : null,
        onHorizontalDragEnd: _horizontal ? (_) => _end() : null,
        onVerticalDragStart: _horizontal ? null : (_) => _start(),
        onVerticalDragUpdate: _horizontal
            ? null
            : (details) => _update(details.delta.dy),
        onVerticalDragEnd: _horizontal ? null : (_) => _end(),
        // Back to an even split, the way the panel's own handle resets.
        onDoubleTap: () => widget.onEnd(0.5),
        child: Center(child: line),
      ),
    );
  }
}
