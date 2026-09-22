import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui/views.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/palette_item.dart';
import '../domain/palette_ranking.dart';
import '../palette_recents.dart';
import '../palette_registry.dart';
import '../palette_shortcuts.dart';
import 'palette_row.dart';

/// What the palette hands back when something is chosen: the item, for
/// remembering it, and the one of its actions to run.
@immutable
class PaletteChoice {
  const PaletteChoice(this.item, this.action);

  final PaletteItem item;
  final PaletteAction action;
}

/// The category's name in the user's language — drawn on each row, and part
/// of what a query matches.
String paletteCategoryLabel(AppLocalizations l10n, PaletteCategory category) =>
    switch (category) {
      PaletteCategory.host => l10n.paletteCategoryHost,
      PaletteCategory.session => l10n.paletteCategorySession,
      PaletteCategory.snippet => l10n.paletteCategorySnippet,
      PaletteCategory.tunnel => l10n.paletteCategoryTunnel,
      PaletteCategory.setting => l10n.paletteCategorySetting,
      PaletteCategory.action => l10n.paletteCategoryAction,
    };

/// The palette itself: a search field over every item the registered sources
/// contribute.
///
/// **Keyboard first.** The field has focus from the start and keeps it; ↑/↓
/// move the highlight, Enter runs the highlighted item's selected action, Tab
/// and Shift+Tab choose among its actions (shown as chips at the bottom), and
/// Esc — or the chord that opened it — closes it. Everything is also a tap.
///
/// Pops a [PaletteChoice], or null when dismissed. Running the choice is the
/// caller's job, after the route is gone — see `openCommandPalette` — so an
/// action that opens a dialog or pushes a page never does it on top of the
/// palette.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({this.fullScreen = false, super.key});

  /// On a phone: a close button beside the field, and no keyboard hint.
  final bool fullScreen;

  /// Whether one is on screen now. Counted by the widgets themselves rather
  /// than flagged by whoever opened one, so a palette torn down any way at
  /// all — popped, or its whole tree replaced — can never leave it stuck on.
  static bool get isShowing => _CommandPaletteState._live > 0;

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _query = TextEditingController();
  final _highlightKey = GlobalKey(debugLabel: 'palette highlight');
  var _highlight = 0;
  var _action = 0;

  static var _live = 0;

  @override
  void initState() {
    super.initState();
    _live++;
  }

  @override
  void dispose() {
    _live--;
    _query.dispose();
    super.dispose();
  }

  void _pick(PaletteItem item, PaletteAction action) =>
      Navigator.of(context).pop(PaletteChoice(item, action));

  void _close() => Navigator.of(context).pop();

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() {
      _highlight = (_highlight + delta).clamp(0, count - 1);
      _action = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _highlightKey.currentContext;
      if (row == null || !mounted) return;
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: delta > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void _cycleAction(PaletteItem? item, int delta) {
    if (item == null || item.actions.length < 2) return;
    final count = item.actions.length;
    setState(() => _action = (_action + delta) % count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = ref.watch(paletteItemsProvider(l10n));
    final recents = ref.watch(paletteRecentsProvider);
    final query = _query.text;
    final ranked = rankPaletteItems(
      items,
      query,
      recents: recents,
      categoryLabel: (c) => paletteCategoryLabel(l10n, c),
    );
    final highlight = ranked.isEmpty
        ? 0
        : _highlight.clamp(0, ranked.length - 1);
    final current = ranked.isEmpty ? null : ranked[highlight].item;
    final action = current == null
        ? 0
        : _action.clamp(0, current.actions.length - 1);

    final field = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _move(1, ranked.length),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(-1, ranked.length),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (current != null) _pick(current, current.actions[action]);
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (current != null) _pick(current, current.actions[action]);
        },
        const SingleActivator(LogicalKeyboardKey.tab): () =>
            _cycleAction(current, 1),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
            _cycleAction(current, -1),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        // The chord that opened it closes it, as in every editor.
        for (final activator in commandPaletteActivators()) activator: _close,
      },
      child: TextField(
        key: const Key('palette.search'),
        controller: _query,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) {
          // A phone's Go key; a hardware Enter is caught above first.
          if (current != null) _pick(current, current.actions[action]);
        },
        decoration: InputDecoration(
          hintText: l10n.paletteSearchHint,
          prefixIcon: const Icon(PiconsRegular.magnifyingGlass),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => setState(() {
          _highlight = 0;
          _action = 0;
        }),
      ),
    );

    final Widget results;
    if (ranked.isEmpty) {
      results = query.trim().isEmpty
          ? EmptyView(
              icon: PiconsRegular.magnifyingGlass,
              title: l10n.paletteEmptyTitle,
              message: l10n.paletteEmptyBody,
            )
          : EmptyView(
              key: const Key('palette.noResults'),
              icon: PiconsRegular.magnifyingGlass,
              title: l10n.paletteNoResults(query.trim()),
              message: l10n.paletteNoResultsBody,
            );
    } else {
      results = ListView.builder(
        key: const Key('palette.results'),
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        itemCount: ranked.length,
        itemBuilder: (context, i) {
          final row = PaletteRow(
            key: Key('palette.item.${ranked[i].item.id}'),
            ranked: ranked[i],
            highlighted: i == highlight,
            categoryLabel: paletteCategoryLabel(l10n, ranked[i].item.category),
            recentLabel: query.trim().isEmpty && ranked[i].recent
                ? l10n.paletteRecent
                : null,
            onTap: () => _pick(ranked[i].item, ranked[i].item.primary),
          );
          return i == highlight
              ? KeyedSubtree(key: _highlightKey, child: row)
              : row;
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            Spacing.sm,
          ),
          child: widget.fullScreen
              ? Row(
                  children: [
                    IconButton(
                      key: const Key('palette.close'),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      icon: const Icon(PiconsRegular.x),
                      onPressed: _close,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(child: field),
                  ],
                )
              : field,
        ),
        Expanded(child: results),
        if (current != null) ...[
          const Divider(height: 1),
          _ActionBar(
            item: current,
            selected: action,
            hint: context.usesSoftwareKeyboard || widget.fullScreen
                ? null
                : l10n.paletteKeyHint,
            onPick: (a) => _pick(current, a),
            textStyle: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The highlighted item's actions, as chips: the selected one is what Enter
/// runs, and any of them runs on a tap.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.item,
    required this.selected,
    required this.onPick,
    this.hint,
    this.textStyle,
  });

  final PaletteItem item;
  final int selected;
  final ValueChanged<PaletteAction> onPick;
  final String? hint;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < item.actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: Spacing.sm),
                  ChoiceChip(
                    key: Key('palette.action.${item.actions[i].id}'),
                    avatar: Icon(item.actions[i].icon, size: 16),
                    label: Text(item.actions[i].label),
                    selected: i == selected,
                    showCheckmark: false,
                    onSelected: (_) => onPick(item.actions[i]),
                  ),
                ],
              ],
            ),
          ),
          if (hint case final hint?) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              hint,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
