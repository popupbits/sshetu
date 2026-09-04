import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/shell/workspace_layout.dart';

/// How the workspace divides a window.
void main() {
  /// Resolves as the shell does: the window decides whether the terminal is
  /// shown, and the space left over decides how it is split.
  WorkspaceLayout resolve(double available, {double preferred = 320}) =>
      WorkspaceLayout.resolve(
        available: available,
        preferred: preferred,
        showTerminal: WorkspaceLayout.showsTerminalAt(
          available + WorkspaceLayout.railAllowance,
        ),
      );

  test('a wide window honours the width the user chose', () {
    final layout = resolve(1600, preferred: 420);

    expect(layout.panelWidth, 420);
    expect(layout.showTerminal, isTrue);
  });

  test('a narrower window takes it from the panel, not the terminal', () {
    // The terminal is the work; the panel is the index to it. When one has to
    // give, it is the index.
    final layout = resolve(700, preferred: 500);

    expect(layout.panelWidth, 700 - 1 - WorkspaceLayout.minTerminal);
    expect(layout.showTerminal, isTrue);
  });

  test('and never below the width a host list needs', () {
    // The tightest window that still shows both: the panel is squeezed to
    // exactly its floor and the terminal to exactly its own.
    const tightest = WorkspaceLayout.minPanel + 1 + WorkspaceLayout.minTerminal;

    final layout = resolve(tightest, preferred: 500);

    expect(layout.panelWidth, WorkspaceLayout.minPanel);
    expect(layout.showTerminal, isTrue);
  });

  test('one point narrower than that, and it is one pane', () {
    const tightest = WorkspaceLayout.minPanel + 1 + WorkspaceLayout.minTerminal;

    expect(resolve(tightest - 1, preferred: 500).showTerminal, isFalse);
  });

  test('a window too small for both shows one pane', () {
    final layout = resolve(500, preferred: 320);

    expect(layout.showTerminal, isFalse);
    expect(layout.panelWidth, 500, reason: 'the one pane gets the window');
  });

  test('the rail and the panes never disagree about the terminal', () {
    // They used to: the rail asked the window and the panes asked what was
    // left after it, so around 700 points the rail dropped Sessions because
    // it thought the terminal was on screen while the panes had dropped the
    // terminal — leaving no way to reach it at all.
    for (var window = 600.0; window <= 1400; window += 1) {
      final shown = WorkspaceLayout.showsTerminalAt(window);
      final layout = WorkspaceLayout.resolve(
        available: window - WorkspaceLayout.railAllowance,
        preferred: 320,
        showTerminal: shown,
      );
      expect(layout.showTerminal, shown, reason: 'at $window');
    }
  });

  test('the preference survives a window that could not honour it', () {
    // Squeezed, then widened again: the number the user dragged to is still
    // theirs, because resolving never rewrites it.
    const preferred = 480.0;

    expect(resolve(700, preferred: preferred).panelWidth, lessThan(preferred));
    expect(resolve(1600, preferred: preferred).panelWidth, preferred);
  });

  test('a drag cannot leave the sensible range', () {
    expect(WorkspaceLayout.clampPreference(50), WorkspaceLayout.minPanel);
    expect(WorkspaceLayout.clampPreference(9000), WorkspaceLayout.maxPanel);
    expect(WorkspaceLayout.clampPreference(400), 400);
  });

  test('the panel never exceeds what the window has', () {
    for (final width in [300.0, 460.0, 601.0, 640.0, 900.0, 2000.0]) {
      final layout = resolve(width, preferred: WorkspaceLayout.maxPanel);
      expect(layout.panelWidth, lessThanOrEqualTo(width), reason: 'at $width');
      expect(layout.panelWidth, greaterThan(0), reason: 'at $width');
    }
  });
}
