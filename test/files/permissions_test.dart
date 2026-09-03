import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/features/files/domain/permissions.dart';

void main() {
  group('formatPermissions', () {
    test('0755 on a regular file renders rwxr-xr-x with a - type', () {
      // The exact string `ls -l` and every SFTP client already print — a
      // permissions column that does not match what a terminal shows next
      // to it would be its own kind of confusing.
      expect(formatPermissions(0x8000 | 0x1ED), '-rwxr-xr-x');
    });

    test('0644 on a regular file renders rw-r--r--', () {
      expect(formatPermissions(0x8000 | 0x1A4), '-rw-r--r--');
    });

    test('a directory gets the d type character', () {
      // The bug this guards against: reusing the file-type switch from
      // `dart:io` (which has no directory bit in the same position) would
      // silently print '-' for every folder.
      expect(formatPermissions(0x4000 | 0x1ED), 'drwxr-xr-x');
    });

    test('a symlink gets the l type character', () {
      expect(formatPermissions(0xA000 | 0x1FF), 'lrwxrwxrwx');
    });

    test('0000 is all dashes past the type character', () {
      expect(formatPermissions(0x8000), '----------');
    });
  });

  group('PermissionBits <-> octal round trip', () {
    test('fromMode extracts only the low 9 bits, ignoring file-type bits', () {
      // The bug this guards against: `RemoteEntry.permissions` is a full
      // `st_mode` word with file-type bits packed in above the permission
      // bits. A chmod editor that read those bits back as part of the value
      // would show impossible octal like "40755" instead of "755", and could
      // send the type bits back to the server as part of a `setStat` call.
      final bits = PermissionBits.fromMode(0x4000 | 0x1ED); // directory + 755
      expect(bits.value, 0x1ED);
      expect(bits.octal, '755');
    });

    test('every checkbox maps to its documented octal digit', () {
      const bits = PermissionBits(
        ownerRead: true,
        ownerWrite: true,
        ownerExecute: true,
        groupRead: true,
        groupWrite: false,
        groupExecute: true,
        otherRead: false,
        otherWrite: false,
        otherExecute: true,
      );
      expect(bits.octal, '751');
    });

    test('octal 000 pads to three digits, not "0"', () {
      expect(PermissionBits.fromValue(0).octal, '000');
    });

    test('parsing a typed octal string reproduces the same bits', () {
      // The round trip the checkbox grid and the octal field both feed: a
      // value written one way and read back the other way must be identical,
      // or the two controls in the chmod editor would visibly disagree.
      final original = PermissionBits.fromValue(0x1ED);
      final parsed = parseOctalPermissions(original.octal);
      expect(parsed, original);
    });

    test('a leading zero is accepted the way chmod accepts it', () {
      expect(parseOctalPermissions('0644')?.value, 0x1A4);
    });

    test('an out-of-range or non-octal string is rejected, not clamped', () {
      // The bug this guards against: silently clamping "999" to something
      // plausible would apply a mode the user never actually typed.
      expect(parseOctalPermissions('999'), isNull);
      expect(parseOctalPermissions('abc'), isNull);
      expect(parseOctalPermissions(''), isNull);
      expect(parseOctalPermissions('77777'), isNull);
    });

    test('copyWith flips exactly the bit asked for', () {
      final bits = PermissionBits.fromValue(0x1ED); // 755
      final updated = bits.copyWith(otherWrite: true);
      expect(updated.octal, '757');
      // Every other bit is untouched.
      expect(updated.ownerRead, bits.ownerRead);
      expect(updated.groupExecute, bits.groupExecute);
    });
  });
}
