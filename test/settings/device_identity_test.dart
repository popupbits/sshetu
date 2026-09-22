import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/device_identity.dart';

void main() {
  test('made once, then the same every time', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = readOrCreateDeviceId(preferences);
    expect(first, matches(RegExp(r'^[a-z0-9]{6}$')));
    expect(readOrCreateDeviceId(preferences), first);
    expect(preferences.getString('device.tmuxId'), first);
  });

  test('a stored value that is not a valid id is replaced', () async {
    SharedPreferences.setMockInitialValues({'device.tmuxId': 'NOT OK;'});
    final preferences = await SharedPreferences.getInstance();
    expect(
      readOrCreateDeviceId(preferences),
      matches(RegExp(r'^[a-z0-9]{6}$')),
    );
  });

  test('two installs get different ids', () async {
    final ids = <String>{};
    for (var i = 0; i < 50; i++) {
      SharedPreferences.setMockInitialValues({});
      ids.add(readOrCreateDeviceId(await SharedPreferences.getInstance()));
    }
    expect(ids.length, greaterThan(45));
  });
}
