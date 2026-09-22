import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/terminal/terminal_session.dart';
import '../../core/ui/feedback.dart';
import '../../l10n/app_localizations.dart';
import 'session_manager.dart';

/// "Restart in tmux" from a tab's menu: asks first, because the plain shell
/// and whatever is running in it end, then reopens the tab inside tmux.
///
/// For after tmux was installed by hand — typed into the terminal behind a
/// sudo password — or for a tab opened without tmux that should now survive
/// a drop.
Future<void> confirmRestartInTmux(
  BuildContext context,
  WidgetRef ref,
  TerminalSession session,
) async {
  final l10n = AppLocalizations.of(context);
  final ok = await context.confirm(
    title: l10n.tmuxRestartConfirmTitle,
    message: l10n.tmuxRestartConfirmBody,
    confirmLabel: l10n.tmuxRestartConfirmAction,
    cancelLabel: l10n.actionCancel,
    isDestructive: true,
  );
  if (!ok) return;
  await ref.read(sessionManagerProvider.notifier).restartInTmux(session.id);
}
