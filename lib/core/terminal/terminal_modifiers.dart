import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';

/// Ctrl and Alt, held for exactly one keystroke.
///
/// A software keyboard has no Ctrl. Nobody can hold two keys at once on a
/// touch screen either, so a chord has to become a sequence: tap Ctrl, then C.
/// That is what the modifier bar promises, and this is the state behind it.
///
/// It is **shared, not local**, and that is the whole point. The first version
/// kept these two flags inside the bar's own [State], where they could only
/// ever affect keys tapped on the bar itself. A letter typed on the software
/// keyboard goes somewhere else entirely — into the terminal's own input path
/// — so the latch was invisible to it, and tapping Ctrl and then C on the
/// keyboard sent a literal `c`. On a terminal that means Ctrl-C, the one chord
/// nobody can do without, did nothing at all.
class TerminalModifiers extends ChangeNotifier {
  var _ctrl = false;
  var _alt = false;

  bool get ctrl => _ctrl;
  bool get alt => _alt;

  bool get isEmpty => !_ctrl && !_alt;

  void toggleCtrl() {
    _ctrl = !_ctrl;
    notifyListeners();
  }

  void toggleAlt() {
    _alt = !_alt;
    notifyListeners();
  }

  /// Releases both, the way a shift-once does.
  ///
  /// A modifier that stays down silently is a modifier that eats the next
  /// thing you type.
  void release() {
    if (isEmpty) return;
    _ctrl = false;
    _alt = false;
    notifyListeners();
  }
}

/// Applies a latched [TerminalModifiers] to whatever is typed next.
///
/// Installed on the [Terminal] itself rather than consulted at the keyboard
/// bar, so it sees **every** route into the terminal: the software keyboard,
/// the bar's own keys, and a hardware keyboard on a tablet alike.
///
/// It does not translate anything itself. It sets the flags on the event and
/// hands it to the standard chain, so a latched Ctrl-C produces byte-for-byte
/// what a hardware Ctrl-C produces — including everything the chain knows that
/// a hand-written mapping would not: DECBKM backspace, application keypad
/// mode, kitty and modifyOtherKeys encodings, the keytab. A phone and a laptop
/// then behave the same because they run the same code, not because two
/// implementations were kept in step.
class LatchedModifierInputHandler implements TerminalInputHandler {
  const LatchedModifierInputHandler(
    this.modifiers, {
    this.inner = defaultInputHandler,
  });

  final TerminalModifiers modifiers;

  /// The chain that does the real translation. Defaults to xterm's own.
  final TerminalInputHandler inner;

  @override
  String? call(TerminalKeyboardEvent event) {
    // Releases are not keystrokes; consuming a latch on one would eat the
    // modifier before the key it was meant for ever arrived.
    if (event.type == TerminalKeyEventType.release) return inner(event);

    if (modifiers.isEmpty) return inner(event);

    final ctrl = modifiers.ctrl;
    final alt = modifiers.alt;
    // Released before translating, not after: the chain can re-enter this
    // handler, and a latch still set at that point would apply twice.
    modifiers.release();

    return inner(
      event.copyWith(ctrl: event.ctrl || ctrl, alt: event.alt || alt),
    );
  }
}
