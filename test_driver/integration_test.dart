import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for the store-screenshot integration test.
///
/// Writes each captured screenshot to `build/screenshots/`, where the
/// Screenshots workflow captions them and the fastlane `upload_screenshots`
/// lane uploads the result.
///
/// ```sh
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_test.dart \
///   -d <device>
/// ```
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> bytes, [
      Map<String, Object?>? args,
    ]) async {
      final file = await File(
        'build/screenshots/$name.png',
      ).create(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
