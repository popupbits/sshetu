/// Names for the tmux sessions SSHetu keeps on a server.
///
/// A name is `sshetu-<device>-<tab>`: six characters that identify this
/// install and eight that identify one tab, both random.
///
/// **Why both halves.** The first scheme named a session after the tab's id,
/// and tab ids restart at zero every launch — so after a restart a brand new
/// tab could reattach whatever an unrelated tab left running last week, and
/// two devices connected to the same account could share one shell without
/// either of them asking to. Randomness fixes the first; the device half
/// fixes the second and is also what lets "Sessions on this server" say which
/// device started each one.
library;

import 'dart:math';

/// Characters a generated half is drawn from. Lower case and digits only:
/// safe in a tmux target, in a URL, and in a shell word without quoting.
const String _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Length of the per-install half of a session name.
const int kTmuxDeviceIdLength = 6;

/// Length of the per-tab half of a session name.
const int kTmuxTabKeyLength = 8;

/// Every SSHetu session name starts with this.
const String kTmuxNamePrefix = 'sshetu-';

final Random _secure = Random.secure();

/// [length] random characters from a safe alphabet.
///
/// Secure randomness, although nothing here is secret: a predictable name is
/// one another device could collide with by accident, which is the bug this
/// exists to fix.
String randomTmuxToken(int length, {Random? random}) {
  final source = random ?? _secure;
  return List.generate(
    length,
    (_) => _alphabet[source.nextInt(_alphabet.length)],
  ).join();
}

/// Replaces anything tmux would read as part of a target (`.` and `:`), or a
/// shell as syntax, with `_`.
String tmuxSafeName(String name) =>
    name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

/// Whether [name] is safe to use as-is: nothing a target or a shell would
/// interpret, and not so long that a terminal title would be all name.
bool isSafeTmuxName(String name) =>
    RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(name);

/// The session name for the tab [tabKey] on the install [deviceId].
String tmuxSessionName({required String deviceId, required String tabKey}) =>
    '$kTmuxNamePrefix${tmuxSafeName(deviceId)}-${tmuxSafeName(tabKey)}';

/// A fresh name for a new tab on the install [deviceId].
String newTmuxSessionName(String deviceId, {Random? random}) => tmuxSessionName(
  deviceId: deviceId,
  tabKey: randomTmuxToken(kTmuxTabKeyLength, random: random),
);

/// Who started a session, read back out of its name.
sealed class TmuxSessionOrigin {
  const TmuxSessionOrigin();
}

/// A name in the current scheme, from the install [deviceId].
class TmuxFromDevice extends TmuxSessionOrigin {
  const TmuxFromDevice(this.deviceId, this.tabKey);

  final String deviceId;
  final String tabKey;
}

/// An SSHetu session named before names carried a device — so which device
/// started it cannot be known.
class TmuxFromOlderVersion extends TmuxSessionOrigin {
  const TmuxFromOlderVersion();
}

final RegExp _current = RegExp(
  '^$kTmuxNamePrefix([a-z0-9]{$kTmuxDeviceIdLength})-'
  '([a-z0-9]{$kTmuxTabKeyLength})\$',
);

/// Reads [name]'s origin. Null when it is not an SSHetu name at all.
TmuxSessionOrigin? parseTmuxSessionName(String name) {
  if (!name.startsWith(kTmuxNamePrefix)) return null;
  final match = _current.firstMatch(name);
  if (match == null) return const TmuxFromOlderVersion();
  return TmuxFromDevice(match[1]!, match[2]!);
}
