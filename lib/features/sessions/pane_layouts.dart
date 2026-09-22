import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pane_tree.dart';

/// Asks for a new session to open as a split of an existing pane rather than
/// as a tab of its own.
class PaneSplitRequest {
  const PaneSplitRequest({required this.target, required this.axis});

  /// The session whose pane is split.
  final String target;
  final SplitAxis axis;
}

/// The split layouts of the workspace's tabs.
///
/// Only tabs with two panes or more have one; a plain tab is a session with no
/// tree. Sessions themselves stay owned by `SessionManager` — this holds
/// which of them share a tab and how, and nothing that would keep a session
/// alive. The manager keeps the two in step: a session it closes leaves its
/// layout here, and a split it opens lands here before anything is drawn.
class PaneLayouts extends Notifier<List<PaneTree>> {
  @override
  List<PaneTree> build() => const [];

  /// The layout [id] is part of, if any.
  PaneTree? treeFor(String id) {
    for (final tree in state) {
      if (tree.contains(id)) return tree;
    }
    return null;
  }

  void _replace(String member, PaneTree? next) {
    final current = treeFor(member);
    final keep = next != null && next.length > 1 ? next : null;
    state = [
      for (final tree in state)
        if (!identical(tree, current)) tree else ?keep,
      if (current == null) ?keep,
    ];
  }

  /// Splits [target]'s pane, putting [newId] beside or below it.
  void split(String target, String newId, SplitAxis axis) {
    final tree = treeFor(target) ?? PaneTree.single(target);
    _replace(target, tree.split(target, newId, axis));
  }

  /// Takes [id] out of its layout. Returns the pane that should take focus in
  /// its place, or null when [id] was in no layout.
  String? remove(String id) {
    final tree = treeFor(id);
    if (tree == null) return null;
    final next = tree.close(id);
    _replace(id, next);
    return next?.focused;
  }

  void focus(String id) {
    final tree = treeFor(id);
    if (tree == null) return;
    final next = tree.focus(id);
    if (!identical(next, tree)) _replace(id, next);
  }

  /// Moves focus [delta] panes from [from] within its tab. Returns the pane
  /// now focused, or null when [from] has no other pane to move to.
  String? cycle(String from, int delta) {
    final tree = treeFor(from);
    if (tree == null) return null;
    final next = tree.focus(from).cycleFocus(delta);
    _replace(from, next);
    return next.focused;
  }

  void resize(String member, String path, double ratio) {
    final tree = treeFor(member);
    if (tree != null) _replace(member, tree.resize(path, ratio));
  }

  void toggleMaximize(String id) {
    final tree = treeFor(id);
    if (tree != null) _replace(id, tree.toggleMaximize(id));
  }

  void setBroadcast(String member, bool on) {
    final tree = treeFor(member);
    if (tree != null) _replace(member, tree.withBroadcast(on));
  }

  void toggleExcluded(String id) {
    final tree = treeFor(id);
    if (tree != null) _replace(id, tree.toggleExcluded(id));
  }

  /// Adds restored layouts. One naming a session already in a layout is
  /// skipped rather than merged: two trees claiming one pane cannot both be
  /// drawn.
  void addAll(Iterable<PaneTree> trees) {
    final next = [...state];
    for (final tree in trees) {
      if (tree.length < 2) continue;
      final taken = tree.panes.any(
        (id) => next.any((existing) => existing.contains(id)),
      );
      if (!taken) next.add(tree);
    }
    state = next;
  }
}

final paneLayoutsProvider = NotifierProvider<PaneLayouts, List<PaneTree>>(
  PaneLayouts.new,
);
