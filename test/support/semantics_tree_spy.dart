import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// A test binding that watches every semantics update the framework sends to
/// the engine and checks it the way the desktop accessibility bridge does.
///
/// Windows' bridge applies each update to a `ui::AXTree`, which refuses one
/// that carries a node no parent points at: "Failed to update ui::AXTree,
/// error: N will not be in the tree and is not the new root". The engine
/// only logs it, so nothing fails — except the screen reader, which is left
/// with a stale tree. This keeps the same tree (id → children) and records
/// each node an update sends that the tree, after the update, cannot reach
/// from the root.
///
/// Create it first thing in `main`, before any test runs:
///
/// ```dart
/// void main() {
///   final spy = SemanticsTreeSpyBinding.ensureInitialized();
///   ...
/// }
/// ```
class SemanticsTreeSpyBinding extends AutomatedTestWidgetsFlutterBinding {
  SemanticsTreeSpyBinding._();

  static SemanticsTreeSpyBinding? _instance;

  static SemanticsTreeSpyBinding ensureInitialized() =>
      _instance ??= SemanticsTreeSpyBinding._();

  /// The tree as the engine would hold it: each node's children.
  final Map<int, List<int>> tree = {};

  /// Nodes sent that were not reachable from the root once applied, one
  /// entry per update that had any.
  final List<Set<int>> orphans = [];

  /// How many updates were checked.
  int updates = 0;

  /// Forgets everything, for a fresh test.
  void resetSpy() {
    tree.clear();
    orphans.clear();
    updates = 0;
  }

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      _SpyBuilder(super.createSemanticsUpdateBuilder(), applyUpdate);

  /// Applies one update, as the engine would, and records its orphans.
  void applyUpdate(Map<int, List<int>> sent) {
    updates++;
    tree.addAll(sent);
    final reachable = <int>{};
    final stack = <int>[0];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!reachable.add(id)) continue;
      stack.addAll(tree[id] ?? const []);
    }
    // The engine drops what is no longer reachable; so does this.
    tree.removeWhere((id, _) => !reachable.contains(id));
    final lost = sent.keys.where((id) => !reachable.contains(id)).toSet();
    if (lost.isNotEmpty) orphans.add(lost);
  }
}

class _SpyBuilder implements ui.SemanticsUpdateBuilder {
  _SpyBuilder(this._real, this._onBuild);

  final ui.SemanticsUpdateBuilder _real;
  final void Function(Map<int, List<int>> sent) _onBuild;
  final Map<int, List<int>> _sent = {};

  @override
  ui.SemanticsUpdate build() {
    _onBuild(Map.of(_sent));
    return _real.build();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateNode) {
      final args = invocation.namedArguments;
      final children = args[#childrenInTraversalOrder] as Int32List;
      _sent[args[#id] as int] = children.toList();
    }
    // Everything else, and the call itself, goes to the engine's builder.
    final Function method = switch (invocation.memberName) {
      #updateNode => (_real as dynamic).updateNode as Function,
      #updateCustomAction => (_real as dynamic).updateCustomAction as Function,
      _ => throw UnsupportedError('${invocation.memberName}'),
    };
    return Function.apply(
      method,
      invocation.positionalArguments,
      invocation.namedArguments,
    );
  }
}
