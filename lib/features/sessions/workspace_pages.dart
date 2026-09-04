import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A workspace tab that is not a terminal.
///
/// The desktop layout's right-hand side is where work happens, and until now
/// only sessions could live there — so anything else (moving a configuration
/// to another device, browsing files) took over the whole window and the shell
/// someone was working in disappeared. On a desktop that is the wrong trade:
/// these are things you do *beside* a terminal, not instead of one.
class WorkspacePage {
  const WorkspacePage({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });

  /// Stable, so opening the same page twice selects the existing tab rather
  /// than stacking a second copy of it.
  final String id;

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// The non-terminal tabs currently open, and which one is showing.
///
/// Selection is deliberately split from [SessionManager]'s: sessions keep
/// their own active id, and this holds "a page is covering it". One of the two
/// is authoritative at a time, which is simpler to reason about than a single
/// list of mixed ids that every session-specific caller then has to filter.
class WorkspacePages extends Notifier<List<WorkspacePage>> {
  @override
  List<WorkspacePage> build() => const [];

  String? _selectedId;

  /// The page currently covering the terminal, if any.
  WorkspacePage? get selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final page in state) {
      if (page.id == id) return page;
    }
    return null;
  }

  /// Opens [page], or selects it if it is already open.
  void open(WorkspacePage page) {
    if (!state.any((existing) => existing.id == page.id)) {
      state = [...state, page];
    }
    _selectedId = page.id;
    ref.notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    ref.notifyListeners();
  }

  /// Returns to the terminal without closing anything.
  void deselect() {
    _selectedId = null;
    ref.notifyListeners();
  }

  void close(String id) {
    state = [
      for (final page in state)
        if (page.id != id) page,
    ];
    if (_selectedId == id) {
      // Falls back to whatever is left, then to the terminal — closing a tab
      // should never leave the workspace showing nothing.
      _selectedId = state.isEmpty ? null : state.last.id;
    }
  }
}

final workspacePagesProvider =
    NotifierProvider<WorkspacePages, List<WorkspacePage>>(WorkspacePages.new);
