import 'dart:async';

/// What an approval dialog shows about one part of a request. Named by
/// [kind] rather than by a label so the dialog can say it in the user's
/// language; [value] is shown exactly as the client sent it, with control
/// characters made visible (see [visibleText]).
enum ApprovalDetailKind {
  command,
  input,
  host,
  tunnel,
  snippet,
  remotePath,
  localPath,
  overwrite,
}

class ApprovalDetail {
  const ApprovalDetail(this.kind, this.value);

  final ApprovalDetailKind kind;
  final String value;
}

/// One act call, waiting for the user.
class ApprovalRequest {
  ApprovalRequest({
    required this.clientName,
    required this.toolName,
    required this.target,
    this.details = const [],
    this.canRememberSimilar = false,
  });

  /// What the client called itself. Self-reported, shown as such.
  final String clientName;
  final String toolName;

  /// The exact host, session or tunnel the call acts on.
  final String target;
  final List<ApprovalDetail> details;

  /// Whether the dialog may offer "approve similar for a while".
  final bool canRememberSimilar;

  final _expiry = Completer<void>();

  /// Completes when the request stops waiting — answered elsewhere, or out of
  /// time. A dialog still showing it closes itself.
  Future<void> get expired => _expiry.future;
  bool get isExpired => _expiry.isCompleted;

  void expire() {
    if (!_expiry.isCompleted) _expiry.complete();
  }
}

enum ApprovalDecision { approveOnce, approveSimilar, deny }

/// How an act call's approval went.
enum ApprovalOutcome {
  approved,

  /// Allowed without asking, under an earlier "approve similar".
  remembered,
  denied,

  /// Nobody answered in time.
  timedOut,

  /// There was no window to ask in.
  unavailable,
}

/// Thrown by an approver that has nowhere to show the dialog.
class ApprovalUnavailable implements Exception {
  const ApprovalUnavailable();

  @override
  String toString() => "SSHetu's window is not ready.";
}

/// Asks the user. The UI layer's is a dialog; a test's answers at once.
typedef McpApprover = Future<ApprovalDecision> Function(ApprovalRequest);

/// Every act call passes here, and only here decides whether it runs.
///
/// **Approve similar.** A user can let the same client call the same tool on
/// the same session for [rememberFor] without being asked again — typing a
/// dozen commands into one shell should not be a dozen dialogs. The grant is
/// keyed on all three, held in memory only, and dropped with the server; it
/// is only ever offered for a request that supplies a key (see
/// [ApprovalRequest.canRememberSimilar]), and never on by default.
class ApprovalGate {
  ApprovalGate({
    required this.approver,
    this.timeout = const Duration(minutes: 2),
    this.rememberFor = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final McpApprover approver;
  final Duration timeout;
  final Duration rememberFor;
  final DateTime Function() _clock;
  final Map<String, DateTime> _grants = {};

  /// Whether [rememberKey] is currently allowed without asking.
  bool isRemembered(String rememberKey) {
    final until = _grants[rememberKey];
    if (until == null) return false;
    if (_clock().isBefore(until)) return true;
    _grants.remove(rememberKey);
    return false;
  }

  Future<ApprovalOutcome> check(
    ApprovalRequest request, {
    String? rememberKey,
  }) async {
    if (rememberKey != null && isRemembered(rememberKey)) {
      return ApprovalOutcome.remembered;
    }
    try {
      final decision = await approver(request).timeout(timeout);
      switch (decision) {
        case ApprovalDecision.deny:
          return ApprovalOutcome.denied;
        case ApprovalDecision.approveSimilar:
          if (rememberKey != null && request.canRememberSimilar) {
            _grants[rememberKey] = _clock().add(rememberFor);
          }
          return ApprovalOutcome.approved;
        case ApprovalDecision.approveOnce:
          return ApprovalOutcome.approved;
      }
    } on TimeoutException {
      return ApprovalOutcome.timedOut;
    } on ApprovalUnavailable {
      return ApprovalOutcome.unavailable;
    } finally {
      request.expire();
    }
  }

  /// Forgets every "approve similar".
  void clear() => _grants.clear();
}

/// [text] with every character that could hide what it does made visible:
/// C0 and C1 controls, DEL, and the invisible formatting characters —
/// bidirectional overrides, zero-width spaces — that can make a command
/// read differently from what it runs.
///
/// An approval dialog shows this, never the raw text: the whole point of the
/// dialog is that what the user reads is what the server receives.
String visibleText(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final named = switch (rune) {
      0x0D => '<Enter>',
      0x0A => '<LF>\n',
      0x09 => '<Tab>',
      0x1B => '<Esc>',
      0x7F => '<Backspace>',
      _ => null,
    };
    if (named != null) {
      out.write(named);
    } else if (rune >= 0x01 && rune <= 0x1A) {
      out.write('<Ctrl-${String.fromCharCode(0x40 + rune)}>');
    } else if (rune < 0x20 || (rune >= 0x80 && rune <= 0x9F)) {
      out.write('<0x${rune.toRadixString(16).padLeft(2, '0').toUpperCase()}>');
    } else if (_isInvisibleFormat(rune)) {
      out.write('<U+${rune.toRadixString(16).padLeft(4, '0').toUpperCase()}>');
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

bool _isInvisibleFormat(int rune) =>
    rune == 0x00AD ||
    (rune >= 0x200B && rune <= 0x200F) ||
    (rune >= 0x202A && rune <= 0x202E) ||
    (rune >= 0x2060 && rune <= 0x2069) ||
    rune == 0xFEFF;
