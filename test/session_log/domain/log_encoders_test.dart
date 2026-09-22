import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/session_log/domain/log_encoders.dart';
import 'package:sshetu/features/session_log/domain/log_format.dart';

void main() {
  final started = DateTime(2026, 9, 22, 10, 15, 30);
  final header = SessionLogHeader(
    title: 'me@web-1',
    started: started,
    columns: 80,
    rows: 24,
  );

  List<int> out(
    SessionLogEncoder e,
    String text, {
    int ms = 0,
    int columns = 80,
    int rows = 24,
  }) => e.output(
    utf8.encode(text),
    elapsed: Duration(milliseconds: ms),
    columns: columns,
    rows: rows,
  );

  group('asciicast v2', () {
    List<Object?> lines(List<int> bytes) {
      final text = utf8.decode(bytes);
      expect(text.endsWith('\n'), isTrue, reason: 'every event ends a line');
      return [
        for (final line in const LineSplitter().convert(text)) jsonDecode(line),
      ];
    }

    test('the header names the version, size, start and title', () {
      final e = AsciicastEncoder();
      final h = lines(e.header(header)).single! as Map<String, Object?>;
      expect(h['version'], 2);
      expect(h['width'], 80);
      expect(h['height'], 24);
      expect(h['timestamp'], started.millisecondsSinceEpoch ~/ 1000);
      expect(h['title'], 'me@web-1');
      expect((h['env']! as Map)['TERM'], isNotEmpty);
    });

    test('output is one [time, "o", text] line, escapes kept', () {
      final e = AsciicastEncoder()..header(header);
      final events = lines(out(e, '\x1b[31mred\x1b[0m\r\n', ms: 1500));
      expect(events, [
        [1.5, 'o', '\x1b[31mred\x1b[0m\r\n'],
      ]);
    });

    test('a character split across two reads arrives whole', () {
      final e = AsciicastEncoder()..header(header);
      final bytes = utf8.encode('न');
      final first = e.output(
        bytes.sublist(0, 1),
        elapsed: Duration.zero,
        columns: 80,
        rows: 24,
      );
      expect(first, isEmpty, reason: 'nothing complete yet');
      final second = e.output(
        bytes.sublist(1),
        elapsed: const Duration(milliseconds: 10),
        columns: 80,
        rows: 24,
      );
      expect(lines(second), [
        [0.01, 'o', 'न'],
      ]);
    });

    test('timestamps never go backwards', () {
      final e = AsciicastEncoder()..header(header);
      final times = <num>[];
      for (final ms in [100, 250, 90, 250, 400, 10]) {
        final event = lines(out(e, 'x', ms: ms)).single! as List;
        times.add(event[0]! as num);
      }
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThanOrEqualTo(times[i - 1]));
      }
      expect(times, [0.1, 0.25, 0.25, 0.25, 0.4, 0.4]);
    });

    test('a resize is recorded before the output drawn at the new size', () {
      final e = AsciicastEncoder()..header(header);
      final events = lines(out(e, 'wide', ms: 200, columns: 120, rows: 40));
      expect(events, [
        [0.2, 'r', '120x40'],
        [0.2, 'o', 'wide'],
      ]);
      // Unchanged size: no second resize.
      expect(lines(out(e, 'more', ms: 300, columns: 120, rows: 40)), [
        [0.3, 'o', 'more'],
      ]);
    });

    test('markers are "m" events on the timeline, not output', () {
      final e = AsciicastEncoder()..header(header);
      out(e, 'x', ms: 500);
      final events = lines(
        e.marker(
          'reconnected',
          elapsed: const Duration(seconds: 2),
          wallClock: started,
        ),
      );
      expect(events, [
        [2.0, 'm', 'reconnected'],
      ]);
    });
  });

  group('plain text', () {
    test('header, stripped lines, marker, then the last line on finish', () {
      final e = PlainLogEncoder();
      final text = StringBuffer()
        ..write(utf8.decode(e.header(header)))
        ..write(utf8.decode(out(e, '\x1b[1mhello\x1b[0m\r\n\$ ')))
        ..write(
          utf8.decode(
            e.marker(
              'connection lost',
              elapsed: Duration.zero,
              wallClock: DateTime(2026, 9, 22, 10, 20),
            ),
          ),
        )
        ..write(utf8.decode(out(e, 'back\r\n\$ ')))
        ..write(utf8.decode(e.finish()));
      expect(
        text.toString(),
        '# me@web-1 — 2026-09-22 10:15:30\n'
        'hello\n'
        '\$ \n'
        '# connection lost — 2026-09-22 10:20:00\n'
        'back\n'
        '\$ \n',
      );
    });
  });

  group('raw', () {
    test('bytes pass through exactly; markers are dim lines of their own', () {
      final e = RawLogEncoder();
      expect(e.header(header), isEmpty);
      final bytes = [0x1b, 0x5b, 0x33, 0x31, 0x6d, 0xff, 0x0d];
      expect(
        e.output(bytes, elapsed: Duration.zero, columns: 80, rows: 24),
        bytes,
      );
      final marker = utf8.decode(
        e.marker('reconnected', elapsed: Duration.zero, wallClock: started),
      );
      expect(marker, startsWith('\x1b[0m\r\n'));
      expect(marker, contains('reconnected'));
      expect(marker, endsWith('\x1b[0m\r\n'));
    });
  });

  group('file name', () {
    test('host and local time, with the format\'s extension', () {
      final when = DateTime(2026, 1, 2, 3, 4, 5);
      expect(
        sessionLogFileName('web-1', when, SessionLogFormat.plain),
        'web-1-20260102-030405.log',
      );
      expect(
        sessionLogFileName('web-1', when, SessionLogFormat.asciicast),
        'web-1-20260102-030405.cast',
      );
    });

    test('characters a file system rejects are replaced', () {
      final when = DateTime(2026, 1, 2, 3, 4, 5);
      expect(
        sessionLogFileName('prod: db/1 <eu>', when, SessionLogFormat.raw),
        'prod_db_1_eu-20260102-030405.log',
      );
      expect(
        sessionLogFileName('..', when, SessionLogFormat.raw),
        'session-20260102-030405.log',
      );
    });
  });
}
