import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/ui/feedback.dart';
import '../../l10n/app_localizations.dart';
import '../palette/domain/palette_item.dart';
import '../sessions/session_manager.dart';
import 'domain/snippet.dart';
import 'snippet_delivery.dart';
import 'snippets_controller.dart';
import 'use_snippet.dart';

/// Every saved snippet, run or inserted in the session in front.
///
/// Run is the primary action here, unlike the picker where a bare Enter
/// inserts: choosing a command by name from a palette is asking for it to
/// happen. Insert is one Tab away, and both go through [useSnippet] — the
/// same variable prompts and the same refusal of a multi-line insert the
/// picker applies.
final snippetPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>((ref, l10n) {
      final snippets = ref.watch(snippetsProvider).value ?? const <Snippet>[];
      return [
        for (final snippet in snippets)
          PaletteItem(
            id: 'snippet:${snippet.id}',
            title: snippet.label,
            subtitle: snippet.body.trim().split(RegExp('\r|\n')).first,
            category: PaletteCategory.snippet,
            icon: PiconsRegular.codeBlock,
            keywords: snippet.tags,
            actions: [
              PaletteAction(
                id: 'run',
                label: l10n.snippetRun,
                icon: PiconsRegular.play,
                run: (context, ref) => useSnippetInActiveSession(
                  context,
                  ref,
                  snippet,
                  SnippetAction.run,
                ),
              ),
              PaletteAction(
                id: 'insert',
                label: l10n.snippetInsert,
                icon: PiconsRegular.cursorText,
                run: (context, ref) => useSnippetInActiveSession(
                  context,
                  ref,
                  snippet,
                  SnippetAction.insert,
                ),
              ),
            ],
          ),
      ];
    });

/// Uses [snippet] in the session the workspace is showing, or says there is
/// none — the picker's message, so the two cannot disagree.
Future<void> useSnippetInActiveSession(
  BuildContext context,
  WidgetRef ref,
  Snippet snippet,
  SnippetAction action,
) async {
  final session = ref.read(sessionManagerProvider.notifier).active;
  if (session == null) {
    context.toast(AppLocalizations.of(context).snippetsNoSession);
    return;
  }
  await useSnippet(
    context,
    snippet: snippet,
    action: action,
    current: SnippetTarget.fromSession(session),
  );
}
