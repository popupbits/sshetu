import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sshetu/features/files/domain/browse_path.dart';

void main() {
  // Remote paths are always POSIX regardless of what OS this app runs on, so
  // these use `p.posix` explicitly rather than `p.context` — the whole point
  // of `BrowsePath` taking an explicit context is that these assertions must
  // not depend on the machine running the test suite.
  group('remote (POSIX) navigation', () {
    final nav = BrowsePath(p.posix);

    test('up() from the root is idempotent', () {
      // The bug this guards against: a naive dirname('/') can misbehave, and
      // a browser that lets the user walk "above" the filesystem root has
      // nowhere sensible to show.
      expect(nav.up('/'), '/');
    });

    test('up() walks to the immediate parent', () {
      expect(nav.up('/var/log/nginx'), '/var/log');
      expect(nav.up('/var/log'), '/var');
      expect(nav.up('/var'), '/');
    });

    test('isRoot is true only at the root', () {
      expect(nav.isRoot('/'), isTrue);
      expect(nav.isRoot('/var'), isFalse);
    });

    test('ancestry from root lists just the root', () {
      expect(nav.ancestry('/'), ['/']);
    });

    test(
      'ancestry breadcrumbs every level from root to the current directory',
      () {
        expect(nav.ancestry('/var/log/nginx'), [
          '/',
          '/var',
          '/var/log',
          '/var/log/nginx',
        ]);
      },
    );

    test('label shows the root itself, and the basename elsewhere', () {
      expect(nav.label('/'), '/');
      expect(nav.label('/var/log'), 'log');
    });

    test('join composes a child path under a directory', () {
      expect(nav.join('/var/log', 'nginx'), '/var/log/nginx');
    });

    group('looksNavigable (path entry)', () {
      test('an absolute path is navigable', () {
        expect(nav.looksNavigable('/var/log'), isTrue);
      });

      test('a bare relative fragment is rejected', () {
        // The bug this guards against: with two panes on screen, resolving
        // "build/output" against "whichever directory happens to be open" is
        // a silent guess a typo could send somewhere the user never meant.
        expect(nav.looksNavigable('build/output'), isFalse);
        expect(nav.looksNavigable('relative'), isFalse);
      });

      test('~ alone and ~/rest are navigable', () {
        expect(nav.looksNavigable('~'), isTrue);
        expect(nav.looksNavigable('~/projects'), isTrue);
      });

      test('a tilde not followed by a slash is not the shorthand', () {
        // "~foo" names another user's home in a real shell (`~foo` expands
        // via getpwnam), which this app cannot resolve — treating it as
        // relative and rejecting it is honest; silently mangling it into
        // something else would not be.
        expect(nav.looksNavigable('~foo'), isFalse);
      });

      test('blank input is not navigable', () {
        expect(nav.looksNavigable(''), isFalse);
        expect(nav.looksNavigable('   '), isFalse);
      });
    });
  });

  // A local pane on Windows gets a drive letter root, not '/' — `p.windows`
  // pins that case down without needing to run this suite on Windows.
  group('local (Windows) navigation', () {
    final nav = BrowsePath(p.windows);

    test('the root is the drive prefix, not the filesystem root', () {
      expect(nav.up(r'C:\Users\me'), r'C:\Users');
      expect(nav.up(r'C:\Users'), r'C:\');
    });

    test('up() from the drive root is idempotent', () {
      expect(nav.up(r'C:\'), r'C:\');
    });

    test('ancestry starts at the drive root', () {
      expect(nav.ancestry(r'C:\Users\me\Documents'), [
        r'C:\',
        r'C:\Users',
        r'C:\Users\me',
        r'C:\Users\me\Documents',
      ]);
    });
  });
}
