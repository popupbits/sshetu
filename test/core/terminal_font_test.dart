import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/theme/terminal_theme.dart';

/// `monospace` is not a font on most platforms. Windows resolves it to the
/// proportional UI font and never reaches `fontFamilyFallback`, which is how
/// the terminal ended up drawn in a variable-width face.
void main() {
  String familyOn(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final family = Mono.family;
    debugDefaultTargetPlatformOverride = null;
    return family;
  }

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    test('names a real face on $platform', () {
      expect(
        familyOn(platform),
        isNot('monospace'),
        reason: 'a generic family leaves the face to the system to guess',
      );
    });
  }

  test('every named face is in the fallback list too', () {
    // The fallback is what covers a machine without the first choice
    // installed — Cascadia Mono is Windows 11's, and Windows 10 has Consolas.
    expect(Mono.fallback, contains('Consolas'));
    expect(Mono.fallback, contains('Menlo'));
  });
}
