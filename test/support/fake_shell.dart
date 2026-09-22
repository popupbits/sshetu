import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sshetu/core/terminal/remote_shell.dart';

/// A [ShellLauncher] with no server behind it: every shell it opens is a
/// [FakeShell] the test can feed, drop or exit by hand.
class FakeLauncher implements ShellLauncher {
  final shells = <FakeShell>[];
  var opens = 0;
  var discards = 0;
  Object? failWith;

  /// When set, [open] waits for it — an attempt caught in the middle.
  Completer<void>? hold;

  /// The origin of each successive shell; plain once exhausted.
  List<ShellOrigin> origins = [];

  /// The history handed to each successive reattached shell.
  List<String?> histories = [];

  @override
  Future<RemoteShell> open({required int columns, required int rows}) async {
    opens++;
    final gate = hold;
    if (gate != null) await gate.future;
    final failure = failWith;
    if (failure != null) throw failure;
    final origin = origins.isEmpty ? ShellOrigin.plain : origins.removeAt(0);
    final shell = FakeShell(
      origin,
      history: origin == ShellOrigin.tmuxReattached && histories.isNotEmpty
          ? histories.removeAt(0)
          : null,
    );
    shells.add(shell);
    return shell;
  }

  /// Whether [enableTmux] was called.
  var tmuxEnabled = false;

  @override
  void enableTmux() => tmuxEnabled = true;

  @override
  Future<void> discard() async => discards++;
}

class FakeShell implements RemoteShell {
  FakeShell(this.origin, {this.history});

  @override
  final ShellOrigin origin;

  @override
  final String? history;

  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _done = Completer<void>();
  final written = <String>[];
  var _exited = false;

  void emit(String text) => _stdout.add(Uint8List.fromList(utf8.encode(text)));

  /// The link went away: the channel closes with no exit status.
  void drop() => _finish();

  /// The program ended: an exit status, then the channel closes.
  void exit() {
    _exited = true;
    _finish();
  }

  void _finish() {
    if (!_done.isCompleted) _done.complete();
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get exited => _exited;

  @override
  void write(Uint8List data) => written.add(utf8.decode(data));

  @override
  void resize(int width, int height, int pixelWidth, int pixelHeight) {}

  @override
  void close() => _finish();
}
