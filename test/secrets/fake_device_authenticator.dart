import 'package:sshetu/core/secrets/device_authenticator.dart';

/// A [DeviceAuthenticator] that answers from fields instead of a sensor.
class FakeDeviceAuthenticator implements DeviceAuthenticator {
  FakeDeviceAuthenticator({
    this.available = true,
    this.result = DeviceAuthResult.success,
  });

  bool available;
  DeviceAuthResult result;

  /// Every reason a prompt was raised with, in order.
  final List<String> prompts = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    prompts.add(reason);
    return result;
  }
}
