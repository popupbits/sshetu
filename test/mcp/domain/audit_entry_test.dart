import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/domain/audit_entry.dart';

void main() {
  AuditEntry entry(int n) => AuditEntry(
    time: DateTime.utc(2026, 9, 22, 12, 0, n % 60),
    client: 'claude-code',
    tool: 'tool$n',
    decision: AuditDecision.read,
  );

  test('newest first, capped', () {
    var log = <AuditEntry>[];
    for (var i = 0; i < kMcpAuditCap + 25; i++) {
      log = prependCapped(log, entry(i));
    }
    expect(log, hasLength(kMcpAuditCap));
    expect(log.first.tool, 'tool${kMcpAuditCap + 24}');
    expect(log.last.tool, 'tool25');
  });

  test('a small cap is honoured', () {
    var log = <AuditEntry>[];
    for (var i = 0; i < 5; i++) {
      log = prependCapped(log, entry(i), cap: 3);
    }
    expect(log.map((e) => e.tool), ['tool4', 'tool3', 'tool2']);
  });

  test('round-trips through JSON', () {
    final original = AuditEntry(
      time: DateTime.utc(2026, 9, 22, 8, 30),
      client: 'Cursor',
      tool: 'run_command',
      target: 'web-1 — deploy@10.0.0.4:22 (session s-1)',
      decision: AuditDecision.denied,
      resultBytes: 12,
      error: 'denied',
    );
    final copy = AuditEntry.fromJson(original.toJson())!;
    expect(copy.time, original.time);
    expect(copy.client, 'Cursor');
    expect(copy.tool, 'run_command');
    expect(copy.target, original.target);
    expect(copy.decision, AuditDecision.denied);
    expect(copy.resultBytes, 12);
    expect(copy.error, 'denied');
  });

  test('a corrupt entry reads as null, an unknown decision as rejected', () {
    expect(AuditEntry.fromJson('nope'), isNull);
    expect(AuditEntry.fromJson({'t': 'yesterday', 'c': 'x', 'n': 'y'}), isNull);
    final odd = AuditEntry.fromJson({
      't': '2026-09-22T00:00:00Z',
      'c': 'x',
      'n': 'y',
      'd': 'exploded',
    });
    expect(odd?.decision, AuditDecision.rejected);
  });
}
