import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// How one attempt to confirm the user's presence ended.
///
/// More than a bool because the Settings switch has to tell these apart: "set
/// up a screen lock first" and "you cancelled" are different instructions, and
/// collapsing them leaves the user guessing why the switch will not stay on.
enum DeviceAuthResult {
  /// The user proved presence — biometric or device PIN/password.
  success,

  /// The user dismissed the prompt, or the system did.
  cancelled,

  /// The device has nothing to check against: no screen lock, no biometrics,
  /// no Windows Hello — or no implementation on this platform at all.
  unavailable,

  /// Too many failed attempts; the device will not ask again for a while.
  lockedOut,

  /// Anything else. The prompt was shown and did not succeed.
  failed,
}

/// Asks the device to confirm the user is present.
///
/// The one seam in front of `local_auth`, so everything that decides *when* to
/// ask — the locked vault, the Settings switch — is testable without a device.
abstract interface class DeviceAuthenticator {
  /// Whether this device can confirm presence at all right now.
  ///
  /// True when a screen lock, a biometric or Windows Hello is set up. Asked
  /// before the lock is turned on, so nobody can enable a lock their device
  /// cannot satisfy.
  Future<bool> isAvailable();

  /// Shows the system prompt with [reason], accepting the device PIN or
  /// password as well as biometrics.
  Future<DeviceAuthResult> authenticate(String reason);
}

/// [DeviceAuthenticator] backed by `local_auth`: BiometricPrompt on Android,
/// LocalAuthentication on iOS and macOS, Windows Hello on Windows.
///
/// **Never biometric-only.** `biometricOnly` is false on every call, so the
/// system offers the device PIN, pattern or password beside the fingerprint or
/// face — someone in gloves, or with a sensor that has stopped reading them,
/// still gets in. Windows could not honour the flag anyway: Windows Hello
/// chooses the method itself.
///
/// Linux has no `local_auth` implementation. There the plugin call fails, which
/// is reported as [DeviceAuthResult.unavailable] rather than thrown, so the
/// Settings switch explains itself instead of crashing.
class LocalAuthDeviceAuthenticator implements DeviceAuthenticator {
  LocalAuthDeviceAuthenticator({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    try {
      // `isDeviceSupported`, not `canCheckBiometrics`: the device PIN counts.
      // A phone with a screen lock and no fingerprint enrolled can still
      // confirm presence, and refusing it would push people towards
      // biometrics this lock deliberately does not require.
      return await _localAuth.isDeviceSupported();
    } on MissingPluginException {
      return false;
    } on UnsupportedError {
      return false;
    } on Object {
      // A platform that cannot answer the question cannot answer the prompt.
      return false;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        // Always false. See the class comment: the PIN is the fallback that
        // stops a lock from becoming a lockout.
        biometricOnly: false,
        // Not sticky: an app sent to the background mid-prompt should come
        // back to a cancelled prompt, not to one that reappears on resume.
        persistAcrossBackgrounding: false,
      );
      return ok ? DeviceAuthResult.success : DeviceAuthResult.failed;
    } on LocalAuthException catch (e) {
      return resultFor(e.code);
    } on MissingPluginException {
      return DeviceAuthResult.unavailable;
    } on UnsupportedError {
      return DeviceAuthResult.unavailable;
    } on Object {
      return DeviceAuthResult.failed;
    }
  }

  /// How each `local_auth` error reads to the rest of the app.
  static DeviceAuthResult resultFor(LocalAuthExceptionCode code) =>
      switch (code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.authInProgress => DeviceAuthResult.cancelled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.uiUnavailable => DeviceAuthResult.unavailable,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => DeviceAuthResult.lockedOut,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.deviceError ||
        LocalAuthExceptionCode.unknownError => DeviceAuthResult.failed,
      };
}

/// The device's presence check. Overridden with a fake in tests.
final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalAuthDeviceAuthenticator(),
);
