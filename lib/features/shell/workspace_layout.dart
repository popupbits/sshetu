import 'dart:math' as math;

/// How the desktop workspace divides the space beside the rail.
///
/// Pulled out of the widget because it is the part that can be wrong. The
/// question "at 900 points, with a panel the user dragged to 500, what should
/// happen?" has an answer that is worth stating once and testing, rather than
/// discovering by resizing a window.
class WorkspaceLayout {
  const WorkspaceLayout({required this.panelWidth, required this.showTerminal});

  /// Narrower than this a list of hosts is a column of ellipses.
  ///
  /// 240 rather than a round 200: an IPv4 address plus a monogram and a
  /// status dot is close to 240, and below it the addresses — the one thing
  /// someone is scanning for — start truncating.
  static const double minPanel = 240;

  /// Wider than this the panel is no longer a list beside your work; it is a
  /// second window competing with the terminal. The drag stops here.
  static const double maxPanel = 560;

  /// About 45 columns at the default size. Below that a terminal stops being
  /// a place you can read output and starts being a place text goes to wrap.
  static const double minTerminal = 360;

  /// What a fresh install gets.
  static const double defaultPanel = 320;

  /// Roughly what the navigation rail occupies, including its divider.
  ///
  /// An allowance, not a measurement — the rail sizes itself from its labels
  /// and the text scale. It exists so *one* decision about whether the
  /// terminal fits can be made from the window width, before the rail is
  /// built. Deciding it twice, once for the rail's destinations and once for
  /// the panes, is how the terminal ended up hidden and unreachable at the
  /// same time: the rail thought there was room and dropped Sessions, the
  /// panes disagreed and dropped the terminal.
  ///
  /// Being a little wrong is harmless. A rail wider than this only means the
  /// panel gives up a few more points, which the clamp already handles.
  static const double railAllowance = 96;

  final double panelWidth;

  /// False when the window cannot hold a usable panel *and* a usable terminal.
  ///
  /// Two cramped panes are worse than one good one: at that width the answer
  /// is to show a single pane and let the rail switch between them, which is
  /// why Sessions rejoins the rail exactly when this is false.
  final bool showTerminal;

  /// One divider sits between the panel and the terminal.
  static const double _divider = 1;

  /// Whether a window this wide can hold a usable panel *and* terminal.
  ///
  /// Answered from the whole window rather than from what is left after the
  /// rail, because the rail's own contents depend on the answer.
  static bool showsTerminalAt(double windowWidth) =>
      windowWidth >= railAllowance + minPanel + _divider + minTerminal;

  /// Divides [available] — the space left after the rail and its divider.
  ///
  /// [preferred] is what the user dragged the panel to. It is a preference,
  /// not an instruction: a window narrow enough that honouring it would
  /// squeeze the terminal into uselessness overrides it, and widening the
  /// window restores it, because the preference itself is never rewritten.
  factory WorkspaceLayout.resolve({
    required double available,
    required double preferred,
    required bool showTerminal,
  }) {
    if (!showTerminal) {
      return WorkspaceLayout(panelWidth: available, showTerminal: false);
    }

    final ceiling = math.min(maxPanel, available - _divider - minTerminal);
    return WorkspaceLayout(
      panelWidth: preferred.clamp(minPanel, math.max(minPanel, ceiling)),
      showTerminal: true,
    );
  }

  /// Where a drag may put the panel, before the window has its say.
  static double clampPreference(double width) =>
      width.clamp(minPanel, maxPanel);
}
