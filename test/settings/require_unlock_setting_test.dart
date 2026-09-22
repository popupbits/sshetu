import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:sshetu/core/settings/settings_controller.dart';

/// The credential lock's stored setting: off unless deliberately turned on,
/// and surviving a restart once it is.
void main() {
  test('defaults to off', () {
    expect(const AppSettings().requireUnlock, isFalse);
  });

  test('reads as off from empty preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    expect(readSettings(preferences).requireUnlock, isFalse);
  });

  test('a value of the wrong type reads as off, not as a crash', () async {
    SharedPreferences.setMockInitialValues({'settings.requireUnlock': 'true'});
    final preferences = await SharedPreferences.getInstance();
    expect(readSettings(preferences).requireUnlock, isFalse);
  });

  test('persists, and comes back on the next launch', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    container.read(settingsControllerProvider.notifier).setRequireUnlock(true);
    // The write is fire-and-forget; let it land.
    await Future<void>.delayed(Duration.zero);

    expect(container.read(settingsControllerProvider).requireUnlock, isTrue);
    expect(preferences.getBool('settings.requireUnlock'), isTrue);
    expect(readSettings(preferences).requireUnlock, isTrue);

    container.read(settingsControllerProvider.notifier).setRequireUnlock(false);
    await Future<void>.delayed(Duration.zero);
    expect(readSettings(preferences).requireUnlock, isFalse);
  });

  test('takes part in equality, so a toggle is a change', () {
    const off = AppSettings();
    expect(off.copyWith(requireUnlock: true), isNot(off));
    expect(off.copyWith(requireUnlock: true).copyWith(), isNot(off));
    expect(off.copyWith(requireUnlock: false), off);
  });
}
