import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/domain/approval.dart';

void main() {
  ApprovalRequest request({bool remember = true}) => ApprovalRequest(
    clientName: 'claude-code',
    toolName: 'run_command',
    target: 'web-1',
    canRememberSimilar: remember,
  );

  test('approve, deny and unavailable map to outcomes', () async {
    for (final (decision, outcome) in [
      (ApprovalDecision.approveOnce, ApprovalOutcome.approved),
      (ApprovalDecision.approveSimilar, ApprovalOutcome.approved),
      (ApprovalDecision.deny, ApprovalOutcome.denied),
    ]) {
      final gate = ApprovalGate(approver: (_) async => decision);
      expect(await gate.check(request()), outcome);
    }
    final noWindow = ApprovalGate(
      approver: (_) async => throw const ApprovalUnavailable(),
    );
    expect(await noWindow.check(request()), ApprovalOutcome.unavailable);
  });

  test('an unanswered request times out and expires', () async {
    final pending = Completer<ApprovalDecision>();
    final gate = ApprovalGate(
      approver: (_) => pending.future,
      timeout: const Duration(milliseconds: 20),
    );
    final r = request();
    expect(await gate.check(r), ApprovalOutcome.timedOut);
    expect(r.isExpired, isTrue, reason: 'the dialog must close itself');
  });

  test('an answered request expires too', () async {
    final gate = ApprovalGate(approver: (_) async => ApprovalDecision.deny);
    final r = request();
    await gate.check(r);
    expect(r.isExpired, isTrue);
  });

  test(
    'approve similar skips the dialog for that key until it lapses',
    () async {
      var now = DateTime(2026, 9, 22, 12);
      var asked = 0;
      final gate = ApprovalGate(
        approver: (_) async {
          asked++;
          return ApprovalDecision.approveSimilar;
        },
        clock: () => now,
      );
      expect(
        await gate.check(request(), rememberKey: 'k'),
        ApprovalOutcome.approved,
      );
      expect(
        await gate.check(request(), rememberKey: 'k'),
        ApprovalOutcome.remembered,
      );
      expect(asked, 1);

      // A different key — another session or tool — still asks.
      await gate.check(request(), rememberKey: 'other');
      expect(asked, 2);

      now = now.add(const Duration(minutes: 11));
      expect(
        await gate.check(request(), rememberKey: 'k'),
        ApprovalOutcome.approved,
      );
      expect(asked, 3);
    },
  );

  test('approve similar is not honoured where it was not offered', () async {
    var asked = 0;
    final gate = ApprovalGate(
      approver: (_) async {
        asked++;
        return ApprovalDecision.approveSimilar;
      },
    );
    await gate.check(request(remember: false), rememberKey: 'k');
    await gate.check(request(remember: false), rememberKey: 'k');
    expect(asked, 2);
    await gate.check(request(), rememberKey: null);
    await gate.check(request(), rememberKey: null);
    expect(asked, 4);
  });

  test('clear forgets every grant', () async {
    var asked = 0;
    final gate = ApprovalGate(
      approver: (_) async {
        asked++;
        return ApprovalDecision.approveSimilar;
      },
    );
    await gate.check(request(), rememberKey: 'k');
    gate.clear();
    await gate.check(request(), rememberKey: 'k');
    expect(asked, 2);
  });

  group('visibleText', () {
    test('leaves ordinary text alone', () {
      expect(
        visibleText('ls -la /var/log | grep ä'),
        'ls -la /var/log | grep ä',
      );
    });

    test('names control keys', () {
      expect(visibleText('\u0003'), '<Ctrl-C>');
      expect(visibleText('y\r'), 'y<Enter>');
      expect(visibleText('\u001b:q!\r'), '<Esc>:q!<Enter>');
      expect(visibleText('a\tb'), 'a<Tab>b');
      expect(visibleText('\u007f'), '<Backspace>');
      expect(visibleText('\u0000'), '<0x00>');
      expect(visibleText('\u009b'), '<0x9B>');
    });

    test('shows invisible characters that could disguise a command', () {
      expect(visibleText('rm\u202e-rf'), 'rm<U+202E>-rf');
      expect(visibleText('a\u200bb'), 'a<U+200B>b');
      expect(visibleText('\ufeff'), '<U+FEFF>');
    });
  });
}
