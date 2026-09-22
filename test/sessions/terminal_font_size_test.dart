import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/sessions/terminal_font_size.dart';

/// A host's own terminal font size, over the app's.
void main() {
  group('resolveTerminalFontSize', () {
    test('no override follows the app setting', () {
      expect(resolveTerminalFontSize(hostOverride: null, appDefault: 14), 14);
    });

    test('an override wins', () {
      expect(resolveTerminalFontSize(hostOverride: 20, appDefault: 14), 20);
    });

    test('an out-of-range stored value is clamped', () {
      expect(
        resolveTerminalFontSize(hostOverride: 200, appDefault: 14),
        AppSettings.maxTerminalFontSize,
      );
      expect(
        resolveTerminalFontSize(hostOverride: 1, appDefault: 14),
        AppSettings.minTerminalFontSize,
      );
    });
  });

  test('the provider reads the host by id', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026);
    SshHost host(String id, {double? fontSize}) => SshHost(
      id: id,
      label: id,
      hostname: id,
      username: 'root',
      fontSize: fontSize,
      createdAt: now,
      updatedAt: now,
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        settingsControllerProvider.overrideWith(
          () => SettingsController(initial: readSettings(preferences)),
        ),
        hostsProvider.overrideWith(
          (ref) => [host('big', fontSize: 22), host('plain')],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostsProvider.future);

    expect(container.read(terminalFontSizeProvider('big')), 22);
    expect(
      container.read(terminalFontSizeProvider('plain')),
      AppSettings.defaultTerminalFontSize,
    );
    // A session whose host has since been deleted still draws.
    expect(
      container.read(terminalFontSizeProvider('gone')),
      AppSettings.defaultTerminalFontSize,
    );
  });
}
