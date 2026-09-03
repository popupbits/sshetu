import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picons/picons.dart';

import '../../core/ssh/sftp_service.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../sessions/session_manager.dart';
import 'file_browser_controller.dart';
import 'widgets/local_pane.dart';
import 'widgets/remote_pane.dart';
import 'widgets/transfer_tile.dart';

/// The dual-pane SFTP browser for one live session.
///
/// Opened over the shell from a running terminal (see the folder action in
/// `TerminalScreen`'s app bar), never from a route reachable without one —
/// there is no host picker here, because the whole point is reusing the
/// session's already-authenticated connection rather than dialling in again.
class FileBrowserScreen extends ConsumerStatefulWidget {
  const FileBrowserScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  FileBrowserController? _controller;
  var _initStarted = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Deferred out of [initState]: the session is looked up from the current
  /// build, not cached at construction, so a session that closes mid-init is
  /// noticed rather than driving a controller into a dead connection.
  Future<void> _init(TerminalSession session) async {
    if (_initStarted) return;
    _initStarted = true;

    // Sandboxed but always writable, on every platform this app ships to —
    // the safe default starting point for "where do downloads land". A user
    // free to browse anywhere on desktop can still navigate elsewhere; this
    // only decides where the local pane opens.
    final docs = await getApplicationDocumentsDirectory();
    if (!mounted) return;

    // Mobile local storage, decided once here rather than left to whatever
    // `dart:io` happens to do:
    //
    // - iOS sandboxes every app to its own container. There is no "rest of
    //   the filesystem" to browse even in principle, so the honest answer is
    //   to scope the pane to the app's documents directory and say so, not
    //   to open a `Directory('/')` that lists nothing the user can act on.
    // - Android's scoped storage (API 30+, which is this app's floor) makes
    //   general filesystem access require either a manifest permission this
    //   app does not otherwise need, or the `MANAGE_EXTERNAL_STORAGE`
    //   special permission, which the Play Store only grants to apps whose
    //   *primary* purpose is file management. Neither is a fit for a
    //   terminal app that grew an SFTP browser. The directory `path_provider`
    //   already hands back needs no permission on either platform and is
    //   fully writable, so the two platforms get the same honest answer:
    //   scoped to the app's own storage, told to the user, rather than an
    //   empty root that reads like a bug.
    //
    // Desktop keeps the unrestricted filesystem it already had — none of the
    // above applies there.
    final isMobile = Platform.isIOS || Platform.isAndroid;

    final controller = FileBrowserController(
      sftp: SshSftpService(session.connection),
      localRoot: docs.path,
      localBoundary: isMobile ? docs.path : null,
    );
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);
    final session = sessions.where((s) => s.id == widget.sessionId).firstOrNull;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.filesTitle)),
        body: EmptyView(
          icon: PiconsRegular.folderOpen,
          title: l10n.filesNoSessionTitle,
          message: l10n.filesNoSessionBody,
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      unawaited(_init(session));
      return Scaffold(
        appBar: AppBar(title: Text(l10n.filesTitle)),
        body: const LoadingView(),
      );
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.filesTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                session.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: context.isCompact
                    ? _CompactBrowser(controller: controller)
                    : _WideBrowser(controller: controller),
              ),
              if (controller.transfers.isNotEmpty)
                _TransfersPanel(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

/// Side by side, for a tablet or desktop window wide enough to show both
/// panes and still let each one read as more than a sliver.
class _WideBrowser extends StatelessWidget {
  const _WideBrowser({required this.controller});

  final FileBrowserController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: RemotePane(controller: controller)),
      const VerticalDivider(width: 1),
      Expanded(child: LocalPane(controller: controller)),
    ],
  );
}

/// One pane at a time, switched with a segmented control — a phone has no
/// room for two file listings side by side. Transfers keep running and the
/// panel below stays visible regardless of which pane is showing, because a
/// transfer started from one pane is not something switching away should
/// hide.
class _CompactBrowser extends StatelessWidget {
  const _CompactBrowser({required this.controller});

  final FileBrowserController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            Spacing.xs,
          ),
          child: SegmentedButton<BrowserPane>(
            segments: [
              ButtonSegment(
                value: BrowserPane.remote,
                label: Text(l10n.filesRemote),
                icon: const Icon(PiconsRegular.hardDrives, size: 16),
              ),
              ButtonSegment(
                value: BrowserPane.local,
                label: Text(l10n.filesLocal),
                icon: const Icon(PiconsRegular.deviceMobile, size: 16),
              ),
            ],
            selected: {controller.activePane},
            onSelectionChanged: (selection) =>
                controller.selectPane(selection.first),
          ),
        ),
        Expanded(
          child: controller.activePane == BrowserPane.remote
              ? RemotePane(controller: controller)
              : LocalPane(controller: controller),
        ),
      ],
    );
  }
}

/// Active and recently finished transfers, whichever pane started them.
class _TransfersPanel extends StatelessWidget {
  const _TransfersPanel({required this.controller});

  final FileBrowserController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transfers = controller.transfers;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 160),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          shrinkWrap: true,
          itemCount: transfers.length,
          itemBuilder: (context, index) {
            final job = transfers[transfers.length - 1 - index];
            return TransferTile(
              job: job,
              onCancel: () => controller.cancelTransfer(job.id),
            );
          },
        ),
      ),
    );
  }
}
