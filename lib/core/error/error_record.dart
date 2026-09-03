/// One captured error.
///
/// Records are deduplicated by [fingerprint]: the same failure hit five
/// hundred times is one record with `count == 500`, not five hundred rows.
/// That is what keeps a crash loop from filling the device's storage, and what
/// makes the list readable when a user does send it in.
class ErrorRecord {
  const ErrorRecord({
    required this.fingerprint,
    required this.type,
    required this.message,
    required this.stack,
    required this.source,
    required this.firstSeen,
    required this.lastSeen,
    required this.count,
  });

  /// Stable hash of type + message + top stack frame. Deterministic across
  /// runs — `Object.hash` is not, so this cannot use it.
  final String fingerprint;

  /// The error's runtime type, e.g. `StateError`.
  final String type;

  final String message;

  /// Trimmed to the top frames. A full trace is mostly framework noise and
  /// the interesting part is always at the top.
  final String stack;

  /// Which handler caught it: `flutter`, `platform`, `zone`, `bootstrap` or
  /// `manual`. Useful because the same bug surfaces differently depending on
  /// whether it happened during a build or in an async callback.
  final String source;

  final DateTime firstSeen;
  final DateTime lastSeen;

  /// How many times this fingerprint has been seen.
  final int count;

  ErrorRecord seenAgain(DateTime at) => ErrorRecord(
    fingerprint: fingerprint,
    type: type,
    message: message,
    stack: stack,
    source: source,
    firstSeen: firstSeen,
    lastSeen: at,
    count: count + 1,
  );

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'type': type,
    'message': message,
    'stack': stack,
    'source': source,
    'firstSeen': firstSeen.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'count': count,
  };

  /// Tolerant on purpose: a record written by an older build must not stop the
  /// whole log from loading.
  static ErrorRecord? fromJson(Map<String, dynamic> json) {
    final fingerprint = json['fingerprint'];
    final firstSeen = DateTime.tryParse('${json['firstSeen']}');
    final lastSeen = DateTime.tryParse('${json['lastSeen']}');
    if (fingerprint is! String || firstSeen == null || lastSeen == null) {
      return null;
    }
    return ErrorRecord(
      fingerprint: fingerprint,
      type: '${json['type'] ?? 'Error'}',
      message: '${json['message'] ?? ''}',
      stack: '${json['stack'] ?? ''}',
      source: '${json['source'] ?? 'manual'}',
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      count: json['count'] is int ? json['count'] as int : 1,
    );
  }

  /// FNV-1a, 32-bit. Small, dependency-free, and — unlike `Object.hash` or
  /// `String.hashCode` — identical on every run and every platform, which is
  /// the entire point of a fingerprint that has to survive a restart.
  static String fingerprintOf(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      // 16777619, applied with shifts to stay inside 32 bits on web too.
      hash =
          (hash +
              (hash << 1) +
              (hash << 4) +
              (hash << 7) +
              (hash << 8) +
              (hash << 24)) &
          0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
