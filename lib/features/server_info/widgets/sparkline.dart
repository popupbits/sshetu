import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A small line of recent values on a fixed 0–[maxValue] scale.
///
/// Fixed rather than fitted to the data: a sparkline that rescales to its own
/// peak draws an idle server's 2% → 4% as the same cliff as 20% → 90%, and the
/// shape is the whole point of drawing it. One series, so no legend — the
/// label beside it names it — and a 2 px line with a faint wash beneath so a
/// flat zero still reads as a line rather than as nothing.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    required this.semanticLabel,
    this.maxValue = 100,
    this.capacity = 60,
    this.height = 40,
    super.key,
  });

  final List<double> values;
  final double maxValue;

  /// How many samples fill the width. Fewer are drawn from the right, so the
  /// line grows in from the edge instead of stretching as it fills.
  final int capacity;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: SparklinePainter(
            values: values,
            maxValue: maxValue,
            capacity: capacity,
            line: scheme.primary,
            fill: scheme.primary.withValues(alpha: 0.12),
            baseline: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  SparklinePainter({
    required this.values,
    required this.maxValue,
    required this.capacity,
    required this.line,
    required this.fill,
    required this.baseline,
  });

  final List<double> values;
  final double maxValue;
  final int capacity;
  final Color line;
  final Color fill;
  final Color baseline;

  /// Where each value lands, right-aligned. Exposed for tests.
  static List<Offset> pointsFor(
    List<double> values,
    Size size, {
    required double maxValue,
    required int capacity,
  }) {
    if (values.isEmpty || size.isEmpty) return const [];
    final slots = math.max(capacity, values.length);
    final step = slots <= 1 ? 0.0 : size.width / (slots - 1);
    final start = size.width - step * (values.length - 1);
    // Half the stroke of headroom, so a 100% sample is not clipped.
    const inset = 1.0;
    final usable = size.height - inset * 2;
    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          start + step * i,
          inset + usable - (values[i].clamp(0, maxValue) / maxValue) * usable,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
    final points = pointsFor(
      values,
      size,
      maxValue: maxValue,
      capacity: capacity,
    );
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.single, 2, Paint()..color = line);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      !identical(old.values, values) ||
      old.line != line ||
      old.fill != fill ||
      old.maxValue != maxValue;
}
