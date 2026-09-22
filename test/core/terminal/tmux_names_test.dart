import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/tmux_names.dart';

void main() {
  group('session names', () {
    test('are sshetu-<device>-<tab>, device first', () {
      expect(
        tmuxSessionName(deviceId: 'abc123', tabKey: 'k3j9x0qa'),
        'sshetu-abc123-k3j9x0qa',
      );
    });

    test('a new name is unique per tab and carries the device', () {
      final names = {
        for (var i = 0; i < 500; i++) newTmuxSessionName('abc123'),
      };
      expect(names, hasLength(500));
      for (final name in names) {
        expect(name, matches(RegExp(r'^sshetu-abc123-[a-z0-9]{8}$')));
        expect(isSafeTmuxName(name), isTrue);
      }
    });

    test('are not derived from anything that restarts with the app', () {
      // Two launches with the same seedless generator still differ; with a
      // fixed seed the output is reproducible, which is the only way to pin
      // the alphabet.
      final a = newTmuxSessionName('abc123', random: Random(1));
      final b = newTmuxSessionName('abc123', random: Random(1));
      expect(a, b);
      expect(newTmuxSessionName('abc123'), isNot(newTmuxSessionName('abc123')));
    });

    test('anything a target or a shell would read becomes _', () {
      expect(
        tmuxSessionName(deviceId: 'a.b', tabKey: "c:d'e"),
        'sshetu-a_b-c_d_e',
      );
      expect(tmuxSafeName(r'x;$(id)'), 'x___id_');
    });

    test('safe names are plain and bounded', () {
      expect(isSafeTmuxName('sshetu-abc123-k3j9x0qa'), isTrue);
      expect(isSafeTmuxName('a b'), isFalse);
      expect(isSafeTmuxName('a:b'), isFalse);
      expect(isSafeTmuxName("a'b"), isFalse);
      expect(isSafeTmuxName(''), isFalse);
      expect(isSafeTmuxName('x' * 65), isFalse);
    });
  });

  group('reading a name back', () {
    test('a current name gives its device and tab', () {
      final origin = parseTmuxSessionName('sshetu-abc123-k3j9x0qa');
      expect(origin, isA<TmuxFromDevice>());
      origin as TmuxFromDevice;
      expect(origin.deviceId, 'abc123');
      expect(origin.tabKey, 'k3j9x0qa');
    });

    test('an old tab-id name is SSHetu, device unknown', () {
      expect(
        parseTmuxSessionName('sshetu-h1abc-0'),
        isA<TmuxFromOlderVersion>(),
      );
    });

    test('anything else is not ours', () {
      expect(parseTmuxSessionName('main'), isNull);
    });
  });
}
