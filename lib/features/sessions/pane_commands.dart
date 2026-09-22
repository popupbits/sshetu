import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/providers.dart';
import '../../core/router/router.dart' show rootNavigatorKey;
import '../../core/ui/context_menu.dart';
import '../../l10n/app_localizations.dart';
import 'connect.dart';
import 'pane_layouts.dart';
import 'pane_tree.dart';
import 'session_manager.dart';
import 'workspace_pages.dart';

/// What can be done to the panes of a split tab from the keyboard or a menu.
enum PaneCommand { splitRight, splitDown, close, next, previous, maximize }

class PaneCommandIntent extends Intent {
  const PaneCommandIntent(this.command);

  final PaneCommand command;
}

/// The chord for [command].
///
/// **macOS** takes iTerm2's: Cmd+D and Cmd+Shift+D to split, Cmd+Option+→ and
/// ← to move between panes, Cmd+Shift+Enter to maximize — Command is never a
/// key a shell sees. **Windows and Linux** take Terminator's, the split
/// terminal people there already know: Ctrl+Shift+E and O to split,
/// Ctrl+Shift+W to close a pane, Ctrl+Shift+X to maximize. Always shifted:
/// a plain Ctrl letter has to keep reaching the shell. Next and previous are
/// Ctrl+Shift+→ and ←, because Terminator's N and P collide with the chord
/// every command palette uses, and Ctrl+Shift+↑ and ↓ are the terminal's own
/// prompt navigation.
///
/// None of them collides with a tab, find, snippet or terminal binding;
/// `test/sessions/pane_shortcuts_test.dart` checks that rather than trusting
/// this comment. "Type in all panes" deliberately has no chord: a
/// mistyped shortcut must not start sending keystrokes to every server.
SingleActivator paneActivator(PaneCommand command) {
  final mac = defaultTargetPlatform == TargetPlatform.macOS;
  return switch (command) {
    PaneCommand.splitRight =>
      mac
          ? const SingleActivator(LogicalKeyboardKey.keyD, meta: true)
          : const SingleActivator(
              LogicalKeyboardKey.keyE,
              control: true,
              shift: true,
            ),
    PaneCommand.splitDown =>
      mac
          ? const SingleActivator(
              LogicalKeyboardKey.keyD,
              meta: true,
              shift: true,
            )
          : const SingleActivator(
              LogicalKeyboardKey.keyO,
              control: true,
              shift: true,
            ),
    PaneCommand.close => SingleActivator(
      LogicalKeyboardKey.keyW,
      meta: mac,
      control: !mac,
      shift: true,
    ),
    PaneCommand.next => SingleActivator(
      LogicalKeyboardKey.arrowRight,
      meta: mac,
      alt: mac,
      control: !mac,
      shift: !mac,
    ),
    PaneCommand.previous => SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      meta: mac,
      alt: mac,
      control: !mac,
      shift: !mac,
    ),
    PaneCommand.maximize =>
      mac
          ? const SingleActivator(
              LogicalKeyboardKey.enter,
              meta: true,
              shift: true,
            )
          : const SingleActivator(
              LogicalKeyboardKey.keyX,
              control: true,
              shift: true,
            ),
  };
}

/// Every pane chord. Installed app-wide by `SessionShortcuts`, and in the
/// terminal view's own map too — a focused terminal answers Ctrl chords
/// before its ancestors are asked, so without that they would go to the
/// shell.
Map<ShortcutActivator, Intent> paneShortcutMap() => {
  for (final command in PaneCommand.values)
    paneActivator(command): PaneCommandIntent(command),
};

/// Runs [command] on the active pane. Shared by the shortcuts, the menu bar
/// and the context menus, so none of them can mean something different.
void runPaneCommand(BuildContext context, WidgetRef ref, PaneCommand command) {
  final manager = ref.read(sessionManagerProvider.notifier);
  switch (command) {
    case PaneCommand.splitRight:
      unawaited(splitActivePane(context, ref, SplitAxis.horizontal));
    case PaneCommand.splitDown:
      unawaited(splitActivePane(context, ref, SplitAxis.vertical));
    case PaneCommand.close:
      final id = manager.activeId;
      if (id != null) manager.close(id);
    case PaneCommand.next:
      manager.cyclePane(1);
    case PaneCommand.previous:
      manager.cyclePane(-1);
    case PaneCommand.maximize:
      final id = manager.activeId;
      if (id != null) ref.read(paneLayoutsProvider.notifier).toggleMaximize(id);
  }
}

/// Splits the active pane, opening a new session to the same host beside or
/// below it.
///
/// Through [connectToHost], the flow every connection takes, so a host key
/// or a password is asked for in the same dialogs — a split is a second
/// connection, not a second view of the first one, and it authenticates like
/// one.
Future<void> splitActivePane(
  BuildContext context,
  WidgetRef ref,
  SplitAxis axis, {
  String? target,
}) async {
  final manager = ref.read(sessionManagerProvider.notifier);
  final source = target == null ? manager.active : manager.byId(target);
  if (source == null) return;
  final host = await ref.read(hostRepositoryProvider).byId(source.hostId);
  if (host == null || !context.mounted) return;
  // A page covering the terminal would hide the pane just asked for.
  ref.read(workspacePagesProvider.notifier).deselect();
  await connectToHost(
    context,
    ref,
    host,
    navigate: false,
    split: PaneSplitRequest(target: source.id, axis: axis),
  );
}

/// Turns "type in all panes" on or off for the tab [member] is in.
void toggleBroadcast(WidgetRef ref, String member) {
  final layouts = ref.read(paneLayoutsProvider.notifier);
  final tree = layouts.treeFor(member);
  if (tree != null) layouts.setBroadcast(member, !tree.broadcast);
}

/// The pane entries of a session tab's context menu.
List<MenuAction> paneTabMenuActions(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) {
  final l10n = AppLocalizations.of(context);
  final tree = ref.read(paneLayoutsProvider.notifier).treeFor(sessionId);
  return [
    MenuAction(
      label: l10n.paneSplitRight,
      icon: PiconsRegular.columns,
      onSelected: () => unawaited(
        splitActivePane(
          context,
          ref,
          SplitAxis.horizontal,
          target: tree?.focused ?? sessionId,
        ),
      ),
    ),
    MenuAction(
      label: l10n.paneSplitDown,
      icon: PiconsRegular.rows,
      onSelected: () => unawaited(
        splitActivePane(
          context,
          ref,
          SplitAxis.vertical,
          target: tree?.focused ?? sessionId,
        ),
      ),
    ),
    if (tree != null)
      MenuAction(
        label: tree.broadcast ? l10n.paneStopTypingInAll : l10n.paneTypeInAll,
        icon: PiconsRegular.broadcast,
        isDestructive: !tree.broadcast,
        onSelected: () => toggleBroadcast(ref, sessionId),
      ),
  ];
}

/// The pane items of the menu bar's Session menu.
PlatformMenuItemGroup paneMenuGroup(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  ref.watch(sessionManagerProvider);
  final layouts = ref.watch(paneLayoutsProvider);
  final active = ref.read(sessionManagerProvider.notifier).activeId;
  final tree = active == null
      ? null
      : layouts.where((t) => t.contains(active)).firstOrNull;
  // Shown from the navigator's context: this bar sits above the router, and
  // a split may raise a host-key or password dialog.
  BuildContext dialogs() => rootNavigatorKey.currentContext ?? context;
  VoidCallback? run(PaneCommand command, {bool enabled = true}) =>
      active != null && enabled
      ? () => runPaneCommand(dialogs(), ref, command)
      : null;

  return PlatformMenuItemGroup(
    members: [
      PlatformMenuItem(
        label: l10n.menuSplitRight,
        shortcut: paneActivator(PaneCommand.splitRight),
        onSelected: run(PaneCommand.splitRight),
      ),
      PlatformMenuItem(
        label: l10n.menuSplitDown,
        shortcut: paneActivator(PaneCommand.splitDown),
        onSelected: run(PaneCommand.splitDown),
      ),
      PlatformMenuItem(
        label: l10n.menuClosePane,
        shortcut: paneActivator(PaneCommand.close),
        onSelected: run(PaneCommand.close),
      ),
      PlatformMenuItem(
        label: l10n.menuNextPane,
        shortcut: paneActivator(PaneCommand.next),
        onSelected: run(PaneCommand.next, enabled: tree != null),
      ),
      PlatformMenuItem(
        label: l10n.menuPreviousPane,
        shortcut: paneActivator(PaneCommand.previous),
        onSelected: run(PaneCommand.previous, enabled: tree != null),
      ),
      PlatformMenuItem(
        label: l10n.menuMaximizePane,
        shortcut: paneActivator(PaneCommand.maximize),
        onSelected: run(PaneCommand.maximize, enabled: tree != null),
      ),
      PlatformMenuItem(
        label: tree?.broadcast ?? false
            ? l10n.menuStopTypingInAllPanes
            : l10n.menuTypeInAllPanes,
        onSelected: tree == null || active == null
            ? null
            : () => toggleBroadcast(ref, active),
      ),
    ],
  );
}
