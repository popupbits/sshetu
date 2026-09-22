# Vendored: xterm2 5.3.0

- **Upstream:** https://github.com/SoFluffyOS/xterm2
- **Version:** 5.3.0, at commit `2a339558ba103e38a304a4eda7c984b45c47e186`
  (also recorded in `.upstream-commit`). pub.dev is one release behind at 5.2.0.
- **Vendored on:** 2026-09-03

## Why xterm2 and not xterm

`xterm.dart` — the package karmashala vendored — is effectively unmaintained:
last push June 2025, 107 open issues, two commits in all of 2025. `xterm2` is a
community fork of it that is actively developed, and it has already shipped
things this app specifically needs on a phone: DEC synchronized updates, OSC 8
hyperlinks, cursor shapes, procedurally drawn box/block glyphs (no font seams),
IME composition positioning, a Flutter shortcut system, and real allocation
work in the parser and cell-copy paths.

So the base is xterm2, not karmashala's fork of xterm 4.0.0. Karmashala's
patches were then re-evaluated against it one at a time — see below.

## Why this is forked anyway

Two of the bugs karmashala found in xterm 4.0.0 are still present in xterm2
5.3.0, and both are reproducible. They are fixed here and pinned by
`test/terminal/vendored_xterm2_test.dart` in the app, which **fails against
pristine upstream** — that is the point of it. If a re-vendor makes those tests
fail, the patch was dropped: re-apply it, do not delete the test.

Runtime dependencies are unchanged, so vendoring adds nothing new to the
dependency graph.

## Files that diverge from upstream

Five of the 86 `.dart` files under `lib/`. Everything else is byte-identical;
the only other differences are `pubspec.yaml` and `analysis_options.yaml`
(packaging, below).

| File | Divergence |
| --- | --- |
| `lib/src/utils/circular_buffer.dart` | `_adoptChild` and `_moveChild` detach the outgoing occupant of a slot only if it is still **homed** there (`_isHomedAt` / `_evict`). `Buffer._scrollUpFullWidth` shifts lines with `lines[i] = lines[i + count]` (`buffer.dart:935`), which leaves one `BufferLine` referenced from two slots between iterations of the loop — it has already been re-attached at the lower index while the higher slot still holds it. Upstream detaches unconditionally and therefore detaches a line that is still live; every later `_move` of it then trips `assert(attached)`. Measured here: a 40×24 terminal with a `CSI 2;10r` scroll region leaves **lines 1–8 — the entire scroll region — detached** after 400 lines of ordinary output. The comparison is against the *cyclic slot*, not the logical index: `push` evicts by adopting into `_getCyclicIndex(_length)`, which when the list is full is the slot of element 0, and keying the check on the logical index instead silently disables overflow eviction and leaks every line the buffer ever held. Both directions are pinned by tests. |
| `lib/src/ui/render.dart` | A drag selection's start is held as a `CellAnchor` (`_dragAnchor`, resolved by `_dragStart`) instead of being re-derived from a screen position on every update. `TerminalGestureHandler._updateDragSelection` passes the position the drag *began* at every time, and upstream feeds it back through `getCellOffset`, which adds the **current** scroll offset — so as soon as the buffer moves under the pointer (output arriving, or the view scrolling) the start of the selection slides onto a different line and everything that scrolled off the top falls out of it. Selecting a build log while it is still printing gave you the last screen, not what you dragged over. Measured: 20 lines of output mid-drag moved the selection start from line 7 to line 27. Applied to all three selection entry points — `selectCharacters`, `selectWord` and `selectLine` — because on a touch device the long-press (`selectWord`) path is *the* selection path, not the mouse one. Held separately from the selection's own anchors because `TerminalController.setSelection` takes ownership of those and disposes them on the next call; released in `dispose()`. One import (`core/buffer/line.dart`) is added, since `CellAnchor` is now named directly. |
| `lib/src/ui/custom_text_edit.dart` | An insertion delta is decided by whether the platform's new value **continues** the last one it sent (`_lastPlatformText`, `_resetRequested`) rather than by assuming the widget's own `setEditingState(_initEditingState)` reset took effect. That reset is asynchronous and on iOS it races the next keystroke. Logged from inside `updateEditingValue` on an iPhone 17 Pro simulator, typing `abcde` arrives as `a` (reset landed), `b` (landed), `bc` (**not** landed — the platform appended), `bcd` (appended), `e` (landed); upstream re-sends the appended values in full, so the shell received `abbcbcde`. Measured against a live server: `uname -s` reached the prompt as `unnaname --s-s`. A strict prefix test tells an append from a fresh value; a *common-prefix* diff does not — it swallows a new keystroke that happens to repeat a leading character, which turned the same input into `una -s; ho`, so the identical-value case is disambiguated by whether a reset was requested in between (`ll` is two keystrokes, not a no-op). All three cases are pinned by tests, using the sequence the simulator actually sent. |
| `lib/src/core/buffer/buffer.dart`, `lib/src/core/buffer/line.dart` | **Performance, not a bug.** Once the scrollback is full, every line feed pushes a new line and evicts `lines[0]`, and upstream allocates a fresh `BufferLine` for every push — a `Uint32List` of 16 bytes per cell of *capacity* (2 KiB at 80–128 columns). A newline flood therefore spends most of its time allocating a line per `\n` and collecting the one that fell off: 200,000 bare `\r\n` took 170 ms, of which allocating 200,000 lines alone was 150 ms. `Buffer._newLineForPush` reuses the line being evicted instead, via `BufferLine.resetForReuse` (zeroes the cells, clears `isWrapped`, combining characters and underline colours — what the constructor would give). Used only where a push is certain to evict `lines[0]`: the full-width scroll-up push loop, `index()`'s bottom-of-screen push, and its margin-top-0 insert *only when the insert is at the end* (a push). A line holding an anchor (selection end, search highlight) is never reused, so an anchor on an evicted line still reads as detached exactly as before. Measured with `test/terminal/throughput_bench_test.dart` (with the app's coalescer fix): `seq 1 1250000` end to end 5.0 → 21.5 MB/s, a 50 MB mixed-text `cat` 55 → 112 MB/s. Pinned by the "line reuse" group — identity of the reused line and its blankness fail against upstream; exact scrollback contents after a long flood, the anchored case and reuse after a resize guard the patch itself. |

## Karmashala patches deliberately NOT carried

| karmashala's patch | Why not |
| --- | --- |
| `parser.dart` — `_csiHandleSgr` returns early on a prefixed CSI | **Already fixed upstream, and better.** xterm2 does not merely ignore `CSI > 4 ; 2 m`; it routes it to `handler.setModifyOtherKeysMode` and actually implements xterm's `modifyOtherKeys`. Nothing to port. |
| `painter.dart` — batched text runs, one `Paragraph` per run of equal (fg, bg, flags) plus a per-frame layout budget | **Not ported yet — deliberately, pending measurement.** xterm2 already merges *backgrounds* into runs (`paintLineBackgrounds`) but still lays out one `Paragraph` per cell in `paintLineForegrounds`, so karmashala's 16.7 ms → 3.0 ms win may well still be on the table. But that measurement was taken against xterm 4.0.0, and xterm2 has since done its own allocation, parser and paragraph-cache work. Porting a delicate painter rewrite onto a diverged painter (procedural glyphs, hyperlink state, selection contrast, combining characters, glyph cell spans) on the strength of a stale benchmark is the wrong order. **Benchmark xterm2 first; port only if the numbers still justify it, and bring the pixel-equivalence test with it.** |
| `controller.dart` / `lib/ui.dart` — `underline` flag on `TerminalHighlight`, extra exports | Belongs to karmashala's Ctrl+hover link affordance, which this app does not have. Add it with that feature if it is ever wanted, not before. |

## What was NOT vendored

- `example/`, `media/`, `bin/`, `script/`, `test/` — upstream's own example app,
  README images, developer tooling and tests. `bin/` would otherwise make this
  an executable entry point on the package.
- `dev_dependencies` — dropped with the tests they served, so `mockito` and
  `build_runner` (code generators, which this project does not run) stay out of
  the dependency graph.
- `analysis_options.yaml` — replaced with a permissive one, so third-party code
  does not have to satisfy this project's lint profile while `flutter analyze`
  at the repo root stays clean.

## Rules

Every new divergence must be listed in the table above **with its reason and a
measurement**, and must be pinned by a test in
`test/terminal/vendored_xterm2_test.dart` that fails against pristine upstream.
A patch nobody can prove is needed is a patch that will be silently lost at the
next re-vendor.

All three bugs fixed here are upstream bugs and are worth reporting to
https://github.com/SoFluffyOS/xterm2/issues — if they are fixed there, delete
the patch and keep the test. The line reuse is worth offering upstream too.

## Re-vendoring

```sh
git clone --depth 1 https://github.com/SoFluffyOS/xterm2.git /tmp/xterm2
diff -rq /tmp/xterm2/lib packages/xterm2/lib   # should list only the table above
```

Then copy `lib/`, restore this file, `pubspec.yaml` and `analysis_options.yaml`,
re-apply the patches, update `.upstream-commit`, and run
`flutter test test/terminal/vendored_xterm2_test.dart`.
