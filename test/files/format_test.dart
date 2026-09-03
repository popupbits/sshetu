import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/files/domain/format.dart';

void main() {
  group('humanFileSize', () {
    test('null renders as an em dash, not a fabricated 0 B', () {
      // A directory or a server that sent no size must not be shown as "0
      // B" — that claims a fact ("this is empty") nobody actually reported.
      expect(humanFileSize(null), '—');
    });

    test('bytes below 1024 have no decimal and no unit conversion', () {
      expect(humanFileSize(0), '0 B');
      expect(humanFileSize(512), '512 B');
      expect(humanFileSize(1023), '1023 B');
    });

    test('crosses into KB at exactly 1024', () {
      expect(humanFileSize(1024), '1.0 KB');
    });

    test('shows one decimal below 10 units, none at or above it', () {
      // The precision rule this pins: "1.4 MB" is worth the extra digit,
      // "14 MB" is not — a decimal there would be noise, not information.
      expect(humanFileSize(1500 * 1024), '1.5 MB');
      expect(humanFileSize(15 * 1024 * 1024), '15 MB');
    });

    test('climbs through GB for a large file', () {
      expect(humanFileSize(2 * 1024 * 1024 * 1024), '2.0 GB');
    });
  });

  group('relativeModified', () {
    final now = DateTime.utc(2026, 1, 1, 12);

    test('null renders as an em dash', () {
      expect(relativeModified(null, now: now), '—');
    });

    test('under a minute uses the caller-supplied "now" label', () {
      expect(
        relativeModified(
          now.subtract(const Duration(seconds: 30)),
          now: now,
          nowLabel: 'just now',
        ),
        'just now',
      );
    });

    test(
      'minutes, hours, days and years each pick the coarsest unit that fits',
      () {
        expect(
          relativeModified(now.subtract(const Duration(minutes: 5)), now: now),
          '5m',
        );
        expect(
          relativeModified(now.subtract(const Duration(hours: 3)), now: now),
          '3h',
        );
        expect(
          relativeModified(now.subtract(const Duration(days: 10)), now: now),
          '10d',
        );
        expect(
          relativeModified(now.subtract(const Duration(days: 800)), now: now),
          '2y',
        );
      },
    );

    test('a modified time in the future — clock skew — reads as unknown, not negative', () {
      // Guards against "-3m" ever reaching the UI: that would read as a bug,
      // not as "the remote host's clock is a little ahead".
      expect(
        relativeModified(now.add(const Duration(minutes: 3)), now: now),
        '—',
      );
    });
  });
}
