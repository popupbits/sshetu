import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/sessions/pane_tree.dart';

/// The split layout model: every operation a tab's panes can go through, and
/// the geometry the widgets draw from it.
void main() {
  /// a | b, then b split down into b / c:
  ///
  ///   +---+---+
  ///   |   | b |
  ///   | a +---+
  ///   |   | c |
  ///   +---+---+
  PaneTree abc() =>
      PaneTree.single('a')
          .split('a', 'b', SplitAxis.horizontal)
          .split('b', 'c', SplitAxis.vertical);

  group('split', () {
    test('puts the new pane after the target and focuses it', () {
      final tree = PaneTree.single('a').split('a', 'b', SplitAxis.horizontal);
      expect(tree.panes, ['a', 'b']);
      expect(tree.focused, 'b');
      expect(
        tree.root,
        const PaneBranch(
          axis: SplitAxis.horizontal,
          first: PaneLeaf('a'),
          second: PaneLeaf('b'),
        ),
      );
    });

    test('nests inside the pane that was split', () {
      final tree = abc();
      expect(tree.panes, ['a', 'b', 'c']);
      final root = tree.root as PaneBranch;
      expect(root.first, const PaneLeaf('a'));
      expect(
        root.second,
        const PaneBranch(
          axis: SplitAxis.vertical,
          first: PaneLeaf('b'),
          second: PaneLeaf('c'),
        ),
      );
    });

    test('refuses an unknown target and a duplicate pane', () {
      expect(
        () => PaneTree.single('a').split('x', 'b', SplitAxis.horizontal),
        throwsArgumentError,
      );
      expect(
        () => PaneTree.single('a').split('a', 'a', SplitAxis.horizontal),
        throwsArgumentError,
      );
    });

    test('restores a maximized pane', () {
      final tree = abc()
          .toggleMaximize('a')
          .split('a', 'd', SplitAxis.vertical);
      expect(tree.maximized, isNull);
    });
  });

  group('close', () {
    test('collapses the parent: the sibling takes the whole space', () {
      final tree = abc().close('b')!;
      expect(tree.panes, ['a', 'c']);
      expect(
        tree.root,
        const PaneBranch(
          axis: SplitAxis.horizontal,
          first: PaneLeaf('a'),
          second: PaneLeaf('c'),
        ),
      );
    });

    test('the last pane closing leaves no tree', () {
      expect(PaneTree.single('a').close('a'), isNull);
      final one = PaneTree.single('a')
          .split('a', 'b', SplitAxis.horizontal)
          .close('a')!;
      expect(one.panes, ['b']);
      expect(one.close('b'), isNull);
    });

    test('focus passes to the nearest pane in the sibling', () {
      // c focused (the last split); closing it lands on b, above it.
      expect(abc().close('c')!.focused, 'b');
      // a focused and closed: the pane on its near side is b, not c.
      expect(abc().focus('a').close('a')!.focused, 'b');
      // A pane that was not focused closing leaves focus alone.
      expect(abc().focus('a').close('c')!.focused, 'a');
    });

    test('broadcast turns off when fewer than two panes are left', () {
      final tree = PaneTree.single('a')
          .split('a', 'b', SplitAxis.horizontal)
          .withBroadcast(true)
          .toggleExcluded('a');
      expect(tree.broadcast, isTrue);
      final alone = tree.close('b')!;
      expect(alone.broadcast, isFalse);
      expect(alone.excluded, isEmpty);
      // Splitting again does not bring it back by itself.
      expect(alone.split('a', 'c', SplitAxis.horizontal).broadcast, isFalse);
    });

    test('broadcast survives while two panes remain', () {
      final tree = abc().withBroadcast(true).toggleExcluded('c').close('c')!;
      expect(tree.broadcast, isTrue);
      expect(tree.excluded, isEmpty);
    });

    test('closing the maximized pane restores the layout', () {
      expect(abc().toggleMaximize('b').close('b')!.maximized, isNull);
    });
  });

  group('focus traversal', () {
    test('follows reading order and wraps both ways', () {
      var tree = abc().focus('a');
      final order = <String>[];
      for (var i = 0; i < 4; i++) {
        tree = tree.cycleFocus(1);
        order.add(tree.focused);
      }
      expect(order, ['b', 'c', 'a', 'b']);
      expect(abc().focus('a').cycleFocus(-1).focused, 'c');
    });

    test('moving off a maximized pane maximizes where focus lands', () {
      final tree = abc().toggleMaximize('a').cycleFocus(1);
      expect(tree.focused, 'b');
      expect(tree.maximized, 'b');
    });

    test('focus on an unknown pane is ignored', () {
      final tree = abc();
      expect(identical(tree.focus('zzz'), tree), isTrue);
    });
  });

  group('resize', () {
    test('sets the ratio of the split at a path', () {
      final tree = abc().resize('', 0.3).resize('1', 0.7);
      final root = tree.root as PaneBranch;
      expect(root.ratio, 0.3);
      expect((root.second as PaneBranch).ratio, 0.7);
    });

    test('a stored ratio never reaches either end', () {
      final root = abc().resize('', 0).root as PaneBranch;
      expect(root.ratio, greaterThan(0));
      expect((abc().resize('', 2).root as PaneBranch).ratio, lessThan(1));
    });

    test('layout clamps each side to its minimum', () {
      const size = Size(1000, 600);
      final squeezed = abc().resize('', 0.05).layout(size);
      expect(squeezed.panes['a']!.width, kMinPaneSize.width);
      final wide = abc().resize('', 0.95).layout(size);
      // The right-hand side holds b and c stacked: one pane wide.
      expect(wide.panes['b']!.width, kMinPaneSize.width);
      expect(wide.panes['c']!.width, kMinPaneSize.width);
    });

    test('a divider drag asks for no less than the minimum', () {
      const size = Size(1000, 600);
      final divider = abc()
          .layout(size)
          .dividers
          .firstWhere((d) => d.path.isEmpty);
      final available = size.width - kPaneDivider;
      expect(
        divider.ratioAt(-500) * available,
        closeTo(kMinPaneSize.width, 0.001),
      );
      expect(
        divider.ratioAt(5000) * available,
        closeTo(available - kMinPaneSize.width, 0.001),
      );
      expect(divider.ratioAt(available * 0.4), closeTo(0.4, 0.001));
    });

    test('the minimum of a branch adds along its axis, not across it', () {
      final root = abc().root;
      // a | (b / c): two panes across, two panes down.
      expect(
        minExtent(root, SplitAxis.horizontal),
        kMinPaneSize.width * 2 + kPaneDivider,
      );
      expect(
        minExtent(root, SplitAxis.vertical),
        kMinPaneSize.height * 2 + kPaneDivider,
      );
    });
  });

  group('layout', () {
    test('tiles the whole area with no overlap', () {
      const size = Size(1001, 601);
      final geometry = abc().layout(size);
      final a = geometry.panes['a']!;
      final b = geometry.panes['b']!;
      final c = geometry.panes['c']!;
      expect(a.left, 0);
      expect(a.height, size.height);
      expect(b.left, a.right + kPaneDivider);
      expect(b.right, size.width);
      expect(c.top, b.bottom + kPaneDivider);
      expect(c.bottom, size.height);
      expect(geometry.dividers.map((d) => d.path), ['', '1']);
    });

    test('a maximized pane fills it alone', () {
      const size = Size(800, 500);
      final geometry = abc().toggleMaximize('b').layout(size);
      expect(geometry.panes, {'b': Offset.zero & size});
      expect(geometry.dividers, isEmpty);
    });

    test('fits only when every pane gets its minimum', () {
      expect(abc().fits(const Size(900, 600)), isTrue);
      // Two panes across need 481 points.
      expect(abc().fits(const Size(400, 600)), isFalse);
      // Two panes down need 241.
      expect(abc().fits(const Size(900, 200)), isFalse);
    });
  });

  group('maximize', () {
    test('toggles, and focuses the pane', () {
      final on = abc().focus('a').toggleMaximize('b');
      expect(on.maximized, 'b');
      expect(on.focused, 'b');
      expect(on.toggleMaximize('b').maximized, isNull);
    });

    test('means nothing with one pane', () {
      final one = PaneTree.single('a');
      expect(one.toggleMaximize('a').maximized, isNull);
    });
  });

  group('broadcast targets', () {
    bool live(String id) => id != 'dead';

    test('off: nothing but the pane typed into', () {
      expect(broadcastTargets(abc(), 'a', isLive: live), isEmpty);
      expect(broadcastTargets(null, 'a', isLive: live), isEmpty);
    });

    test('on: every other connected, included pane', () {
      final tree = abc().withBroadcast(true);
      expect(broadcastTargets(tree, 'a', isLive: live), ['b', 'c']);
      expect(broadcastTargets(tree, 'c', isLive: live), ['a', 'b']);
    });

    test('an excluded pane receives nothing', () {
      final tree = abc().withBroadcast(true).toggleExcluded('b');
      expect(broadcastTargets(tree, 'a', isLive: live), ['c']);
      expect(tree.receivesBroadcast('b'), isFalse);
      // …and let back in.
      expect(broadcastTargets(tree.toggleExcluded('b'), 'a', isLive: live), [
        'b',
        'c',
      ]);
    });

    test('typing in an excluded pane stays in that pane', () {
      final tree = abc().withBroadcast(true).toggleExcluded('a');
      expect(broadcastTargets(tree, 'a', isLive: live), isEmpty);
    });

    test('a disconnected pane is skipped', () {
      final tree = PaneTree.single('a')
          .split('a', 'dead', SplitAxis.horizontal)
          .split('dead', 'c', SplitAxis.vertical)
          .withBroadcast(true);
      expect(broadcastTargets(tree, 'a', isLive: live), ['c']);
    });

    test('typing into a disconnected pane goes nowhere else', () {
      final tree = PaneTree.single('dead')
          .split('dead', 'b', SplitAxis.horizontal)
          .withBroadcast(true);
      expect(broadcastTargets(tree, 'dead', isLive: live), isEmpty);
    });

    test('cannot be turned on with one pane', () {
      expect(PaneTree.single('a').withBroadcast(true).broadcast, isFalse);
    });
  });

  group('tabs', () {
    test('a layout is one tab, where its first session is', () {
      final tree = PaneTree.single('b').split('b', 'c', SplitAxis.horizontal);
      final tabs = groupIntoTabs(['a', 'b', 'c', 'd'], [tree]);
      expect(tabs.map((t) => t.panes), [
        ['a'],
        ['b', 'c'],
        ['d'],
      ]);
      expect(tabs[1].tree, tree);
      expect(tabs[1].focused, 'c');
      expect(tabs[0].focused, 'a');
    });
  });

  group('json', () {
    test('round-trips shape, ratios and focus', () {
      final tree = abc().resize('', 0.3).focus('b');
      final back = PaneTree.fromJson(jsonDecode(jsonEncode(tree.toJson())))!;
      expect(back.root, tree.root);
      expect(back.focused, 'b');
    });

    test('never writes broadcast or a maximized pane', () {
      final tree = abc().withBroadcast(true).toggleMaximize('a');
      final back = PaneTree.fromJson(jsonDecode(jsonEncode(tree.toJson())))!;
      expect(back.broadcast, isFalse);
      expect(back.maximized, isNull);
    });

    test('rejects malformed shapes', () {
      expect(PaneTree.fromJson(null), isNull);
      expect(
        PaneTree.fromJson({
          'root': {'p': 'a'},
        }),
        isNull,
        reason: 'one pane is not a layout',
      );
      expect(
        PaneTree.fromJson({
          'root': {
            'a': 'h',
            'c': [
              {'p': 'a'},
              {'p': 'a'},
            ],
          },
        }),
        isNull,
        reason: 'a pane named twice',
      );
      expect(
        PaneTree.fromJson({
          'root': {
            'a': 'sideways',
            'c': [
              {'p': 'a'},
              {'p': 'b'},
            ],
          },
        }),
        isNull,
      );
    });

    test('relabel renames, and closes what maps to nothing', () {
      final renamed = abc().relabel((id) => id == 'b' ? null : '$id!')!;
      expect(renamed.panes, ['a!', 'c!']);
      expect(abc().relabel((id) => id == 'a' ? 'a' : null), isNull);
    });
  });
}
