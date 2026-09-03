import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ssh_navigator/core/error/error_logger.dart';
import 'package:ssh_navigator/core/error/error_record.dart';

void main() {
  final logger = ErrorLogger.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await logger.clear();
  });

  group('fingerprints', () {
    test('are stable for the same input', () {
      expect(
        ErrorRecord.fingerprintOf('StateError|bad|frame'),
        ErrorRecord.fingerprintOf('StateError|bad|frame'),
      );
    });

    test('differ for different inputs', () {
      expect(
        ErrorRecord.fingerprintOf('StateError|bad|frame'),
        isNot(ErrorRecord.fingerprintOf('StateError|worse|frame')),
      );
    });

    test('are eight hex characters', () {
      expect(ErrorRecord.fingerprintOf('anything'), matches(r'^[0-9a-f]{8}$'));
    });
  });

  group('recording', () {
    test('captures an error', () {
      logger.record(StateError('boom'), StackTrace.current);

      expect(logger.records.value, hasLength(1));
      expect(logger.records.value.single.type, 'StateError');
      expect(logger.records.value.single.message, contains('boom'));
    });

    test('deduplicates repeats into a count', () {
      final stack = StackTrace.current;
      for (var i = 0; i < 5; i++) {
        logger.record(StateError('same'), stack);
      }

      expect(logger.records.value, hasLength(1));
      expect(logger.records.value.single.count, 5);
    });

    test('keeps distinct errors apart', () {
      logger.record(StateError('one'), StackTrace.current);
      logger.record(ArgumentError('two'), StackTrace.current);

      expect(logger.records.value, hasLength(2));
    });

    test('caps the log so a crash loop cannot fill storage', () {
      for (var i = 0; i < ErrorLogger.maxRecords + 20; i++) {
        logger.record(StateError('distinct $i'), StackTrace.current);
      }

      expect(logger.records.value, hasLength(ErrorLogger.maxRecords));
    });

    test('ignore: true records nothing', () {
      logger.record(StateError('quiet'), null, ignore: true);

      expect(logger.records.value, isEmpty);
    });

    test('survives a null stack trace', () {
      logger.record(StateError('no stack'), null);

      expect(logger.records.value, hasLength(1));
      expect(logger.records.value.single.stack, isEmpty);
    });
  });

  group('persistence', () {
    test('a saved log is restored', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await logger.attachStorage(preferences);

      logger.record(StateError('persisted'), StackTrace.current);
      // The save is coalesced onto a microtask, so let it run.
      await Future<void>.delayed(Duration.zero);

      expect(preferences.getString(ErrorLogger.storageKey), isNotNull);
    });

    test('a corrupt log is discarded rather than thrown', () async {
      SharedPreferences.setMockInitialValues({
        ErrorLogger.storageKey: 'not json at all',
      });
      final preferences = await SharedPreferences.getInstance();

      await expectLater(logger.attachStorage(preferences), completes);
      expect(logger.records.value, isEmpty);
    });
  });

  group('export', () {
    test('names every recorded error', () {
      logger.record(StateError('exported'), StackTrace.current);

      expect(logger.export(), contains('exported'));
      expect(logger.export(), contains('StateError'));
    });
  });
}
