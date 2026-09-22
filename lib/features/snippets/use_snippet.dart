import 'package:material_ui/material_ui.dart';

import '../../core/ui/feedback.dart';
import '../../l10n/app_localizations.dart';
import 'domain/snippet.dart';
import 'domain/snippet_template.dart';
import 'snippet_delivery.dart';
import 'widgets/run_on_dialog.dart';
import 'widgets/snippet_variables_dialog.dart';

/// Uses [snippet] in [current], or — with [chooseTargets] — in whichever of
/// [targets] the user ticks.
///
/// The steps, each of which the user can back out of:
///
/// 1. With [chooseTargets], pick sessions ([RunOnDialog]). Always a Run: a
///    command typed into five prompts and left there is five chances to
///    press Enter on the wrong one later.
/// 2. If the body has user variables, ask for all of them at once
///    ([SnippetVariablesDialog]). Built-ins are filled per session, so each
///    server gets its own `{{host}}`.
/// 3. Type it ([deliverSnippet]) and say how it went, in a toast, when there
///    is anything to say.
///
/// Returns how many sessions it was typed into.
Future<int> useSnippet(
  BuildContext context, {
  required Snippet snippet,
  required SnippetAction action,
  required SnippetTarget current,
  List<SnippetTarget> targets = const [],
  bool chooseTargets = false,
  DateTime Function() clock = DateTime.now,
}) async {
  final l10n = AppLocalizations.of(context);

  var chosen = [current];
  var effectiveAction = action;
  if (chooseTargets) {
    final picked = await RunOnDialog.show(
      context,
      targets: targets.isEmpty ? [current] : targets,
      initial: {current.id},
    );
    if (picked == null || picked.isEmpty || !context.mounted) return 0;
    chosen = picked;
    effectiveAction = SnippetAction.run;
  }

  final template = SnippetTemplate.parse(snippet.body);
  final now = clock();
  final firstBuiltins = chosen.first.builtins(now);
  var values = const <String, String>{};
  final questions = template.userVariables(firstBuiltins);
  if (questions.isNotEmpty) {
    final answers = await SnippetVariablesDialog.show(
      context,
      variables: questions,
      action: effectiveAction,
      preview: (typed) =>
          template.render(builtins: firstBuiltins, values: typed),
    );
    if (answers == null || !context.mounted) return 0;
    values = answers;
  }

  if (!chooseTargets) {
    final result = deliverSnippet(
      current,
      template.render(builtins: firstBuiltins, values: values),
      effectiveAction,
    );
    final message = switch (result) {
      SnippetDeliveryResult.sent => null,
      SnippetDeliveryResult.notLive => l10n.snippetNotConnected,
      SnippetDeliveryResult.empty => l10n.snippetEmpty,
      SnippetDeliveryResult.multilineNeedsBracketedPaste =>
        l10n.snippetMultilineInsertRefused,
    };
    if (message != null && context.mounted) {
      context.toast(message, isError: true);
    }
    return result == SnippetDeliveryResult.sent ? 1 : 0;
  }

  final summary = deliverToMany(
    template,
    chosen,
    effectiveAction,
    values: values,
    now: now,
  );
  if (context.mounted) {
    context.toast(
      summary.skipped.isEmpty
          ? l10n.snippetRanIn(summary.sent.length)
          : l10n.snippetRanInSome(summary.sent.length, chosen.length),
      isError: summary.sent.isEmpty,
    );
  }
  return summary.sent.length;
}
