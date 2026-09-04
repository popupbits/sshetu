import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/navigation.dart';
import '../../core/util/responsive.dart';
import 'workspace_pages.dart';

/// Opens a screen where it belongs on this form factor.
///
/// On a desktop that is a **tab in the workspace**, beside the terminals.
/// Editing a host, adding a tunnel or reading a fingerprint are things you do
/// *next to* a shell, and a full-screen route takes the session someone is
/// working in off the screen to show them a form. That is the wrong trade on a
/// window wide enough to hold both — and it is why the workspace exists.
///
/// On a phone there is only ever one thing on screen, so it stays a route.
/// Same call site either way: the caller says what it wants opened, not where.
void openInWorkspace(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String title,
  required IconData icon,
  required String route,
  required WidgetBuilder builder,
}) {
  if (!context.useRail) {
    context.pushTo(route);
    return;
  }
  ref
      .read(workspacePagesProvider.notifier)
      .open(WorkspacePage(id: id, title: title, icon: icon, builder: builder));
}
