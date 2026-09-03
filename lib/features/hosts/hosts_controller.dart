import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'domain/ssh_host.dart';

/// Every saved host, most recently used first.
///
/// A plain [FutureProvider] rather than a stream: hosts change only when the
/// user changes them, and invalidating after a write is simpler to follow than
/// a database change-feed nobody else needs.
final hostsProvider = FutureProvider<List<SshHost>>(
  (ref) => ref.watch(hostRepositoryProvider).all(),
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

/// Hosts matching the current search.
final filteredHostsProvider = Provider<AsyncValue<List<SshHost>>>((ref) {
  final query = ref.watch(hostSearchProvider);
  return ref
      .watch(hostsProvider)
      .whenData((hosts) => hosts.where((h) => h.matches(query)).toList());
});

/// Writes, each of which invalidates [hostsProvider].
class HostsController {
  const HostsController(this._ref);

  final Ref _ref;

  Future<void> save(SshHost host) async {
    await _ref.read(hostRepositoryProvider).save(host);
    _ref.invalidate(hostsProvider);
  }

  Future<void> saveAll(List<SshHost> hosts) async {
    await _ref.read(hostRepositoryProvider).saveAll(hosts);
    _ref.invalidate(hostsProvider);
  }

  Future<void> delete(String id) async {
    await _ref
        .read(hostRepositoryProvider)
        .delete(id, now: DateTime.now().toUtc());
    _ref.invalidate(hostsProvider);
  }
}

final hostsControllerProvider = Provider<HostsController>(HostsController.new);
