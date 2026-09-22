import 'package:xterm2/xterm.dart';

/// A [Terminal] that knows whether what it is sending was typed.
///
/// `onOutput` carries two kinds of traffic on one callback: what the user
/// typed or pasted, and what the terminal answers on its own — device
/// attributes, a cursor position report, focus in and out, mouse reports.
/// Broadcasting input to other panes must forward only the first kind: a
/// cursor-position reply meant for one shell is garbage typed into another.
///
/// So the four user-input entry points set [isUserInput] around the call, and
/// `onOutput` reads it. Done by subclassing here rather than by patching the
/// vendored package, which keeps its divergence from upstream to what
/// `VENDORED.md` lists.
class InputTrackingTerminal extends Terminal {
  InputTrackingTerminal({super.maxLines});

  var _depth = 0;

  /// True while a keystroke, typed text or a paste is being sent.
  bool get isUserInput => _depth > 0;

  T _tracking<T>(T Function() send) {
    _depth++;
    try {
      return send();
    } finally {
      _depth--;
    }
  }

  @override
  bool keyInput(
    TerminalKey key, {
    bool shift = false,
    bool alt = false,
    bool ctrl = false,
    bool superKey = false,
    bool capsLock = false,
    bool numLock = false,
    TerminalKeyEventType type = TerminalKeyEventType.press,
    String? text,
  }) => _tracking(
    () => super.keyInput(
      key,
      shift: shift,
      alt: alt,
      ctrl: ctrl,
      superKey: superKey,
      capsLock: capsLock,
      numLock: numLock,
      type: type,
      text: text,
    ),
  );

  @override
  bool charInput(int charCode, {bool alt = false, bool ctrl = false}) =>
      _tracking(() => super.charInput(charCode, alt: alt, ctrl: ctrl));

  @override
  void textInput(String text) => _tracking(() => super.textInput(text));

  @override
  void paste(String text) => _tracking(() => super.paste(text));
}
