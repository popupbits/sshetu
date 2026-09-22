import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/sessions/terminal_appearance.dart';
import 'package:xterm2/xterm.dart';

/// A host's own terminal theme, over the app's.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'settings.terminalTheme': 'nord'});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026);
    SshHost host(String id, {String? theme}) => SshHost(
      id: id,
      label: id,
      hostname: id,
      username: 'root',
      terminalTheme: theme,
      createdAt: now,
      updatedAt: now,
    );

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        settingsControllerProvider.overrideWith(
          () => SettingsController(initial: readSettings(preferences)),
        ),
        hostsProvider.overrideWith(
          (ref) => [
            host('prod', theme: 'dracula'),
            host('plain'),
            host('future', theme: 'from-a-newer-build'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostsProvider.future);
  });

  String themeOf(String hostId) =>
      container.read(terminalThemePresetProvider(hostId)).id;

  test('a host with an override draws in it', () {
    expect(themeOf('prod'), 'dracula');
  });

  test('a host without one follows the app setting', () {
    expect(themeOf('plain'), 'nord');
  });

  test('an unknown override falls back to the app setting', () {
    expect(themeOf('future'), 'nord');
  });

  test('a deleted host still draws', () {
    expect(themeOf('gone'), 'nord');
  });

  test('changing the app setting reaches hosts without an override', () {
    container
        .read(settingsControllerProvider.notifier)
        .setTerminalTheme('monokai');
    expect(themeOf('plain'), 'monokai');
    expect(themeOf('prod'), 'dracula');
  });

  test('the font follows the setting', () {
    expect(container.read(terminalFontProvider).id, 'system');
    container
        .read(settingsControllerProvider.notifier)
        .setTerminalFont('fira-code');
    expect(container.read(terminalFontProvider).family, 'Fira Code');
  });

  test('cursor shapes map onto xterm2', () {
    expect(TerminalCursorShape.block.cursorType, TerminalCursorType.block);
    expect(
      TerminalCursorShape.underline.cursorType,
      TerminalCursorType.underline,
    );
    expect(TerminalCursorShape.bar.cursorType, TerminalCursorType.verticalBar);
  });
}
