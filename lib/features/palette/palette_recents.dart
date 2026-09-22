import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';

/// The palette items used most recently, newest first — ids only.
///
/// What is stored is an item's id (`host:<row id>`, `action:newHost`) and
/// nothing else: never a label, a hostname, a query or a snippet body. A row
/// id is already in the database beside it; a list of them says what was
/// opened, not what it was called or how to reach it.
///
/// Kept in memory and mirrored to shared preferences, so the order survives a
/// restart. Capped at [cap].
class PaletteRecents extends Notifier<List<String>> {
  static const String key = 'palette.recents';
  static const int cap = 20;

  @override
  List<String> build() {
    final stored = ref.read(sharedPreferencesProvider).getStringList(key);
    if (stored == null) return const [];
    // A hand-edited or older value is trimmed rather than trusted.
    final seen = <String>{};
    return List.unmodifiable(
      [
        for (final id in stored)
          if (id.isNotEmpty && seen.add(id)) id,
      ].take(cap),
    );
  }

  /// Moves [id] to the front, dropping the oldest past [cap].
  void record(String id) {
    final next = [id, ...state.where((existing) => existing != id)];
    state = List.unmodifiable(next.take(cap));
    ref.read(sharedPreferencesProvider).setStringList(key, state);
  }
}

final paletteRecentsProvider = NotifierProvider<PaletteRecents, List<String>>(
  PaletteRecents.new,
);
