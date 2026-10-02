import 'package:flutter_test/flutter_test.dart';

/// Hands control back to the real event loop, then pumps what that produced.
///
/// `pumpAndSettle` cannot do this: it advances the test binding's fake clock,
/// and a real future — a sqlite read, a file write — never completes on it.
/// Each turn here is a real delay inside `runAsync` followed by a pump.
Future<void> realTurn(
  WidgetTester tester, [
  Duration step = const Duration(milliseconds: 20),
]) async {
  await tester.runAsync(() => Future<void>.delayed(step));
  await tester.pump();
}

/// Real turns until [condition] holds, failing the test after [timeout].
///
/// Prefer this to a fixed number of turns. A fixed count is a guess about how
/// long a database write takes, and the guess is made on a developer machine:
/// on a loaded CI runner the same write finished after the test had already
/// ended, which read as "the saved tab did not close" rather than as "nobody
/// waited for the save".
Future<void> settleUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 20),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    await realTurn(tester, step);
    if (condition()) return;
    if (DateTime.now().isAfter(deadline)) {
      fail('${reason ?? 'condition'} still false after $timeout');
    }
  }
}

/// [settleUntil] for the common case: waiting for something to appear.
Future<void> settleUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) => settleUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  timeout: timeout,
  reason: '$finder',
);
