import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/error/error_logger.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/ssh/host_key.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/ui/feedback.dart';
import '../../core/util/responsive.dart';
import '../hosts/domain/ssh_host.dart';
import '../hosts/widgets/host_key_dialog.dart';
import '../hosts/widgets/secret_dialog.dart';
import 'session_manager.dart';

/// Opens a session to [host] and shows its terminal.
///
/// One function, called from every place that connects — the host list, a
/// row's menu, a keyboard shortcut — so the dialogs a connection can raise are
/// wired identically everywhere. Duplicating this per call site is how one
/// entry point ends up silently refusing unknown hosts because nobody
/// remembered to pass the handler.
Future<void> connectToHost(
  BuildContext context,
  WidgetRef ref,
  SshHost host,
) async {
  final manager = ref.read(sessionManagerProvider.notifier);

  final TerminalSession session;
  try {
    session = await manager.connect(
      host,
      onUnknownHostKey: (presentation) async {
        if (!context.mounted) return false;
        return showHostKeyDialog(context, presentation);
      },
      prompt: (request) async {
        if (!context.mounted) return null;
        return showSecretDialog(context, request);
      },
    );
  } on Object catch (error, stackTrace) {
    // Everything that can fail *before* a session exists lands here — reading
    // known hosts, resolving a jump chain, the first database touch. Without
    // this the future completes with an error nobody is listening to and the
    // tap simply does nothing, which is the single most confusing way for a
    // connection to fail.
    ErrorLogger.instance.record(error, stackTrace, source: 'connect');
    if (context.mounted) context.toast('$error');
    return;
  }

  if (!context.mounted) return;

  // A refused host key deserves its own explanation rather than a generic
  // failure line: for a *changed* key it is the most important thing this app
  // ever tells anyone, and it must not be mistaken for a network glitch.
  final rejection = session.hostKeyRejection;
  if (rejection != null && rejection.verdict == HostKeyVerdict.changed) {
    await showHostKeyChangedDialog(context, rejection.presentation);
    if (context.mounted) manager.close(session.id);
    return;
  }

  if (session.status == TerminalSessionStatus.failed) {
    context.toast(session.error ?? 'Could not connect');
  }

  if (!context.mounted) return;

  // Where a session opens depends on the form factor, because the two shapes
  // are genuinely different:
  //
  //  * Desktop has a workspace — sidebar, tabs, terminal — so connecting means
  //    switching to it. Pushing a full-screen route over it would throw away
  //    the tabs and the sidebar that are the point of having a desktop layout.
  //  * A phone has no room for all three, so the terminal is a page of its own.
  if (context.useRail) {
    context.goTo(Routes.sessions);
  } else {
    context.pushTo(Routes.terminalFor(session.id));
  }
}
