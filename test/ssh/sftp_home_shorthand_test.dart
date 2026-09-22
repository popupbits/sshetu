import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/sftp_service.dart';

/// `~` in a typed remote path. SFTP's REALPATH does not expand it — OpenSSH
/// resolves `~/x` as a directory literally named `~` — so the client has to,
/// using the session's starting directory as home. Found on a device: typing
/// `~/dir` into the path bar went nowhere against a real OpenSSH server while
/// the fake, which expanded `~` itself, passed.
void main() {
  group('isRemoteHomeShorthand', () {
    test('recognises ~ and ~/…', () {
      expect(isRemoteHomeShorthand('~'), isTrue);
      expect(isRemoteHomeShorthand('~/'), isTrue);
      expect(isRemoteHomeShorthand('~/projects'), isTrue);
    });

    test('leaves everything else alone', () {
      expect(isRemoteHomeShorthand('/home/me'), isFalse);
      expect(isRemoteHomeShorthand('~other'), isFalse);
      expect(isRemoteHomeShorthand('a/~/b'), isFalse);
      expect(isRemoteHomeShorthand(''), isFalse);
    });
  });

  group('expandHomeShorthand', () {
    test('~ alone is home', () {
      expect(expandHomeShorthand('~', '/home/me'), '/home/me');
      expect(expandHomeShorthand('~/', '/home/me'), '/home/me');
    });

    test('~/rest is joined onto home', () {
      expect(expandHomeShorthand('~/ssx-qa', '/home/me'), '/home/me/ssx-qa');
      expect(expandHomeShorthand('~//a/b', '/home/me'), '/home/me/a/b');
    });

    test('a root home does not double the slash', () {
      expect(expandHomeShorthand('~/etc', '/'), '/etc');
    });

    test('non-shorthand paths are returned unchanged', () {
      expect(expandHomeShorthand('/var/log', '/home/me'), '/var/log');
      expect(expandHomeShorthand('~other/x', '/home/me'), '~other/x');
    });
  });
}
