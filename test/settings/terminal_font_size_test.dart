import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:sshetu/core/settings/settings_controller.dart';

/// The terminal grid's size is its own setting, not the interface text scale.
/// A dense display at 100% scaling makes the default unreadably small, and
/// that is the whole reason this is adjustable.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
  });

  double size() => container.read(settingsControllerProvider).terminalFontSize;
  SettingsController controller() =>
      container.read(settingsControllerProvider.notifier);

  test('starts at the default', () {
    expect(size(), AppSettings.defaultTerminalFontSize);
  });

  test('a step moves it by one point', () {
    controller().adjustTerminalFontSize(1);
    expect(size(), AppSettings.defaultTerminalFontSize + 1);
    controller().adjustTerminalFontSize(-1);
    expect(size(), AppSettings.defaultTerminalFontSize);
  });

  test('will not shrink to nothing', () {
    controller().adjustTerminalFontSize(-1000);
    expect(size(), AppSettings.minTerminalFontSize);
  });

  test('will not grow past the maximum', () {
    controller().adjustTerminalFontSize(1000);
    expect(size(), AppSettings.maxTerminalFontSize);
  });

  test('reset returns to the default', () {
    controller().adjustTerminalFontSize(6);
    controller().resetTerminalFontSize();
    expect(size(), AppSettings.defaultTerminalFontSize);
  });

  test('a stored size out of range is clamped on read', () async {
    // A preferences file edited by hand, or written by a build whose limits
    // differed, must not produce a one-character grid.
    SharedPreferences.setMockInitialValues({
      'settings.terminalFontSize': 900.0,
    });
    final preferences = await SharedPreferences.getInstance();
    expect(
      readSettings(preferences).terminalFontSize,
      AppSettings.maxTerminalFontSize,
    );
  });

  test('survives a round trip through storage', () async {
    controller().setTerminalFontSize(17);
    final preferences = await SharedPreferences.getInstance();
    expect(readSettings(preferences).terminalFontSize, 17);
  });
}
