import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm2/xterm.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/terminal/paste_sanitizer.dart';
import '../../core/ui/feedback.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/paste_confirm_dialog.dart';

/// Paste from the clipboard into the focused terminal.
///
/// Stands in for xterm2's `PasteTextIntent`, which its own actions answer by
/// sending the clipboard straight to the terminal. The pane remaps the paste
/// shortcuts to this intent so they reach [pasteClipboardInto] instead.
class TerminalPasteIntent extends Intent {
  const TerminalPasteIntent();
}

/// The one way text from the clipboard reaches a terminal.
///
/// Every paste path — the context menu, the keyboard shortcut, the phone's
/// long-press sheet — comes through here, so none of them can skip a step:
///
/// 1. [sanitizePaste] strips control bytes, escape sequences and invisible
///    direction marks.
/// 2. If what is left would press Enter, and the user has not turned the
///    question off, [PasteConfirmDialog] shows it first.
/// 3. `Terminal.paste` sends it, wrapped for bracketed paste when the remote
///    program asked for that.
///
/// The confirmation is asked even when bracketed paste is on. Bracketed paste
/// protects a program that understands it; a plain `sh` prompt, or a remote
/// shell that never enabled it, still runs the line the moment the newline
/// arrives. Whether to be asked is the user's setting, not a guess about the
/// remote side.
Future<void> pasteClipboardInto(
  BuildContext context,
  WidgetRef ref,
  Terminal terminal,
) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (text == null || text.isEmpty || !context.mounted) return;
  await pasteTextInto(context, ref, terminal, text);
}

/// Steps 1–3 of [pasteClipboardInto] for text already in hand. Returns
/// whether anything was sent.
Future<bool> pasteTextInto(
  BuildContext context,
  WidgetRef ref,
  Terminal terminal,
  String raw,
) async {
  final paste = sanitizePaste(raw);
  if (paste.text.isEmpty) {
    if (paste.removedCount > 0) {
      context.toast(
        AppLocalizations.of(context).pasteHiddenRemoved(paste.removedCount),
      );
    }
    return false;
  }

  final settings = ref.read(settingsControllerProvider);
  var confirmed = false;
  if (paste.executes && settings.confirmMultilinePaste) {
    final decision = await PasteConfirmDialog.show(context, paste);
    if (decision == null) return false;
    confirmed = true;
    if (decision.dontAskAgain) {
      ref
          .read(settingsControllerProvider.notifier)
          .setConfirmMultilinePaste(false);
    }
  }

  terminal.paste(paste.text);

  // The dialog already said so; without one, a toast is the only place the
  // user learns that what they pasted is not quite what they copied.
  if (!confirmed && paste.removedCount > 0 && context.mounted) {
    context.toast(
      AppLocalizations.of(context).pasteHiddenRemoved(paste.removedCount),
    );
  }
  return true;
}
