import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';

/// A labelled horizontal meter: what it is, how much, and a bar.
///
/// The figures are text in text colours; the bar carries only the share.
/// Past [warnAt] the fill turns to the error colour — and the percentage is
/// always printed beside it, so a nearly full disk never relies on colour
/// alone to say so.
class UsageMeter extends StatelessWidget {
  const UsageMeter({
    required this.label,
    required this.fraction,
    this.detail,
    this.warnAt = 0.9,
    super.key,
  });

  final String label;

  /// 0–1.
  final double fraction;

  /// `1.2 GB of 4.0 GB`.
  final String? detail;
  final double warnAt;

  static const double barHeight = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final hot = value >= warnAt;
    final percent = '${(value * 100).round()}%';

    return Semantics(
      label: label,
      value: detail == null ? percent : '$percent, $detail',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    percent,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: hot ? scheme.error : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: SizedBox(
                  height: barHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: scheme.surfaceContainerHighest),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: hot ? scheme.error : scheme.primary,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: Spacing.xxs),
                Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
