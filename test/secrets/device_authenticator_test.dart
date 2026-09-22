import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sshetu/core/secrets/device_authenticator.dart';

/// What `local_auth` is asked for, and how its answers are read.
void main() {
  test('never asks for biometrics alone', () async {
    // The device PIN is the fallback that keeps a user in gloves, or with a
    // sensor that stopped reading them, out of a lockout.
    final plugin = _FakeLocalAuth();
    await LocalAuthDeviceAuthenticator(localAuth: plugin).authenticate('why');

    expect(plugin.biometricOnly, isFalse);
    expect(plugin.reason, 'why');
  });

  test('a successful prompt is success, a declined one is not', () async {
    final plugin = _FakeLocalAuth();
    final auth = LocalAuthDeviceAuthenticator(localAuth: plugin);

    expect(await auth.authenticate('why'), DeviceAuthResult.success);
    plugin.answer = false;
    expect(await auth.authenticate('why'), DeviceAuthResult.failed);
  });

  for (final (code, result) in [
    (LocalAuthExceptionCode.userCanceled, DeviceAuthResult.cancelled),
    (LocalAuthExceptionCode.systemCanceled, DeviceAuthResult.cancelled),
    (LocalAuthExceptionCode.noCredentialsSet, DeviceAuthResult.unavailable),
    (LocalAuthExceptionCode.noBiometricHardware, DeviceAuthResult.unavailable),
    (LocalAuthExceptionCode.biometricLockout, DeviceAuthResult.lockedOut),
    (LocalAuthExceptionCode.unknownError, DeviceAuthResult.failed),
  ]) {
    test('${code.name} reads as ${result.name}', () async {
      final plugin = _FakeLocalAuth()..error = LocalAuthException(code: code);
      expect(
        await LocalAuthDeviceAuthenticator(localAuth: plugin).authenticate('x'),
        result,
      );
    });
  }

  test(
    'a platform with no implementation is unavailable, not a crash',
    () async {
      // Linux: local_auth has no implementation there at all.
      final plugin = _FakeLocalAuth()..error = MissingPluginException();
      final auth = LocalAuthDeviceAuthenticator(localAuth: plugin);

      expect(await auth.isAvailable(), isFalse);
      expect(await auth.authenticate('x'), DeviceAuthResult.unavailable);
    },
  );

  test('availability is whether the device can confirm presence', () async {
    final plugin = _FakeLocalAuth();
    final auth = LocalAuthDeviceAuthenticator(localAuth: plugin);

    expect(await auth.isAvailable(), isTrue);
    plugin.supported = false;
    expect(await auth.isAvailable(), isFalse);
  });
}

class _FakeLocalAuth implements LocalAuthentication {
  bool supported = true;
  bool answer = true;
  Object? error;

  bool? biometricOnly;
  String? reason;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    reason = localizedReason;
    this.biometricOnly = biometricOnly;
    if (error case final e?) throw e;
    return answer;
  }

  @override
  Future<bool> isDeviceSupported() async {
    if (error case final e?) throw e;
    return supported;
  }

  @override
  Future<bool> get canCheckBiometrics async => supported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => const [];

  @override
  Future<bool> stopAuthentication() async => true;
}
