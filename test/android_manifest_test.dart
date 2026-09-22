import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android manifest, checked for the one permission that matters.
///
/// Flutter's template puts `INTERNET` in the debug and profile manifests only
/// — there it serves the Dart VM service, not the app — so a release build of
/// an app that never asked for it explicitly cannot open a socket. For an SSH
/// client that is total failure with no error anywhere in the Dart code: every
/// debug run connects, and the shipped app cannot reach a single host.
///
/// It cost an emulator install to find. A string search is a poor test of an
/// Android build, but it is a very good test of a line that is easy to lose in
/// a merge and impossible to notice missing until release.
void main() {
  test('the release manifest grants INTERNET', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue, reason: 'run from the package root');

    expect(
      manifest.readAsStringSync(),
      contains('android.permission.INTERNET'),
      reason:
          'the main manifest must declare INTERNET; the debug one does not '
          'count, and without it a release build can reach no server at all',
    );
  });

  // The credential lock's two Android requirements. Both compile and pass
  // every Dart test without being there; the lock then fails only on a phone.
  test('the manifest grants USE_BIOMETRIC for the credential lock', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest.readAsStringSync(),
      contains('android.permission.USE_BIOMETRIC'),
    );
  });

  test(
    'MainActivity is a FlutterFragmentActivity, as BiometricPrompt needs',
    () {
      final activity = File(
        'android/app/src/main/kotlin/com/popupbits/sshetu/MainActivity.kt',
      );
      expect(activity.existsSync(), isTrue);
      expect(
        activity.readAsStringSync(),
        contains(': FlutterFragmentActivity()'),
        reason:
            'local_auth cannot show its prompt from a plain FlutterActivity',
      );
    },
  );
}
