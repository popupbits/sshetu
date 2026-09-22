import 'package:dartssh2/dartssh2.dart';
// The channel is not exported, and a real one is the only way to get the
// real behaviour of a window-change on a closed channel under test.
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';

/// A shell over a real dartssh2 channel whose outgoing messages go to
/// [send].
({SshRemoteShell shell, SSHChannelController channel}) _shell(
  void Function(Object? message) send,
) {
  final channel = SSHChannelController(
    localId: 0,
    localMaximumPacketSize: 32768,
    localInitialWindowSize: 65536,
    remoteId: 0,
    remoteInitialWindowSize: 0,
    remoteMaximumPacketSize: 32768,
    sendMessage: send,
  );
  return (
    shell: SshRemoteShell(SSHSession(channel.channel), ShellOrigin.plain),
    channel: channel,
  );
}

void main() {
  test('a resize reaches the server while the channel is open', () {
    final sent = <Object?>[];
    final (:shell, channel: _) = _shell(sent.add);
    shell.resize(100, 30, 0, 0);
    expect(sent, hasLength(1));
  });

  test('a resize after the connection closed is dropped, not thrown — '
      'dartssh2 rethrows the error that ended the channel', () {
    final sent = <Object?>[];
    final (:shell, :channel) = _shell(sent.add);
    // What SSHClient._handleTransportClosed does to every channel.
    channel.destroy(SSHStateError('SSH connection closed'));
    sent.clear();

    expect(() => shell.resize(100, 30, 0, 0), returnsNormally);
    expect(sent, isEmpty);
  });

  test('a resize in the moment the transport is closed but the channel has not '
      'heard yet is dropped too', () {
    final (:shell, channel: _) = _shell(
      (_) => throw SSHStateError('Transport is closed'),
    );
    expect(() => shell.resize(100, 30, 0, 0), returnsNormally);
  });

  test('bad arguments and non-SSH failures still throw', () {
    final (:shell, channel: _) = _shell((_) {});
    expect(() => shell.resize(-1, 30, 0, 0), throwsArgumentError);

    final (shell: failing, channel: _) = _shell(
      (_) => throw StateError('a bug'),
    );
    expect(() => failing.resize(100, 30, 0, 0), throwsStateError);
  });
}
