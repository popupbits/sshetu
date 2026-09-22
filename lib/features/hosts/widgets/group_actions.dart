import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/host_group.dart';
import '../hosts_controller.dart';
import 'group_name_dialog.dart';

/// Asks for a name and creates the group. Null when cancelled.
///
/// Shared by the host list and the host editor, so "New group…" behaves the
/// same wherever it is offered.
Future<HostGroup?> createGroupFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final name = await showGroupNameDialog(
    context,
    title: l10n.hostsNewGroup,
    confirmLabel: l10n.hostGroupCreate,
  );
  if (name == null) return null;
  return ref.read(hostsControllerProvider).createGroup(name);
}

Future<void> renameGroupFlow(
  BuildContext context,
  WidgetRef ref,
  HostGroup group,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await showGroupNameDialog(
    context,
    title: l10n.hostGroupRename,
    confirmLabel: l10n.hostGroupRenameAction,
    initial: group.name,
  );
  if (name == null || name == group.name) return;
  await ref.read(hostsControllerProvider).renameGroup(group, name);
}

/// Confirms, then deletes the group. Its hosts are moved out, never deleted.
Future<void> deleteGroupFlow(
  BuildContext context,
  WidgetRef ref,
  HostGroup group,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await context.confirm(
    title: l10n.hostGroupDeleteConfirm(group.name),
    message: l10n.hostGroupDeleteBody,
    confirmLabel: l10n.hostGroupDelete,
    cancelLabel: l10n.actionCancel,
    isDestructive: true,
  );
  if (!confirmed) return;
  await ref.read(hostsControllerProvider).deleteGroup(group.id);
}
