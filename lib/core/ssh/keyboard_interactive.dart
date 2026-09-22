/// One question a server asks during keyboard-interactive authentication.
class KeyboardInteractivePrompt {
  const KeyboardInteractivePrompt(this.text, {required this.echo});

  /// Exactly what the server sent — `Password:`, `Verification code:`.
  final String text;

  /// Whether the answer may be shown as it is typed. False for a password;
  /// usually true for a one-time code.
  final bool echo;

  @override
  String toString() => 'KeyboardInteractivePrompt($text, echo: $echo)';
}

/// One round of keyboard-interactive authentication (RFC 4256).
///
/// A server can ask several rounds in one sign-in — PAM's usual shape is a
/// password round followed by a one-time-code round — so [round] says where in
/// that conversation this one falls. It counts rounds that actually asked
/// something; an informational round with no prompts is answered by the
/// connection itself and never reaches a credential source.
class KeyboardInteractiveChallenge {
  const KeyboardInteractiveChallenge({
    required this.prompts,
    required this.round,
    this.name = '',
    this.instruction = '',
    this.allowSavedPassword = true,
  });

  /// The server's title for the exchange, often empty.
  final String name;

  /// The server's explanation, often empty.
  final String instruction;

  final List<KeyboardInteractivePrompt> prompts;

  /// Zero for the first round of this authentication attempt.
  final int round;

  /// False once the saved password has already been sent to this hop and
  /// refused. The connection sets it so a wrong saved password is tried
  /// **once** and then the user is asked, rather than being replayed at the
  /// server on every attempt.
  final bool allowSavedPassword;

  /// Whether this round is a server asking for the login password — the
  /// common PAM shape where password authentication itself is disabled and
  /// `Password:` arrives through keyboard-interactive instead.
  ///
  /// Deliberately narrow: exactly one prompt, not echoed, mentioning a
  /// password, and not a one-time password. Sending the saved password to a
  /// prompt that turns out to be for something else discloses it to a
  /// question it did not answer.
  bool get asksForPassword {
    if (prompts.length != 1) return false;
    final prompt = prompts.single;
    if (prompt.echo) return false;
    final text = prompt.text.toLowerCase();
    return text.contains('password') && !looksLikeOneTimeCode(text);
  }

  @override
  String toString() =>
      'KeyboardInteractiveChallenge(round $round, ${prompts.length} prompts)';
}

/// A credential source's answer to one round.
class KeyboardInteractiveAnswers {
  const KeyboardInteractiveAnswers(
    this.answers, {
    this.fromSavedPassword = false,
  });

  /// One answer per prompt, in the prompts' order.
  final List<String> answers;

  /// True when this was the saved password sent without asking. The
  /// connection needs to know: if authentication then fails, the next attempt
  /// must ask the user instead of sending the same wrong password again.
  final bool fromSavedPassword;

  /// Never prints the answers — they are passwords and one-time codes.
  @override
  String toString() => 'KeyboardInteractiveAnswers(${answers.length})';
}

/// Whether [challenge] may be answered with the saved password without asking.
///
/// Checked **before** reading the vault, so a round that could never be
/// auto-answered costs no credential-store lookup (and on macOS, no keychain
/// prompt).
bool mayAnswerWithSavedPassword(KeyboardInteractiveChallenge challenge) =>
    challenge.round == 0 &&
    challenge.allowSavedPassword &&
    challenge.asksForPassword;

/// The saved password as the answer to [challenge], or null to ask the user.
///
/// Only the first round, only a lone non-echoed password prompt, only when a
/// password is saved, and only once per connection (see
/// [KeyboardInteractiveChallenge.allowSavedPassword]). Everything else — a
/// second password round, a one-time code, a multi-prompt form — is a question
/// only the user can answer.
List<String>? answerWithSavedPassword(
  KeyboardInteractiveChallenge challenge,
  String? savedPassword,
) {
  if (savedPassword == null || savedPassword.isEmpty) return null;
  if (!mayAnswerWithSavedPassword(challenge)) return null;
  return [savedPassword];
}

/// Whether a prompt is asking for a one-time code rather than a secret the
/// user keeps — used to pick a keyboard hint, and to keep the saved password
/// away from a prompt like `One-time password:`.
bool looksLikeOneTimeCode(String promptText) {
  final text = promptText.toLowerCase();
  const markers = [
    'one-time',
    'one time',
    'otp',
    'code',
    'verification',
    'token',
    'passcode',
    '2fa',
    'two-factor',
  ];
  return markers.any(text.contains);
}

/// The server's answer to one [KeyboardInteractiveChallenge], from whatever
/// supplies it.
typedef KeyboardInteractiveAnswerer =
    Future<KeyboardInteractiveAnswers?> Function(
      KeyboardInteractiveChallenge challenge,
    );

/// Drives keyboard-interactive for one hop, for one authentication attempt.
///
/// Separate from the connection so the part with branches — counting rounds,
/// answering informational rounds, noticing a decline — can be tested without
/// a server. One instance per `SSHClient`: rounds restart with every attempt.
class KeyboardInteractiveSession {
  KeyboardInteractiveSession(this._answer, {this.allowSavedPassword = true});

  final KeyboardInteractiveAnswerer _answer;

  /// Whether the saved password may be sent without asking on this attempt.
  final bool allowSavedPassword;

  var _round = 0;

  /// Set when a round asked something and nothing answered it — the user
  /// cancelled, or the source refuses on principle (key verification). The
  /// connection reports that instead of a generic rejection.
  bool get declined => _declined;
  var _declined = false;

  /// Set when the saved password was sent without asking on this attempt.
  bool get usedSavedPassword => _usedSavedPassword;
  var _usedSavedPassword = false;

  /// Answers one server round. Null tells dartssh2 to give up on
  /// keyboard-interactive, which then fails authentication promptly rather
  /// than waiting on anything.
  Future<List<String>?> respond({
    required String name,
    required String instruction,
    required List<KeyboardInteractivePrompt> prompts,
  }) async {
    // RFC 4256 allows a round with nothing to ask — a banner, a "push sent"
    // notice. It wants an empty reply, and there is nothing to ask anyone.
    if (prompts.isEmpty) return const [];

    final challenge = KeyboardInteractiveChallenge(
      name: name,
      instruction: instruction,
      prompts: List.unmodifiable(prompts),
      round: _round++,
      allowSavedPassword: allowSavedPassword && !_usedSavedPassword,
    );

    final KeyboardInteractiveAnswers? reply;
    try {
      reply = await _answer(challenge);
    } on Object {
      // An exception thrown into dartssh2 here tears the transport down as an
      // "internal error" and reads as a network fault. Declining is the truth.
      _declined = true;
      return null;
    }

    if (reply == null || reply.answers.length != prompts.length) {
      _declined = true;
      return null;
    }
    if (reply.fromSavedPassword) _usedSavedPassword = true;
    return reply.answers;
  }
}
