package com.popupbits.sshetu

import io.flutter.embedding.android.FlutterFragmentActivity

// A FragmentActivity, not a plain FlutterActivity: local_auth shows Android's
// BiometricPrompt, which is a fragment and cannot attach to anything else.
// Without it the credential lock fails on every Android device.
// Guarded by test/android_manifest_test.dart.
class MainActivity : FlutterFragmentActivity()
