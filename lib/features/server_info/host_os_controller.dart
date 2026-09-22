import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/error_logger.dart';
import '../../core/settings/settings_controller.dart';
import 'data/server_exec.dart';
import 'data/server_info_service.dart';
import 'domain/host_os.dart';

/// The operating system each host was last seen running, by host id.
///
/// In shared preferences rather than the database: it is a cache of
/// something the server will say again on the next connect, not a record
/// worth a migration. Losing it costs a glyph until the next connection.
class HostOsController extends Notifier<Map<String, HostOsInfo>> {
  static const keyPrefix = 'serverInfo.os.';

  /// Hosts asked this run, so reconnects and second tabs do not ask again.
  final Set<String> _asked = {};

  SharedPreferences? _preferences;

  @override
  Map<String, HostOsInfo> build() {
    try {
      _preferences = ref.read(sharedPreferencesProvider);
    } on Object {
      // No preferences (a test that never bootstrapped): an in-memory cache
      // still works for the run.
      _preferences = null;
    }
    final preferences = _preferences;
    if (preferences == null) return const {};
    final cached = <String, HostOsInfo>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(keyPrefix)) continue;
      try {
        final info = HostOsInfo.fromJson(
          jsonDecode(preferences.getString(key) ?? ''),
        );
        if (info != null) cached[key.substring(keyPrefix.length)] = info;
      } on Object {
        // A corrupt entry is skipped, not fatal.
      }
    }
    return cached;
  }

  /// Records [info] for [hostId], in memory and on disk.
  Future<void> remember(String hostId, HostOsInfo info) async {
    if (state[hostId] == info) return;
    state = {...state, hostId: info};
    await _preferences?.setString(
      '$keyPrefix$hostId',
      jsonEncode(info.toJson()),
    );
  }

  /// Forgets [hostId] — for a deleted host.
  Future<void> forget(String hostId) async {
    if (!state.containsKey(hostId)) return;
    state = {...state}..remove(hostId);
    await _preferences?.remove('$keyPrefix$hostId');
  }

  /// Asks [exec] which OS [hostId] runs, once per run per host.
  ///
  /// Best effort and silent: a host that cannot answer keeps whatever was
  /// cached. An unknown answer never overwrites a known one — a host briefly
  /// reached through a restricted shell should not lose its mark.
  Future<void> detect(String hostId, ServerExec exec) async {
    if (!_asked.add(hostId)) return;
    try {
      final info = await ServerInfoService(exec).detectOs();
      if (info.family == OsFamily.unknown && state.containsKey(hostId)) {
        return;
      }
      await remember(hostId, info);
    } on ServerOfflineException {
      _asked.remove(hostId);
    } on Object catch (error, stackTrace) {
      // Allowed to try again next connect.
      _asked.remove(hostId);
      // The link dropping mid-question fails the exec with dartssh2's
      // `SSHStateError(SSH connection closed)`: the connection going
      // offline, which the tab already reports, not something wrong with
      // detection — so it is treated like being offline, not recorded.
      if (!exec.isConnected) return;
      ErrorLogger.instance.record(error, stackTrace, source: 'os-detect');
    }
  }
}

final hostOsProvider =
    NotifierProvider<HostOsController, Map<String, HostOsInfo>>(
      HostOsController.new,
    );
