/// Turning a password login into a key login, on the server.
///
/// The scripts live here, away from the code that runs them, because they are
/// the part that has to be *read* to be trusted: they append to a file that
/// controls who can log in to someone's machine.
///
/// Three properties they are written for:
///
///  * **Nothing is interpolated.** The public key never appears in the script.
///    It arrives on stdin and is compared with `grep -f`, so a key — or a
///    label someone typed into it — cannot become shell syntax. This is the
///    whole reason the "already present" check reads a pattern *file* rather
///    than doing the obvious `grep "$(cat ...)"`.
///  * **POSIX sh, not bash.** The remote shell may be dash, ash on a router,
///    or busybox. Nothing here needs more.
///  * **Every step is undoable.** [install] takes a copy before it writes, and
///    [rollback] puts it back. Failing halfway must not leave a machine that
///    someone can no longer log in to.
abstract final class KeySetupScripts {
  /// Where the copy of `authorized_keys` lives between install and commit.
  ///
  /// Dotted, so it does not show up in a casual `ls ~/.ssh`, and named after
  /// the app so a leftover from a crashed run is identifiable rather than
  /// mysterious.
  static const String backupPath = r'$HOME/.ssh/.sshetu-authorized_keys.bak';

  /// Where the incoming key is staged. Never left behind.
  static const String stagePath = r'$HOME/.ssh/.sshetu-key.pub';

  /// Printed on success, so a result is recognised rather than inferred from
  /// an exit code alone — a shell that could not run the script at all also
  /// exits non-zero, and the two deserve different messages.
  static const String addedMarker = 'SSHETU:added';
  static const String presentMarker = 'SSHETU:present';
  static const String restoredMarker = 'SSHETU:restored';
  static const String committedMarker = 'SSHETU:committed';

  /// Reads the key from stdin and appends it if it is not already there.
  ///
  /// `umask 077` first: a file created before the `chmod` would exist,
  /// briefly, with whatever the login umask says — and sshd refuses to use an
  /// `authorized_keys` that is group-writable, so getting this wrong produces
  /// a key that installs cleanly and silently never works.
  static const String install =
      'set -e\n'
      'umask 077\n'
      'mkdir -p "\$HOME/.ssh"\n'
      'chmod 700 "\$HOME/.ssh"\n'
      'cat > "$stagePath"\n'
      'touch "\$HOME/.ssh/authorized_keys"\n'
      'cp "\$HOME/.ssh/authorized_keys" "$backupPath"\n'
      'if grep -qxFf "$stagePath" "\$HOME/.ssh/authorized_keys"; then\n'
      '  echo "$presentMarker"\n'
      'else\n'
      // Appended, never rewritten: this file is the user's, and it may hold
      // keys from machines that are not this one.
      '  cat "$stagePath" >> "\$HOME/.ssh/authorized_keys"\n'
      '  echo "$addedMarker"\n'
      'fi\n'
      'chmod 600 "\$HOME/.ssh/authorized_keys"\n'
      'rm -f "$stagePath"\n';

  /// Puts `authorized_keys` back as it was.
  ///
  /// Restores rather than deleting the line it added: a copy taken moments
  /// ago is exactly right, and editing the file a second time to undo an edit
  /// is a second chance to get it wrong.
  ///
  /// Succeeds when there is nothing to undo, so it is safe to run after any
  /// failure without first working out how far the install got.
  static const String rollback =
      'set -e\n'
      'if [ -f "$backupPath" ]; then\n'
      '  cp "$backupPath" "\$HOME/.ssh/authorized_keys"\n'
      '  chmod 600 "\$HOME/.ssh/authorized_keys"\n'
      '  rm -f "$backupPath"\n'
      'fi\n'
      'rm -f "$stagePath"\n'
      'echo "$restoredMarker"\n';

  /// Removes the copy, once the key is known to work.
  static const String commit =
      'set -e\n'
      'rm -f "$backupPath" "$stagePath"\n'
      'echo "$committedMarker"\n';
}

/// What happened on the server.
enum KeyInstallOutcome {
  /// The key was appended.
  added,

  /// It was already in `authorized_keys`. Not an error: someone may have put
  /// it there by hand, or a previous attempt got this far and failed later.
  alreadyPresent,
}

/// Reads the marker out of a script's output.
///
/// Throws [KeySetupException] when no marker is found. Output without one
/// means the script did not reach its end — a read-only home directory, a
/// missing `grep`, a shell that is not a shell — and guessing from an exit
/// code would turn "your /home is full" into "the key was installed".
KeyInstallOutcome readInstallOutcome(String output) {
  if (output.contains(KeySetupScripts.addedMarker)) {
    return KeyInstallOutcome.added;
  }
  if (output.contains(KeySetupScripts.presentMarker)) {
    return KeyInstallOutcome.alreadyPresent;
  }
  throw KeySetupException(
    'The server did not finish setting up the key.',
    detail: output.trim(),
  );
}

/// A step of the key setup that did not work, in words a dialog can show.
class KeySetupException implements Exception {
  const KeySetupException(this.message, {this.detail});

  final String message;

  /// What the server said, when it said anything. Shown under the message,
  /// because "Permission denied" from the machine itself is worth more than
  /// any sentence written here in advance.
  final String? detail;

  @override
  String toString() =>
      detail == null ? message : '$message\n${detail!}';
}

/// Checks a public key looks like one before it is sent anywhere.
///
/// Not a security control — the server decides what it accepts — but a bad
/// line appended to `authorized_keys` is a line someone has to find and remove
/// by hand later, and the commonest cause is a blank or half-copied key.
bool isPlausiblePublicKey(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.contains('\n')) return false;

  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length < 2) return false;
  if (!parts.first.startsWith('ssh-') && !parts.first.startsWith('ecdsa-')) {
    return false;
  }
  // The base64 body. Short enough to be a typo is short enough to refuse.
  return parts[1].length >= 32 &&
      RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(parts[1]);
}
