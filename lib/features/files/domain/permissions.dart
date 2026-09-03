/// POSIX mode formatting and editing for `RemoteEntry.permissions` — the
/// `st_mode` word SFTP hands back, file-type bits and permission bits packed
/// into the same integer the way `stat(2)` reports it.
///
/// Kept dependency-free (no dartssh2 import) on purpose: this is display and
/// editing logic, not wire logic, and a widget test or a plain unit test
/// should not need an SFTP type in scope to check that 0755 prints as
/// `rwxr-xr-x`.
library;

const _typeMask = 0xF000;
const _dirType = 0x4000;
const _linkType = 0xA000;
const _fifoType = 0x1000;
const _socketType = 0xC000;
const _blockType = 0x6000;
const _charType = 0x2000;

/// The permission bits only — the low 9 bits of a POSIX mode, the part a
/// `chmod` call actually changes. Everything above bit 8 (file type, setuid,
/// sticky, ...) is metadata this editor does not touch.
int permissionBitsOf(int mode) => mode & 0x1FF;

/// The `drwxr-xr-x` string `ls -l` would print for [mode] — the type
/// character from the high bits, then user/group/other read-write-execute
/// from the low 9. Setuid/setgid/sticky are deliberately not rendered as
/// `s`/`t`: this is a chmod editor for ordinary files and directories, not a
/// security audit tool, and a permissions column that suddenly grows an `s`
/// nobody asked to set is more confusing than showing the plain `x` under it.
String formatPermissions(int mode) {
  final buffer = StringBuffer(_typeChar(mode));
  for (final shift in [6, 3, 0]) {
    final bits = (mode >> shift) & 0x7;
    buffer
      ..write(bits & 0x4 != 0 ? 'r' : '-')
      ..write(bits & 0x2 != 0 ? 'w' : '-')
      ..write(bits & 0x1 != 0 ? 'x' : '-');
  }
  return buffer.toString();
}

String _typeChar(int mode) => switch (mode & _typeMask) {
  _dirType => 'd',
  _linkType => 'l',
  _fifoType => 'p',
  _socketType => 's',
  _blockType => 'b',
  _charType => 'c',
  _ => '-',
};

/// The nine read/write/execute checkboxes a chmod editor shows, and the
/// octal string that is the same information written the other way — kept as
/// one immutable value so the checkbox grid and the octal text field the
/// editor also offers can never independently disagree about what the mode
/// actually is.
class PermissionBits {
  const PermissionBits({
    required this.ownerRead,
    required this.ownerWrite,
    required this.ownerExecute,
    required this.groupRead,
    required this.groupWrite,
    required this.groupExecute,
    required this.otherRead,
    required this.otherWrite,
    required this.otherExecute,
  });

  factory PermissionBits.fromMode(int mode) {
    final bits = permissionBitsOf(mode);
    return PermissionBits.fromValue(bits);
  }

  /// [value] is the low 9 bits only (0-511) — the same range as
  /// [permissionBitsOf], so a caller can round-trip through [value] without
  /// ever seeing a stray file-type bit reappear.
  factory PermissionBits.fromValue(int value) => PermissionBits(
    ownerRead: value & 0x100 != 0,
    ownerWrite: value & 0x080 != 0,
    ownerExecute: value & 0x040 != 0,
    groupRead: value & 0x020 != 0,
    groupWrite: value & 0x010 != 0,
    groupExecute: value & 0x008 != 0,
    otherRead: value & 0x004 != 0,
    otherWrite: value & 0x002 != 0,
    otherExecute: value & 0x001 != 0,
  );

  final bool ownerRead;
  final bool ownerWrite;
  final bool ownerExecute;
  final bool groupRead;
  final bool groupWrite;
  final bool groupExecute;
  final bool otherRead;
  final bool otherWrite;
  final bool otherExecute;

  int get value =>
      (ownerRead ? 0x100 : 0) |
      (ownerWrite ? 0x080 : 0) |
      (ownerExecute ? 0x040 : 0) |
      (groupRead ? 0x020 : 0) |
      (groupWrite ? 0x010 : 0) |
      (groupExecute ? 0x008 : 0) |
      (otherRead ? 0x004 : 0) |
      (otherWrite ? 0x002 : 0) |
      (otherExecute ? 0x001 : 0);

  /// `755`, `644` — the form every chmod command line and every server admin
  /// actually thinks in, padded to three digits so `4` never displays where
  /// `004` was meant.
  String get octal => value.toRadixString(8).padLeft(3, '0');

  PermissionBits copyWith({
    bool? ownerRead,
    bool? ownerWrite,
    bool? ownerExecute,
    bool? groupRead,
    bool? groupWrite,
    bool? groupExecute,
    bool? otherRead,
    bool? otherWrite,
    bool? otherExecute,
  }) => PermissionBits(
    ownerRead: ownerRead ?? this.ownerRead,
    ownerWrite: ownerWrite ?? this.ownerWrite,
    ownerExecute: ownerExecute ?? this.ownerExecute,
    groupRead: groupRead ?? this.groupRead,
    groupWrite: groupWrite ?? this.groupWrite,
    groupExecute: groupExecute ?? this.groupExecute,
    otherRead: otherRead ?? this.otherRead,
    otherWrite: otherWrite ?? this.otherWrite,
    otherExecute: otherExecute ?? this.otherExecute,
  );

  @override
  bool operator ==(Object other) =>
      other is PermissionBits && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Parses a typed octal string (`"755"`, `"0644"`) back into [PermissionBits]
/// — the other half of the round trip the checkbox grid and the text field
/// both feed. Returns null for anything that is not 1-4 octal digits or that
/// encodes a bit above the permission range, so an editor can reject a
/// keystroke instead of silently clamping it to something the user did not
/// type.
PermissionBits? parseOctalPermissions(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || trimmed.length > 4) return null;
  final value = int.tryParse(trimmed, radix: 8);
  if (value == null || value < 0 || value > 0x1FF) return null;
  return PermissionBits.fromValue(value);
}
