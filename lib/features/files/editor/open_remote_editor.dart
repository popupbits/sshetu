import 'dart:async';

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/ssh/sftp_service.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../sessions/workspace_pages.dart';
import 'remote_file_editor_controller.dart';
import 'remote_file_editor_screen.dart';

/// Opens [path] in the text editor, where it belongs on this form factor —
/// the same rule `openInWorkspace` applies to every other screen: a tab
/// beside the terminal on a desktop, a full-screen route on a phone.
///
/// Not `openInWorkspace` itself because that needs a go_router path for the
/// phone case, and an open file is not something a URL can name: it is a
/// live SFTP channel and an unsaved buffer. The phone gets an imperative
/// route instead, which owns the editor and asks before discarding edits.
///
/// [sftp] builds the editor's own channel — see
/// [RemoteFileEditorController.ownsSftp] for why it does not borrow the file
/// browser's.
void openRemoteEditor(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required String path,
  required SftpService Function() sftp,
}) {
  if (!context.useRail) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RemoteEditorRoute(
            create: () => RemoteFileEditorController(sftp: sftp(), path: path),
          ),
        ),
      ),
    );
    return;
  }

  final id = 'edit/$sessionId:$path';
  final registry = ref.read(remoteEditorsProvider);
  registry.obtain(
    id,
    () => RemoteFileEditorController(sftp: sftp(), path: path)..load(),
  );
  final name = path.substring(path.lastIndexOf('/') + 1);
  ref
      .read(workspacePagesProvider.notifier)
      .open(
        WorkspacePage(
          id: id,
          title: name,
          icon: PiconsRegular.fileText,
          builder: (_) => _EditorTab(id: id),
          // The phone route asks before discarding; a desktop tab's × must
          // not be the one way to lose an edit without a word.
          confirmClose: (context) async {
            final controller = registry[id];
            if (controller == null || !controller.isDirty) return true;
            final l10n = AppLocalizations.of(context);
            return context.confirm(
              title: l10n.editorDiscardTitle,
              message: l10n.editorDiscardBody(controller.name),
              confirmLabel: l10n.editorDiscard,
              cancelLabel: l10n.actionCancel,
              isDestructive: true,
            );
          },
        ),
      );
}

/// The editor controllers behind open desktop tabs, keyed by page id.
///
/// A workspace tab's widget is rebuilt from nothing every time it is
/// selected, so an editor's buffer cannot live in the widget — switching to
/// the terminal and back would throw the edit away. It lives here instead,
/// and is disposed when its tab closes.
class RemoteEditorRegistry {
  final Map<String, RemoteFileEditorController> _open = {};

  RemoteFileEditorController? operator [](String id) => _open[id];

  /// The controller for [id], creating it with [create] the first time.
  RemoteFileEditorController obtain(
    String id,
    RemoteFileEditorController Function() create,
  ) => _open[id] ??= create();

  /// Disposes every controller whose tab is no longer open.
  ///
  /// After the frame, not now: the tab being closed is still in the tree
  /// until the next build, and its text field must not outlive the
  /// controller it is listening to.
  void retain(Set<String> openIds) {
    final closed = _open.keys.where((id) => !openIds.contains(id)).toList();
    if (closed.isEmpty) return;
    final gone = [for (final id in closed) _open.remove(id)!];
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        for (final controller in gone) {
          controller.dispose();
        }
      })
      ..scheduleFrame();
  }

  void disposeAll() {
    for (final controller in _open.values) {
      controller.dispose();
    }
    _open.clear();
  }
}

final remoteEditorsProvider = Provider<RemoteEditorRegistry>((ref) {
  final registry = RemoteEditorRegistry();
  ref
    ..listen(
      workspacePagesProvider,
      (_, pages) => registry.retain({for (final page in pages) page.id}),
    )
    ..onDispose(registry.disposeAll);
  return registry;
});

class _EditorTab extends ConsumerWidget {
  const _EditorTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(remoteEditorsProvider)[id];
    if (controller == null) return const SizedBox.shrink();
    return RemoteFileEditorScreen(controller: controller, embedded: true);
  }
}

/// The phone's editor: a full-screen route that owns its controller, and
/// asks before a back gesture throws unsaved edits away.
class RemoteEditorRoute extends StatefulWidget {
  const RemoteEditorRoute({required this.create, super.key});

  final RemoteFileEditorController Function() create;

  @override
  State<RemoteEditorRoute> createState() => _RemoteEditorRouteState();
}

class _RemoteEditorRouteState extends State<RemoteEditorRoute> {
  late final RemoteFileEditorController _controller = widget.create();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final discard = await context.confirm(
      title: l10n.editorDiscardTitle,
      message: l10n.editorDiscardBody(_controller.name),
      confirmLabel: l10n.editorDiscard,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (discard && mounted) {
      _controller.revert();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PopScope(
      canPop: !_controller.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: RemoteFileEditorScreen(controller: _controller),
    ),
  );
}
