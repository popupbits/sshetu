import 'package:flutter_test/flutter_test.dart';

import 'semantics_tree_spy.dart';

/// The spy has to catch what the engine refuses, or its silence proves
/// nothing.
void main() {
  final spy = SemanticsTreeSpyBinding.ensureInitialized();

  setUp(spy.resetSpy);

  test('a node no parent lists is an orphan; a listed one is not', () {
    spy.applyUpdate({
      0: [1],
      1: [2],
      2: [],
    });
    expect(spy.orphans, isEmpty);
    // 3 arrives but nobody lists it: what Windows logs as "3 will not be in
    // the tree and is not the new root".
    spy.applyUpdate({3: []});
    expect(spy.orphans, [
      {3},
    ]);
  });

  test('a parent dropping a child takes its subtree out of the tree', () {
    spy.applyUpdate({
      0: [1],
      1: [2],
      2: [],
    });
    spy.applyUpdate({0: []});
    expect(spy.tree.keys, [0]);
    // Updating the dropped grandchild afterwards is an orphan too.
    spy.applyUpdate({2: []});
    expect(spy.orphans.single, {2});
  });
}
