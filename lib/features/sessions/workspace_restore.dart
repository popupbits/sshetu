import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/terminal/tmux_names.dart';

/// One terminal tab as it is remembered between launches.
class SavedTab {
  const SavedTab({required this.hostId, this.tmuxName, this.ownsTmux = true});

  final String hostId;

  /// The tmux session the tab lived in, or null for a plain shell — which has
  /// nothing on the server to come back to, and reopens as a new one.
  final String? tmuxName;

  /// False for a session the tab attached from the server's list rather than
  /// started; reopening keeps it borrowed, so closing still leaves it running.
  final bool ownsTmux;

  Map<String, Object?> toJson() => {
    'host': hostId,
    if (tmuxName != null) 'tmux': tmuxName,
    if (!ownsTmux) 'owns': false,
  };

  /// Null for anything malformed. A tmux name that is not safe to put in a
  /// command is dropped rather than trusted — preferences are a file on disk.
  static SavedTab? fromJson(Object? json) {
    if (json is! Map) return null;
    final host = json['host'];
    if (host is! String || host.isEmpty) return null;
    final tmux = json['tmux'];
    return SavedTab(
      hostId: host,
      tmuxName: tmux is String && isSafeTmuxName(tmux) ? tmux : null,
      ownsTmux: json['owns'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SavedTab &&
      other.hostId == hostId &&
      other.tmuxName == tmuxName &&
      other.ownsTmux == ownsTmux;

  @override
  int get hashCode => Object.hash(hostId, tmuxName, ownsTmux);

  @override
  String toString() => 'SavedTab($hostId, $tmuxName)';
}

/// The terminal tabs open when the app last changed them, in order, and
/// which was selected.
///
/// Terminal tabs only. A host editor or a file browser left open is not
/// something to reconnect to, and reopening half-finished forms at launch
/// would be clutter, not continuity.
class SavedWorkspace {
  const SavedWorkspace({required this.tabs, this.selected});

  final List<SavedTab> tabs;

  /// Index into [tabs], or null.
  final int? selected;

  bool get isEmpty => tabs.isEmpty;

  static const int _version = 1;

  Map<String, Object?> toJson() => {
    'v': _version,
    'tabs': [for (final tab in tabs) tab.toJson()],
    if (selected != null) 'selected': selected,
  };

  /// Null for anything unreadable, including a version this build does not
  /// know — a newer build's workspace is not worth guessing at.
  static SavedWorkspace? fromJson(Object? json) {
    if (json is! Map || json['v'] != _version) return null;
    final rawTabs = json['tabs'];
    if (rawTabs is! List) return null;
    final tabs = [for (final raw in rawTabs) ?SavedTab.fromJson(raw)];
    final selected = json['selected'];
    return SavedWorkspace(
      tabs: tabs,
      selected: selected is int && selected >= 0 && selected < tabs.length
          ? selected
          : null,
    );
  }
}

/// Where the workspace is kept between launches.
///
/// **Preferences, not a table.** Three reasons. It belongs to this install:
/// the tmux names in it start with this device's id, so it must not travel
/// in a transfer or a backup, which carry the database. It needs no
/// integrity with the hosts table — hosts are tombstoned, not deleted, so a
/// foreign key would never fire; a tab for a deleted host is simply dropped
/// when the plan is made. And it is one small value rewritten whole, which is
/// what preferences are for.
class WorkspaceStore {
  WorkspaceStore(this._preferences);

  /// Null in a test that installed none: reads find nothing, writes vanish.
  final SharedPreferences? _preferences;

  static const String key = 'workspace.tabs';

  SavedWorkspace? read() {
    final preferences = _preferences;
    if (preferences == null) return null;
    try {
      final raw = preferences.getString(key);
      if (raw == null) return null;
      return SavedWorkspace.fromJson(jsonDecode(raw));
    } on Object {
      // Corrupt, or a value of another type: as if nothing were saved.
      return null;
    }
  }

  Future<void> write(SavedWorkspace workspace) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      if (workspace.isEmpty) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, jsonEncode(workspace.toJson()));
      }
    } on Object {
      // Losing the workspace costs a relaunch its tabs, nothing more.
    }
  }
}

final workspaceStoreProvider = Provider<WorkspaceStore>((ref) {
  try {
    return WorkspaceStore(ref.watch(sharedPreferencesProvider));
  } on Object {
    return WorkspaceStore(null);
  }
});

/// What reopening will actually do, worked out before anything connects.
class RestorePlan {
  const RestorePlan({required this.tabs, this.selected, this.dropped = 0});

  /// In their saved order.
  final List<SavedTab> tabs;

  /// Index into [tabs] to select once they are open.
  final int? selected;

  /// Tabs left out because their host has been deleted since.
  final int dropped;

  bool get isEmpty => tabs.isEmpty;
}

/// Plans reopening [saved] against the hosts that still exist.
///
/// A tab whose host was deleted since is dropped: there is nothing to
/// connect it to. The selection follows its tab; if that tab was dropped, it
/// falls to the nearest surviving tab before it — the one that would have
/// been selected had it been closed — or the first.
RestorePlan planRestore(SavedWorkspace saved, Set<String> liveHostIds) {
  final kept = <SavedTab>[];
  int? selected;
  for (final (index, tab) in saved.tabs.indexed) {
    if (!liveHostIds.contains(tab.hostId)) {
      if (index == saved.selected && kept.isNotEmpty) {
        selected = kept.length - 1;
      }
      continue;
    }
    if (index == saved.selected) selected = kept.length;
    kept.add(tab);
  }
  if (selected == null && saved.selected != null && kept.isNotEmpty) {
    selected = 0;
  }
  return RestorePlan(
    tabs: kept,
    selected: selected,
    dropped: saved.tabs.length - kept.length,
  );
}

/// Opens a plan's tabs, strictly one after another.
///
/// **One at a time, never a stampede.** [open] runs the whole connect flow
/// for a tab — host key, password, "use a key instead" — and the next does
/// not begin until it has finished. Five tabs to five servers must not put
/// five password dialogs on screen at once, each one hiding which server it
/// is asking about.
///
/// [open] returns the new tab's id, or null when it did not open (cancelled,
/// refused). A failure on one tab does not stop the rest.
Future<List<String?>> runRestore(
  RestorePlan plan, {
  required Future<String?> Function(SavedTab tab) open,
  bool Function()? cancelled,
}) async {
  final ids = <String?>[];
  for (final tab in plan.tabs) {
    if (cancelled?.call() ?? false) break;
    try {
      ids.add(await open(tab));
    } on Object {
      ids.add(null);
    }
  }
  return ids;
}
