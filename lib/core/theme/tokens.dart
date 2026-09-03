/// Design tokens for SSH Navigator.
///
/// Single source of truth for every spacing, radius, duration and border value
/// in the app. No `EdgeInsets.all(13)` in a widget file — pick the nearest step
/// here, or add one and say why.
library;

abstract final class Spacing {
  /// Hairline. Off the 4-pt ladder deliberately, for insets too tight to round
  /// up (a 1-px breathing gap inside a chip border).
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Default screen gutter on a phone.
  static const double gutter = md;

  /// Wider gutter once there is room for it.
  static const double gutterWide = xl;

  /// Bottom padding for a scrollable that shares the screen with a FAB, so the
  /// last row is not tucked behind it.
  static const double fabClearance = 96;
}

/// Fixed row heights for application chrome.
///
/// Chrome is measured, not spaced: a tab strip is a *row of a known height*,
/// not padding around a label, and the same height has to be reused or the top
/// of a window reads as several slabs that nearly line up. Borrowed from
/// karmashala, whose terminal shell made the same argument — vertical space in
/// a terminal is the scarcest thing on the screen, so every row of chrome has
/// to justify itself and none of them may drift.
abstract final class Chrome {
  /// The session tab strip, and any pane header that shares its row.
  static const double tabStrip = 34;

  /// The thin bar a pane draws when it has no live session behind it.
  static const double statusBar = 26;

  /// A dense list row — the host sidebar on desktop.
  static const double row = 30;

  /// A row in a popup or context menu.
  static const double menuRow = 34;

  /// The accent rule marking the selected tab.
  ///
  /// Selection is a rule rather than an outline: against a neutral surface
  /// ramp at this size an outline is simply invisible, and tinting the label
  /// would collide with liveness, which is already carrying meaning.
  static const double selectionRule = 2;
}

abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;

  /// Material 3 specifies 28 for bottom sheets.
  static const double sheet = 28;
  static const double pill = 999;
}

/// Named `Motion` rather than `Durations`: material_ui exports a class by
/// that name, and an ambiguous import is a confusing way to learn it.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

abstract final class BorderWidths {
  static const double hairline = 1;
  static const double thick = 1.5;
  static const double emphasis = 2;
}

/// Layout breakpoints. See `core/util/responsive.dart` for the helpers that
/// read them.
abstract final class Breakpoints {
  /// Below this is a phone: bottom navigation, one column.
  static const double medium = 600;

  /// At or above this is a desktop or a wide tablet: rail, multiple columns.
  static const double expanded = 1024;

  /// Forms and prose stop growing here; beyond it they centre.
  static const double maxContentWidth = 1280;

  /// Cap for a short centred message — an empty state, an error. Wide enough
  /// for a couple of lines, narrow enough that it stays one readable column
  /// instead of one very long line on a desktop window.
  static const double maxMessageWidth = 420;
}
