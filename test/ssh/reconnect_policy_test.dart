import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/locked_secret_vault.dart';
import 'package:sshetu/core/ssh/host_key.dart';
import 'package:sshetu/core/ssh/reconnect_policy.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';

/// When a dropped session comes back by itself, and when it must not.
void main() {
  const policy = ReconnectPolicy();

  group('delayBefore', () {
    test('ramps 1.5 s, 3 s, 5 s, 8 s, then holds at 10 s', () {
      final delays = [
        for (var i = 0; i < 7; i++)
          policy.delayBefore(i, elapsed: Duration(seconds: i * 10)),
      ];
      expect(delays, const [
        Duration(milliseconds: 1500),
        Duration(seconds: 3),
        Duration(seconds: 5),
        Duration(seconds: 8),
        Duration(seconds: 10),
        Duration(seconds: 10),
        Duration(seconds: 10),
      ]);
    });

    test('slows to every 30 s once three minutes have gone by', () {
      expect(
        policy.delayBefore(20, elapsed: const Duration(minutes: 3)),
        const Duration(seconds: 30),
      );
      expect(
        policy.delayBefore(20, elapsed: const Duration(seconds: 179)),
        const Duration(seconds: 10),
      );
      expect(
        policy.delayBefore(500, elapsed: const Duration(hours: 50)),
        const Duration(seconds: 30),
      );
    });

    test('simulated from the drop, the schedule is the documented one', () {
      var elapsed = Duration.zero;
      final waits = <Duration>[];
      for (var attempt = 0; elapsed < const Duration(minutes: 4); attempt++) {
        final wait = policy.delayBefore(attempt, elapsed: elapsed);
        waits.add(wait);
        elapsed += wait;
      }
      // 17.5 s of ramp, then 10 s steps until 3 minutes, then 30 s.
      expect(waits.take(4), const [
        Duration(milliseconds: 1500),
        Duration(seconds: 3),
        Duration(seconds: 5),
        Duration(seconds: 8),
      ]);
      final steady = waits.skip(4).takeWhile((w) => w.inSeconds == 10).length;
      expect(steady, 17);
      expect(waits.skip(4 + steady), everyElement(const Duration(seconds: 30)));
    });
  });

  group('shouldReconnect', () {
    test('only a network drop comes back by itself', () {
      expect(policy.shouldReconnect(DisconnectReason.network), isTrue);
      for (final reason in [
        DisconnectReason.userInitiated,
        DisconnectReason.hostKeyRejected,
        DisconnectReason.authenticationFailed,
        DisconnectReason.remoteExited,
      ]) {
        expect(policy.shouldReconnect(reason), isFalse, reason: '$reason');
      }
    });
  });

  group('classify', () {
    DisconnectReason classify(Object error) => ReconnectPolicy.classify(error);

    test('an unreachable host is a network failure', () {
      expect(
        classify(
          SshConnectionException(
            'Cannot reach example.com:22',
            cause: const SocketException('Connection refused'),
            retryable: true,
          ),
        ),
        DisconnectReason.network,
      );
    });

    test('a handshake cut off by the socket is a network failure', () {
      expect(
        classify(
          SshConnectionException(
            'Handshake with me@host:22 failed',
            cause: SSHAuthAbortError(
              'Connection closed before authentication',
              SSHSocketError(const SocketException('reset')),
            ),
            retryable: true,
          ),
        ),
        DisconnectReason.network,
      );
    });

    test('a timeout or unknown error is treated as network', () {
      expect(classify(Exception('timeout')), DisconnectReason.network);
      expect(classify(StateError('odd')), DisconnectReason.network);
    });

    test('a refused host key never reconnects', () {
      final presentation = HostKeyPresentation(
        verdict: HostKeyVerdict.changed,
        hostname: 'host',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:abc',
      );
      expect(
        classify(
          SshConnectionException(
            presentation.describe(),
            cause: HostKeyRejected(presentation),
          ),
        ),
        DisconnectReason.hostKeyRejected,
      );
      expect(
        classify(SSHHostkeyError('changed during rekey')),
        DisconnectReason.hostKeyRejected,
      );
    });

    test('a rejected credential never reconnects', () {
      expect(
        classify(
          SshConnectionException(
            'Authentication as me@host was rejected.',
            cause: SSHAuthFailError('All authentication methods failed'),
          ),
        ),
        DisconnectReason.authenticationFailed,
      );
    });

    test('a declined keyboard-interactive challenge never reconnects', () {
      expect(
        classify(
          SshConnectionException(
            'Sign-in stopped: the server asked for an answer and none was '
            'given.',
            cause: SSHAuthFailError('declined'),
          ),
        ),
        DisconnectReason.authenticationFailed,
      );
    });

    test('a declined credential lock never reconnects', () {
      expect(
        classify(
          SshConnectionException(
            'Unlock to connect',
            cause: const VaultLockedException('Unlock to connect'),
          ),
        ),
        DisconnectReason.authenticationFailed,
      );
      expect(
        classify(const VaultLockedException('Unlock to connect')),
        DisconnectReason.authenticationFailed,
      );
    });

    test('a cancelled password prompt, wrapped by dartssh2, never '
        'reconnects', () {
      // What a null password actually looks like by the time it surfaces:
      // thrown inside dartssh2's callback, wrapped as an internal error, then
      // reported by SshConnection as a *retryable* handshake failure.
      final error = SshConnectionException(
        'Handshake with me@host:22 failed',
        cause: SSHAuthAbortError(
          'Connection closed before authentication',
          SSHInternalError(
            SshConnectionException('No password supplied for me@host:22.'),
          ),
        ),
        retryable: true,
      );
      expect(classify(error), DisconnectReason.authenticationFailed);
    });

    test('a missing key is configuration, not network', () {
      expect(
        classify(
          SshConnectionException('The private key for me@host is missing.'),
        ),
        DisconnectReason.authenticationFailed,
      );
    });
  });
}
