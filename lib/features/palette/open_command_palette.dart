import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/util/responsive.dart';
import 'palette_recents.dart';
import 'widgets/command_palette.dart';

/// Shows the palette where it belongs on this form factor: a centred dialog
/// no wider than 640 on a desktop or tablet, the whole screen on a phone.
Future<PaletteChoice?> showCommandPalette(BuildContext context) {
  if (context.isCompact) {
    return showDialog<PaletteChoice>(
      context: context,
      builder: (_) => const Dialog.fullscreen(
        child: SafeArea(child: CommandPalette(fullScreen: true)),
      ),
    );
  }
  return showDialog<PaletteChoice>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _PaletteSize.maxWidth,
          maxHeight: _PaletteSize.maxHeight,
        ),
        child: const CommandPalette(),
      ),
    ),
  );
}

abstract final class _PaletteSize {
  /// Wide enough for a label, an address and a category on one row; narrow
  /// enough to read as a prompt rather than a page.
  static const double maxWidth = 640;
  static const double maxHeight = 520;
}

/// Opens the command palette and runs what is chosen.
///
/// Shared by every entry point — the shortcuts, the View menu, the phone's
/// search button — so none of them can run a choice differently.
///
/// **Focus goes back where it was.** Whatever had the keyboard before —
/// almost always a terminal — is given it back as soon as the palette closes,
/// chosen or not, and *before* the choice runs: an action that opens a page or
/// a dialog then takes focus for itself, and one that types into the terminal
/// (a snippet) finds the keyboard already there.
///
/// [context] must be below the router's navigator; the choice runs against it.
Future<void> openCommandPalette(BuildContext context, WidgetRef ref) async {
  // A second chord while one is up does not stack another.
  if (CommandPalette.isShowing) return;
  final previous = FocusManager.instance.primaryFocus;
  final choice = await showCommandPalette(context);
  if (!context.mounted) return;

  if (previous != null &&
      previous.context != null &&
      previous.canRequestFocus) {
    previous.requestFocus();
  }
  if (choice == null) return;

  ref.read(paletteRecentsProvider.notifier).record(choice.item.id);
  await choice.action.run(context, ref);
}
