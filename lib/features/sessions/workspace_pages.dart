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
    this.confirmClose,
  });

  /// Stable, so opening the same page twice selects the existing tab rather
  /// than stacking a second copy of it.
  final String id;

  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  /// Asked before the tab closes; false keeps it open. For a page holding
  /// work that closing would throw away — an editor with unsaved changes.
  /// Null closes without asking.
  final Future<bool> Function(BuildContext context)? confirmClose;
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

  /// Closes [id] as the user asked to: through the page's [WorkspacePage.
  /// confirmClose] first, so a tab holding unsaved work is not discarded by
  /// a click on its ×. Every user-facing close goes through here; [close] is
  /// for code that has already decided.
  Future<void> requestClose(BuildContext context, String id) async {
    final page = state.where((p) => p.id == id).firstOrNull;
    if (page == null) return;
    final confirm = page.confirmClose;
    if (confirm != null && !await confirm(context)) return;
    close(id);
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

/// Tells a screen that it is showing as the workspace tab [id].
///
/// A screen opened with `openInWorkspace` is a route on a phone and a tab on a
/// desktop, and "I am done" means a different thing in each: pop the route, or
/// close the tab. `Navigator.maybePop` only knows the first — inside a tab it
/// finds the shell's navigator, has nothing to pop, and quietly does nothing,
/// so a saved form stayed open and a second Save wrote a second copy. See
/// `closeOpenedScreen`.
class WorkspacePageScope extends InheritedWidget {
  const WorkspacePageScope({required this.id, required super.child, super.key});

  final String id;

  /// The tab [context] is showing in, or null when it is not in one.
  static String? idOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WorkspacePageScope>()?.id;

  @override
  bool updateShouldNotify(WorkspacePageScope oldWidget) => oldWidget.id != id;
}
