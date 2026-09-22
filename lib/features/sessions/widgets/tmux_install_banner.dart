import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/terminal/remote_shell.dart';
import '../../../core/terminal/terminal_session.dart';
import '../../hosts/domain/ssh_host.dart';
import '../../hosts/hosts_controller.dart';
import '../tmux_install_assistant.dart';
import 'tmux_install_prompt.dart';

/// The install offer for [session], when its server turned out to have no
/// tmux although tmux was wanted.
///
/// Appears only for a shell that fell back to plain because tmux was
/// missing — never for a host set to "never", and not again this run for a
/// host answered "Not now". The question is asked of the server (over exec,
/// read-only) the first time this is shown; nothing is installed without the
/// user choosing Install.
class TmuxInstallBanner extends ConsumerWidget {
  const TmuxInstallBanner({required this.session, super.key});

  final TerminalSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistants = ref.read(tmuxInstallAssistantsProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        // Nearly every tab: tmux was not wanted, or is there. Nothing is
        // watched and nothing is made for those.
        if (session.shellOrigin != ShellOrigin.plainWithoutTmux &&
            !assistants.has(session)) {
          return const SizedBox.shrink();
        }
        return _Offer(session: session);
      },
    );
  }
}

class _Offer extends ConsumerWidget {
  const _Offer({required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snoozed = ref.watch(
      tmuxInstallSnoozeProvider.select((s) => s.contains(session.hostId)),
    );
    // Nothing until the host is known: asking before its "never" has been
    // read would ask exactly the host that said not to.
    final hosts = ref.watch(hostsProvider).value;
    if (hosts == null) return const SizedBox.shrink();
    final host = hosts.where((h) => h.id == session.hostId).firstOrNull;
    if (snoozed || host?.tmuxMode == HostTmuxMode.never) {
      return const SizedBox.shrink();
    }

    final assistant = ref
        .read(tmuxInstallAssistantsProvider)
        .forSession(session);

    return ListenableBuilder(
      listenable: assistant,
      builder: (context, _) {
        final stage = assistant.stage;
        final origin = session.shellOrigin;
        final wanted = origin == ShellOrigin.plainWithoutTmux && session.isLive;
        if (stage is TmuxInstallIdle) {
          if (wanted) {
            // After the frame: detecting notifies, and a build must not.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => assistant.detect(),
            );
          }
          return const SizedBox.shrink();
        }
        // In tmux now — restarted from the tab's menu, say — so there is
        // nothing left to offer.
        if (origin == ShellOrigin.tmuxCreated ||
            origin == ShellOrigin.tmuxReattached) {
          return const SizedBox.shrink();
        }
        // The question is for a live plain shell; once asked and answered,
        // the progress and the result stay whatever the link is doing.
        if (stage is TmuxInstallOffered && !wanted) {
          return const SizedBox.shrink();
        }
        return TmuxInstallPrompt(
          stage: stage,
          hostLabel: host?.label ?? session.title,
          onInstall: assistant.install,
          onInstallWithUpdate: assistant.installWithUpdate,
          onNotNow: assistant.notNow,
          onNever: assistant.never,
          onRestart: assistant.restart,
          onDismiss: assistant.dismiss,
        );
      },
    );
  }
}
