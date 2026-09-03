// Regression tests for the divergences in packages/xterm2.
//
// Every patch we carry against upstream xterm2 is pinned here. If one of these
// fails after a re-vendor, the patch was lost — re-apply it rather than
// deleting the test. See packages/xterm2/VENDORED.md.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

void main() {
  group('circular buffer aliasing (utils/circular_buffer.dart)', () {
    // Buffer._scrollUpFullWidth shifts lines with `lines[i] = lines[i + count]`,
    // which leaves one BufferLine referenced from two slots between iterations:
    // it has already been re-attached at the lower index while the higher slot
    // still holds it. Upstream detaches the outgoing occupant unconditionally,
    // so it detaches a line that is still live — and the next insert, which
    // asserts `attached`, blows up. Reaching the aliasing branch needs a scroll
    // region narrower than the viewport, otherwise scrolling just pushes lines.
    test('scrolling inside a scroll region does not detach a live line', () {
      final terminal = Terminal(maxLines: 200);
      terminal.resize(40, 24);

      // DECSTBM: rows 2..10 scroll, the rest of the viewport does not.
      terminal.write('\x1b[2;10r');

      // Enough passes through the region to shift the same lines many times.
      for (var i = 0; i < 400; i++) {
        terminal.write('line $i\r\n');
      }

      // Assert the corruption directly rather than waiting for the assert it
      // eventually trips: a line sitting in the buffer while detached is
      // already broken, and every later `_move` of it throws. Upstream leaves
      // a run of them here.
      final detached = <int>[
        for (var i = 0; i < terminal.buffer.lines.length; i++)
          if (!terminal.buffer.lines[i].attached) i,
      ];
      expect(
        detached,
        isEmpty,
        reason: 'lines still held by the buffer must stay attached; '
            'detaching a live alias is what trips assert(attached) later',
      );

      // And the operations that walk the buffer with _moveChild still work.
      expect(() => terminal.write('\x1b[5L'), returnsNormally);
      expect(() => terminal.write('\x1b[3M'), returnsNormally);
      terminal.write('after\r\n');
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('a genuinely evicted line is still detached', () {
      // The guard must not become "never detach": a line that really is
      // dropped has to release its anchors, or scrollback leaks every line it
      // ever held.
      final terminal = Terminal(maxLines: 30);
      terminal.resize(20, 5);

      terminal.write('pinned\r\n');
      final anchor = terminal.buffer.createAnchor(0, 0);
      expect(anchor.attached, isTrue);

      // Push far past maxLines so the anchored line falls off the top.
      for (var i = 0; i < 200; i++) {
        terminal.write('filler $i\r\n');
      }

      expect(
        anchor.attached,
        isFalse,
        reason: 'a line evicted from scrollback must detach its anchors',
      );
    });
  });

  group('drag selection anchor (ui/render.dart)', () {
    // TerminalGestureHandler passes the position the drag *began* at on every
    // update. Upstream feeds that back through getCellOffset, which adds the
    // CURRENT scroll offset — so once output arrives under the pointer, the
    // start of the selection slides down onto a different line and everything
    // that scrolled off the top drops out of it. Selecting a build log while it
    // is still printing gave you the last screen, not what you dragged over.
    testWidgets('selection start survives output arriving mid-drag', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 1000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: SizedBox(
              width: 800,
              height: 600,
              child: TerminalView(
                terminal,
                controller: controller,
                autofocus: true,
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < 40; i++) {
        terminal.write('row $i\r\n');
      }
      await tester.pumpAndSettle();

      // Begin a mouse drag part-way down the viewport.
      final origin = tester.getTopLeft(find.byType(TerminalView));
      final start = origin + const Offset(20, 60);
      final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(start + const Offset(120, 40));
      await tester.pump();

      final startedAt = controller.selection?.begin;
      expect(startedAt, isNotNull, reason: 'the drag should have selected something');
      final anchoredLine = startedAt!.y;

      // Output arrives while the drag is still held: the buffer scrolls under
      // the pointer without the pointer moving.
      for (var i = 0; i < 20; i++) {
        terminal.write('noise $i\r\n');
      }
      await tester.pumpAndSettle();

      // The gesture updates again from the SAME physical start position.
      await gesture.moveTo(start + const Offset(140, 40));
      await tester.pump();

      expect(
        controller.selection?.begin.y,
        anchoredLine,
        reason: 'the selection start must follow its buffer line, not the '
            'screen position it was first seen at',
      );

      await gesture.up();
    });
  });
}
