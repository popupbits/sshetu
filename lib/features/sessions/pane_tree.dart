import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Which way a split lays its two halves out.
enum SplitAxis {
  /// Side by side, left then right — what "split right" makes.
  horizontal,

  /// Stacked, top then bottom — what "split down" makes.
  vertical,
}

/// One node of a tab's split layout: a pane, or a split of two nodes.
///
/// Immutable, and plain Dart. The layout is the part of split panes that can
/// be wrong in ways nobody notices until a window is resized — which pane gets
/// focus when its neighbour closes, whether a divider can be dragged until a
/// terminal is two columns wide — so it lives here, where a test can reach
/// every case, and the widgets only draw what it says.
sealed class PaneNode {
  const PaneNode();
}

/// A pane, naming the terminal session shown in it.
final class PaneLeaf extends PaneNode {
  const PaneLeaf(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is PaneLeaf && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PaneLeaf($id)';
}

/// Two nodes sharing a rectangle along [axis]; [first] takes [ratio] of it.
final class PaneBranch extends PaneNode {
  const PaneBranch({
    required this.axis,
    required this.first,
    required this.second,
    this.ratio = 0.5,
  });

  final SplitAxis axis;
  final PaneNode first;
  final PaneNode second;

  /// The share of the space (after the divider) [first] asks for. A request:
  /// layout clamps it so neither side drops below its minimum, without
  /// rewriting it — widening the window again gives the old split back.
  final double ratio;

  PaneBranch copyWith({PaneNode? first, PaneNode? second, double? ratio}) =>
      PaneBranch(
        axis: axis,
        first: first ?? this.first,
        second: second ?? this.second,
        ratio: ratio ?? this.ratio,
      );

  @override
  bool operator ==(Object other) =>
      other is PaneBranch &&
      other.axis == axis &&
      other.first == first &&
      other.second == second &&
      other.ratio == ratio;

  @override
  int get hashCode => Object.hash(axis, first, second, ratio);

  @override
  String toString() => 'PaneBranch(${axis.name}, $ratio, $first, $second)';
}

/// The smallest a pane may be drawn: about 30 columns by 6 rows at the
/// default font size. Below that a terminal stops being somewhere output can
/// be read, and a split that would need it is shown one pane at a time.
const Size kMinPaneSize = Size(240, 120);

/// The gap a divider occupies between two panes.
const double kPaneDivider = 1;

/// A split ratio is kept inside this margin of either end, whatever a drag or
/// a stored file says, so no pane can be dragged to nothing.
const double _ratioMargin = 0.05;

/// A tab's split layout of terminal sessions, and the state that belongs to
/// the tab rather than to any one pane.
class PaneTree {
  const PaneTree({
    required this.root,
    required this.focused,
    this.maximized,
    this.broadcast = false,
    this.excluded = const {},
  });

  /// A tab with one pane. Not stored — a single pane needs no tree — but the
  /// starting point for the first split.
  factory PaneTree.single(String id) =>
      PaneTree(root: PaneLeaf(id), focused: id);

  final PaneNode root;

  /// The pane that had focus last in this tab — where focus returns when the
  /// tab is selected again.
  final String focused;

  /// The pane filling the tab while the others are hidden, if any.
  final String? maximized;

  /// "Type in all panes": what is typed in one pane goes to every other one
  /// that is connected and not [excluded].
  final bool broadcast;

  /// Panes left out of [broadcast].
  final Set<String> excluded;

  /// Every pane, in reading order: left to right, top to bottom. This is also
  /// the order next-pane and previous-pane walk.
  List<String> get panes => _leaves(root);

  int get length => panes.length;

  bool contains(String id) => panes.contains(id);

  /// Whether [id] currently receives what is typed in another pane.
  bool receivesBroadcast(String id) =>
      broadcast && length > 1 && contains(id) && !excluded.contains(id);

  PaneTree copyWith({
    PaneNode? root,
    String? focused,
    String? maximized,
    bool clearMaximized = false,
    bool? broadcast,
    Set<String>? excluded,
  }) => PaneTree(
    root: root ?? this.root,
    focused: focused ?? this.focused,
    maximized: clearMaximized ? null : (maximized ?? this.maximized),
    broadcast: broadcast ?? this.broadcast,
    excluded: excluded ?? this.excluded,
  );

  /// Splits [target] in two along [axis], with [newId] after it, and focuses
  /// the new pane. A maximized pane is restored: the point of splitting is to
  /// see both.
  PaneTree split(String target, String newId, SplitAxis axis) {
    if (!contains(target)) throw ArgumentError.value(target, 'target');
    if (contains(newId)) throw ArgumentError.value(newId, 'newId');
    return copyWith(
      root: _replaceLeaf(
        root,
        target,
        PaneBranch(
          axis: axis,
          first: PaneLeaf(target),
          second: PaneLeaf(newId),
        ),
      ),
      focused: newId,
      clearMaximized: true,
    );
  }

  /// The tree with [id] gone and its sibling taking the space, or null when
  /// [id] was the only pane.
  ///
  /// If [id] had focus, it passes to the pane nearest where [id] was — the
  /// sibling's closest edge — rather than to the first pane in the tab.
  /// Broadcast turns itself off when fewer than two panes are left: there is
  /// nobody left to type to, and a toggle that silently comes back on after
  /// the next split is how someone types into servers they forgot about.
  PaneTree? close(String id) {
    if (!contains(id)) return this;
    final removed = _remove(root, id);
    final next = removed.node;
    if (next == null) return null;
    final remaining = _leaves(next);
    return PaneTree(
      root: next,
      focused: focused == id ? (removed.successor ?? remaining.first) : focused,
      maximized: maximized == id ? null : maximized,
      broadcast: broadcast && remaining.length > 1,
      excluded: remaining.length > 1
          ? {
              for (final pane in excluded)
                if (pane != id) pane,
            }
          : const {},
    );
  }

  PaneTree focus(String id) =>
      contains(id) && id != focused ? copyWith(focused: id) : this;

  /// Moves focus [delta] panes along [panes], wrapping. A maximized pane
  /// hands the tab over to the pane focus moves to, so moving never lands on
  /// a pane nobody can see.
  PaneTree cycleFocus(int delta) {
    final order = panes;
    if (order.length < 2) return this;
    final index = math.max(0, order.indexOf(focused));
    final next = order[(index + delta) % order.length];
    return copyWith(focused: next, maximized: maximized == null ? null : next);
  }

  /// Sets the ratio of the split at [path] (see [PaneDivider.path]).
  PaneTree resize(String path, double ratio) =>
      copyWith(root: _setRatio(root, path, clampRatio(ratio)));

  /// Fills the tab with [id], or puts it back if it already does.
  PaneTree toggleMaximize(String id) {
    if (!contains(id) || length < 2) return this;
    return maximized == id
        ? copyWith(clearMaximized: true)
        : copyWith(maximized: id, focused: id);
  }

  /// Turns "type in all panes" on or off. Only on with two panes or more.
  PaneTree withBroadcast(bool on) => copyWith(broadcast: on && length > 1);

  /// Leaves [id] out of broadcast, or lets it back in.
  PaneTree toggleExcluded(String id) {
    if (!contains(id)) return this;
    return copyWith(
      excluded: excluded.contains(id)
          ? {
              for (final pane in excluded)
                if (pane != id) pane,
            }
          : {...excluded, id},
    );
  }

  /// The tree with every pane renamed by [rename]; a pane it maps to null is
  /// closed. Null when fewer than two panes are left — one pane is a plain
  /// tab, not a layout.
  ///
  /// Used to write a layout with panes named by tab position, and to read one
  /// back once those tabs have sessions again.
  PaneTree? relabel(String? Function(String id) rename) {
    PaneTree? tree = this;
    for (final id in panes) {
      if (rename(id) == null) tree = tree?.close(id);
    }
    if (tree == null || tree.length < 2) return null;
    final names = {for (final id in tree.panes) id: rename(id)!};
    if (names.values.toSet().length != names.length) return null;
    return PaneTree(
      root: _rename(tree.root, names),
      focused: names[tree.focused]!,
      maximized: tree.maximized == null ? null : names[tree.maximized],
      broadcast: tree.broadcast,
      excluded: {for (final id in tree.excluded) names[id]!},
    );
  }

  /// The layout as it is remembered between launches: the shape, the ratios
  /// and the focus. Never broadcast, and never a maximized pane — a relaunch
  /// that comes back already typing into every server is the one surprise
  /// this must not spring.
  Map<String, Object?> toJson() => {'root': _nodeToJson(root), 'f': focused};

  /// Null for anything malformed, including a pane named twice.
  static PaneTree? fromJson(Object? json) {
    if (json is! Map) return null;
    final root = _nodeFromJson(json['root'], 0);
    if (root == null) return null;
    final leaves = _leaves(root);
    if (leaves.length < 2 || leaves.toSet().length != leaves.length) {
      return null;
    }
    final focused = json['f'];
    return PaneTree(
      root: root,
      focused: focused is String && leaves.contains(focused)
          ? focused
          : leaves.first,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaneTree &&
      other.root == root &&
      other.focused == focused &&
      other.maximized == maximized &&
      other.broadcast == broadcast &&
      other.excluded.length == excluded.length &&
      other.excluded.containsAll(excluded);

  @override
  int get hashCode =>
      Object.hash(root, focused, maximized, broadcast, excluded.length);

  @override
  String toString() => 'PaneTree($root, focused: $focused)';
}

/// Keeps a stored or dragged ratio away from either end.
double clampRatio(double ratio) =>
    ratio.isNaN ? 0.5 : ratio.clamp(_ratioMargin, 1 - _ratioMargin).toDouble();

// ------------------------------------------------------------------ layout

/// A divider between the two halves of a split, as laid out.
class PaneDivider {
  const PaneDivider({
    required this.path,
    required this.axis,
    required this.rect,
    required this.bounds,
    required this.firstMin,
    required this.secondMin,
  });

  /// Which split this is: one character per step down from the root, `0` for
  /// the first child and `1` for the second. The root split is `''`.
  final String path;

  final SplitAxis axis;

  /// The divider's own strip.
  final Rect rect;

  /// The whole rectangle the split divides.
  final Rect bounds;

  /// The least each side may be given along [axis].
  final double firstMin;
  final double secondMin;

  /// The ratio a divider dragged to [position] (along [axis], in the same
  /// coordinates as [bounds]) asks for — clamped so neither side drops below
  /// its minimum.
  double ratioAt(double position) {
    final start = axis == SplitAxis.horizontal ? bounds.left : bounds.top;
    final extent = axis == SplitAxis.horizontal ? bounds.width : bounds.height;
    final available = extent - kPaneDivider;
    if (available <= 0) return 0.5;
    final first = splitFirstExtent(
      (position - start) / available,
      available,
      firstMin,
      secondMin,
    );
    return clampRatio(first / available);
  }
}

/// Where every visible pane and divider of a tree goes.
class PaneGeometry {
  const PaneGeometry({required this.panes, required this.dividers});

  /// Visible panes only: a maximized tab shows one.
  final Map<String, Rect> panes;
  final List<PaneDivider> dividers;
}

/// How much of [available] the first side of a split gets for [ratio].
///
/// Clamped so both sides keep their minimum. When the space cannot hold both
/// minimums at all it is shared in proportion to them — the caller should not
/// be tiling at that size (see [PaneTree.fits]), but a layout must still
/// produce something sane mid-resize.
double splitFirstExtent(
  double ratio,
  double available,
  double firstMin,
  double secondMin,
) {
  if (available <= 0) return 0;
  if (firstMin + secondMin > available) {
    return available * firstMin / (firstMin + secondMin);
  }
  return (clampRatio(ratio) * available)
      .clamp(firstMin, available - secondMin)
      .toDouble();
}

/// The least [node] can be drawn in along [axis].
double minExtent(PaneNode node, SplitAxis axis, {Size min = kMinPaneSize}) =>
    switch (node) {
      PaneLeaf() => axis == SplitAxis.horizontal ? min.width : min.height,
      PaneBranch(:final first, :final second) =>
        node.axis == axis
            ? minExtent(first, axis, min: min) +
                  kPaneDivider +
                  minExtent(second, axis, min: min)
            : math.max(
                minExtent(first, axis, min: min),
                minExtent(second, axis, min: min),
              ),
    };

extension PaneTreeLayout on PaneTree {
  /// Whether [size] holds every pane at its minimum. When it does not, the
  /// tab is shown one pane at a time instead of as a row of slivers.
  bool fits(Size size, {Size min = kMinPaneSize}) =>
      minExtent(root, SplitAxis.horizontal, min: min) <= size.width &&
      minExtent(root, SplitAxis.vertical, min: min) <= size.height;

  PaneGeometry layout(Size size, {Size min = kMinPaneSize}) {
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    final zoomed = maximized;
    if (zoomed != null && contains(zoomed)) {
      return PaneGeometry(panes: {zoomed: bounds}, dividers: const []);
    }
    final panes = <String, Rect>{};
    final dividers = <PaneDivider>[];
    void place(PaneNode node, Rect rect, String path) {
      switch (node) {
        case PaneLeaf(:final id):
          panes[id] = rect;
        case PaneBranch(:final axis, :final first, :final second):
          final horizontal = axis == SplitAxis.horizontal;
          final extent = horizontal ? rect.width : rect.height;
          final available = math.max(0.0, extent - kPaneDivider);
          final firstMin = minExtent(first, axis, min: min);
          final secondMin = minExtent(second, axis, min: min);
          final a = splitFirstExtent(
            node.ratio,
            available,
            firstMin,
            secondMin,
          );
          final Rect firstRect;
          final Rect dividerRect;
          final Rect secondRect;
          if (horizontal) {
            firstRect = Rect.fromLTWH(rect.left, rect.top, a, rect.height);
            dividerRect = Rect.fromLTWH(
              rect.left + a,
              rect.top,
              kPaneDivider,
              rect.height,
            );
            secondRect = Rect.fromLTRB(
              dividerRect.right,
              rect.top,
              rect.right,
              rect.bottom,
            );
          } else {
            firstRect = Rect.fromLTWH(rect.left, rect.top, rect.width, a);
            dividerRect = Rect.fromLTWH(
              rect.left,
              rect.top + a,
              rect.width,
              kPaneDivider,
            );
            secondRect = Rect.fromLTRB(
              rect.left,
              dividerRect.bottom,
              rect.right,
              rect.bottom,
            );
          }
          dividers.add(
            PaneDivider(
              path: path,
              axis: axis,
              rect: dividerRect,
              bounds: rect,
              firstMin: firstMin,
              secondMin: secondMin,
            ),
          );
          place(first, firstRect, '${path}0');
          place(second, secondRect, '${path}1');
      }
    }

    place(root, bounds, '');
    return PaneGeometry(panes: panes, dividers: dividers);
  }
}

// ---------------------------------------------------------- tabs, broadcast

/// One workspace tab: a single pane, or a split layout.
class PaneTab {
  const PaneTab({required this.panes, this.tree});

  /// Its sessions, in pane order.
  final List<String> panes;

  final PaneTree? tree;

  /// The pane to show when the tab is selected.
  String get focused => tree?.focused ?? panes.first;

  bool contains(String id) => panes.contains(id);
}

/// Groups the session list into tabs: a session in a layout joins its
/// layout's tab, at the position of the layout's first session in the list.
List<PaneTab> groupIntoTabs(List<String> sessionIds, List<PaneTree> trees) {
  final tabs = <PaneTab>[];
  final placed = <PaneTree>{};
  for (final id in sessionIds) {
    final tree = trees.where((t) => t.contains(id)).firstOrNull;
    if (tree == null) {
      tabs.add(PaneTab(panes: [id]));
    } else if (placed.add(tree)) {
      tabs.add(
        PaneTab(
          panes: [
            for (final pane in tree.panes)
              if (sessionIds.contains(pane)) pane,
          ],
          tree: tree,
        ),
      );
    }
  }
  return tabs;
}

/// The panes that also receive what is typed or pasted into [source].
///
/// Empty unless [source]'s tab has broadcast on, [source] itself takes part
/// (typing into a pane left out of broadcast stays in that pane), and
/// [source] is connected — keystrokes into a dead pane echo nowhere, and
/// sending them on blind to every other server is exactly the accident the
/// banner is there to prevent. A target that is not connected is skipped: it
/// has no shell to type into, and must not replay a backlog when it returns.
List<String> broadcastTargets(
  PaneTree? tree,
  String source, {
  required bool Function(String id) isLive,
}) {
  if (tree == null || !tree.receivesBroadcast(source) || !isLive(source)) {
    return const [];
  }
  return [
    for (final pane in tree.panes)
      if (pane != source && tree.receivesBroadcast(pane) && isLive(pane)) pane,
  ];
}

// ----------------------------------------------------------------- helpers

List<String> _leaves(PaneNode node) => switch (node) {
  PaneLeaf(:final id) => [id],
  PaneBranch(:final first, :final second) => [
    ..._leaves(first),
    ..._leaves(second),
  ],
};

PaneNode _replaceLeaf(PaneNode node, String id, PaneNode replacement) =>
    switch (node) {
      PaneLeaf() => node.id == id ? replacement : node,
      PaneBranch(:final first, :final second) => node.copyWith(
        first: _replaceLeaf(first, id, replacement),
        second: _replaceLeaf(second, id, replacement),
      ),
    };

/// [node] without [id], and the pane that took its place: the sibling's leaf
/// nearest the edge [id] shared with it.
({PaneNode? node, String? successor}) _remove(PaneNode node, String id) {
  switch (node) {
    case PaneLeaf():
      return (node: node.id == id ? null : node, successor: null);
    case PaneBranch(:final first, :final second):
      if (first is PaneLeaf && first.id == id) {
        return (node: second, successor: _leaves(second).first);
      }
      if (second is PaneLeaf && second.id == id) {
        return (node: first, successor: _leaves(first).last);
      }
      final a = _remove(first, id);
      if (a.node != first) {
        return (node: node.copyWith(first: a.node), successor: a.successor);
      }
      final b = _remove(second, id);
      return (node: node.copyWith(second: b.node), successor: b.successor);
  }
}

PaneNode _setRatio(PaneNode node, String path, double ratio) {
  if (node is! PaneBranch) return node;
  if (path.isEmpty) return node.copyWith(ratio: ratio);
  final rest = path.substring(1);
  return path[0] == '0'
      ? node.copyWith(first: _setRatio(node.first, rest, ratio))
      : node.copyWith(second: _setRatio(node.second, rest, ratio));
}

PaneNode _rename(PaneNode node, Map<String, String> names) => switch (node) {
  PaneLeaf(:final id) => PaneLeaf(names[id]!),
  PaneBranch(:final first, :final second) => node.copyWith(
    first: _rename(first, names),
    second: _rename(second, names),
  ),
};

Object? _nodeToJson(PaneNode node) => switch (node) {
  PaneLeaf(:final id) => {'p': id},
  PaneBranch(:final axis, :final ratio, :final first, :final second) => {
    'a': axis == SplitAxis.horizontal ? 'h' : 'v',
    'r': ratio,
    'c': [_nodeToJson(first), _nodeToJson(second)],
  },
};

/// Depth-limited: a preferences file is not trusted to be a sane shape.
PaneNode? _nodeFromJson(Object? json, int depth) {
  if (json is! Map || depth > 16) return null;
  final id = json['p'];
  if (id is String && id.isNotEmpty) return PaneLeaf(id);
  final axis = switch (json['a']) {
    'h' => SplitAxis.horizontal,
    'v' => SplitAxis.vertical,
    _ => null,
  };
  final children = json['c'];
  if (axis == null || children is! List || children.length != 2) return null;
  final first = _nodeFromJson(children[0], depth + 1);
  final second = _nodeFromJson(children[1], depth + 1);
  if (first == null || second == null) return null;
  final ratio = json['r'];
  return PaneBranch(
    axis: axis,
    first: first,
    second: second,
    ratio: ratio is num ? clampRatio(ratio.toDouble()) : 0.5,
  );
}
