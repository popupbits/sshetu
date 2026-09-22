import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../terminal/tmux_names.dart';
import 'settings_controller.dart';

const _keyDeviceId = 'device.tmuxId';

/// This install's short random id, made the first time it is asked for and
/// kept from then on.
///
/// It is the first half of every tmux session name this device creates
/// (`sshetu-<device>-<tab>`), which is what keeps two devices on one account
/// from ever sharing a session by accident, and what lets the server's
/// session list say "this device" about the right ones.
///
/// In preferences, not the keychain or the database: it is not a secret — it
/// is written in plain sight on every server this device connects to — and it
/// must *not* travel in a transfer or a backup. A phone that took the
/// desktop's id would take its sessions with it.
String readOrCreateDeviceId(SharedPreferences preferences) {
  String? stored;
  try {
    stored = preferences.getString(_keyDeviceId);
  } on Object {
    stored = null;
  }
  if (stored != null &&
      RegExp('^[a-z0-9]{$kTmuxDeviceIdLength}\$').hasMatch(stored)) {
    return stored;
  }
  final created = randomTmuxToken(kTmuxDeviceIdLength);
  // Not awaited: the in-memory copy updates at once, and a write that fails
  // costs only a new id next launch — sessions from this run then list as
  // "another device", which is recoverable, not wrong.
  preferences.setString(_keyDeviceId, created).ignore();
  return created;
}

/// This install's id. See [readOrCreateDeviceId].
final deviceIdProvider = Provider<String>((ref) {
  try {
    return readOrCreateDeviceId(ref.watch(sharedPreferencesProvider));
  } on Object {
    // No preferences installed — a test that never asked for them. An id for
    // this run only is the honest answer there.
    return _ephemeralId;
  }
});

final String _ephemeralId = randomTmuxToken(kTmuxDeviceIdLength);
