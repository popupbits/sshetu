import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:sshetu/core/settings/settings_controller.dart';

/// Theme, face, cursor and scrollback survive a restart, and nothing stored
/// by hand or by another build can put the terminal in a state it cannot
/// draw.
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

  AppSettings settings() => container.read(settingsControllerProvider);
  SettingsController controller() =>
      container.read(settingsControllerProvider.notifier);
  Future<AppSettings> reread() async =>
      readSettings(await SharedPreferences.getInstance());

  test('defaults', () {
    final s = settings();
    expect(s.terminalThemeId, 'sshetu');
    expect(s.terminalFontId, 'system');
    expect(s.scrollbackLines, 10000);
    expect(s.cursorShape, TerminalCursorShape.block);
    expect(s.cursorBlink, isFalse);
  });

  test('a fresh install reads the defaults', () async {
    expect(await reread(), const AppSettings());
  });

  test('everything survives a round trip through storage', () async {
    controller()
      ..setTerminalTheme('gruvbox-dark')
      ..setTerminalFont('jetbrains-mono')
      ..setScrollbackLines(50000)
      ..setCursorShape(TerminalCursorShape.bar)
      ..setCursorBlink(true);
    await pumpEventQueue();

    final stored = await reread();
    expect(stored.terminalThemeId, 'gruvbox-dark');
    expect(stored.terminalFontId, 'jetbrains-mono');
    expect(stored.scrollbackLines, 50000);
    expect(stored.cursorShape, TerminalCursorShape.bar);
    expect(stored.cursorBlink, isTrue);
  });

  group('scrollback is clamped', () {
    test('on write', () {
      controller().setScrollbackLines(10);
      expect(settings().scrollbackLines, AppSettings.minScrollbackLines);
      controller().setScrollbackLines(5000000);
      expect(settings().scrollbackLines, AppSettings.maxScrollbackLines);
      controller().setScrollbackLines(25000);
      expect(settings().scrollbackLines, 25000);
    });

    test('on read', () async {
      SharedPreferences.setMockInitialValues({
        'settings.scrollbackLines': 999999999,
      });
      expect((await reread()).scrollbackLines, 100000);
      SharedPreferences.setMockInitialValues({'settings.scrollbackLines': -4});
      expect((await reread()).scrollbackLines, 1000);
    });

    test('a value of the wrong type reads as the default', () async {
      SharedPreferences.setMockInitialValues({
        'settings.scrollbackLines': 'lots',
      });
      expect((await reread()).scrollbackLines, 10000);
    });

    test('every offered step is in range', () {
      for (final step in AppSettings.scrollbackSteps) {
        expect(AppSettings.clampScrollback(step), step);
      }
      expect(
        AppSettings.scrollbackSteps,
        contains(AppSettings.defaultScrollbackLines),
      );
    });
  });

  group('unknown stored values fall back', () {
    test('theme, face and cursor', () async {
      SharedPreferences.setMockInitialValues({
        'settings.terminalTheme': 'solarized-neon',
        'settings.terminalFont': 'comic-mono',
        'settings.cursorShape': 'heart',
      });
      final stored = await reread();
      expect(stored.terminalThemeId, 'sshetu');
      expect(stored.terminalFontId, 'system');
      expect(stored.cursorShape, TerminalCursorShape.block);
    });

    test('an unknown theme is stored as the default, not as itself', () {
      controller().setTerminalTheme('nope');
      expect(settings().terminalThemeId, 'sshetu');
    });
  });
}
