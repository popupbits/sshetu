import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/server_info/widgets/sparkline.dart';

void main() {
  const size = Size(118, 42);

  test('fixed scale: 0 at the bottom, max at the top, clamped', () {
    final points = SparklinePainter.pointsFor(
      const [0, 50, 100, 250],
      size,
      maxValue: 100,
      capacity: 4,
    );
    expect(points.map((p) => p.dx), [
      0,
      closeTo(39.33, 0.01),
      closeTo(78.67, 0.01),
      118,
    ]);
    expect(points[0].dy, 41);
    expect(points[1].dy, 21);
    expect(points[2].dy, 1);
    expect(points[3].dy, 1, reason: 'clamped to the maximum');
  });

  test('fewer samples than capacity grow in from the right edge', () {
    final points = SparklinePainter.pointsFor(
      const [10, 20],
      size,
      maxValue: 100,
      capacity: 60,
    );
    expect(points.last.dx, 118);
    expect(points.first.dx, closeTo(118 - 118 / 59, 0.001));
  });

  test('nothing to draw', () {
    expect(
      SparklinePainter.pointsFor(const [], size, maxValue: 100, capacity: 60),
      isEmpty,
    );
  });
}
