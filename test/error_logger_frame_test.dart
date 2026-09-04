import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/error/error_logger.dart';
import 'package:sshetu/core/error/error_record.dart';

/// Recording an error must not itself cause one.
void main() {
  testWidgets('a real overflow is recorded once, not twice', (tester) async {
    // A layout overflow is reported from inside paint, and anything watching
    // the logger rebuilds when it changes — which during a frame is its own
    // Flutter error. So one overflow used to produce two records, the second
    // ("Build scheduled during frame") louder and less true than the first,
    // and the diagnostics screen filled with the logger's own noise.
    await ErrorLogger.instance.clear();

    final seen = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      seen.add(details.exception.toString());
      ErrorLogger.instance.record(
        details.exception,
        details.stack,
        source: 'flutter',
      );
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<List<ErrorRecord>>(
          valueListenable: ErrorLogger.instance.records,
          builder: (context, records, _) => const Scaffold(
            // Deliberately too wide for the window: the overflow is the point.
            body: SizedBox(
              width: 300,
              child: Row(children: [SizedBox(width: 900, height: 20)]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(seen, hasLength(1), reason: 'one overflow, one error');
    expect(seen.single, contains('overflowed'));
    expect(
      seen.single,
      isNot(contains('Build scheduled during frame')),
      reason: 'the logger must not report itself',
    );
    expect(ErrorLogger.instance.records.value, hasLength(1));
  });
}
