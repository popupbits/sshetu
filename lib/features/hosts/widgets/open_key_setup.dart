import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/providers.dart';
import '../../../core/ssh/ssh_target.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../sessions/session_manager.dart';
import 'key_setup_sheet.dart';

/// Whether swapping this session's password for a key is worth offering.
///
/// Only for a live, password-authenticated session: with no connection there
/// is no way to install anything, and a host already on a key has nothing to
/// swap.
bool canSetUpKey(WidgetRef ref, String hostId) {
  final connection = ref.read(sessionManagerProvider.notifier)
      .connectionForHost(hostId);
  return connection != null &&
      connection.target.authMethod == SshAuthMethod.password;
}

/// Opens the sheet for [hostId], or says why it cannot.
Future<void> openKeySetup(
  BuildContext context,
  WidgetRef ref,
  String hostId,
) async {
  final l10n = AppLocalizations.of(context);
  final connection = ref
      .read(sessionManagerProvider.notifier)
      .connectionForHost(hostId);

  if (connection == null) {
    context.toast(l10n.keySetupUnavailable, isError: true);
    return;
  }

  final host = await ref.read(hostRepositoryProvider).byId(hostId);
  if (host == null || !context.mounted) return;

  await showKeySetupSheet(context, host: host, connection: connection);
}
