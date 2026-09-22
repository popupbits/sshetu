import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/palette/domain/fuzzy_match.dart';

void main() {
  int score(String query, String text) => fuzzyMatch(query, text)!.score;

  group('what matches', () {
    test('a subsequence matches, in order only', () {
      expect(fuzzyMatch('pdb', 'production-database'), isNotNull);
      expect(fuzzyMatch('bdp', 'production-database'), isNull);
    });

    test('is case-insensitive both ways', () {
      expect(fuzzyMatch('PROD', 'production'), isNotNull);
      expect(fuzzyMatch('prod', 'PRODUCTION'), isNotNull);
      expect(
        fuzzyMatch('prod', 'Production')!.indices,
        fuzzyMatch('PROD', 'production')!.indices,
      );
    });

    test('whitespace in the query is ignored', () {
      final match = fuzzyMatch('prod db', 'production-database');
      expect(match, isNotNull);
      expect(match!.indices, hasLength(6));
    });

    test('an empty query matches everything with no highlights', () {
      final match = fuzzyMatch('  ', 'anything');
      expect(match, isNotNull);
      expect(match!.score, 0);
      expect(match.indices, isEmpty);
    });

    test('a query longer than the text cannot match', () {
      expect(fuzzyMatch('longer', 'long'), isNull);
    });

    test('a missing character is no match', () {
      expect(fuzzyMatch('xyz', 'production'), isNull);
    });
  });

  group('highlights', () {
    test('mark the characters the query used, ascending', () {
      expect(fuzzyMatch('ab', 'xaxb')!.indices, [1, 3]);
    });

    test('prefer word starts over the first occurrence', () {
      // Greedy matching would take the "d" in "production"; the word start
      // of "database" is the better placement.
      expect(fuzzyMatch('pd', 'production-database')!.indices, [0, 11]);
    });

    test('prefer a consecutive run over scattered letters', () {
      // "log" appears scattered mid-word early and whole later.
      expect(fuzzyMatch('log', 'lxoxgx logs')!.indices, [7, 8, 9]);
    });

    test('but scattered word starts can outweigh a run', () {
      // Each letter here starts a word, which is worth more than adjacency.
      expect(fuzzyMatch('log', 'l-o-g-logs')!.indices, [0, 2, 4]);
    });

    test('are one per query character', () {
      final match = fuzzyMatch('tail', 'Tail logs')!;
      expect(match.indices, [0, 1, 2, 3]);
    });
  });

  group('ranking', () {
    test('a prefix beats the same letters later on', () {
      expect(score('web', 'web-01'), greaterThan(score('web', 'my-web-01')));
    });

    test('a word start beats a mid-word match', () {
      expect(score('db', 'prod-db'), greaterThan(score('db', 'oddball')));
    });

    test('consecutive characters beat scattered ones', () {
      expect(score('key', 'keys'), greaterThan(score('key', 'kaeay')));
    });

    test('camelCase humps count as word starts', () {
      expect(score('gk', 'generateKey'), greaterThan(score('gk', 'genekey')));
    });

    test('the shorter of two equal matches wins', () {
      expect(
        score('keys', 'Keys'),
        greaterThan(score('keys', 'Keys and certificates')),
      );
    });

    test('the weights are what the prefix bonus says', () {
      // One character, at the start: match + word start + prefix.
      expect(
        score('a', 'a'),
        FuzzyWeights.match + FuzzyWeights.wordStart + FuzzyWeights.prefix,
      );
    });
  });
}
