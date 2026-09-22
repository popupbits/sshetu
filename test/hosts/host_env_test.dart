import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/domain/host_env.dart';

void main() {
  group('stored form', () {
    test('round-trips, in order', () {
      const env = {'Z': 'last', 'A': 'it\'s "\$HOME"', 'EMPTY': ''};
      final stored = HostEnv.encode(env)!;
      expect(HostEnv.parse(stored), env);
      expect(HostEnv.parse(stored).keys, ['Z', 'A', 'EMPTY']);
    });

    test('none is NULL, like a host from before variables existed', () {
      expect(HostEnv.encode(const {}), isNull);
      expect(HostEnv.parse(null), isEmpty);
      expect(HostEnv.parse(''), isEmpty);
    });

    test('a bad row degrades to what is valid, never throws', () {
      expect(HostEnv.parse('{not json'), isEmpty);
      expect(HostEnv.parse('["a"]'), isEmpty);
      expect(HostEnv.parse('{"OK":"1","1BAD":"x","N":2,"NL":"a\\nb"}'), {
        'OK': '1',
      });
    });
  });

  group('editor validation', () {
    EnvVarProblem? problem(List<(String, String)> pairs, int index) =>
        HostEnv.problemAt(pairs, index);

    test('a valid name', () {
      expect(problem([('EDITOR', 'vim')], 0), isNull);
      expect(problem([('_x9', '')], 0), isNull);
    });

    test('names follow ^[A-Za-z_][A-Za-z0-9_]*\$', () {
      for (final bad in ['1A', 'A-B', 'A B', 'É', r'$X', 'A=B']) {
        expect(
          problem([(bad, 'v')], 0),
          EnvVarProblem.invalidName,
          reason: bad,
        );
      }
    });

    test('an empty row is not a problem; a value with no name is', () {
      expect(problem([('', '')], 0), isNull);
      expect(problem([('  ', 'x')], 0), EnvVarProblem.missingName);
    });

    test('the second of a duplicate is the one flagged', () {
      final pairs = [('A', '1'), ('B', '2'), (' A ', '3')];
      expect(problem(pairs, 0), isNull);
      expect(problem(pairs, 2), EnvVarProblem.duplicateName);
    });

    test('a line break in a value is refused', () {
      expect(problem([('A', 'x\ny')], 0), EnvVarProblem.invalidValue);
      expect(problem([('A', 'x\ry')], 0), EnvVarProblem.invalidValue);
    });

    test('saving trims names, keeps values, drops empty rows', () {
      expect(HostEnv.fromPairs([(' A ', ' spaced '), ('', ''), ('B', '')]), {
        'A': ' spaced ',
        'B': '',
      });
    });
  });
}
