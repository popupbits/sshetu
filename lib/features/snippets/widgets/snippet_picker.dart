import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/router/navigation.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/views.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/snippet.dart';
import '../domain/snippet_template.dart';
import '../open_snippets.dart';
import '../snippet_delivery.dart';
import '../snippets_controller.dart';
import '../use_snippet.dart';

/// What the picker was closed with.
sealed class SnippetPickerResult {
  const SnippetPickerResult();
}

/// Use this snippet.
class SnippetPicked extends SnippetPickerResult {
  const SnippetPicked(this.snippet, this.action, {this.chooseTargets = false});

  final Snippet snippet;
  final SnippetAction action;

  /// "Run on…": pick sessions before running.
  final bool chooseTargets;
}

/// Leave the picker for the Snippets screen or the editor.
class SnippetPickerNavigate extends SnippetPickerResult {
  const SnippetPickerNavigate({required this.create});

  /// True for "New snippet", false for "Manage snippets".
  final bool create;
}

/// Shows the picker bound to [current], then does what it was closed with.
///
/// A dialog where there is a pointer and room; a tall sheet on a phone, where
/// a dialog would sit under the software keyboard.
Future<void> showSnippetPicker(
  BuildContext context,
  WidgetRef ref, {
  required SnippetTarget current,
  List<SnippetTarget> targets = const [],
}) async {
  final others = targets.where((t) => t.id != current.id && t.isLive);
  final picker = SnippetPicker(
    sessionTitle: current.title,
    canRunOnOthers: others.isNotEmpty,
  );

  final sheet = context.usesSoftwareKeyboard || context.isCompact;
  final result = sheet
      ? await showModalBottomSheet<SnippetPickerResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FractionallySizedBox(heightFactor: 0.8, child: picker),
          ),
        )
      : await showDialog<SnippetPickerResult>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
              child: picker,
            ),
          ),
        );

  if (result == null || !context.mounted) return;
  switch (result) {
    case SnippetPicked(:final snippet, :final action, :final chooseTargets):
      await useSnippet(
        context,
        snippet: snippet,
        action: action,
        current: current,
        targets: targets,
        chooseTargets: chooseTargets,
      );
    case SnippetPickerNavigate(:final create):
      if (create) {
        openSnippetEditor(context, ref);
      } else {
        context.goTo(Routes.snippets);
      }
  }
}

/// The list itself: search, a row per snippet, Insert and Run.
///
/// **Keyboard first on a desktop.** The search field has focus the moment the
/// picker opens; ↑/↓ move the highlight, Enter inserts, and Cmd/Ctrl+Enter
/// runs. Insert is the one on the bare key because it is the one that cannot
/// do anything by accident.
class SnippetPicker extends ConsumerStatefulWidget {
  const SnippetPicker({
    required this.sessionTitle,
    this.canRunOnOthers = false,
    super.key,
  });

  /// Which tab the snippet will go to, shown in the header.
  final String sessionTitle;

  /// Whether "Run on…" is worth offering — there is another live tab.
  final bool canRunOnOthers;

  @override
  ConsumerState<SnippetPicker> createState() => _SnippetPickerState();
}

class _SnippetPickerState extends ConsumerState<SnippetPicker> {
  final _query = TextEditingController();
  var _highlight = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Snippet> _visible(List<Snippet> all) =>
      all.where((s) => s.matches(_query.text)).toList();

  void _pick(Snippet snippet, SnippetAction action, {bool choose = false}) =>
      Navigator.of(context)
          .pop(SnippetPicked(snippet, action, chooseTargets: choose));

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _highlight = (_highlight + delta).clamp(0, count - 1));
  }

  static bool get _usesMeta => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snippets = ref.watch(snippetsProvider);
    final all = snippets.value ?? const <Snippet>[];
    final visible = _visible(all);
    final highlight = visible.isEmpty
        ? 0
        : _highlight.clamp(0, visible.length - 1);

    void pickHighlighted(SnippetAction action) {
      if (visible.isEmpty) return;
      _pick(visible[highlight], action);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            Spacing.xs,
          ),
          child: Text(
            l10n.snippetPickerTitle(widget.sessionTitle),
            style: theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm,
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _move(1, visible.length),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _move(-1, visible.length),
              const SingleActivator(LogicalKeyboardKey.enter): () =>
                  pickHighlighted(SnippetAction.insert),
              SingleActivator(
                LogicalKeyboardKey.enter,
                meta: _usesMeta,
                control: !_usesMeta,
              ): () =>
                  pickHighlighted(SnippetAction.run),
            },
            child: TextField(
              key: const Key('snippetPicker.search'),
              controller: _query,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: l10n.snippetsSearch,
                prefixIcon: const Icon(PiconsRegular.magnifyingGlass),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _highlight = 0),
            ),
          ),
        ),
        Flexible(
          child: snippets.isLoading && all.isEmpty
              ? const LoadingView()
              : visible.isEmpty
              ? _PickerEmpty(searching: _query.text.trim().isNotEmpty)
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, i) => _PickerRow(
                    snippet: visible[i],
                    highlighted: i == highlight,
                    canRunOnOthers: widget.canRunOnOthers,
                    onPick: _pick,
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context)
                        .pop(const SnippetPickerNavigate(create: false)),
                icon: const Icon(PiconsRegular.listBullets, size: 18),
                label: Text(l10n.snippetPickerManage),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context)
                        .pop(const SnippetPickerNavigate(create: true)),
                icon: const Icon(PiconsRegular.plus, size: 18),
                label: Text(l10n.snippetsAdd),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerEmpty extends StatelessWidget {
  const _PickerEmpty({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyView(
      icon: searching ? PiconsRegular.magnifyingGlass : PiconsRegular.codeBlock,
      title: searching ? l10n.snippetsNoMatch : l10n.snippetsEmptyTitle,
      message: searching ? null : l10n.snippetsEmptyBody(SnippetSyntax.example),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.snippet,
    required this.highlighted,
    required this.canRunOnOthers,
    required this.onPick,
  });

  final Snippet snippet;
  final bool highlighted;
  final bool canRunOnOthers;
  final void Function(Snippet, SnippetAction, {bool choose}) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final firstLine = snippet.body.trim().split(RegExp('\r|\n')).first;

    return ListTile(
      key: Key('snippetPicker.row.${snippet.id}'),
      selected: highlighted,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      dense: true,
      // A tap inserts: the action that cannot run anything by accident.
      onTap: () => onPick(snippet, SnippetAction.insert),
      title: Text(snippet.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        snippet.isMultiline ? '$firstLine …' : firstLine,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Mono.apply(theme.textTheme.bodySmall)
            .copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('snippetPicker.insert.${snippet.id}'),
            tooltip: l10n.snippetInsert,
            icon: const Icon(PiconsRegular.cursorText, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () => onPick(snippet, SnippetAction.insert),
          ),
          IconButton(
            key: Key('snippetPicker.run.${snippet.id}'),
            tooltip: l10n.snippetRun,
            icon: const Icon(PiconsRegular.play, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () => onPick(snippet, SnippetAction.run),
          ),
          if (canRunOnOthers)
            IconButton(
              key: Key('snippetPicker.runOn.${snippet.id}'),
              tooltip: l10n.snippetRunOn,
              icon: const Icon(PiconsRegular.stack, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => onPick(snippet, SnippetAction.run, choose: true),
            ),
        ],
      ),
    );
  }
}
