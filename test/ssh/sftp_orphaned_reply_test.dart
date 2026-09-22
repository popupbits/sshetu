import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/sftp_service.dart';

/// [guardOrphanedChannelReplies], with a stand-in for `SSHClient.sftp()`:
/// something that returns its own result and, beside it, starts a future
/// nobody listens to. The real case — a live connection cut between the
/// SFTP channel opening and the subsystem reply — is in
/// `server_drop_live_test.dart`.
void main() {
  /// Runs [body] through the guard inside a zone that collects what escapes.
  Future<({Object? result, List<Object> uncaught})> guarded<T>(
    Future<T> Function() body,
  ) async {
    final uncaught = <Object>[];
    final result = Completer<Object?>();
    runZonedGuarded(
      () =>
          guardOrphanedChannelReplies(body)
              .then(result.complete, onError: result.complete),
      (error, _) => uncaught.add(error),
    );
    final value = await result.future;
    // Let the orphan fail.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return (result: value, uncaught: uncaught);
  }

  test('an orphaned request failing with the connection is dropped', () async {
    final run = await guarded(() async {
      // What dartssh2 does: the reply future, failed by the transport
      // closing, with nobody listening.
      Future<bool>.error(SSHStateError('SSH connection closed'));
      return 'opened';
    });
    expect(run.result, 'opened');
    expect(run.uncaught, isEmpty);
  });

  test('anything other than an SSH error still escapes', () async {
    final run = await guarded(() async {
      Future<void>.error(StateError('a real bug'));
      return 'opened';
    });
    expect(run.result, 'opened');
    expect(run.uncaught, [isA<StateError>()]);
  });

  test(
    'an error from the call itself reaches the caller, not the zone',
    () async {
      final run = await guarded<String>(
        () async => throw SSHChannelOpenError(2, 'refused'),
      );
      expect(run.result, isA<SSHChannelOpenError>());
      expect(run.uncaught, isEmpty);
    },
  );

  test('a callback the call registers stays guarded the same way', () async {
    final uncaught = <Object>[];
    final registered = Completer<void Function(Object)>();
    runZonedGuarded(
      () => guardOrphanedChannelReplies(() async {
        // Like the SFTP client's channel listener: registered inside, run
        // later from outside.
        registered.complete(
          Zone.current.bindUnaryCallbackGuarded<Object>((error) => throw error),
        );
        return 0;
      }),
      (error, _) => uncaught.add(error),
    );
    final callback = await registered.future;
    callback(SSHStateError('SSH connection closed'));
    callback(ArgumentError('a real bug'));
    expect(uncaught, [isA<ArgumentError>()]);
  });
}
