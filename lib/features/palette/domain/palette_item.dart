import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// What an action does once the palette has closed.
///
/// [context] is the one the palette was opened from — below the router and
/// its navigator — so an action can push a route, open a workspace tab or show
/// a dialog exactly as the button it mirrors would.
typedef PaletteRun = FutureOr<void> Function(
  BuildContext context,
  WidgetRef ref,
);

/// The kind of thing an item is. Drawn as a small label on the row, and part
/// of what a query matches: typing `tunnel` lists tunnels.
enum PaletteCategory { host, session, snippet, tunnel, setting, action }

/// One thing a palette item can do.
@immutable
class PaletteAction {
  const PaletteAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.run,
  });

  /// Stable within its item, for tests and keys.
  final String id;
  final String label;
  final IconData icon;
  final PaletteRun run;
}

/// A row in the command palette.
///
/// Items are contributed by per-feature sources (see `palette_registry.dart`)
/// and carry everything the palette needs to search, draw and run them — the
/// palette itself knows nothing about hosts or tunnels.
@immutable
class PaletteItem {
  const PaletteItem({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.actions,
    this.subtitle,
    this.keywords = const [],
  }) : assert(actions.length > 0, 'an item needs at least one action');

  /// Stable across launches, and all that is remembered about a recently used
  /// item: `host:<row id>`, `action:newHost`. Never a label, a hostname or
  /// anything typed — see `PaletteRecents`.
  final String id;

  final String title;
  final String? subtitle;
  final PaletteCategory category;
  final IconData icon;

  /// Extra words the item answers to without showing them.
  final List<String> keywords;

  /// The first is what Enter and a tap do; the rest are reached with Tab or
  /// by clicking their chip.
  final List<PaletteAction> actions;

  PaletteAction get primary => actions.first;

  @override
  String toString() => 'PaletteItem($id)';
}
