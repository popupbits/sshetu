import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/domain/host_tags.dart';

/// Tags live in one comma-separated column, so what goes in must come back
/// out as the same tags — no splits, no blanks, no near-duplicates.
void main() {
  group('sanitize', () {
    test('trims and collapses whitespace', () {
      expect(HostTags.sanitize('  web   server '), 'web server');
    });

    test('a comma can never survive into a tag', () {
      // It would come back out of the column as two tags.
      expect(HostTags.sanitize('eu,west'), 'eu west');
    });

    test('nothing usable is null, not an empty tag', () {
      expect(HostTags.sanitize('   '), isNull);
      expect(HostTags.sanitize(','), isNull);
    });

    test('is capped in length', () {
      final long = 'x' * 100;
      expect(HostTags.sanitize(long)!.length, HostTags.maxLength);
    });
  });

  group('normalize', () {
    test('drops duplicates case-insensitively, first spelling wins', () {
      expect(HostTags.normalize(['Prod', 'prod ', 'PROD', 'eu']), [
        'Prod',
        'eu',
      ]);
    });

    test('drops empties', () {
      expect(HostTags.normalize(['', ' ', 'db']), ['db']);
    });
  });

  group('parse and join', () {
    test('round-trip through the column', () {
      final stored = HostTags.join(['prod', 'eu west', 'db']);
      expect(stored, 'prod,eu west,db');
      expect(HostTags.parse(stored), ['prod', 'eu west', 'db']);
    });

    test('no tags is null in the column and empty out of it', () {
      expect(HostTags.join(const []), isNull);
      expect(HostTags.join(['  ']), isNull);
      expect(HostTags.parse(null), isEmpty);
      expect(HostTags.parse(''), isEmpty);
    });

    test('a hand-edited column with stray commas reads cleanly', () {
      expect(HostTags.parse(',prod,, eu ,prod,'), ['prod', 'eu']);
    });

    test('commas typed by the user split into separate tags', () {
      expect(HostTags.parse('a, b ,c'), ['a', 'b', 'c']);
    });
  });

  test('union is every distinct tag, sorted', () {
    expect(
      HostTags.union([
        ['web', 'Prod'],
        ['prod', 'db'],
        [],
      ]),
      ['db', 'Prod', 'web'],
    );
  });
}
