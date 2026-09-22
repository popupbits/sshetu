import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/format.dart';
import '../domain/text_document.dart';
import 'code_editor_field.dart';
import 'remote_file_editor_controller.dart';
import 'save_conflict_dialog.dart';

/// A remote text file, open for editing.
///
/// Takes its [controller] rather than building one: on a desktop the
/// controller outlives this widget (a workspace tab is rebuilt from scratch
/// every time it is selected), and on a phone the route that pushed this
/// owns it. Either way the edit is not lost to a rebuild.
class RemoteFileEditorScreen extends StatelessWidget {
  const RemoteFileEditorScreen({
    required this.controller,
    this.embedded = false,
    super.key,
  });

  final RemoteFileEditorController controller;

  /// True in a desktop workspace tab, which supplies the title and the way
  /// out; the actions move into a toolbar row instead of an app bar.
  final bool embedded;

  static const saveKey = ValueKey('editor-save');
  static const revertKey = ValueKey('editor-revert');
  static const dirtyKey = ValueKey('editor-dirty');

  /// The platform's own Save chord: Cmd+S on Apple platforms, Ctrl+S
  /// elsewhere. Bound only around the editor, so it never reaches a terminal
  /// — where Ctrl+S is XOFF — and never collides with Ctrl+Shift+S, which is
  /// the snippet picker.
  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ready = controller.status == EditorStatus.ready;
        final actions = ready ? _actions(context, l10n) : const <Widget>[];
        final title = _Title(controller: controller);

        final body = switch (controller.status) {
          EditorStatus.loading => const LoadingView(),
          EditorStatus.failed => _LoadFailure(controller: controller),
          EditorStatus.ready => CallbackShortcuts(
            bindings: {
              SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: _apple,
                control: !_apple,
              ): () =>
                  unawaited(save(context, controller)),
            },
            child: Column(
              children: [
                Expanded(child: CodeEditorField(controller: controller.text)),
                _StatusBar(controller: controller),
              ],
            ),
          ),
        };

        return Scaffold(
          appBar: embedded ? null : AppBar(title: title, actions: [...actions]),
          body: embedded
              ? Column(
                  children: [
                    _Toolbar(title: title, actions: actions),
                    const Divider(height: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
        );
      },
    );
  }

  List<Widget> _actions(BuildContext context, AppLocalizations l10n) {
    final chord = _apple ? '⌘S' : 'Ctrl+S';
    return [
      IconButton(
        key: revertKey,
        tooltip: l10n.editorRevert,
        icon: const Icon(PiconsRegular.arrowCounterClockwise),
        onPressed: controller.isDirty && !controller.isSaving
            ? controller.revert
            : null,
      ),
      IconButton(
        key: saveKey,
        tooltip: l10n.editorSaveTooltip(chord),
        icon: controller.isSaving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(PiconsRegular.floppyDisk),
        onPressed: controller.isDirty && !controller.isSaving
            ? () => unawaited(save(context, controller))
            : null,
      ),
      const SizedBox(width: Spacing.xs),
    ];
  }

  /// Saves, asking about a conflict with a dialog, and reports the outcome.
  static Future<void> save(
    BuildContext context,
    RemoteFileEditorController controller,
  ) async {
    if (!controller.isDirty || controller.isSaving) return;
    final l10n = AppLocalizations.of(context);
    final outcome = await controller.save(
      onConflict: () => showSaveConflictDialog(context, name: controller.name),
    );
    if (!context.mounted) return;
    switch (outcome) {
      case SaveOutcome.saved:
        context.toast(l10n.editorSaved(controller.name));
      case SaveOutcome.reloaded:
        context.toast(l10n.editorReloaded(controller.name));
      case SaveOutcome.failed:
        context.toast(
          controller.saveError ?? l10n.filesActionFailed,
          isError: true,
        );
      case SaveOutcome.cancelled || SaveOutcome.unchanged:
        break;
    }
  }
}

/// The file's name, with a dot when it has unsaved changes.
class _Title extends StatelessWidget {
  const _Title({required this.controller});

  final RemoteFileEditorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                controller.name,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (controller.isDirty) ...[
              const SizedBox(width: Spacing.sm),
              Tooltip(
                key: RemoteFileEditorScreen.dirtyKey,
                message: l10n.editorUnsaved,
                child: Icon(
                  PiconsRegular.circle,
                  size: 10,
                  color: theme.colorScheme.primary,
                  semanticLabel: l10n.editorUnsaved,
                ),
              ),
            ],
          ],
        ),
        Text(
          controller.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Mono.apply(theme.textTheme.labelSmall)
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.title, required this.actions});

  final Widget title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Spacing.lg,
      Spacing.xs,
      Spacing.xs,
      Spacing.xs,
    ),
    child: Row(
      children: [
        Expanded(child: title),
        ...actions,
      ],
    ),
  );
}

/// Encoding and line endings — what a save will write back, stated plainly.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final RemoteFileEditorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final document = controller.document;
    if (document == null) return const SizedBox.shrink();
    final ending = switch (document.lineEnding) {
      LineEnding.lf => l10n.editorLf,
      LineEnding.crlf => l10n.editorCrlf,
      LineEnding.mixed => l10n.editorMixedEndings,
    };
    final encoding = document.hasBom ? l10n.editorUtf8Bom : l10n.editorUtf8;
    final parts = [
      encoding,
      ending,
      if (controller.isDirty) l10n.editorUnsaved,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                parts.join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.controller});

  final RemoteFileEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = controller.name;
    final (
      IconData icon,
      String title,
      String message,
    ) = switch (controller.loadError) {
      EditorLoadError.tooLarge => (
        PiconsRegular.fileX,
        l10n.editorTooLargeTitle,
        l10n.editorTooLargeBody(name, humanFileSize(controller.maxBytes)),
      ),
      EditorLoadError.binary => (
        PiconsRegular.fileX,
        l10n.editorBinaryTitle,
        l10n.editorBinaryBody(name),
      ),
      EditorLoadError.notUtf8 => (
        PiconsRegular.fileX,
        l10n.editorNotUtf8Title,
        l10n.editorNotUtf8Body(name),
      ),
      EditorLoadError.notAFile => (
        PiconsRegular.folder,
        l10n.editorNotAFileTitle,
        l10n.editorNotAFileBody(name),
      ),
      EditorLoadError.sftp || null => (
        PiconsRegular.warning,
        l10n.editorLoadFailedTitle,
        controller.loadMessage ?? l10n.filesActionFailed,
      ),
    };
    final retryable =
        controller.loadError == EditorLoadError.sftp ||
        controller.loadError == null;
    return EmptyView(
      icon: icon,
      title: title,
      message: message,
      action: retryable
          ? OutlinedButton(
              onPressed: () => unawaited(controller.load()),
              child: Text(l10n.actionRetry),
            )
          : null,
    );
  }
}
