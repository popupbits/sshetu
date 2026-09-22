import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/error/error_logger.dart';
import '../../../core/providers.dart';
import '../../../core/router/navigation.dart';
import '../../../core/router/routes.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../hosts/domain/ssh_host.dart';
import '../connect.dart';
import '../session_manager.dart';
import '../workspace_restore.dart';

/// Whether this run has already offered to reopen last launch's tabs. Once
/// per process, however often the shell is rebuilt or remounted.
class WorkspaceRestoreGate {
  bool attempted = false;
}

final workspaceRestoreGateProvider = Provider<WorkspaceRestoreGate>(
  (ref) => WorkspaceRestoreGate(),
);

/// Reopens the terminal tabs that were open at the last exit — or offers to,
/// per Settings → Terminal → Reopen tabs on launch.
///
/// Each tab goes through [connectToHost], the same flow a tap on a host uses,
/// so a host key or a password is asked for in the ordinary dialog — one tab
/// at a time, never five dialogs at once (see [runRestore]). A tab kept in
/// tmux reattaches its session; one whose session has gone opens a new shell
/// and says so in the terminal.
class WorkspaceRestoreListener extends ConsumerStatefulWidget {
  const WorkspaceRestoreListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WorkspaceRestoreListener> createState() =>
      _WorkspaceRestoreListenerState();
}

class _WorkspaceRestoreListenerState
    extends ConsumerState<WorkspaceRestoreListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    final gate = ref.read(workspaceRestoreGateProvider);
    if (gate.attempted) return;
    gate.attempted = true;

    final choice = ref.read(settingsControllerProvider).effectiveReopenTabs;
    if (choice == ReopenTabs.never) return;

    final saved = ref.read(workspaceStoreProvider).read();
    if (saved == null || saved.isEmpty) return;

    try {
      final hosts = await ref.read(hostRepositoryProvider).all();
      final byId = {for (final host in hosts) host.id: host};
      final plan = planRestore(saved, byId.keys.toSet());
      if (plan.isEmpty || !mounted) return;

      if (choice == ReopenTabs.ask) {
        final accepted = await _ask(plan, byId);
        if (!accepted || !mounted) return;
      }
      await _restore(plan, byId);
    } on Object catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'restore');
    }
  }

  Future<bool> _ask(RestorePlan plan, Map<String, SshHost> hosts) async {
    final l10n = AppLocalizations.of(context);
    final labels = [for (final tab in plan.tabs) hosts[tab.hostId]!.label];
    var remember = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.restoreTabsTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.restoreTabsBody(plan.tabs.length, labels.join(', '))),
              CheckboxListTile(
                key: const Key('restoreTabs.remember'),
                value: remember,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.restoreTabsRemember),
                onChanged: (value) => setState(() => remember = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.restoreTabsNotNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.restoreTabsReopen),
            ),
          ],
        ),
      ),
    );
    if (accepted != null && remember) {
      ref
          .read(settingsControllerProvider.notifier)
          .setReopenTabs(accepted ? ReopenTabs.always : ReopenTabs.never);
    }
    return accepted ?? false;
  }

  Future<void> _restore(RestorePlan plan, Map<String, SshHost> hosts) async {
    final manager = ref.read(sessionManagerProvider.notifier);
    manager.beginRestore();
    final List<String?> ids;
    try {
      ids = await runRestore(
        plan,
        cancelled: () => !mounted,
        open: (tab) async {
          if (!mounted) return null;
          final session = await connectToHost(
            context,
            ref,
            hosts[tab.hostId]!,
            tmuxName: tab.tmuxName,
            resuming: tab.tmuxName != null,
            ownsTmuxSession: tab.ownsTmux,
            // Several tabs in a row: nothing navigates until they are all in.
            navigate: false,
            activate: false,
          );
          return session?.id;
        },
      );
    } finally {
      manager.endRestore();
    }

    final selected = plan.selected;
    final id = selected == null || selected >= ids.length
        ? null
        : ids[selected];
    if (id == null) return;
    manager.select(id);
    // A phone shows a terminal as a page; the desktop's is already on screen.
    if (mounted && !context.useRail) context.pushTo(Routes.terminalFor(id));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
