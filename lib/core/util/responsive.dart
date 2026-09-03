import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// The three layout classes the app designs for.
enum FormFactor {
  /// Phone. Bottom navigation, one column.
  compact,

  /// Tablet or a small window. Navigation rail, two columns.
  medium,

  /// Desktop or a wide window. Rail, multiple columns, capped content width.
  expanded,
}

extension ResponsiveContext on BuildContext {
  /// Width only — deliberately not `MediaQuery.of(this)`, which rebuilds on
  /// every keyboard animation frame because it depends on view insets too.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  FormFactor get formFactor {
    final width = screenWidth;
    if (width >= Breakpoints.expanded) return FormFactor.expanded;
    if (width >= Breakpoints.medium) return FormFactor.medium;
    return FormFactor.compact;
  }

  bool get isCompact => formFactor == FormFactor.compact;
  bool get isMedium => formFactor == FormFactor.medium;
  bool get isExpanded => formFactor == FormFactor.expanded;

  /// Bottom navigation below this, a rail at or above it.
  bool get useRail => formFactor != FormFactor.compact;

  /// A sensible column count for card grids, capped at [max].
  int gridColumns({int max = 4}) {
    final width = screenWidth;
    if (width >= 1500) return max.clamp(1, 4);
    if (width >= Breakpoints.expanded) return (max - 1).clamp(1, 3);
    if (width >= Breakpoints.medium) return 2;
    return 1;
  }

  /// Screen gutter for the current width.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(
    horizontal: isCompact ? Spacing.gutter : Spacing.gutterWide,
    vertical: Spacing.gutter,
  );
}

/// Caps its child's width and centres it.
///
/// Forms and prose become unreadable when a desktop window stretches them to
/// 2000px. Wrap anything text-shaped in this.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
