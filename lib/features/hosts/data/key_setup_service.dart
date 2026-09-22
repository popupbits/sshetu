import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../../core/secrets/secret_ref.dart';
import '../../../core/secrets/secret_vault.dart';
import '../../../core/ssh/ssh_credentials.dart';
import '../../../core/ssh/ssh_target.dart';
import '../domain/key_setup.dart';

/// Where the setup has got to, so the screen can say which step is running.
enum KeySetupStep {
  /// Writing the public key into `~/.ssh/authorized_keys`.
  installing,

  /// Opening a second connection that may use *only* the key.
  verifying,

  /// Removing the copy on the server and the saved password here.
  finishing,

  /// Putting `authorized_keys` back, because verification failed.
  rollingBack,
}

/// How it ended.
class KeySetupResult {
  const KeySetupResult({
    required this.installed,
    required this.verified,
    required this.rolledBack,
  });

  final KeyInstallOutcome installed;

  /// True only when a fresh, key-only connection actually authenticated.
  final bool verified;

  /// True when the server was put back as it was found.
  final bool rolledBack;
}

/// Opens a connection that must authenticate with one specific key.
typedef VerifyConnection = Future<void> Function(
  SshTarget target,
  SshCredentialSource credentials,
);

/// Runs a command on the already-open, password-authenticated session.
typedef RunRemote = Future<({String output, int? exitCode})> Function(
  String script,
  String stdin,
);

/// Credentials that offer exactly one key and no password at all.
///
/// The point of the whole feature is here. Verification has to prove the *key*
/// works, and the ordinary credential source would happily satisfy the same
/// connection with the saved password — the server refuses the key, asks for a
/// password, gets one, and the connection succeeds. Then the password is
/// deleted and the user is locked out of a host that never accepted the key.
///
/// So this returns null for a password, which the connection layer turns into
/// a failure, and records that it was asked — because "the server wanted a
/// password" is the one diagnosis worth reporting differently from the rest.
class KeyOnlyCredentials implements SshCredentialSource {
  KeyOnlyCredentials(this.key);

  final SshPrivateKey key;

  /// Whether the server fell back to asking for a password.
  var askedForPassword = false;

  @override
  Future<List<SshPrivateKey>> privateKeys(SshTarget target) async => [key];

  @override
  Future<String?> password(SshTarget target) async {
    askedForPassword = true;
    return null;
  }

  /// Whether the server asked a keyboard-interactive question — a PAM
  /// `Password:`, or a second factor on top of the key.
  var askedInteractively = false;

  /// Refused, for the same reason as [password]: keyboard-interactive is how
  /// a PAM server asks for the password, so answering here would let the
  /// password verify a key that does not work. No saved password is read and
  /// nobody is prompted.
  @override
  Future<KeyboardInteractiveAnswers?> keyboardInteractive(
    SshTarget target,
    KeyboardInteractiveChallenge challenge,
  ) async {
    askedInteractively = true;
    return null;
  }
}

/// Installs a key on a host, proves it works, then stops using the password.
///
/// **What this does not do: touch `sshd_config`.** Disabling password
/// authentication on the server is a different, much sharper operation — it
/// applies to every user and every client, needs a service reload, and a
/// mistake locks everyone out of a machine that may be in another country.
/// This changes what *this app* uses and what it stores. The server carries on
/// accepting passwords; nothing about that is this app's to decide.
class KeySetupService {
  const KeySetupService({
    required this.vault,
    required this.run,
    required this.verify,
  });

  final SecretVault vault;

  /// Runs a script on the existing session — the one already authenticated
  /// with the password we are trying to stop needing.
  final RunRemote run;

  /// Opens the independent connection that proves the key works.
  final VerifyConnection verify;

  /// The whole sequence, with the server put back if any of it fails.
  ///
  /// [onStep] reports progress. [hostId] is where the saved password lives;
  /// null for a target with nothing saved, in which case there is nothing to
  /// remove and the flow still installs and verifies.
  Future<KeySetupResult> run_({
    required SshTarget target,
    required String publicKey,
    required SshPrivateKey privateKey,
    String? hostId,
    void Function(KeySetupStep)? onStep,
  }) async {
    if (!isPlausiblePublicKey(publicKey)) {
      throw const KeySetupException(
        'That does not look like an OpenSSH public key, so it was not sent.',
      );
    }

    onStep?.call(KeySetupStep.installing);
    final installed = readInstallOutcome(
      await _script(KeySetupScripts.install, stdin: '${publicKey.trim()}\n'),
    );

    try {
      onStep?.call(KeySetupStep.verifying);
      final credentials = KeyOnlyCredentials(privateKey);
      try {
        await verify(
          target.copyWith(
            authMethod: SshAuthMethod.publicKey,
            identityId: privateKey.identityId,
          ),
          credentials,
        );
      } on Object catch (error) {
        throw KeySetupException(
          credentials.askedForPassword
              ? 'The server would not accept the key and asked for a password '
                    'instead, so nothing has been changed.'
              : credentials.askedInteractively
              ? 'The server asked for a password or a code instead of '
                    'accepting the key on its own, so nothing has been changed.'
              : 'The key was installed but could not be used to log in, so '
                    'nothing has been changed.',
          detail: '$error',
        );
      }
    } on Object {
      // Any failure after the file was written: put it back before rethrowing,
      // and let the original failure be the one reported.
      onStep?.call(KeySetupStep.rollingBack);
      await _rollbackQuietly();
      rethrow;
    }

    onStep?.call(KeySetupStep.finishing);
    await _script(KeySetupScripts.commit);

    // Last, and only now. The password stops being stored once the key is
    // proven — never on the strength of having written a file.
    if (hostId != null) {
      await vault.delete(SecretRef.hostPassword(hostId));
    }

    return KeySetupResult(
      installed: installed,
      verified: true,
      rolledBack: false,
    );
  }

  /// Runs a script and insists it succeeded.
  Future<String> _script(String script, {String stdin = ''}) async {
    final result = await run(script, stdin);
    if (result.exitCode != null && result.exitCode != 0) {
      throw KeySetupException(
        'The server refused a step of the setup.',
        detail: result.output.trim().isEmpty
            ? 'exit status ${result.exitCode}'
            : result.output.trim(),
      );
    }
    return result.output;
  }

  /// Rollback must not replace the real failure with its own.
  ///
  /// If putting the file back also fails there is nothing further to try from
  /// here, and reporting *that* would hide why the setup failed in the first
  /// place. The copy is left on the server, named after this app, which is the
  /// only useful thing left to do for someone who has to sort it out by hand.
  Future<void> _rollbackQuietly() async {
    try {
      await _script(KeySetupScripts.rollback);
    } on Object {
      // Deliberately swallowed; see above.
    }
  }
}

/// Runs [script] over [client], feeding [stdin] and collecting both streams.
///
/// `sh -s` reads the script from... no: the script is the command, and stdin
/// carries the key. Keeping those separate is what lets the key stay out of
/// the command line, where it would be visible in the server's process list.
Future<({String output, int? exitCode})> runScript(
  SSHClient client,
  String script,
  String stdin,
) async {
  final session = await client.execute(script);
  if (stdin.isNotEmpty) {
    session.write(Uint8List.fromList(utf8.encode(stdin)));
  }
  await session.stdin.close();

  final out = StringBuffer();
  await Future.wait([
    session.stdout.listen((data) => out.write(utf8.decode(data))).asFuture(),
    session.stderr.listen((data) => out.write(utf8.decode(data))).asFuture(),
  ]);
  await session.done;

  return (output: out.toString(), exitCode: session.exitCode);
}
