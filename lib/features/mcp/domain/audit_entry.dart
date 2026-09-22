/// One line of the MCP activity log.
///
/// Kept on this device only, capped at [kMcpAuditCap] entries, newest first.
/// Records who asked for what and how it went — never the output itself, and
/// never anything a tool refused to expose.
library;

const int kMcpAuditCap = 500;

enum AuditDecision {
  /// A read tool, which needs no approval.
  read,
  approved,

  /// Allowed without a dialog, under an earlier "approve similar".
  remembered,
  denied,
  timedOut,

  /// No window was there to ask in.
  unavailable,

  /// Refused before approval — bad arguments, an unknown session.
  rejected;

  static AuditDecision fromName(Object? name) => AuditDecision.values
      .firstWhere((d) => d.name == name, orElse: () => AuditDecision.rejected);
}

class AuditEntry {
  const AuditEntry({
    required this.time,
    required this.client,
    required this.tool,
    required this.decision,
    this.target,
    this.resultBytes,
    this.error,
  });

  final DateTime time;
  final String client;
  final String tool;
  final String? target;
  final AuditDecision decision;

  /// The size of what was returned, when the call produced a result.
  final int? resultBytes;
  final String? error;

  Map<String, Object?> toJson() => {
    't': time.toUtc().toIso8601String(),
    'c': client,
    'n': tool,
    'g': ?target,
    'd': decision.name,
    'b': ?resultBytes,
    'e': ?error,
  };

  /// Null for an entry that cannot be read — one corrupt line must not cost
  /// the whole log.
  static AuditEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final time = DateTime.tryParse('${json['t']}');
    final client = json['c'];
    final tool = json['n'];
    if (time == null || client is! String || tool is! String) return null;
    final target = json['g'];
    final bytes = json['b'];
    final error = json['e'];
    return AuditEntry(
      time: time,
      client: client,
      tool: tool,
      target: target is String ? target : null,
      decision: AuditDecision.fromName(json['d']),
      resultBytes: bytes is int ? bytes : null,
      error: error is String ? error : null,
    );
  }
}

/// [entries] with [entry] in front, cut to [cap].
List<AuditEntry> prependCapped(
  List<AuditEntry> entries,
  AuditEntry entry, {
  int cap = kMcpAuditCap,
}) => [entry, ...entries.take(cap - 1)];
