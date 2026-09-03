import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Captures store-listing screenshots from an integration test.
///
/// The paired driver in `test_driver/integration_test.dart` decides where the
/// files land; this class owns naming, ordering, and the Android surface
/// conversion that `takeScreenshot` requires.
///
/// ## Fail loudly
///
/// The failure this exists to prevent is a run that reports success while
/// capturing nothing — which is what happens when navigation steps are wrapped
/// in try/catch and every one of them quietly misses. The test goes green, the
/// store listing stays empty, and nobody notices until review. So: do not
/// swallow errors in navigation steps, and always finish with [assertCaptured].
class ScreenshotHelper {
  ScreenshotHelper(this._binding);

  final IntegrationTestWidgetsFlutterBinding _binding;
  final List<String> _captured = <String>[];
  bool _surfaceConverted = false;

  /// Names captured so far, in order.
  List<String> get captured => List.unmodifiable(_captured);

  /// Prepare the binding.
  ///
  /// On Android `takeScreenshot` only works once the Flutter surface has been
  /// converted to an image, and converting twice throws. Call this after the
  /// first `pumpAndSettle` and before the first [take]; calling it again is a
  /// no-op, so calling it defensively is safe.
  Future<void> prepare(WidgetTester tester) async {
    if (_surfaceConverted) return;
    await _binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    _surfaceConverted = true;
  }

  /// Capture a screenshot named `NN_[name]`, zero-padded so the files sort in
  /// capture order — which is also the order the store shows them in.
  Future<void> take(String name) async {
    if (!_surfaceConverted) {
      fail(
        'ScreenshotHelper.prepare() must be called before take("$name"). '
        'Without it takeScreenshot returns an empty image on Android.',
      );
    }
    final index = (_captured.length + 1).toString().padLeft(2, '0');
    final screenshotName = '${index}_$name';
    await _binding.takeScreenshot(screenshotName);
    _captured.add(screenshotName);
  }

  /// Fail unless at least [minimum] screenshots were captured.
  ///
  /// Always call this last. A run that captures nothing must go red: a
  /// silently-green one is indistinguishable from a working one right up until
  /// you look at the empty listing.
  void assertCaptured({int minimum = 1}) {
    expect(
      _captured.length,
      greaterThanOrEqualTo(minimum),
      reason:
          'Captured ${_captured.length} screenshots, expected at least '
          '$minimum. Check the navigation steps actually reached each screen.',
    );
  }
}
