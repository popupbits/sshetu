import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'domain/host_group.dart';
import 'domain/host_sections.dart';
import 'domain/host_tags.dart';
import 'domain/ssh_host.dart';

/// Every saved host, most recently used first.
///
/// A plain [FutureProvider] rather than a stream: hosts change only when the
/// user changes them, and invalidating after a write is simpler to follow than
/// a database change-feed nobody else needs.
final hostsProvider = FutureProvider<List<SshHost>>(
  (ref) => ref.watch(hostRepositoryProvider).all(),
);

/// Every host group, in display order.
final hostGroupsProvider = FutureProvider<List<HostGroup>>(
  (ref) => ref.watch(hostGroupRepositoryProvider).all(),
);

/// The host list's search box.
///
/// A [Notifier] rather than the old `StateProvider`, which Riverpod 3 removed.
class HostSearch extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final hostSearchProvider = NotifierProvider<HostSearch, String>(HostSearch.new);

/// The tags the host list is narrowed to. Empty means no tag filter.
class HostTagFilter extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String tag) {
    final lower = tag.toLowerCase();
    final selected = state.any((t) => t.toLowerCase() == lower);
    state = selected
        ? {...state.where((t) => t.toLowerCase() != lower)}
        : {...state, tag};
  }

  void clear() => state = const {};
}

final hostTagFilterProvider = NotifierProvider<HostTagFilter, Set<String>>(
  HostTagFilter.new,
);

/// Which group sections are folded shut, by [HostSection.key].
///
/// For this run of the app only. Whether a folder is open is a glance-level
/// preference, and remembering it across launches is more machinery than the
/// question deserves.
class CollapsedHostGroups extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String key) => state = state.contains(key)
      ? {...state.where((k) => k != key)}
      : {...state, key};
}

final collapsedHostGroupsProvider =
    NotifierProvider<CollapsedHostGroups, Set<String>>(CollapsedHostGroups.new);

/// Every tag in use across the saved hosts, for the filter row.
final hostTagsProvider = Provider<List<String>>((ref) {
  final hosts = ref.watch(hostsProvider).value ?? const <SshHost>[];
  return HostTags.union(hosts.map((h) => h.tags));
});

/// Hosts matching the current search and tag filter.
final filteredHostsProvider = Provider<AsyncValue<List<SshHost>>>((ref) {
  final query = ref.watch(hostSearchProvider);
  final tags = ref.watch(hostTagFilterProvider);
  return ref
      .watch(hostsProvider)
      .whenData(
        (hosts) => hosts
            .where((h) => h.matches(query) && hasAllTags(h, tags))
            .toList(),
      );
});

/// The filtered hosts, split into group sections.
///
/// A group list that fails to load degrades to an ungrouped list rather than
/// an error screen: folders are organisation, and losing them must not hide
/// the servers themselves.
final hostSectionsProvider = Provider<AsyncValue<List<HostSection>>>((ref) {
  final hosts = ref.watch(filteredHostsProvider);
  final groups = ref.watch(hostGroupsProvider);
  if (groups.isLoading && !groups.hasValue) {
    return const AsyncLoading<List<HostSection>>();
  }
  final filtering =
      ref.watch(hostSearchProvider).isNotEmpty ||
      ref.watch(hostTagFilterProvider).isNotEmpty;
  return hosts.whenData(
    (list) => sectionHosts(
      list,
      groups.value ?? const [],
      includeEmptyGroups: !filtering,
    ),
  );
});

/// Writes, each of which invalidates what it changed.
class HostsController {
  const HostsController(this._ref);

  final Ref _ref;

  Future<void> save(SshHost host) async {
    await _ref.read(hostRepositoryProvider).save(host);
    // The write can outlive whoever asked for it (a test that has already
    // torn its container down); a disposed ref cannot invalidate, and there
    // is nothing left to refresh.
    if (!_ref.mounted) return;
    _ref.invalidate(hostsProvider);
  }

  Future<void> saveAll(List<SshHost> hosts) async {
    await _ref.read(hostRepositoryProvider).saveAll(hosts);
    if (!_ref.mounted) return;
    _ref.invalidate(hostsProvider);
  }

  /// Deletes the host, then refreshes the list **whatever happened**.
  ///
  /// The row is tombstoned before the vault is touched, so by the time a
  /// credential store refuses to erase the material the deletion has already
  /// happened. Letting that refusal skip the refresh left the host on screen
  /// until the app was restarted — the user had deleted it, the database
  /// agreed, and only the list disagreed.
  ///
  /// The error is still thrown, because "SSHetu has forgotten this host but
  /// the keychain would not erase it" is something the person deleting a saved password deserves to be told.
  Future<void> delete(String id) async {
    try {
      await _ref
          .read(hostRepositoryProvider)
          .delete(id, now: DateTime.now().toUtc());
    } finally {
      _ref.invalidate(hostsProvider);
    }
  }

  /// Creates a group called [name], last in order, and returns it.
  Future<HostGroup> createGroup(String name) async {
    final repository = _ref.read(hostGroupRepositoryProvider);
    final now = DateTime.now().toUtc();
    final group = HostGroup(
      id: _newId(),
      name: name.trim(),
      sortOrder: await repository.nextSortOrder(),
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(group);
    _ref.invalidate(hostGroupsProvider);
    return group;
  }

  Future<void> renameGroup(HostGroup group, String name) async {
    await _ref
        .read(hostGroupRepositoryProvider)
        .save(
          group.copyWith(name: name.trim(), updatedAt: DateTime.now().toUtc()),
        );
    _ref.invalidate(hostGroupsProvider);
  }

  /// Deletes the group. Its hosts move to ungrouped; none are deleted.
  Future<void> deleteGroup(String id) async {
    try {
      await _ref
          .read(hostGroupRepositoryProvider)
          .delete(id, now: DateTime.now().toUtc());
    } finally {
      _ref
        ..invalidate(hostGroupsProvider)
        ..invalidate(hostsProvider);
    }
  }

  static final _random = Random.secure();

  static String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      20,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}

final hostsControllerProvider = Provider<HostsController>(HostsController.new);
