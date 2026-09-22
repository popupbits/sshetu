import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'domain/snippet.dart';

/// Every saved snippet, in display order.
final snippetsProvider = FutureProvider<List<Snippet>>(
  (ref) => ref.watch(snippetRepositoryProvider).all(),
);

/// The Snippets screen's search box.
class SnippetSearch extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final snippetSearchProvider = NotifierProvider<SnippetSearch, String>(
  SnippetSearch.new,
);

/// The snippets the search leaves.
final filteredSnippetsProvider = Provider<AsyncValue<List<Snippet>>>((ref) {
  final query = ref.watch(snippetSearchProvider);
  return ref
      .watch(snippetsProvider)
      .whenData((all) => all.where((s) => s.matches(query)).toList());
});

/// Writes, each of which invalidates [snippetsProvider].
class SnippetsController {
  const SnippetsController(this._ref);

  final Ref _ref;

  Future<void> save(Snippet snippet) async {
    await _ref.read(snippetRepositoryProvider).save(snippet);
    _ref.invalidate(snippetsProvider);
  }

  Future<void> delete(Snippet snippet) async {
    await _ref
        .read(snippetRepositoryProvider)
        .delete(snippet.id, now: DateTime.now().toUtc());
    _ref.invalidate(snippetsProvider);
  }

  static final _random = Random.secure();

  /// A new row id, in the same shape the other editors use.
  static String newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      20,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}

final snippetsControllerProvider = Provider<SnippetsController>(
  SnippetsController.new,
);
