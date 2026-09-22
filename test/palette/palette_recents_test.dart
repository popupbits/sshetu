import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/palette/palette_recents.dart';

void main() {
  Future<(ProviderContainer, SharedPreferences)> build([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return (container, preferences);
  }

  test('starts empty', () async {
    final (container, _) = await build();
    expect(container.read(paletteRecentsProvider), isEmpty);
  });

  test('the newest is first, and using one again moves it up', () async {
    final (container, _) = await build();
    final recents = container.read(paletteRecentsProvider.notifier);
    recents
      ..record('host:a')
      ..record('host:b')
      ..record('host:a');
    expect(container.read(paletteRecentsProvider), ['host:a', 'host:b']);
  });

  test('is capped, dropping the oldest', () async {
    final (container, _) = await build();
    final recents = container.read(paletteRecentsProvider.notifier);
    for (var i = 0; i < PaletteRecents.cap + 5; i++) {
      recents.record('host:$i');
    }
    final state = container.read(paletteRecentsProvider);
    expect(state, hasLength(PaletteRecents.cap));
    expect(state.first, 'host:${PaletteRecents.cap + 4}');
    expect(state, isNot(contains('host:0')));
    expect(PaletteRecents.cap, 20);
  });

  test('survives a restart through preferences', () async {
    final (container, preferences) = await build();
    container.read(paletteRecentsProvider.notifier)
      ..record('snippet:s')
      ..record('action:newHost');
    expect(preferences.getStringList(PaletteRecents.key), [
      'action:newHost',
      'snippet:s',
    ]);

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(second.dispose);
    expect(second.read(paletteRecentsProvider), [
      'action:newHost',
      'snippet:s',
    ]);
  });

  test('a stored list that is too long or repeats is cleaned', () async {
    final (container, _) = await build({
      PaletteRecents.key: ['a', 'a', '', for (var i = 0; i < 30; i++) 'x$i'],
    });
    final state = container.read(paletteRecentsProvider);
    expect(state.first, 'a');
    expect(state.where((id) => id == 'a'), hasLength(1));
    expect(state, isNot(contains('')));
    expect(state, hasLength(PaletteRecents.cap));
  });
}
