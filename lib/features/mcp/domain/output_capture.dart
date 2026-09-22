import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../session_log/domain/ansi_stripper.dart';

/// Collects what a session prints after a command was typed, as plain text,
/// and decides when it has stopped printing.
///
/// Screen output, not a command's result: there is no exit status and no
/// line between "the command's output" and "the next prompt". What this
/// gives back is what the terminal received, with escape sequences removed
/// by the same [AnsiStripper] session logging uses.
class OutputCapture {
  OutputCapture({this.maxChars = 64 * 1024}) {
    _decoder = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(_DecodedSink(_onDecoded));
  }

  /// The most text kept. A command that prints more keeps its tail — the
  /// end of the output, where the prompt and any error are.
  final int maxChars;

  final _stripper = AnsiStripper();
  final _text = StringBuffer();
  late final ByteConversionSink _decoder;
  bool _received = false;
  bool _truncated = false;
  void Function()? _onData;

  /// Whether anything arrived.
  bool get receivedAny => _received;

  /// Whether the start of the output was dropped to stay within [maxChars].
  bool get truncated => _truncated;

  /// Feed it every chunk the session receives.
  void add(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _received = true;
    _decoder.add(bytes);
    _onData?.call();
  }

  void _onDecoded(String text) {
    _text.write(_stripper.add(text));
    if (_text.length > maxChars * 2) _trim();
  }

  void _trim() {
    final all = _text.toString();
    if (all.length <= maxChars) return;
    _truncated = true;
    _text
      ..clear()
      ..write(all.substring(all.length - maxChars));
  }

  /// Waits until the output has been quiet for [quiet] after the first byte,
  /// or [max] has passed, whichever is first; then returns the text.
  Future<String> settle({
    required Duration max,
    Duration quiet = const Duration(milliseconds: 600),
  }) async {
    if (max > Duration.zero) {
      final done = Completer<void>();
      void finish() {
        if (!done.isCompleted) done.complete();
      }

      Timer? quietTimer;
      void restartQuiet() {
        quietTimer?.cancel();
        quietTimer = Timer(quiet, finish);
      }

      final maxTimer = Timer(max, finish);
      _onData = restartQuiet;
      if (_received) restartQuiet();
      await done.future;
      _onData = null;
      maxTimer.cancel();
      quietTimer?.cancel();
    }
    return text;
  }

  /// Everything so far, including the unfinished last line (often the
  /// prompt). Reading it ends that line.
  String get text {
    _text.write(_stripper.flush());
    _trim();
    return _text.toString();
  }
}

class _DecodedSink implements Sink<String> {
  _DecodedSink(this.onText);

  final void Function(String text) onText;

  @override
  void add(String data) => onText(data);

  @override
  void close() {}
}
