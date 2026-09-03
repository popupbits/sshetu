import 'package:material_ui/material_ui.dart';

import '../util/responsive.dart';

/// Shows [child] only while a software keyboard is on screen.
///
/// Exists because "is the keyboard up?" cannot be answered by reading a
/// MediaQuery at the point where the answer is needed. A [Scaffold] that
/// resizes for the keyboard strips the bottom inset from the MediaQuery it
/// gives its body, so the accessory row — which lives at the bottom of that
/// body, directly above the keyboard — sees zero no matter what the keyboard
/// is doing. See [ResponsiveContext.isSoftwareKeyboardVisible].
///
/// The view's own insets are honest, but reading them creates no dependency,
/// so this listens for metrics changes and rebuilds itself. Keeping that in
/// one widget means a caller writes what it means and nothing else:
///
/// ```dart
/// if (context.usesSoftwareKeyboard)
///   KeyboardAccessory(child: TerminalKeyBar(onSend: session.send)),
/// ```
class KeyboardAccessory extends StatefulWidget {
  const KeyboardAccessory({required this.child, super.key});

  final Widget child;

  @override
  State<KeyboardAccessory> createState() => _KeyboardAccessoryState();
}

class _KeyboardAccessoryState extends State<KeyboardAccessory>
    with WidgetsBindingObserver {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fired for every keyboard show and hide, and for rotation and resize.
  @override
  void didChangeMetrics() => _sync();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The keyboard can already be up when this is first built — reopening a
    // session while typing, for instance.
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final visible = context.isSoftwareKeyboardVisible;
    if (visible != _visible) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : const SizedBox.shrink();
}
