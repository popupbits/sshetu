import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/routes.dart';
import '../../core/ui/feedback.dart';
import '../../l10n/app_localizations.dart';
import '../sessions/open_in_workspace.dart';
import '../sessions/session_manager.dart';
import 'snippet_delivery.dart';
import 'snippet_editor_screen.dart';
import 'widgets/snippet_picker.dart';

/// Add or edit a snippet: a tab beside the terminal on a desktop, a route on
/// a phone — the same rule every other editor follows.
void openSnippetEditor(
  BuildContext context,
  WidgetRef ref, {
  String? snippetId,
}) => openInWorkspace(
  context,
  ref,
  id: 'snippet/${snippetId ?? 'new'}',
  title: (l10n) =>
      snippetId == null ? l10n.snippetEditorNew : l10n.snippetEditorEdit,
  icon: PiconsRegular.codeBlock,
  route: snippetId == null
      ? Routes.snippetNew
      : Routes.snippetEditFor(snippetId),
  builder: (_) => SnippetEditorScreen(snippetId: snippetId, embedded: true),
);

/// Opens the snippet picker bound to one open session.
///
/// [sessionId] is the pane that asked; without one — the menu bar, the
/// app-wide shortcut — it is the session the workspace is showing. The other
/// open tabs are offered too, for "Run on…".
///
/// Shared by every entry point — shortcut, menu, context menu, the phone's
/// app bar — so none of them can bind the picker to a different session.
Future<void> openSnippetPicker(
  BuildContext context,
  WidgetRef ref, {
  String? sessionId,
}) async {
  final manager = ref.read(sessionManagerProvider.notifier);
  final session =
      (sessionId == null ? null : manager.byId(sessionId)) ?? manager.active;
  if (session == null) {
    context.toast(AppLocalizations.of(context).snippetsNoSession);
    return;
  }

  await showSnippetPicker(
    context,
    ref,
    current: SnippetTarget.fromSession(session),
    targets: [
      for (final open in ref.read(sessionManagerProvider))
        SnippetTarget.fromSession(open),
    ],
  );
}
